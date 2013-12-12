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

#define IMHT 16
#define IMWD 16

// USE CONSTANTS FOR BIT-FIELD OF WORKER QUADRANT POSITION
// NE = N & E
#define N 1
#define E 2
#define S 4
#define W 8

#define BLACK 0

#define WORKERNO 4
#define BLOCKSIZE (IMWD) * ((IMHT / WORKERNO) + 2) //130*130 //ENLARGE FOR GREATER THAN 256 * 256, CURRENTLY (256*256)/4

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
void distributor(chanend toWorker[], chanend c_in)
{
    uchar val;
    int i = 0;
    // TODO: Fix when not an integer
    int sliceH = IMHT / WORKERNO;
    printf( "ProcessImage:Start, size = %dx%d\n", IMHT, IMWD );


    toWorker[i] <: (int)IMWD;
    toWorker[i] <: sliceH + 1;
    toWorker[i] <: (char)(N | E | W);
    for (i++; i < WORKERNO - 1; i++) {
    	toWorker[i] <: (int)IMWD;
    	toWorker[i] <: (int)sliceH + 2;
    	toWorker[i] <: (char)(E | W);
    }
    toWorker[i] <: (int)IMWD;
    toWorker[i] <: sliceH + 1;
    toWorker[i] <: (char)(S | E | W);

    i = 0;
    for( int y = 0; y < IMHT; y++ )
    {
        for( int x = 0; x < IMWD; x++ )
        {
        	c_in :> val;
        	toWorker[i] <: val;
        	if ((y % sliceH) == (sliceH - 1) && y != (IMHT - 1)) {
        		// If at bottom of slice, need to send to next slice.
        		toWorker[i + 1] <: val;
        	} else if ((y % sliceH) == 0 && y != 0) {
        		// If at top of slice, send the current row to the previous slice too.
        		toWorker[i - 1] <: val;
        	}
        }
        if ((y % sliceH) == (sliceH - 1)) {
        	// If after looping through X on the bottom of a slice, we should target the next slice.
        	i++;
        }
    }
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

//	while (pc < (IMHT * IMWD)) {
//		for (i=0;i<WORKERNO;i++) {
//			select {
//				case fromWorker[i] :> tmp:
//					printf("%d gave us %i\n", i, tmp);
//					pc++;
//					dataOut <: tmp;
//					break;
//				default:
//					break;
//			}
//		}
//	}


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

	fromDistributor :> width;
	fromDistributor :> height;
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
//			printf("SHIT\n");
		}
		toCollector <: temp;
	}

	printf("blur loop done\n");
	//	for (i = ind(1,1,size); i <= ind(size-2,size-2,size); endline(i, size) ? i += 3 : i++) {
//		temp = (block[i + 1] + block[i - 1] + block[i + size] + block[i - size] + block[i + size + 1] + block[i + size - 1] + block[i - size + 1] + block[i - size - 1] + block[i]) / 9;
//		toCollector <: temp;
//	}

}


//MAIN PROCESS defining channels, orchestrating and starting the threads
int main() {
//    char infname[] = "src/test0.pgm"; //put your input image path here
//    char outfname[] = "bin/testout.pgm"; //put your output image path here
    chan c_inIO, c_outIO, dataOut, fromWorker[WORKERNO], toWorker[WORKERNO]; //extend your channel definitions here

    par //extend/change this par statement to implement your concurrent filter
    {
        on stdcore[0]: DataInStream( "src/test0.pgm", c_inIO );
        on stdcore[0]: distributor( toWorker, c_inIO );
        on stdcore[0]: DataOutStream( "bin/testout.pgm", c_outIO );
        on stdcore[0]: collector(fromWorker, c_outIO);
        par (int i=0;i<WORKERNO;i++) {
        	on stdcore[i%4] : worker(toWorker[i], fromWorker[i]);
        }
    }

    return 0;
}

