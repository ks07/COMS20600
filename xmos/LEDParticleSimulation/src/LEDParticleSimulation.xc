/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20600 - WEEKS 6 and 7
// ASSIGNMENT 2
// CODE SKELETON
// TITLE: "LED Particle Simulation"
//
/////////////////////////////////////////////////////////////////////////////////////////


#include <stdio.h>
#include <platform.h>

out port cled[4] = {PORT_CLOCKLED_0,PORT_CLOCKLED_1,PORT_CLOCKLED_2,PORT_CLOCKLED_3};
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;
in port buttons = PORT_BUTTON;
out port speaker = PORT_SPEAKER;

#define noParticles 3 //overall number of particles threads in the system

#define LEFT -1
#define RIGHT 1
#define NO_DIR 0

#define MOVE_OK 16
#define MOVE_FAIL 32


/////////////////////////////////////////////////////////////////////////////////////////
//
// Helper Functions provided for you
//
/////////////////////////////////////////////////////////////////////////////////////////


//DISPLAYS an LED pattern in one quadrant of the clock LEDs
void showLED(out port p, chanend fromVisualiser) {
	unsigned int lightUpPattern;
	unsigned int running = 1;
	while (running) {
		select {
			case fromVisualiser :> lightUpPattern: //read LED pattern from visualiser process
				p <: lightUpPattern; //send pattern to LEDs
			break;
			default:
			break;
		}
	}
}


//PLAYS a short sound (pls use with caution and consideration to other students in the labs!)
void playSound(unsigned int wavelength, int duration, out port speaker) {
	timer tmr;
	int t, isOn = 1;
	tmr :> t;
	for (int i=0; i<duration; i++) {
		isOn = !isOn;
		t += wavelength;
		tmr when timerafter(t) :> void;
		speaker <: isOn;
	}
}


