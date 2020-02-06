import asyncdispatch
import audio
import codec2
import critbits
import irc
import locks
import message
import ncurses
import os
import sequtils
import strutils
import times

const BITS_PER_SECOND = 1200
const BITS_PER_MESSAGE = 2496
# BITS_PER_MESSAGE / 8
const BYTES_PER_MESSAGE = 312
const SAMPLE_RATE = 8000
# SAMPLE_RATE * BITS_PER_MESSAGE / BITS_PER_SECOND
const BUFFER_SIZE = 16640

type
  ReceivedAudio = ref object of RootObj
    id: string
    frames: seq[int16]

var recordingAudio = false
var lastRecordingAudio = false
var audioTrackerModifyLock: Lock
initLock(audioTrackerModifyLock)

let arguments = commandLineParams()
var stdscr, wtext, wstatus, wfield: ptr window

var currServerSplit = split(arguments[0], {':'})
var currPort = Port(6667)
var currNickname = arguments[1]
var currChannel = arguments[2]
var client: AsyncIrc
var msgCnt = 0
var audioTracker = newSeq[var ReceivedAudio](0)

if currServerSplit.len >= 2:
  currPort = Port(parseInt(currServerSplit[1]))
var currServer = currServerSplit[0]

audio.init()

proc finishMain() {.noconv.} =
  audio.deinit()
  endwin()

addQuitProc(finishMain)

stdscr = initscr()
cbreak()
noecho()
scrollok(wtext, true)
nodelay(stdscr, true)
keypad(stdscr, true)

let codec = codec2Create(CODEC2_MODE_1200)
let samplesPerFrame = codec2_samples_per_frame(codec)
let bytesPerFrame = (codec2_bits_per_frame(codec) + 7) div 8

proc showMsg(msg: string) =
  waddstr(wtext, cstring(msg))
  wrefresh(wtext)

proc updateStatusbar() =
  werase(wstatus)
  wmove(wstatus, 0, 0)
  waddstr(wstatus, if recordingAudio: "[REC] " else: "[   ] ")
  var names: CritBitTree[void]
  for i in 0..<audioTracker.len:
    let id = audioTracker[i].id
    if audioTracker[i].frames.len > 0:
      names.incl(id[8..<id.len])
  var i = 0
  for name in names.keys:
    if i > 0:
      waddstr(wstatus, ", ")
    waddstr(wstatus, name)
    i += 1
  wrefresh(wstatus)

proc findAudioTracker(key: string): var ReceivedAudio =
  for i in 0..audioTracker.high:
    if audioTracker[i].id == key:
      return audioTracker[i]
  add(audioTracker, ReceivedAudio(id: key, frames: newSeq[int16](0)))
  return audioTracker[audioTracker.high]

proc calcPrivmsgSpace(nick: string, channel: string): int =
  var l = 512
  # ":[nick]![host] "
  l -= (3 + nick.len + 63)
  # "PRIVMSG [channel] :"
  l -= (10 + channel.len)
  return l

proc decodeFrame(sender: string, msg: string): bool =
  if msg.len < 8:
    return false
  let msgHeader = msg[0..7]
  let msgHeaderLower = toLower(msgHeader)
  if msgHeaderLower != "voirc01]":
    return false
  let msgEnc = msg[8..<msg.len]
  let msgKey = msgHeader & sender
  var msgDec = message.decode(msgEnc)
  var outBuf: array[SAMPLE_RATE, cshort]
  var frameHolder = findAudioTracker(msgKey)
  var inPos = 0
  var changed = frameHolder.frames.len == 0
  while inPos < msgDec.len:
    codec2_decode(codec, cast[ptr cshort](outBuf[0].addr), cast[ptr cuchar](msgDec[inPos].addr))
    acquire(audioTrackerModifyLock)
    for i in 0..<samplesPerFrame:
      add(frameHolder.frames, int16(outBuf[i]))
    release(audioTrackerModifyLock)
    inPos += bytesPerFrame
  if changed:
    updateStatusbar()
  return true

proc writeCallback(fcMin: int, fcMax: int): seq[int16] =
  var outSeq = newSeq[int16](0)
  if fcMax < 1:
    return outSeq
  for i in 0..<fcMax:
    var sample = int16(0)
    for j in 0..<audioTracker.len:
      let tracker = audioTracker[j]
      if tracker.frames.high >= i:
        sample += tracker.frames[i]
    add(outSeq, sample)
  var changed = false
  acquire(audioTrackerModifyLock)
  for j in 0..<audioTracker.len:
    if audioTracker[j].frames.len > 0:
      delete(audioTracker[j].frames, 0, min(audioTracker[j].frames.high, fcMax-1))
      changed = changed or (audioTracker[j].frames.len == 0)
  release(audioTrackerModifyLock)
  if changed:
    updateStatusbar()
  return outSeq

