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
#define BLOCKSIZE (IMHT + 2) * (IMWD + 2) / WORKERNO //130*130 //ENLARGE FOR GREATER THAN 256 * 256, CURRENTLY (256*256)/4

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

    printf( "ProcessImage:Start, size = %dx%d\n", IMHT, IMWD );

    //This code is to be replaced – it is a place holder for farming out the work...
    for (int i = 0; i < WORKERNO; i++) {
    	toWorker[i] <: (int)(IMHT + 2) /2;
    	toWorker[i] <: (char)0;
    }


    for( int y = -1; y < IMHT + 1; y++ )
    {
        for( int x = -1; x < IMWD + 1; x++ )
        {
        	if (y < 0 || y >= IMHT || x < 0 || x >= IMWD) {
        		val = BLACK;
        	} else {
        		c_in :> val;
        	}
            toWorker[i] <: val;
            i = (i + 1) % WORKERNO;
//            c_out <: (uchar)( val ^ 0xFF ); //Need to cast
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
	int i;

	while (1) {
	for (i=0;i<WORKERNO;i++) {
		select {
			case fromWorker[i] :> tmp:
				printf("%d gave us %i\n", i, tmp);
				break;
			default:
				break;
		}
	}
	}

	printf("Collector quitting.");
}

unsigned int ind(unsigned int x, unsigned int y, unsigned int size) {
	return (y * size) + x;
}

int endline(unsigned int i, unsigned int size) {
	int x = i % size;
	return x == size - 2;
}

void worker(chanend fromDistributor, chanend toCollector)
{
	char pos; // TODO: Not needed anymore?
	int size; //ASSUME SQUARE FOR NOW
	unsigned int x, y, i;
	char temp;
	char block[BLOCKSIZE];

	fromDistributor :> size;
	fromDistributor :> pos;
// not square
	for (i = 0; i < size * size; i++) {
		fromDistributor :> block[i];
	}

	// Do work on inner pixels only
	for (i = ind(1,1,size); i <= ind(size-2,size-2,size); endline(i, size) ? i += 3 : i++) {
		temp = (block[i + 1] + block[i - 1] + block[i + size] + block[i - size] + block[i + size + 1] + block[i + size - 1] + block[i - size + 1] + block[i - size - 1] + block[i]) / 9;
		toCollector <: temp;
	}

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

