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
out port cled0 = PORT_CLOCKLED_0;
out port cled1 = PORT_CLOCKLED_1;
out port cled2 = PORT_CLOCKLED_2;
out port cled3 = PORT_CLOCKLED_3;
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;

#define ROUNDS 20

//#define IMAGE "src/test0.pgm"
#define IMAGE "src/BristolCathedral.pgm"
//#define IMAGE "src/spaceship.pgm"
#define IMAGE_OUT "bin/testout.pgm"
#define FILEBUFFA "bin/tmpa.pgm"
#define FILEBUFFB "bin/tmpb.pgm"
#define IMWD 400
#define IMHT 256

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
#define BTN_PAUSE 1
#define BTN_RES 2

#define WORKER_RDY 1

#define LED_STOP 15

#define LED_STEP_SLICES (NSLICE + 1) * ROUNDS / 12
//#define DBGPRT

// Timing for the system
void time(chanend fromDistributor, chanend fromCollector) {
    timer tmr;
    unsigned int startTime, endTime, collectTime, oldTime, overallTime, oldOverallTime, overflowCount;
    int temp, x;
    x = 1;
    fromDistributor :> temp;
    tmr :> startTime;
    startTime = startTime;
    oldTime = startTime;
    overflowCount = 0;
    overallTime = 0;
    oldOverallTime = 0;
    while (x) {
        select {
            case tmr :> collectTime:
//                printf("collectTime = %d oldTime = %d overallTime = %d oldOverallTime = %d\n", collectTime, oldTime, overallTime, oldOverallTime);
                if (collectTime > oldTime && overallTime >= oldOverallTime) {
                    overallTime = overallTime + collectTime - oldTime;
//                    printf("Yay\n");
                } else if (overallTime < oldOverallTime) {
                    overflowCount++;
//                    overallTime = overallTime + collectTime - oldTime;
                } else {
                    printf("Overflow\n");
                    overallTime = overallTime + collectTime;
                }
                oldOverallTime = overallTime;
                oldTime = collectTime;
                break;
            default:
                 break;
        }
        select {
            case fromCollector :> temp:
                 tmr :> endTime;
                if (endTime > oldTime && overallTime > oldOverallTime) {
                    overallTime = overallTime + endTime - oldTime;
                } else if (overallTime <= oldOverallTime){
                    overflowCount++;
//                    overallTime = overallTime + collectTime - oldTime;
                } else {
                    overallTime = overallTime + endTime;
                }
                x = 0;
                break;
            default:
                break;
        }
//        printf("overallTime = %d oldOverallTime = %d\n", overallTime, oldOverallTime);
    }
    printf("overflow count = %u\n", overflowCount);
    printf("overallTime = %u\n", overallTime);
    overallTime = overallTime / 100000;
    overallTime = overflowCount * 42949 + overallTime;
    printf("Overall time running was %ums\n", overallTime);
}

//DISPLAYS an LED pattern in one quadrant of the clock LEDs
void showLED(out port p, chanend fromVisualiser) {
	unsigned int lightUpPattern;
	int running = 1;
	while (running) {
		fromVisualiser :> lightUpPattern; //read LED pattern from visualiser process
		if (lightUpPattern == LED_STOP) {
			running = 0;
		} else {
			p <: lightUpPattern; //send pattern to LEDs
		}
	}

	p <: 0; // Shut off lights before quit.
#ifdef DBGPRT
	printf("LED quad finished\n");
#endif
}

// Displays an arbitrary pattern on LEDs. Takes an array of active LED numbers.
void showPattern(int setOn[], int len, chanend quad0, chanend quad1, chanend quad2, chanend quad3) {
	int pat0, pat1, pat2, pat3, t0;
	pat0 = pat1 = pat2 = pat3 = 0;

	for (int i = 0; i < len; i++) {
		t0 = 16 << (setOn[i] % 3);
		pat0 = (t0 * ((setOn[i] / 3) == 0)) | pat0;
		pat1 = (t0 * ((setOn[i] / 3) == 1)) | pat1;
		pat2 = (t0 * ((setOn[i] / 3) == 2)) | pat2;
		pat3 = (t0 * ((setOn[i] / 3) == 3)) | pat3;
	}

	quad0 <: pat0;
	quad1 <: pat1;
	quad2 <: pat2;
	quad3 <: pat3;
}

