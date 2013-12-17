/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20600 - WEEKS 9 to 12
// ASSIGNMENT 3
// CODE SKELETON
// TITLE: "Concurrent Image Filter"
//
/////////////////////////////////////////////////////////////////////////////////////////
typedef unsigned char uchar;

#include <platform.h>
#include <stdio.h>
#include "pgmIO.h"

in port buttons = PORT_BUTTON;

#define IMHT 256
#define IMWD 400

// USE CONSTANTS FOR BIT-FIELD OF WORKER QUADRANT POSITION
// NE = N & E
#define N 1
#define E 2
#define S 4
#define W 8

#define BLACK 0

#define WORKERNO 4
#define SLICEH 3
#define NSLICE (IMHT/SLICEH) // The number of full slices.
#define BLOCKSIZE (IMWD * (SLICEH+2))

// Button Input IO
#define BTNA 14
#define BTNB 13
#define BTNC 11
#define BTND 7
#define BTN_STOP 0
#define BTN_PAUSERES 1

#define WORKER_RDY 1

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from pgm file with path and name infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(char infname[], chanend c_out)
{
    int res;
    uchar line[ IMWD ];

    printf( "DataInStream:Start...\n" );

    res = _openinpgm( infname, IMWD, IMHT );
    if( res )
    {
        printf( "DataInStream:Error openening %s\n.", infname );
        return;
    }

    for( int y = 0; y < IMHT; y++ )
    {
        _readinline( line, IMWD );
        for( int x = 0; x < IMWD; x++ )
        {
            c_out <: line[ x ];
            //printf( "-%4.1d ", line[ x ] ); //uncomment to show image values
        }
        //printf( "\n" ); //uncomment to show image values
    }

    _closeinpgm();
    printf( "DataInStream:Done...\n" );
    return;
}

int getWaiting(chanend workers[], int last) {
    int waiting, i, temp;

    i = (last + 1) % WORKERNO;
    waiting = -1;
    while (waiting < 0 || waiting >= WORKERNO) {
        select {
            case workers[i] :> temp:
                if (temp == WORKER_RDY) {
                    waiting = i;
                } else {
                    printf("ISSUES\n");
                }
                break;
            default:
                break;
            }
        i = (i + 1) % WORKERNO;
    }
    return waiting;
}

// INSERTING TWO EXTRA PIXELS TO ACCOUNT FOR OVERLAP
void distributor(chanend toWorker[], chanend c_in, chanend buttonListener) {
    int cWorker, x, y, workRemaining, rdy, temp;
    uchar buffa[IMWD], buffb[IMWD], tmp;
    //Blocking till button A is pressed
    buttonListener :> cWorker;
    cWorker = 0;


    // Initialise buffb from input. buffa can stay uninitialised as it will be ignored.
    for (x = 0; x < IMWD; x++) {
    	c_in :> buffb[x];
    }

    for (workRemaining = NSLICE; workRemaining >= 1; workRemaining--) {
        cWorker = getWaiting(toWorker, cWorker);
        printf("Sending slice %d/%d to worker %d\n", NSLICE - workRemaining, NSLICE, cWorker);
        // height gives number of rows the worker must OUTPUT (i.e. input + 2)
        toWorker[cWorker] <: NSLICE - workRemaining;
        toWorker[cWorker] <: IMWD;
        toWorker[cWorker] <: SLICEH;
        if (workRemaining == NSLICE) {
        	toWorker[cWorker] <: (char) (N | E | W);
        } else {
        	toWorker[cWorker] <: (char) (E | W);
        }
        for (x = 0; x < IMWD; x++) {
            toWorker[cWorker] <: buffa[x]; // Row already output, calc only.
        }
        for (x = 0; x < IMWD; x++) {
            toWorker[cWorker] <: buffb[x]; // First row to output.
        }
        for (y = 0; y < SLICEH; y++) { // Send the rest of the output rows, as well as buffer row.
            for (x = 0; x < IMWD; x++) {
                c_in :> tmp;
                toWorker[cWorker] <: tmp;
                if (y == SLICEH - 2) {
                	// 2nd last line, i.e. final output line.
                	buffa[x] = tmp;
                } else if (y == SLICEH - 1) {
                	// Last line, the next worker will output this.
                	buffb[x] = tmp;
                }
            }
        }
        select {
            case buttonListener :> temp:
                printf("Button Paused\n");
                 while (temp != BTND) {
                     buttonListener :> temp;
                 }
                break;
            default:
                break;
        }
    }
    cWorker = getWaiting(toWorker, cWorker);
    printf("Sending final slice %d/%d to worker %d\n", NSLICE - workRemaining, NSLICE, cWorker);
    toWorker[cWorker] <: NSLICE - workRemaining;
    toWorker[cWorker] <: IMWD;
    toWorker[cWorker] <: IMHT % SLICEH;
    toWorker[cWorker] <: (char) (S | E | W);
    for (x = 0; x < IMWD; x++) {
        toWorker[cWorker] <: buffa[x]; // Row already output, calc only.
    }
    for (x = 0; x < IMWD; x++) {
        toWorker[cWorker] <: buffb[x]; // First row to output.
    }
    for (y = 1; y < IMHT % SLICEH; y++) {
        for (x = 0; x < IMWD; x++) {
            c_in :> tmp;
            toWorker[cWorker] <: tmp;
            // Can ignore buff now.
        }
    }
    for (x = 0; x < IMWD; x++) {
        toWorker[cWorker] <: (char)0; // Need to send placeholder values for final row, ala buffa at first iter.
    }

    // Need to inform workers that all work is complete.
    for (cWorker = 0; cWorker < WORKERNO; cWorker++) {
    	toWorker[cWorker] :> rdy;
		// Worker is done and asking for more. Tell it to shut off.
        toWorker[cWorker] <: 0;
		toWorker[cWorker] <: 0;
		toWorker[cWorker] <: 0;
    }

    printf( "Distributor:Done...\n" );
}