proc sendFrame(audioBuffer: var seq[int16]) =
  let maxFramePos = min(BUFFER_SIZE, audioBuffer.len)
  var frame: array[BUFFER_SIZE, cshort]
  var output: array[BYTES_PER_MESSAGE, cuchar]
  for i in 0..<BUFFER_SIZE:
    if audioBuffer.high >= i:
      frame[i] = audioBuffer[i]
    else:
      frame[i] = 0
  audioBuffer.delete(0, maxFramePos - 1)
  var outPos = 0
  var framePos = 0
  while framePos < maxFramePos:
    codec2_encode(codec, cast[ptr cuchar](output[outPos].addr), cast[ptr cshort](frame[framePos].addr))
    framePos += samplesPerFrame
    outPos += bytesPerFrame
  var msgCntStr = ""
  add(msgCntStr, if (msgCnt and 4) != 0: 'I' else: 'i')
  add(msgCntStr, if (msgCnt and 2) != 0: 'R' else: 'r')
  add(msgCntStr, if (msgCnt and 1) != 0: 'C' else: 'c')
  var msg = "Vo" & msgCntStr & "01]" & message.encode(output, outPos)
  var pmFuture = client.privmsg(currChannel, msg)

proc readCallback(audioBuffer: var seq[int16]) =
  if lastRecordingAudio or recordingAudio:
    if (audioBuffer.len >= BUFFER_SIZE) or (not recordingAudio):
      sendFrame(audioBuffer)
  else:
    delete(audioBuffer, 0, audioBuffer.high)
  lastRecordingAudio = recordingAudio

proc ircCallback(client: AsyncIrc, event: IrcEvent) {.async.} =
  case event.typ
  of EvConnected:
    return
  of EvDisconnected, EvTimeout:
    return
  of EvMsg:
    if event.cmd == MPrivMsg:
      if not decodeFrame(event.nick, event.params[event.params.high]):
        showMsg("\n[" & event.origin & "] <" & event.nick & "> " & event.params[event.params.high])
    elif event.cmd == MPong:
      return
    else:
      showMsg("\n" & event.raw)

var scrw, scrh: cint
var lastw = 0
var lasth = 0

getmaxyx(stdscr, scrh, scrw)
wtext = newwin(scrh - 2, scrw, 0, 0)
wstatus = newwin(1, scrw, scrh - 2, 0)
wfield = newwin(1, scrw, scrh - 1, 0)
lastw = scrw
lasth = scrh

proc processKeypresses() {.async.} =
  var msgBuf = ""
  while true:
    var c = wgetch(stdscr)
    if c < 0:
      await sleepAsync(20)
    elif c == 10 or c == 13:
      if msgBuf.len > 0 and not recordingAudio:
        var pmfuture = client.privmsg(currChannel, msgBuf)
        showMsg("\n[" & currChannel & "] <" & currNickname & "> " & msgBuf)
        msgBuf = ""
        werase(wfield)
    elif c >= 32 and c < 127:
      add(msgBuf, char(c))
      waddstr(wfield, $char(c))
      wrefresh(wfield)
    elif c == 263 or c == 127:
      if msgBuf.len > 0:
        msgBuf = msgBuf[0..(msgBuf.high-1)]
        var cx, cy: cint
        getyx(wfield, cy, cx)
        if cx >= 1:
          cx -= 1
          mvwaddch(wfield, cy, cx, 32)
          wmove(wfield, cy, cx)
          wrefresh(wfield)
    elif c == 276:
      recordingAudio = not recordingAudio
      if recordingAudio:
        msgCnt += 1
      updateStatusbar()
    elif c == 410:
      getmaxyx(stdscr, scrh, scrw)
      if (scrw != lastw) or (scrh != lasth):
        mvwin(wtext, 0, 0)
        wresize(wtext, scrh - 2, scrw)
        mvwin(wstatus, scrh - 2, 0)
        wresize(wstatus, 1, scrw)
        mvwin(wfield, scrh - 1, 0)
        wresize(wfield, 1, scrw)
        lastw = scrw
        lasth = scrh
        wrefresh(wtext)
        wrefresh(wstatus)
        wrefresh(wfield)
    else:
      showMsg("\nUnknown key: " & $c)

proc processAudio() {.async.} =
  while true:
    audio.update()
    await sleepAsync(40)

audio.init_record(SAMPLE_RATE, readCallback)
audio.init_playback(SAMPLE_RATE, writeCallback)

client = newAsyncIrc(currServer, port=currPort, nick=currNickname, joinChans = @[currChannel], callback = ircCallback)
asyncCheck client.run()
asyncCheck processAudio()

asyncCheck processKeypresses()

updateStatusbar()
runForever()
