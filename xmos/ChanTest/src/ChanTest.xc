#include <platform.h>
#include <stdio.h>

void p(chanend other) {
	int read;
	select {
		case other :> read:
			printf("read\n");
			break;
		default:
			printf("skipping\n");
			break;
	}
	printf("done\n");
}

void p2(chanend other) {
	/*int read;
	other :> read;
	other <: 1;
	printf("p2: %d\n", read);*/
}

int main() {
//	int i, j;
//	unsigned int userAntToDisplay = 2;
//	unsigned int attackerAntToDisplay = 3;
//	j = 16<<(userAntToDisplay%3);
//				i = 16<<(attackerAntToDisplay%3);
//				printf("q0 %d\n", (j*(userAntToDisplay/3==0)) + (i*(attackerAntToDisplay/3==0)));
//				printf("q1 %d\n", (j*(userAntToDisplay/3==1)) + (i*(attackerAntToDisplay/3==1)));
//				printf("q2 %d\n", (j*(userAntToDisplay/3==2)) + (i*(attackerAntToDisplay/3==2)));
//				printf("q3 %d\n", (j*(userAntToDisplay/3==3)) + (i*(attackerAntToDisplay/3==3)));
	chan c;

	par {
		on stdcore[0] : p(c);
		on stdcore[1] : p2(c);
	}
	return 0;
}