//PROCESS TO COORDINATE DISPLAY of LED Ants
void visualiser(chanend fromCollector, chanend toQuadrant0, chanend toQuadrant1, chanend toQuadrant2, chanend toQuadrant3) {
	int progress = 0;
	int lCnt, sCnt, perStep;
	int lights[] = {0,1,2,3,4,5,6,7,8,9,10,11};
	timer tmr;
	unsigned int t;
	lCnt = 0;
	sCnt = 0;

	cledG <: 0;
	cledR <: 1;

	showPattern(lights, 12, toQuadrant0, toQuadrant1, toQuadrant2, toQuadrant3);

	if (NSLICE * ROUNDS <= 1) {
		perStep = 12;
	} else if (NSLICE * ROUNDS <= 2) {
		perStep = 6;
	} else if (NSLICE * ROUNDS <= 3) {
		perStep = 4;
	} else if (NSLICE * ROUNDS <= 4) {
		perStep = 3;
	} else if (NSLICE * ROUNDS <= 6) {
		perStep = 2;
	} else {
		perStep = 1;
	}

	// We have less slices than we have LEDs, so we gotta fudge the numbers.
	while (progress != -1) {
		fromCollector :> progress; // Read a number of newly added slices.
		sCnt += progress;

		// Convert progress to an LED number.
		if (sCnt >= LED_STEP_SLICES) {
			lCnt += perStep;
			sCnt = 0;
		}
		if (lCnt > 12) {
			lCnt = 12; // Sanitise led count.
		}
		cledG <: 1;
		cledR <: 0;
		showPattern(lights, lCnt, toQuadrant0, toQuadrant1, toQuadrant2, toQuadrant3);
	}
	cledG <: 0;
	cledR <: 1;
	showPattern(lights, 12, toQuadrant0, toQuadrant1, toQuadrant2, toQuadrant3);
	tmr :> t;
	tmr when timerafter(t + 5000000) :> void;

	cledG <: 0;
	cledR <: 0;

	// Shut off LED processes
	toQuadrant0 <: LED_STOP;
	toQuadrant1 <: LED_STOP;
	toQuadrant2 <: LED_STOP;
	toQuadrant3 <: LED_STOP;

#ifdef DBGPRT
	printf("Visualiser: finished\n");
#endif
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from pgm file with path and name infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(char infname[], char filebuffa[], char filebuffb[], chanend c_out, chanend loop)
{
    int res, round;
    uchar line[ IMWD ];

#ifdef DBGPRT
    printf( "DataInStream:Start...\n" );
#endif

    for (round = 0; round < ROUNDS; round++) {
#ifdef DBGPRT
    	printf("DataInStream: Starting round %d...\n", round);
#endif
    	if (round == 0) {
    		res = _openinpgm( infname, IMWD, IMHT );
    	} else {
    		// Wait for the output to be done, or shutdown signal from distrib.
    		select {
    			case loop :> res:
    				if (round & 1) {
    					res = _openinpgm( filebuffa, IMWD, IMHT );
    				} else {
    					res = _openinpgm( filebuffb, IMWD, IMHT );
    				}
    				break;
    			case c_out :> res:
    				round = ROUNDS;
    				break;
    		}
    	}
		if( res )
		{
#ifdef DBGPRT
			printf( "DataInStream:Error opening %s\n.", infname );
#endif
			return;
		}

		for( int y = 0; y < IMHT; y++ )
		{
			_readinline( line, IMWD );
			for( int x = 0; x < IMWD; x++ )
			{
				select {
					case c_out :> res:
						y = IMHT;
						x = IMWD;
						round = ROUNDS;
						break;
					default:
						c_out <: line[ x ];
						break;
				}
			}
		}

    _closeinpgm();
    }

    loop :> res;
#ifdef DBGPRT
    printf( "DataInStream:Done...\n" );
#endif
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
#ifdef DBGPRT
                    printf("Accidentally pulling data from worker!\n");
#endif
                }
                break;
            default:
                break;
            }
        i = (i + 1) % WORKERNO;
    }
    return waiting;
}

