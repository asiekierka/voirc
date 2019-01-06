proc encode*(inArray: openArray[cuchar], maxLen: int): string =
  var outString = ""
  var inValue = int(0)
  var inBits = int(0)
  # turn every 13 bits into an output char pair. that's the spirit!
  for i in 0..<maxLen:
    inValue = inValue or (int(inArray[i]) shl inBits)
    inBits += 8
    if (inBits >= 13) or (i == inArray.high):
      let chValue = (inValue and 0x1FFF)
      inValue = inValue shr 13
      inBits -= 13
      add(outString, char(33 + (chValue div 94)))
      add(outString, char(33 + (chValue mod 94)))
  return outString

proc decode*(inString: string): seq[cuchar] =
  var outSeq = newSeq[cuchar](0)
  var outValue = int(0)
  var outBits = int(0)
  if (inString.len mod 2) == 1:
    return outSeq
  for i in countup(0,inString.len-1,2):
    var tmpValue = ((int(inString[i])-33)*94) + (int(inString[i+1])-33)
    outValue = outValue or (tmpValue shl outBits)
    outBits += 13
    while (outBits >= 8):
      add(outSeq, cuchar(outValue and 0xFF))
      outValue = outValue shr 8
      outBits -= 8
  return outSeq
