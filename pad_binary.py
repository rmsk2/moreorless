import sys

BLOCK_LEN = 8192

start_offset = 0x0300
num_blocks = 3

with open(sys.argv[1], "rb") as f:
    data = f.read()

bytes_left = (num_blocks * BLOCK_LEN) - (len(data) + start_offset)

if bytes_left < 0:
    print("Binary is too large. We need another 8K block. Adapt this program, the loader, the makefile and bulk.csv")
    sys.exit(42)

print(f"Bytes left in last 8K block: {bytes_left}")

data = bytearray(start_offset) + data
end_pad = bytearray(BLOCK_LEN)
data = data + end_pad[0:(num_blocks * BLOCK_LEN) - len(data)]

start_offset = 0
end_offset = BLOCK_LEN

for i in range(num_blocks):
    file_name = f"{sys.argv[1]}{i+1:02x}.bin"

    with open(file_name, "wb") as f:
        f.write(data[start_offset:end_offset])
    
    start_offset += BLOCK_LEN
    end_offset += BLOCK_LEN
    