void distributor(chanend toWorker[], chanend c_in, chanend buttonListener, chanend toTimer) {
    int cWorker, x, y, workRemaining, temp, shutdown, i;
    uchar buffa[IMWD], buffb[IMWD], tmp;
    //Blocking till button A is pressed
    buttonListener :> temp;
    printf("Starting blur of %s (%d x %dpx) %d time(s).\n", IMAGE, IMWD, IMHT, ROUNDS);
    toTimer <: temp;
    cWorker = 0;
    shutdown = 0;

    for (int round = 0; round < ROUNDS; round++) {
		// Initialise buffb from input. buffa can stay uninitialised as it will be ignored.
		for (x = 0; x < IMWD; x++) {
			c_in :> buffb[x];
		}

		for (workRemaining = NSLICE; workRemaining >= 1; workRemaining--) {
			// Check if buttonListener is asking us to cancel or pause.
			select {
				case buttonListener :> temp:
					if (temp == BTN_STOP) {
#ifdef DBGPRT
						printf("Button Stop\n");
#endif
						shutdown = 1;
					} else if (temp == BTN_PAUSE) {
#ifdef DBGPRT
						printf("Button Paused\n");
#endif
						while (temp != BTN_RES) {
							buttonListener :> temp;
						}
					}
					break;
				default:
					break;
			}

			if (shutdown) {
				workRemaining = 0; // Set workRemaining so we don't try to continue.
			} else {
				cWorker = getWaiting(toWorker, cWorker);
#ifdef DBGPRT
				printf("Sending slice %d/%d to worker %d\n", NSLICE - workRemaining, NSLICE, cWorker);
#endif
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
			}
		}
		if (!shutdown) {
			cWorker = getWaiting(toWorker, cWorker);
#ifdef DBGPRT
			printf("Sending final slice %d/%d to worker %d\n", NSLICE - workRemaining, NSLICE, cWorker);
#endif
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

		} else {
			// Tell data in that we don't want to hear from it no mo'
			select {
				case c_in :> tmp:
					break;
				default:
					break;
			}
			c_in <: 0;
		}
#ifdef DBGPRT
		printf("Distributor: Done round %d\n", round);
#endif
    }// Round finish


    if (!shutdown) {
		// Inform the button listener that it has no friends and nobody loves it, if it wasn't the one who killed us.
		select {
			case buttonListener :> temp:
				if (temp != BTN_STOP) {
					buttonListener <: 0;
				}
				break;
			default:
				buttonListener <: 0;
				break;
		}
    }

    // Need to inform workers that all work is complete.
    for (cWorker = 0; cWorker < WORKERNO; cWorker++) {
    	toWorker[cWorker] :> temp;
		// Worker is done and asking for more. Tell it to shut off.
        toWorker[cWorker] <: 0;
		toWorker[cWorker] <: 0;
		toWorker[cWorker] <: 0;
    }

#ifdef DBGPRT
    printf( "Distributor:Done...\n" );
#endif
}

unsigned int ind(unsigned int x, unsigned int y, unsigned int width) {
	return (y * width) + x;
}

