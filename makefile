RM=rm
PORT=/dev/ttyUSB0
SUDO=
FORCE=-f
PYTHON=python3

ifdef WIN
RM=del
PORT=COM3
SUDO=
FORCE=
PYTHON=python
endif

BINARY=mless
KEYVAL=keyval
LOADER=loader.bin

FLASHBLOCKS = $(BINARY)01.bin $(BINARY)02.bin $(BINARY)03.bin
ZIP = mless_flash.zip

.PHONY: all
all: editor validator

.PHONY: validator
validator: $(KEYVAL).pgz

.PHONY: editor
editor: $(BINARY).pgz

.PHONY: clean
clean: 
	$(RM) $(FORCE) $(BINARY)
	$(RM) $(FORCE) $(BINARY).pgz
	$(RM) $(FORCE) $(KEYVAL)
	$(RM) $(FORCE) $(KEYVAL).pgz
	$(RM) $(FORCE) tests/bin/*.bin
	$(RM) $(FORCE) *.bin
	$(RM) $(FORCE) $(ZIP)

.PHONY: scrub
scrub: zeroes.dat
	$(SUDO) $(PYTHON) fnxmgr.zip --port $(PORT) --flash-bulk bulk_scrub.csv

.PHONY: upload
upload: $(BINARY).pgz
	$(SUDO) $(PYTHON) fnxmgr.zip --port $(PORT) --run-pgz $(BINARY).pgz

.PHONY: validate
validate: $(KEYVAL).pgz
	$(SUDO) $(PYTHON) fnxmgr.zip --port $(PORT) --run-pgz $(KEYVAL).pgz

.PHONY: test
test:
	6502profiler verifyall -c config_768.json -trapaddr 0x07FF

$(BINARY): *.asm
	64tass --nostart -o $(BINARY) main.asm

$(BINARY).pgz: $(BINARY)
	$(PYTHON) make_pgz.py $(BINARY)

$(KEYVAL): api.asm zeropage.asm setup.asm clut.asm arith16.asm txtio.asm khelp.asm key_repeat.asm keyval.asm
	64tass --nostart -o $(KEYVAL) keyval.asm

$(KEYVAL).pgz: $(KEYVAL)
	$(PYTHON) make_pgz.py $(KEYVAL)

.PHONY: flash
flash: $(LOADER) blocks
	$(SUDO) $(PYTHON) fnxmgr.zip --port $(PORT) --flash-bulk bulk.csv

$(LOADER): flashloader.asm
	64tass --nostart -o $(LOADER) flashloader.asm

.PHONY: blocks
blocks: $(FLASHBLOCKS)

$(FLASHBLOCKS) &: $(BINARY)
	$(PYTHON) pad_binary.py $(BINARY)

.PHONY: dist
dist: $(LOADER) $(FLASHBLOCKS) $(BINARY).pgz
	zip $(ZIP) $(LOADER) $(FLASHBLOCKS) bulk.csv
