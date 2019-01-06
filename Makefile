all: voirc

voirc: src/main.nim src/audio.nim src/message.nim lib/codec2.nim
	nim c --threads:on --tlsEmulation:off --gc:stack -d:release src/main.nim
	mv src/main voirc

clean:
	rm voirc