void worker(int id, chanend fromDistributor, chanend toCollector) {
	char pos;
	int height, width, sliceNo, DBGSENT;
	unsigned int x, y, i;
	uchar temp;
	uchar block[BLOCKSIZE];
	uchar resBuff[IMWD][SLICEH]; // Smaller buffer to hold results

	fromDistributor <: WORKER_RDY;
	fromDistributor :> sliceNo;
	fromDistributor :> width;
	fromDistributor :> height; // number of output rows (sent rows = height + 2)!

	while (width > 0 && height > 0) {
		fromDistributor :> pos;

#ifdef DBGPRT
		printf("[%d] collecting %d px\n", id, (height+2) * width);
#endif
		for (i = 0; i < (height + 2) * width; i++) {
			fromDistributor :> block[i];
		}

#ifdef DBGPRT
		printf("[%d] Telling collector our slice: %d and size %d.\n", id, sliceNo, height * IMWD);
#endif
		toCollector <: sliceNo;
		toCollector <: height * IMWD;

		DBGSENT = 0;
		// Start one pixel in in either direction.
		for (y = 1; y <= height; y++) {
			for (x = 0; x < width; x++) {
				if ((y == 1 && (pos & N)) || (x == 0) || (y == height && (pos & S)) || (x == width - 1)) {
					temp = BLACK;
				} else {
					temp = (block[ind(x,y,width)] + block[ind(x+1,y,width)] + block[ind(x-1,y,width)] + block[ind(x,y-1,width)] + block[ind(x,y+1,width)] + block[ind(x-1,y-1,width)] + block[ind(x-1,y+1,width)] + block[ind(x+1,y-1,width)] + block[ind(x+1,y+1,width)]) / 9;
				}
				resBuff[x][y-1] = temp;
				//toCollector <: temp;
				DBGSENT++;
			}
		}

#ifdef DBGPRT
		printf("[%d] done slice, processed %dpx.\n", id, DBGSENT);
#endif

		// Start sending results as soon as possible.
		for (y = 0; y < height; y++) {
			for (x = 0; x < width; x++) {
				toCollector <: resBuff[x][y];
			}
		}

#ifdef DBGPRT
		printf("[%d] slice sent to collector.\n", id, DBGSENT);
#endif

		// We could possibly interleave sending/waiting to send to the collector with receiving data from distributor.
		// The only issue being we may distribute chunks in a biased fashion, which could hurt performance.
		fromDistributor <: WORKER_RDY;
		fromDistributor :> sliceNo;
		fromDistributor :> width;
		fromDistributor :> height;
	}
#ifdef DBGPRT
	printf("[%d] informing collector we are done.\n", id);
#endif
	toCollector <: -1;

#ifdef DBGPRT
	printf("[%d] Worker done\n", id);
#endif
}


/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to pgm image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], char fileBuffA[], char fileBuffB[], chanend c_in, chanend loop)
{
    int res, tmp, round;
    uchar line[ IMWD ];

#ifdef DBGPRT
    printf( "DataOutStream: Start...\n" );
#endif

    for (round = 0; round < ROUNDS; round++) {
#ifdef DBGPRT
    	printf("DataOutStream: Starting round %d...\n", round);
#endif
    	if (round == ROUNDS - 1) {
    		res = _openoutpgm( outfname, IMWD, IMHT );
    	} else {
			if (round & 1) {
				res = _openoutpgm( fileBuffB, IMWD, IMHT );
			} else {
				res = _openoutpgm( fileBuffA, IMWD, IMHT );
			}
    	}
		if( res )
		{
	#ifdef DBGPRT
			printf( "DataOutStream: Error opening %s\n.", outfname );
	#endif
			return;
		}
		res = 1;
		for( int y = 0; y < IMHT; y++ )
		{
			for( int x = 0; x < IMWD; x++ )
			{
				c_in :> tmp;
				if (tmp < 0) {
					// This line means we should give up, all hope is lost.
					x = IMWD;
					y = IMHT;
					round = ROUNDS;
				} else {
					line[x] = (uchar) tmp;
				}
			}
			_writeoutline( line, IMWD );
		}

		_closeoutpgm();
		loop <: 0;
    }
#ifdef DBGPRT
    printf( "DataOutStream: Done...\n" );
#endif
    // Read from loop in case it was waiting on us.
    select {
    	case loop :> tmp:
    		break;
    	default:
    		break;
    }
    return;
}

