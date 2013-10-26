#include <stdio.h>

typedef struct Loc {
	int x;
	int y;
} Loc;

Loc loc(int x, int y) {
	Loc ret;
	ret.x = x;
	ret.y = y;
	return ret;
}

typedef unsigned char fert;

void queen(chanend ch, chanend ch1) {
	fert collected = 0;
	fert recv;
	fert recv1;
	for (int i = 0; i < 2; i++) {
		printf("Waiting for workers to report harvest. Current total = %d\n", collected);
		ch :> recv;
		ch1 :> recv1;
		if (recv <= recv1) {
			ch <: 1;
			ch1 <: 0;
			collected += recv1;
		}
		else {
			ch <: 0;
			ch1 <: 1;
			collected += recv;
		}
		//collected += recv + recv1;
	}
	printf("Harvest finished, food collected = %d\n", collected);
}

int goEast(Loc p, fert world[3][4]) {
	return (world[p.y][p.x + 1] > world[p.y + 1][p.x]);
}

void antz(chanend ch, Loc place, fert world[3][4]) {
	int move;
	for (int i = 0; i < 2; i++) {
		ch <: world[place.y][place.x];
		ch :> move;
		if (move) {
			for (int j = 0; j < 2; j++) {
				if (goEast(place, world)) {
					place.x += 1;
				} else {
					place.y += 1;
				}
			}
		}
	}

}

int main(void) {
	fert world[3][4] = {{10, 0, 1, 7}, {2, 10, 0, 3}, {6, 8, 7, 6}};
	fert world1[3][4] = {{10, 0, 1, 7}, {2, 10, 0, 3}, {6, 8, 7, 6}};

	chan ch, ch1, ch2;
	Loc start = loc(0,1);
	Loc start1 = loc(1,0);
	par {
		queen(ch, ch1);
		antz(ch, start, world);
		antz(ch1, start1, world1);
	}
	return 0;
}
