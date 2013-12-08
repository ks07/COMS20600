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

#define BLOCKSIZE 130*130 //ENLARGE FOR GREATER THAN 256 * 256, CURRENTLY (256*256)/4

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
void distributor(chanend c_in, chanend c_out)
{
    uchar val;

    printf( "ProcessImage:Start, size = %dx%d\n", IMHT, IMWD );

    //This code is to be replaced – it is a place holder for farming out the work...
    for( int y = 0; y < IMHT; y++ )
    {
        for( int x = 0; x < IMWD; x++ )
        {
            c_in :> val;
            c_out <: (uchar)( val ^ 0xFF ); //Need to cast
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

void Collector(chanend fromWorker[], chanend dataOut){

}

unsigned int ind(unsigned int x, unsigned int y, unsigned int size) {
	return (y * size) + x;
}

int endline(unsigned int i, unsigned int size) {
	int x = i % size;
	return x == size - 2;
}

void Worker(chanend fromDistributor, chanend toCollector)
{
	char pos;
	int size; //ASSUME SQUARE FOR NOW
	unsigned int x, y, i, temp;
	char block[BLOCKSIZE];

	fromDistributor :> size;
	fromDistributor :> pos;

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
int main()
{
    char infname[] = "src/test0.pgm"; //put your input image path here
    char outfname[] = "bin/testout.pgm"; //put your output image path here
    chan c_inIO, c_outIO; //extend your channel definitions here

    par //extend/change this par statement to implement your concurrent filter
    {
        DataInStream( infname, c_inIO );
        distributor( c_inIO, c_outIO );
        DataOutStream( outfname, c_outIO );
    }

    printf( "Main:Done...\n" );

    return 0;
}