//WAIT function
void waitMoment(uint myTime) {
	timer tmr;
	unsigned int waitTime;
	tmr :> waitTime;
	waitTime += myTime;
	tmr when timerafter(waitTime) :> void;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// RELEVANT PART OF CODE TO EXPAND
//
/////////////////////////////////////////////////////////////////////////////////////////

//PROCESS TO COORDINATE DISPLAY of LED Particles
void visualiser(chanend toButtons, chanend show[], chanend toQuadrant[], out port speaker) {
	unsigned int display[noParticles]; //array of ant positions to be displayed, all values 0..11
	unsigned int running = 1; //helper variable to determine system shutdown
	int j; //helper variable
	cledR <: 1;
	while (running) {
		if (display[1] < display[0] && display[1] > display[2]) {
			printf("balls\n");
		}
		for (int k=0;k<noParticles;k++) {
			select {
				case show[k] :> j:
					if (j<12) display[k] = j; else
					playSound(20000,20,speaker);
				break;
				///////////////////////////////////////////////////////////////////////
				//
				// ADD YOUR CODE HERE TO ACT ON BUTTON INPUT
				//
				///////////////////////////////////////////////////////////////////////
				default:
				break;
			}
			//visualise particles
			for (int i=0;i<4;i++) {
				j = 0;
				for (int k=0;k<noParticles;k++)
					j += (16<<(display[k]%3))*(display[k]/3==i);
				toQuadrant[i] <: j;
			}
		}
	}
}

//READ BUTTONS and send commands to Visualiser
void buttonListener(in port buttons, chanend toVisualiser) {
	int buttonInput; //button pattern currently pressed
	unsigned int running = 1; //helper variable to determine system shutdown
	while (running) {
		buttons when pinsneq(15) :> buttonInput;
		///////////////////////////////////////////////////////////////////////
		//
		// ADD YOUR CODE HERE TO ACT ON BUTTON INPUT
		//
		///////////////////////////////////////////////////////////////////////
	}
}

unsigned int vToT(int velocity) {
	// TODO: Return a function of v.
	return 10000000;
}

// % operator in C is remainder, not modulus!
int mod12(int a) {
	int r;
	r = a % 12;
	return (r >= 0) ? r : r + 12;
}

int isLeft(unsigned int base, unsigned int l, unsigned int r) {
	return mod12((l - base)) > mod12((r - base));
}

//PARTICLE...thread to represent a particle - to be replicated noParticle-times
void particle(streaming chanend left, streaming chanend right, chanend toVisualiser, int startPosition, int startDirection) {
	unsigned int moveCounter = 0; //overall no of moves performed by particle so far
	int position = startPosition; //the current particle position
	int attemptedPosition; //the next attempted position after considering move direction
	int currentDirection = startDirection; //the current direction the particle is moving
	int leftMoveForbidden = 0; //the verdict of the left neighbour if move is allowed
	int rightMoveForbidden = 0; //the verdict of the right neighbour if move is allowed
	int currentVelocity = 1; //the current particle velocity
	int waitingOn = NO_DIR; // -1 if waiting for left resp, 1 if right, 0 if no req sent
	int rcvTemp; //temp var to hold messages
	timer tmr;
	unsigned int t, waitTime;
	int lp, rp;
	lp = mod12((startPosition -1));
	rp = mod12((startPosition +1));
	if (!isLeft(position, lp, rp)) {
		printf("fuck\n");
	}

	toVisualiser <: startPosition;
	tmr :> waitTime; //First move is now.

	while (1) {
		select {
			case left :> rcvTemp:
//				switch (waitingOn) {
//				case LEFT:
//
//					break;
//				case RIGHT:
//
//					break;
//				default:
//
//					break;
//				}

				if (waitingOn == LEFT) {
					// Waiting for resp from left, this must be a resp.
					if (rcvTemp == MOVE_OK) {
						position = attemptedPosition;
						toVisualiser <: position;
					} else {
						// MOVE_FAIL
						currentDirection *= -1;
						attemptedPosition = position; // Reset our attempt.
					}
//					printf("%d %d\n", startPosition, position);
					waitingOn = NO_DIR;
				} else {
					// Left is requesting info from us.
					if (rcvTemp > 11) {
						printf("shit\n");
					}
					lp = rcvTemp - 1;
					if (rcvTemp == position) {
						if (waitingOn == RIGHT) {
							left <: MOVE_FAIL;
							// Two possibilities - right isn't present, so we can move - left will not change our direction (though may bounce early)
							// Else right is present, and is about to switch our direction. However, left approach afterwards mean outcome = right
							// Thus, no bounce
						} else {
							left <: MOVE_FAIL;
							// We're waiting on nothing. Thus bounce if going left.
							if (currentDirection == LEFT) {
								// We should switch direction iff we collide head on.
								currentDirection = RIGHT;
							}
						}
					} else {
						left <: MOVE_OK;
					}
				}
				break;
			case right :> rcvTemp:
				if (waitingOn == RIGHT) {
					// Waiting for resp from right, this must be a resp.
					if (rcvTemp == MOVE_OK) {
						position = attemptedPosition;
						toVisualiser <: position;
					} else {
						// MOVE_FAIL
						currentDirection *= -1;
						attemptedPosition = position; // Reset our attempt.
					}
//					printf("%d %d\n", startPosition, position);
					waitingOn = NO_DIR;
				} else {
					if (rcvTemp > 11) {
						printf("shit\n");
					}
					rp = rcvTemp +1;
					// Left is requesting info from us.
					if (rcvTemp == position) {
						if (waitingOn == LEFT) {
							right <: MOVE_FAIL;
							// Two possibilities - right isn't present, so we can move - left will not change our direction (though may bounce early)
							// Else right is present, and is about to switch our direction. However, left approach afterwards mean outcome = right
							// Thus, no bounce
						} else {
							right <: MOVE_FAIL;
							// We're waiting on nothing. Thus bounce if going left.
							if (currentDirection == RIGHT) {
								// We should switch direction iff we collide head on.
								currentDirection = LEFT;
							}
						}
					} else {
						right <: MOVE_OK;
					}
				}
				break;
			//case tmr when timerafter(waitTime) :> t:
			default:
				// TODO: Remove busy wait?
				tmr :> t;
				if (t >= waitTime) {
					// We've waited long enough to attempt another move. Check if we're still waiting for a response.
					if (waitingOn == NO_DIR) {
						attemptedPosition = mod12((position + currentDirection));
						waitTime = t + vToT(currentVelocity);
						if (currentDirection == LEFT) {
							left <: attemptedPosition;
							waitingOn = LEFT;
						} else {
							right <: attemptedPosition;
							waitingOn = RIGHT;
						}
					} else {
						// We're still waiting for a response, return to wait but don't update timer.
					}
				}
				break;
		}
	}
}

//MAIN PROCESS defining channels, orchestrating and starting the threads
int main(void) {
	chan quadrant[4]; //helper channels for LED visualisation
	chan show[noParticles]; //channels to link visualiser with particles
	streaming chan neighbours[noParticles]; //channels to link neighbouring particles
	chan buttonToVisualiser; //channel to link buttons and visualiser

	//MAIN PROCESS HARNESS
	par{

		//BUTTON LISTENER THREAD
		on stdcore[0]: buttonListener(buttons,buttonToVisualiser);

		par (int i=0;i<noParticles;i++) {
			on stdcore[i%4]: particle(neighbours[i], neighbours[(i+1) % noParticles], show[i], ((12/noParticles)*i) % 12, (i & 1) ? -1 : 1);
		}

		//VISUALISER THREAD
		on stdcore[0]: visualiser(buttonToVisualiser,show,quadrant,speaker);

		//REPLICATION FOR THREADS PERFORMING LED VISUALISATION
		par (int k=0;k<4;k++) {
			on stdcore[k%4]: showLED(cled[k],quadrant[k]);
		}

	}
	return 0;
}