// TODO: Reduce blocking on collector.
void collector(chanend fromWorker[], chanend dataOut, chanend toVis, chanend toTimer){
	uchar tmp;
	int i, j, x, cWorker, pc, cTotal, idBuff[WORKERNO], sliceLen, working;

	for (int round = 0; round < ROUNDS; round++) {
#ifdef DBGPRT
		printf("Collector: start round %d\n", round);
#endif
		cWorker = -1;
		// Buffer from other workers.
		for (i = 0; i < WORKERNO; i++) {
			idBuff[i] = -2;
		}

		for (i = 0; i <= NSLICE; i++) {
			working = 1;
			for (j = 0; (cWorker < 0 || cWorker >= WORKERNO) && working; j = (j + 1) % WORKERNO) {
				// Attempt a read from every worker until we find the next slice ID, i.e. i. Must buffer read values to avoid reading data prematurely.
				// If idBuff[j] == -1, that worker is dead. If < -1, read.
				if (idBuff[j] < -1) {
					select {
						case fromWorker[j] :> idBuff[j]:
	#ifdef DBGPRT
							printf("Collector: [%d] told us it has %d\n", j, idBuff[j]);
	#endif
							break;
						default:
							break;
					}
				}
				if (idBuff[j] == i) {
					cWorker = j;
					idBuff[j] = -2;
				}
				cTotal = 0;
				for (x = 0; x < WORKERNO; x++) {
					if (idBuff[x] == -1) {
						cTotal--;
					}
				}
				if (cTotal == -4) {
					working = 0;
				}
			}

			if (!working) {
				//All workers are dead
	#ifdef DBGPRT
				printf("Collector: All workers gone, quitting...\n");
	#endif
				i = NSLICE + 1;
				// Tell data out that it's time in this world is up. Such a depressing state of affairs.
				dataOut <: -1;
			} else {
				fromWorker[cWorker] :> sliceLen;
	#ifdef DBGPRT
				printf("Collector: Reading slice %d of size %d from [%d]\n", i, sliceLen, cWorker);
	#endif
				for (pc = 0; pc < sliceLen; pc++) {
					fromWorker[cWorker] :> tmp;
					dataOut <: (int)tmp;
				}
	#ifdef DBGPRT
				printf("Collector: Read done\n");
	#endif
				toVis <: 1; // Tell vis that we have added another slice to output.
				cWorker = -1;
			}
		}

#ifdef DBGPRT
		printf("Collector: end round %d\n", round);
#endif
	}

	// Wait until all workers are dead before sepuku
	for (i = 0; i < WORKERNO; i++) {
		while (idBuff[i] != -1) {
			fromWorker[i] :> idBuff[i];
		}
	}

	// Tell vis we are thankful for it's assistance and wish it a merry christmas
    toTimer <: 1;
	toVis <: -1;

#ifdef DBGPRT
	printf("Collector quitting.\n");
#endif
}

//READ BUTTONS and send commands to Visualiser
void buttonListener(in port buttons, chanend toDistributor) {
    int buttonInput; //button pattern currently pressed
    unsigned int running = 1; //helper variable to determine system shutdown
    int paused = 1;

    while (running) {
    	select {
    		case buttons when pinsneq(15) :> buttonInput:
    	        buttons when pinseq(15) :> void;
    			break;
    		case toDistributor :> buttonInput:
    			running = 0;
    			buttonInput = BTND;
    			break;
    	}

        switch (buttonInput) {
        case BTNA:
            // A = Start/resume
            if (paused) {
                paused = 0;
                toDistributor <: BTN_RES;
            }
            break;
        case BTNB:
            // B = Pause
            if (!paused) {
                toDistributor <: BTN_PAUSE;
                paused = 1;
            }
            break;
        case BTNC:
            // C = Quit
#ifdef DBGPRT
        	printf("Quit btn pressed.\n");
#endif
            if (paused) {
                toDistributor <: BTN_RES;
            }
            toDistributor <: BTN_STOP;
            running = 0;
            paused = 0;
            break;
        case BTND:
            // D = Noop
            break;
        }
    }
}


//MAIN PROCESS defining channels, orchestrating and starting the threads
int main() {
    chan c_inIO, c_outIO, fromWorker[WORKERNO], toWorker[WORKERNO], toVis, quad0, quad1, quad2, quad3, bListener, fLoop, dTimer, cTimer;

    par
    {
    	on stdcore[0]: DataInStream( IMAGE, FILEBUFFA, FILEBUFFB, c_inIO, fLoop );
        on stdcore[0]: buttonListener(buttons, bListener);
        on stdcore[0]: DataOutStream( IMAGE_OUT, FILEBUFFA, FILEBUFFB, c_outIO, fLoop );
        on stdcore[1]: distributor( toWorker, c_inIO, bListener, dTimer);
        on stdcore[2]: collector(fromWorker, c_outIO, toVis, cTimer);
        on stdcore[3]: time(dTimer, cTimer);
		on stdcore[0]: visualiser(toVis,quad0,quad1,quad2,quad3);
		on stdcore[0]: showLED(cled0,quad0);
		on stdcore[1]: showLED(cled1,quad1);
		on stdcore[2]: showLED(cled2,quad2);
		on stdcore[3]: showLED(cled3,quad3);
        par (int i=0;i<WORKERNO;i++) {
        	on stdcore[i%4] : worker(i, toWorker[i], fromWorker[i]);
        }
    }

    return 0;
}

