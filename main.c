
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

#include <stdio.h>
#include <stdlib.h>
#include <SDL.h>
#include <SDL_image.h>

int *map;
int w, h;
#define NUM_BLOCKS 3000

typedef struct {
int x1, y1, x2, y2;
} Block;


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
					}
		if(flag == 0)
			break;
	}
}

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


int main(int argc, char **argv) {
	SDL_Surface *img;
	int bpp;
	char bg[4];
	int i;
	int color = 2;
	int j;
	Block blocks[NUM_BLOCKS];
	int mblocks[NUM_BLOCKS];
	int counter;
	FILE *f;

	if(argc < 3) {
		fprintf(stdout, "usage: %s input_image output_spec [output_bmp]\n", argv[0]);
		exit(1);
	}

	
	img = IMG_Load(argv[1]);
	if(img == 0) {	
		fprintf(stdout, "Cann't load file %s\n", argv[1]);
		exit(1);
	}

	bpp = img->format->BytesPerPixel;
	if(bpp != 3 && bpp != 4) {
		fprintf(stdout, "Image file should have 3 or 4 bytes per pixel color depth\n");
		exit(1);
	}

	
	w = img->w;
	h = img->h;
	map = malloc(w * h * sizeof(int));
	if(map == NULL) {
		fprintf(stdout, "Cann't allocate memory for map\n");
		exit(1);
	}
	
	if(SDL_LockSurface(img) != 0) {
		fprintf(stdout, "Cann't lock surface\n");
		exit(1);
	}
	
	memcpy(bg, img->pixels, bpp);
	
	for(i = 0; i < w * h; i++)
		if(memcmp(&img->pixels[i*bpp], bg, bpp) == 0)
			map[i] = 0;
		else
			map[i] = 1;
	
	SDL_UnlockSurface(img);

	
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

	
	for(i = 0; i < NUM_BLOCKS; i++) {
		blocks[i].x1 = 0;
		blocks[i].y1 = 0;
		blocks[i].x2 = 0;
		blocks[i].y2 = 0;
		mblocks[i] = 0;
	}
	
	counter = 0;
	
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
	
				if(mblocks[color] == 0)
					counter++;
				mblocks[color] = 1;
			}
		}
	
	f = fopen(argv[2], "wt");
	if(f == NULL) {
		fprintf(stdout, "Cann't open file %s to save info\n", argv[2]);
		exit(1);
	}
	
	if(fprintf(f, "%s\n", argv[1]) < 0) {
		fprintf(stdout, "Cann't save image filename %s into %s\n", argv[1], argv[2]);
		exit(1);
	}
	
	if(fprintf(f, "%d\n", counter) < 0) {
		fprintf(stdout, "Cann't save number of characters into %s\n", argv[2]);
		exit(1);
	}
	
	for(i = 0; i < NUM_BLOCKS; i++) {
		Block *b = &blocks[i];
		if(b->x1 != 0 || b->y1 != 0 || b->x2 != 0 || b->y2 != 0)
			if(fprintf(f, "%d %d %d %d\n", b->x1, b->y1, b->x2, b->y2) < 0) {
			 	fprintf(stdout, "Cann't save block\n");
			 	exit(1);
			}
	}

	
	if(argc == 4) {
		SDL_LockSurface(img);
		for(i = 0; i < NUM_BLOCKS; i++) {
		 	Block *b = &blocks[i];
		 	char t[4];
	
			if(b->x1 == 0 && b->y1 == 0 && b->x2 == 0 && b->y2 == 0)
				continue;
			
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
			}
			
			for(j = b->x1; j <= b->x2; j++) {
				memcpy(&img->pixels[(b->y1*w + j)*bpp], t, bpp);
				memcpy(&img->pixels[(b->y2*w + j)*bpp], t, bpp);
			}
			for(j = b->y1; j <= b->y2; j++) {
				memcpy(&img->pixels[(j*w + b->x1)*bpp], t, bpp);
				memcpy(&img->pixels[(j*w + b->x2)*bpp], t, bpp);
			}
		}
		SDL_UnlockSurface(img);
	
		SDL_SaveBMP(img, argv[3]);
	}

	
	SDL_FreeSurface(img);
	free(map);
	return 0;
}