unsigned int ind(unsigned int x, unsigned int y, unsigned int width) {
	return (y * width) + x;
}

unsigned int onedge(unsigned int i, unsigned int w, unsigned int h) {
	return (i < w || i % w == 0 || i % w == w - 1 || i >= w * (h - 1));
}

void worker(int id, chanend fromDistributor, chanend toCollector) {
	char pos;
	int height, width, sliceNo, DBGSENT;
	unsigned int x, y, i;
	char temp;
	char block[BLOCKSIZE];

	fromDistributor <: WORKER_RDY;
	fromDistributor :> sliceNo;
	fromDistributor :> width;
	fromDistributor :> height; // number of output rows (sent rows = height + 2)!

	while (width > 0 && height > 0) {
		fromDistributor :> pos;

		printf("[%d] collecting %d px\n", id, (height+2) * width);
		for (i = 0; i < (height + 2) * width; i++) {
			fromDistributor :> block[i];
		}


		printf("[%d] Telling collector our slice: %d and size %d.\n", id, sliceNo, height * IMWD);
		toCollector <: sliceNo;
		toCollector <: height * IMWD;
		// TODO: width needs a buffer either side
		DBGSENT = 0;
		// Start one pixel in in either direction.
		for (y = 1; y <= height; y++) {
			for (x = 0; x < width; x++) {
				if ((y == 1 && (pos & N)) || (x == 0) || (y == height && (pos & S)) || (x == width - 1)) {
					temp = BLACK;
				} else {
					//temp = block[ind(x,y,width)];
					temp = (block[ind(x,y,width)] + block[ind(x+1,y,width)] + block[ind(x-1,y,width)] + block[ind(x,y-1,width)] + block[ind(x,y+1,width)] + block[ind(x-1,y-1,width)] + block[ind(x-1,y+1,width)] + block[ind(x+1,y-1,width)] + block[ind(x+1,y+1,width)]) / 9;
				}
				toCollector <: temp;
				DBGSENT++;
			}
		}

		printf("[%d] done slice, sent %d to collector.\n", id, DBGSENT);

		fromDistributor <: WORKER_RDY;
		fromDistributor :> sliceNo;
		fromDistributor :> width;
		fromDistributor :> height;
	}
	printf("[%d] informing collector we are done.\n", id);
	toCollector <: -1;

	printf("[%d] Worker done\n", id);
}


