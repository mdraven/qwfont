
CC=gcc
MYWEB=~/MyWork/myweb/myweb.py
LDFLAGS+=`sdl-config --libs` -lSDL_image
CFLAGS+=`sdl-config --cflags`

qwfont: main.o
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

main.o: main.c
	$(CC) $(CFLAGS) -c $<

main.c: main.w
	$(MYWEB) $^
