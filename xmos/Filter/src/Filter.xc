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
#define SLICEH 5
#define NSLICE (int)(IMHT/SLICEH)
//#define BLOCKSIZE (IMWD) * ((IMHT / WORKERNO) + 2) //130*130 //ENLARGE FOR GREATER THAN 256 * 256, CURRENTLY (256*256)/4
#define BLOCKSIZE IMWD * SLICEH

#define WORKER_RDY -1

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


/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to farm out parts of the image...
//
/////////////////////////////////////////////////////////////////////////////////////////

// INSERTING TWO EXTRA PIXELS TO ACCOUNT FOR OVERLAP
void distributor(chanend toWorker[], chanend c_in) {
    uchar val;
    int i, pc, wc, pwc, slicesDone, currWorker;
    int first = 1;
    int sCount = 1; // The last slice we sent a size to.

    int workerLen[WORKERNO];

    printf( "ProcessImage:Start, size = %dx%d\n", IMHT, IMWD );

    for (slicesDone = 0; slicesDone <= NSLICE; slicesDone++) {
		for (pwc = 0; pwc < workerLen[slicesDone]; pwc++) {
			c_in :> val;
			toWorker[slicesDone] <: val;
		}
		currWorker = (currWorker + 1) % WORKERNO;
	}

    /*    	for (i = 0; i < WORKERNO; i++) {
    		toWorker[i] <: (int) IMWD;
    		if (first && sCount == NSLICE) {
    			toWorker[i] <: SLICEH - 2;
    			toWorker[i] <: (char) (N | E | S | W);
    			i = WORKERNO;
    			workerLen[i] = (SLICEH - 2) * IMWD;
    		} else if (first) {
    			toWorker[i] <: SLICEH - 1;
        		toWorker[i] <: (char) (N | E | W);
    			first = 0;
    			workerLen[i] = (SLICEH - 1) * IMWD;
    		} else if (sCount == NSLICE) {
    			toWorker[i] <: SLICEH - 1;
    			toWorker[i] <: (char) (S | E | W);
    			i = WORKERNO;
    			workerLen[i] = (SLICEH - 1) * IMWD;
    		} else {
    			toWorker[i] <: SLICEH;
    			toWorker[i] <: (char) (E | W);
    			workerLen[i] = SLICEH * IMWD;
    		}
    		sCount++;
    	}

    	for (slicesDone = 0; slicesDone <= NSLICE; slicesDone++) {
    		for (pwc = 0; pwc < workerLen[slicesDone]; pwc++) {
    			c_in :> val;
    			toWorker[slicesDone] <: val;
    		}
    		currWorker = (currWorker + 1) % WORKERNO;
    	}
*/



    /*

    toWorker[i] <: (int)IMWD;
    toWorker[i] <: SLICEH + 1;
    toWorker[i] <: (char)(N | E | W);
    for (i++; i < WORKERNO - 1; i++) {
    	toWorker[i] <: (int)IMWD;
    	toWorker[i] <: (int)SLICEH + 2;
    	toWorker[i] <: (char)(E | W);
    }
    toWorker[i] <: (int)IMWD;
    toWorker[i] <: SLICEH + 1;
    toWorker[i] <: (char)(S | E | W);

    i = 0;
    for( int y = 0; y < IMHT; y++ )
    {
        for( int x = 0; x < IMWD; x++ )
        {
        	c_in :> val;
        	toWorker[i % WORKERNO] <: val;
        	if ((y % SLICEH) == (SLICEH - 1) && y != (IMHT - 1)) {
        		// If at bottom of slice, need to send to next slice.
        		toWorker[(i + 1) % WORKERNO] <: val;
        	} else if ((y % SLICEH) == 0 && y != 0) {
        		// If at top of slice, send the current row to the previous slice too.
        		toWorker[(i - 1) % WORKERNO] <: val;
        	}
        }
        if ((y % SLICEH) == (SLICEH - 1)) {
        	// If after looping through X on the bottom of a slice, we should target the next slice.
        	i++;
        }
    }
    */
    printf( "ProcessImage:Done...\n" );
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

void collector(chanend fromWorker[], chanend dataOut){
	char tmp;
	int i, pc, sliceLim;

	sliceLim = IMWD * (IMHT / WORKERNO);

	// TODO: Buffer from other workers.
	for (i = 0; i < WORKERNO; i++) {
		for (pc = 0; pc < sliceLim; pc++) {
			fromWorker[i] :> tmp;
			dataOut <: tmp;
		}
	}

	printf("Collector quitting.\n");
}

unsigned int ind(unsigned int x, unsigned int y, unsigned int width) {
	return (y * width) + x;
}

unsigned int onedge(unsigned int i, unsigned int w, unsigned int h) {
	return (i < w || i % w == 0 || i % w == w - 1 || i >= w * (h - 1));
}

void worker(chanend fromDistributor, chanend toCollector)
{
	char pos;
	int height, width;
	unsigned int x, y, i, jump;
	char temp;
	char block[BLOCKSIZE];

	fromDistributor <: WORKER_RDY;
	fromDistributor :> width;
	fromDistributor :> height;

	while (width > 0 && height > 0) {
		fromDistributor :> pos;

		for (i = 0; i < height * width; i++) {
			fromDistributor :> block[i];
		}

		// Do work on inner pixels only
		if (pos & N && pos & W) {
			i = 0;
		} else if (pos & N) {
			i = ind(1, 0, width);
		} else if (pos & W) {
			i = ind(0, 1, width);
		} else {
			i = ind(1, 1, width);
		}

		x = (pos & E) ? width : width - 1;
		y = (pos & S) ? height - 1 : height - 2;

		if (pos & E && pos & W) {
			jump = 1;
		} else if ((pos & E) || (pos & W)) {
			jump = 2;
		} else {
			jump = 3;
		}

		for (; i < ind(x, y, width); ((i % width) == x - 1) ? i += jump : i++) {
			if (onedge(i, width, height)) {
				temp = 0;
			} else {
				temp = (block[i + 1] + block[i - 1] + block[i + width] + block[i - width] + block[i + width + 1] + block[i + width - 1] + block[i - width + 1] + block[i - width - 1] + block[i]) / 9;
			}
			toCollector <: temp;
		}

		fromDistributor <: WORKER_RDY;
		fromDistributor :> width;
		fromDistributor :> height;
	}

	printf("blur loop done\n");
}


//MAIN PROCESS defining channels, orchestrating and starting the threads
int main() {
//    char infname[] = "src/test0.pgm"; //put your input image path here
//    char outfname[] = "bin/testout.pgm"; //put your output image path here
    chan c_inIO, c_outIO, dataOut, fromWorker[WORKERNO], toWorker[WORKERNO]; //extend your channel definitions here

    par //extend/change this par statement to implement your concurrent filter
    {
        on stdcore[0]: DataInStream( "src/BristolCathedral.pgm", c_inIO );
        on stdcore[0]: distributor( toWorker, c_inIO );
        on stdcore[0]: DataOutStream( "bin/testout.pgm", c_outIO );
        on stdcore[0]: collector(fromWorker, c_outIO);
        par (int i=0;i<WORKERNO;i++) {
        	on stdcore[i%4] : worker(toWorker[i], fromWorker[i]);
        }
    }

    return 0;
}

