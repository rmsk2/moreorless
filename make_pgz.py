import sys
import os

start_address = 0x0300

def make_24bit_address(addr):
    help, lo = divmod(addr, 256)
    higher, hi = divmod(help, 256)
    return (lo, hi, higher)

l, h, hh = make_24bit_address(os.path.getsize(sys.argv[1]))
sl, sh, shh = make_24bit_address(start_address)

pgz_header = bytes([90, sl, sh, shh, l, h, hh])
pgz_footer = bytes([sl, sh, shh, 0, 0, 0])

with open(sys.argv[1], "rb") as f:
    data = f.read()


with open(sys.argv[1]+".pgz", "wb") as f:
    f.write(pgz_header)
    f.write(data)
    f.write(pgz_footer)


