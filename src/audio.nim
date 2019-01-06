import sequtils
import soundio

var audioReaderFunc: proc(buffer: var seq[int16])
var audioWriterFunc: proc(frameCountMin: int, frameCountMax: int): seq[int16] 
var audioBuffer = newSeq[int16](0)
var sio: ptr SoundIo

proc readCallback(inStream: ptr SoundIoInStream, frameCountMin: cint, frameCountMax: cint) {.cdecl.} =
  var areas: ptr SoundIoChannelArea
  var framesLeft = frameCountMax
  
  while true:
    var frameCount = framesLeft
    var err = inStream.begin_read(areas.addr, frameCount.addr)
    if frameCount <= 0:
      break
    for frame in 0..<frameCount:
      var ptrSample = cast[ptr int16](cast[int](areas.pointer) + frame*areas.step)
      audioBuffer.add(ptrSample[])
    err = inStream.end_read()
    framesLeft -= frameCount
    if framesLeft <= 0:
      break
  
  audioReaderFunc(audioBuffer)

proc writeCallback(outStream: ptr SoundIoOutStream, frameCountMin: cint, frameCountMax: cint) {.cdecl.} =
  let data = audioWriterFunc(frameCountMin, frameCountMax)
  var areas: ptr SoundIoChannelArea
  var framesLeft = frameCountMax
  var framePos = 0
  
  while true:
    var frameCount = framesLeft
    var err = outStream.beginWrite(areas.addr, frameCount.addr)
    if frameCount <= 0:
      break
    let layout = outStream.layout
    for frame in 0..<frameCount:
      let sample = data[framePos + frame]
      for channel in 0..<layout.channelCount:
        let ptrArea = cast[ptr SoundIoChannelArea](cast[int](areas) + channel * (sizeof SoundIoChannelArea))
        var ptrSample = cast[ptr int16](cast[int](ptrArea.pointer) + frame*ptrArea.step)
        ptrSample[] = int16(sample)
    err = outStream.endWrite()
    framesLeft -= frameCount
    framePos += frameCount
    if framesLeft <= 0:
      break  

proc init*() =
  sio = soundioCreate()
  if sio.isNil:
    quit "out of memory"
  
  if sio.connect() > 0:
    quit "unable to connect to backend"
  
  echo "Backend: ", sio.currentBackend.name
  sio.flushEvents()

proc init_record*(sampleRate: int, afunc: proc(buffer: var seq[int16])) =
  audioReaderFunc = afunc
  
  let devID = sio.defaultInputDeviceIndex
  let microphone = sio.getInputDevice(devID)
  if microphone.isNil:
    quit "out of memory"
  if microphone.probeError > 0:
    quit "unable to connect to device"

  echo "Microphone: ", microphone.name
  
  let micStream = microphone.inStreamCreate()
  micStream.format = SoundIoFormatS16NE
  micStream.sample_rate = cast[cint](sampleRate)
  micStream.read_callback = readCallback
  let err = micStream.open()
  if err > 0:
    quit "unable to start listening (1)" & $err
  if micStream.layoutError > 0:
    quit "unable to start listening (2)" & $micStream.layoutError
  if micStream.start() > 0:
    quit "unable to start listening (3)"

proc init_playback*(sampleRate: int, afunc: proc(frameCountMin: int, frameCountMax: int): seq[int16]) =
  audioWriterFunc = afunc
  
  let devID = sio.defaultOutputDeviceIndex
  let speaker = sio.getOutputDevice(devID)
  if speaker.isNil:
    quit "out of memory"
  if speaker.probeError > 0:
    quit "unable to connect to device"

  echo "Speaker: ", speaker.name
  
  let outStream = speaker.outStreamCreate()
  outStream.format = SoundIoFormatS16NE
  outStream.sample_rate = cast[cint](sampleRate)
  outStream.write_callback = writeCallback
  let err = outStream.open()
  if err > 0:
    quit "unable to start playing (1)" & $err
  if outStream.layoutError > 0:
    quit "unable to start playing (2)" & $outStream.layoutError.strerror
  if outStream.start() > 0:
    quit "unable to start playing (3)"

proc update*() =
  sio.flushEvents()

proc deinit*() =
  sio.destroy()
