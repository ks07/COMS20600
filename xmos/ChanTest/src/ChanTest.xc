#include <platform.h>
#include <stdio.h>

void p(chanend other) {
	int read;
	other <: 1;
	other :> read;
	printf("%d\n", read);
}

void p2(chanend other) {
	int read;
	other :> read;
	other <: 1;
	printf("p2: %d\n", read);
}

int main() {
	chan c;

	par {
		on stdcore[0] : p(c);
		on stdcore[1] : p2(c);
	}
	return 0;
}
