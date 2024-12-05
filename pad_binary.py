import sys

start_offset = 0x0300

with open(sys.argv[1], "rb") as f:
    data = f.read()

if (len(data) + start_offset) > (3*8192):
    print("Binary is too large. We need another 8K block. Adapt this program, the loader and bulk.csv")
    sys.exit(42)

data = bytearray(start_offset) + data
end_pad = bytearray(8192)
data = data + end_pad[0:3 * 8192 - len(data)]

with open(sys.argv[1]+"01.bin", "wb") as f:
    f.write(data[:8192])

with open(sys.argv[1]+"02.bin", "wb") as f:
    f.write(data[8192:16384])

with open(sys.argv[1]+"03.bin", "wb") as f:
    f.write(data[16384:])