/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to pgm image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in)
{
    int res;
    uchar line[ IMWD ];

    printf( "DataOutStream:Start...\n" );

    res = _openoutpgm( outfname, IMWD, IMHT );
    if( res )
    {
        printf( "DataOutStream:Error opening %s\n.", outfname );
        return;
    }
    for( int y = 0; y < IMHT; y++ )
    {
        for( int x = 0; x < IMWD; x++ )
        {
            c_in :> line[ x ];
            //printf( "+%4.1d ", line[ x ] );
        }
        //printf( "\n" );
        _writeoutline( line, IMWD );
    }

    _closeoutpgm();
    printf( "DataOutStream:Done...\n" );
    return;
}

// TODO: Give workers slice counter, read count first here, find the next one, read data, loop until all slices in.
// TODO: Reduce blocking on collector.
void collector(chanend fromWorker[], chanend dataOut){
	uchar tmp;
	int i, j, cWorker, pc, idBuff[WORKERNO], sliceLen;
	cWorker = -1;
	// Buffer from other workers.
	for (i = 0; i < WORKERNO; i++) {
		idBuff[i] = -2;
	}

	for (i = 0; i <= NSLICE; i++) {
		for (j = 0; cWorker < 0 || cWorker >= WORKERNO; j = (j + 1) % WORKERNO) {
			// Attempt a read from every worker until we find the next slice ID, i.e. i. Must buffer read values to avoid reading data prematurely.
			// If idBuff[j] == -1, that worker is dead. If < -1, read.
			if (idBuff[j] < -1) {
				fromWorker[j] :> idBuff[j];
				printf("Collector: [%d] told us it has %d\n", j, idBuff[j]);
			}
			if (idBuff[j] == i) {
				cWorker = j;
				idBuff[j] = -2;
			}
		}

		fromWorker[cWorker] :> sliceLen;

		printf("Collector: Reading slice %d of size %d from [%d]\n", i, sliceLen, cWorker);
		for (pc = 0; pc < sliceLen; pc++) {
			fromWorker[cWorker] :> tmp;
			dataOut <: tmp;
		}
		printf("Collector: Read done\n");
		cWorker = -1;
	}

	printf("Collector quitting.\n");
}

//READ BUTTONS and send commands to Visualiser
void buttonListener(in port buttons, chanend toDistributor) {
    int buttonInput; //button pattern currently pressed
    unsigned int running = 1; //helper variable to determine system shutdown
    int paused = 1;
    // User is choosing starting positions of particles
//    buttons when pinsneq(15) :> buttonInput;
//    buttons when pinseq(15) :> void;
    while (running) {
        buttons when pinsneq(15) :> buttonInput;
        buttons when pinseq(15) :> void;
        switch (buttonInput) {
        case BTNA:
            // A = Start
            if (paused) {
                paused = 0;
                toDistributor <: BTN_PAUSERES;
            }
            break;
        case BTNB:
            // B = Pause
            if (!paused) {
                toDistributor <: BTN_PAUSERES;
                paused = 1;
            }
            break;
        case BTNC:
            // C = Quit
            if (paused) {
                toDistributor <: BTN_PAUSERES;
            }
            toDistributor <: BTN_STOP;
            running = 0;
            paused = 0;
            break;
        case BTND:
            // D = Noop
            if (paused) {
                toDistributor <: BTND;
                paused = 0;
            }
            break;
        }
    }
}


//MAIN PROCESS defining channels, orchestrating and starting the threads
int main() {
//    char infname[] = "src/test0.pgm"; //put your input image path here
//    char outfname[] = "bin/testout.pgm"; //put your output image path here
    chan c_inIO, c_outIO, fromWorker[WORKERNO], toWorker[WORKERNO], bListener; //extend your channel definitions here

    par //extend/change this par statement to implement your concurrent filter
    {
        //on stdcore[0]: DataInStream( "src/test0.pgm", c_inIO );
    	on stdcore[0]: DataInStream( "src/BristolCathedral.pgm", c_inIO );
        on stdcore[0]: distributor( toWorker, c_inIO, bListener );
        on stdcore[0]: DataOutStream( "bin/testout.pgm", c_outIO );
        on stdcore[0]: collector(fromWorker, c_outIO);
        on stdcore[0]: buttonListener(buttons, bListener);
        par (int i=0;i<WORKERNO;i++) {
        	on stdcore[i%4] : worker(i, toWorker[i], fromWorker[i]);
        }
    }

    return 0;
}

