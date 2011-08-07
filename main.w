
qwfont - первые 2-е буквы выбрал от балды

31 июля 2011

qwfont ищет буквы на картинке и создаёт текстовый файл
с их координатами. Вспомогательная тулза для danmaku,
чтобы там были не моноширинные шрифты -_-

Итак, на картинке раскиданы буквы, они не пересекаются друг с
другом. Но буквы не выстроены в строки и столбцы, те каждая сама по
себе.

Некоторые "вредные" буквы, такие как ё, й и прочие иероглифы, имеют
элементы которые отделены от других частей. Видимо поэтому выходной
файл придётся допиливать руками :(

Тулза переводит изначальную картинку в двухцветную, затем проходит
её точка за точкой и закрашивает ещё не закрашеные участки. После
того как очередной участок закрашен, она вписывает его в прямоугольник
и закрашивает элементы в нём, причём если встретит уже закрашеный
элемент, то делает отметку в журнале, что это один и тот же элемент.
После того как всё закрашено программа создаёт файл со строками вида:
X1 Y1 X2 Y2
те с координатами символов.

@o Makefile @{
CC=gcc
MYWEB=~/MyWork/myweb/myweb.py
LDFLAGS+=@<Ldflags@>
CFLAGS+=@<Cflags@>

qwfont: main.o
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

main.o: main.c
	$(CC) $(CFLAGS) -c $<

main.c: main.w
	$(MYWEB) $^
@}

@o main.c @{
@<License@>
@<Headers@>
@<Global variables@>

@<Functions@>

int main(int argc, char **argv) {
	@<Variables@>

	@<Check params@>
	@<Load image@>
	@<Check image@>
	@<Create twocolors map@>
	@<Paint map@>
	@<Save characters boxes@>
	@<Save BMP@>
	@<Free@>
	return 0;
}@}

Проверим переданные параметры(их должно быть два):
@d Check params @{@-
if(argc < 3) {
	fprintf(stdout, "usage: %s input_image output_spec [output_bmp]\n", argv[0]);
	exit(1);
}
@}

@d Headers @{@-
#include <stdio.h>
#include <stdlib.h>@}

Загрузим картинку:
@d Variables @{@-
SDL_Surface *img;@}

@d Load image @{
img = IMG_Load(argv[1]);
if(img == 0) {	
	fprintf(stdout, "Can't load file %s\n", argv[1]);
	exit(1);
}
@}

@d Free @{
SDL_FreeSurface(img);@}

@d Headers @{
#include <SDL.h>
#include <SDL_image.h>@}

@d Cflags @{@-
`sdl-config --cflags`@}

@d Ldflags @{@-
`sdl-config --libs` -lSDL_image@}

Проверим глубину цвета картинки:
@d Check image @{@-
bpp = img->format->BytesPerPixel;
if(bpp != 3 && bpp != 4) {
	fprintf(stdout, "Image file should have 3 or 4 bytes per pixel color depth\n");
	exit(1);
}
@}

@d Variables @{
int bpp;@}

Создадим карту цветов. Цвет с позицией (0,0) будет считаться цветом фона,
остальные будут обозначены как нейтральный цвет:
@d Create twocolors map @{
w = img->w;
h = img->h;
map = malloc(w * h * sizeof(int));
if(map == NULL) {
	fprintf(stdout, "Can't allocate memory for map\n");
	exit(1);
}

if(SDL_LockSurface(img) != 0) {
	fprintf(stdout, "Can't lock surface\n");
	exit(1);
}

memcpy(bg, img->pixels, bpp);

for(i = 0; i < w * h; i++)
	if(memcmp(&img->pixels[i*bpp], bg, bpp) == 0)
		map[i] = 0;
	else
		map[i] = 1;

SDL_UnlockSurface(img);
@}

@d Free @{
free(map);@}

@d Variables @{
char bg[4];
int i;@}

@d Global variables @{
int *map;
int w, h;@}

Закрасим карту цветов. Для этого нам понадобиться счётчик цвета:
@d Variables @{
int color = 2;@}
Он равен 2, так как 0 - это цвет фона, а 1 цвет не проверенного элемента.

Чтобы не хранить карту один-к-многим будем закрашивать элемент в прямоугольнике
в цвет элемента, который вписан в этот прямоугольник.

Нужeн массив структур прямоугольников следующего вида:
X1 Y1 X2 Y2
если все равны 0, то прямоугольник отсутствует.
@d Global variables @{
#define NUM_BLOCKS 3000

typedef struct {
int x1, y1, x2, y2;
} Block;@}


Функция закрашивающая в нужный цвет:
@d Functions @{
void paint(int x, int y, int color, Block *out) {
	Block b = {x, y, x, y};
	int i, j;
	int flag;

	map[y*w + x] = color;

	out->x1 = x;
	out->y1 = y;
	out->x2 = x;
	out->y2 = y;

	while(1) {
		b.x1 = b.x1 - 1 > 0 ? b.x1 - 1 : 0;
		b.y1 = b.y1 - 1 > 0 ? b.y1 - 1 : 0;
		b.x2 = b.x2 + 1 < w ? b.x2 + 1 : w;
		b.y2 = b.y2 + 1 < h ? b.y2 + 1 : h;

		flag = 0;
		@<Paint pixels@>
		if(flag == 0)
			break;
	}
}
@}

Закрасим точку, если соседняя имеет цвет color. Не забудем установить
флаг flag, который подтвердит, то что итерация не прошла в холостую.
@d Paint pixels @{@-
for(j = b.y1; j < b.y2; j++)
	for(i = b.x1; i < b.x2; i++)
		if(map[j*w + i] != 0 && map[j*w + i] != color)
			if((i < w-1 && map[j*w + (i + 1)] == color) ||
				(j < h-1 && map[(j + 1)*w + i] == color) ||
				(i > 0 && map[j*w + (i - 1)] == color) ||
				(j > 0 && map[(j - 1)*w + i] == color) ||
				(i < w-1 && j > 0 && map[(j - 1)*w + (i + 1)] == color) ||
				(i > 0 && j > 0 && map[(j - 1)*w + (i - 1)] == color) ||
				(i < w-1 && j < h-1 && map[(j + 1)*w + (i + 1)] == color) ||
				(i > 0 && j < h-1 && map[(j + 1)*w + (i - 1)] == color)) {
				if(i < out->x1)
					out->x1 = i;
				else if(i > out->x2)
					out->x2 = i;
				if(j < out->y1)
					out->y1 = j;
				else if(j > out->y2)
					out->y2 = j;
				map[j*w + i] = color;
				flag = 1;
			}@}

Следующая функция принимает координаты прямоугольника, закрашивает
найденые точки по вышеописанным правилам и возвращает координаты
левого-верхнего и правого-нижнего угола прямоугольника в который
внисана закрашеная фигура. Координаты прямоугольника, которые
передаются В функцию ограничивают лишь поиск, но не ограничивают закраску.
@d Functions @{
void paint_block(const Block inBlock, int color, Block *outBlock) {
	Block t;
	int f = 0;
	int i, j;

	for(j = inBlock.y1; j < inBlock.y2; j++)
		for(i = inBlock.x1; i < inBlock.x2; i++)
			if(map[j*w + i] != color && map[j*w + i] != 0) {
				paint(i, j, color, &t);
				if(f == 0) {
					f = 1;
					*outBlock = t;
				} else {
					if(outBlock->x1 > t.x1)
						outBlock->x1 = t.x1;
					else if(outBlock->x2 < t.x2)
						outBlock->x2 = t.x2;
					if(outBlock->y1 > t.y1)
						outBlock->y1 = t.y1;
					else if(outBlock->y2 < t.y2)
						outBlock->y2 = t.y2;
				}
			}
}
@}

Ищем ещё не закрашеные участки, закрашиваем их и закрашиваем
вписаные в них участки, далее закрашиваем вписаные в эти участки участки
и так далее:
@d Paint map @{
for(j = 0; j < h; j++)
	for(i = 0; i < w; i++)
		if(map[j*w + i] == 1) {
			Block b, c;
			paint(i, j, color, &b);
			while(1) {
				paint_block(b, color, &c);
				if(b.x1 == c.x1 && b.y1 == c.y1 &&
					b.x2 == c.x2 && b.y2 == c.y2)
					break;
				b = c;
			}
			color++;
		}
@}

@d Variables @{
int j;@}

Найдем на карте все закрашеные участки и координаты прямоугольников в
которые они вписаны.
@d Variables @{
Block blocks[NUM_BLOCKS];
int mblocks[NUM_BLOCKS];
int counter;@}
mblocks - набор флагов, которые будет использоваться для подсчёта прямоугольников
счётчиком counter.

@d Save characters boxes @{
for(i = 0; i < NUM_BLOCKS; i++) {
	blocks[i].x1 = 0;
	blocks[i].y1 = 0;
	blocks[i].x2 = 0;
	blocks[i].y2 = 0;
	mblocks[i] = 0;
}

counter = 0;
@<Find corners of blocks@>

f = fopen(argv[2], "wt");
if(f == NULL) {
	fprintf(stdout, "Can't open file %s to save info\n", argv[2]);
	exit(1);
}

if(fprintf(f, "%s\n", argv[1]) < 0) {
	fprintf(stdout, "Can't save image filename %s into %s\n", argv[1], argv[2]);
	exit(1);
}

if(fprintf(f, "%d\n", counter) < 0) {
	fprintf(stdout, "Can't save number of characters into %s\n", argv[2]);
	exit(1);
}

for(i = 0; i < NUM_BLOCKS; i++) {
	Block *b = &blocks[i];
	if(b->x1 != 0 || b->y1 != 0 || b->x2 != 0 || b->y2 != 0)
		if(fprintf(f, "%d %d %d %d\n", b->x1, b->y1, b->x2, b->y2) < 0) {
		 	fprintf(stdout, "Can't save block\n");
		 	exit(1);
		}
}
@}

@d Variables @{
FILE *f;@}

@d Find corners of blocks @{
for(i = 0; i < w; i++)
	for(j = 0; j < h; j++) {
		int color = map[j*w + i];

		if(color >= NUM_BLOCKS) {
			fprintf(stdout, ">= NUM_BLOCKS\n");
			exit(1);
		}

		if(color > 1) {
			Block *b;

			color -= 2;

			b = &blocks[color];

			if(b->x1 == 0 && b->y1 == 0 && b->x2 == 0 && b->y2 == 0) {
				b->x1 = i;
				b->y1 = j;
				b->x2 = i;
				b->y2 = j;
			}

			if(b->x1 > i)
				b->x1 = i;
			else if(b->x2 < i)
				b->x2 = i;
			if(b->y1 > j)
				b->y1 = j;
			else if(b->y2 < j)
				b->y2 = j;

			@<Mark mblocks and increase counter@>
		}
	}@}
Вычитаем из color 2 так как 0 - фон, а 1 - нейральный цвет -- они нам не интересны.

@d Mark mblocks and increase counter @{@-
if(mblocks[color] == 0)
	counter++;
mblocks[color] = 1;@}

@d Save BMP @{
if(argc == 4) {
	SDL_LockSurface(img);
	for(i = 0; i < NUM_BLOCKS; i++) {
	 	Block *b = &blocks[i];
	 	char t[4];

		@<Skip empty block@>
		@<Choose color of border@>
		@<Draw border@>
	}
	SDL_UnlockSurface(img);

	SDL_SaveBMP(img, argv[3]);
}
@}

@d Skip empty block @{@-
if(b->x1 == 0 && b->y1 == 0 && b->x2 == 0 && b->y2 == 0)
	continue;@}

@d Choose color of border @{
if(bpp == 3) {
	if(img->format->Rmask == 0x000000ff) {
		t[0] = 0;
		t[1] = 0;
		t[2] = 255; // red
	} else {
		t[0] = 255; // red
		t[1] = 0;
		t[2] = 0;
	}
} else {
	if(img->format->Rmask == 0x000000ff) {
		t[0] = 255; // alpha
		t[1] = 0;
		t[2] = 0;
		t[3] = 255; // red
	} else {
		t[0] = 255; // red
		t[1] = 0;
		t[2] = 0;
		t[3] = 255; // alpha
	}
}@}

@d Draw border @{
for(j = b->x1; j <= b->x2; j++) {
	memcpy(&img->pixels[(b->y1*w + j)*bpp], t, bpp);
	memcpy(&img->pixels[(b->y2*w + j)*bpp], t, bpp);
}
for(j = b->y1; j <= b->y2; j++) {
	memcpy(&img->pixels[(j*w + b->x1)*bpp], t, bpp);
	memcpy(&img->pixels[(j*w + b->x2)*bpp], t, bpp);
}@}

@d License @{@-
/*
 * qwfont - helper for creating font files
 * Copyright (C) 2011 Iljasov Ramil
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
@}