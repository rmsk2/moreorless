RM=rm
PORT=/dev/ttyUSB0
SUDO=

BINARY=f_edit
FORCE=-f

ifdef WIN
RM=del
PORT=COM3
SUDO=
FORCE=
endif


all: pgz
pgz: $(BINARY).pgz

$(BINARY): *.asm
	64tass --nostart -o $(BINARY) main.asm

clean: 
	$(RM) $(FORCE) $(BINARY)
	$(RM) $(FORCE) $(BINARY).pgz
	$(RM) $(FORCE) tests/bin/*.bin

upload: $(BINARY).pgz
	$(SUDO) python fnxmgr.zip --port $(PORT) --run-pgz $(BINARY).pgz


$(BINARY).pgz: $(BINARY)
	python make_pgz.py $(BINARY)

test:
	6502profiler verifyall -c config.json -trapaddr 0x07FF
