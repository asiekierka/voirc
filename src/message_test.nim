import message

const BYTES_PER_MESSAGE = 312

var input = newSeq[cuchar](0)
for i in 0..<BYTES_PER_MESSAGE:
  add(input, cuchar((i and 0x1E) + 67))

let tmp = message.encode(input, input.len)
let output = message.decode(tmp)

for i in 0..<BYTES_PER_MESSAGE:
  if input[i] != output[i]:
    echo("MISMATCH @ ", i, ": ", input[i], " != ", output[i])
  else:
    echo("MATCH @ ", i, ": ", input[i], " == ", output[i])
