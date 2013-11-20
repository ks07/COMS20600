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

// max particles of 5, any more and the number of channels on core 0 will be exceeded.
#define noParticles 4 //overall number of particles threads in the system

// Direction constants
#define LEFT -1
#define RIGHT 1
#define NO_DIR 0

// Particle response constants
#define MOVE_OK 16
#define MOVE_FAIL_CRASH 32
#define MOVE_FAIL_REAR 64

// Button IO signals
#define BTNA 14
#define BTNB 13
#define BTNC 11
#define BTND 7

// Btn -> Vis running tokens
#define BTN_STOP 0
#define BTN_PAUSERES 1

// Btn -> Vis setup tokens
#define BTN_L 0
#define BTN_R 1
#define BTN_CONF 2

// Vis particle status constants
#define RUNNING 0
#define SHUTDOWNPENDING 1
#define SHUTDOWN 2

// Vis -> Part running tokens
#define PARTICLE_PREP_STOP 12
#define PARTICLE_STOP 13
#define PARTICLE_PAUSE 14

// Vis -> LED shutdown token
#define QUAD_STOP 15

#define NO_BOUND 17

/////////////////////////////////////////////////////////////////////////////////////////
//
// Helper Functions provided for you
//
/////////////////////////////////////////////////////////////////////////////////////////

// % operator in C is remainder, not modulus!
int mod12(int a) {
	int r;
	r = a % 12;
	return (r >= 0) ? r : r + 12;
}

//DISPLAYS an LED pattern in one quadrant of the clock LEDs
void showLED(out port p, chanend fromVisualiser) {
	unsigned int lightUpPattern;
	unsigned int running = 1;
	while (running) {
		select {
			case fromVisualiser :> lightUpPattern: //read LED pattern from visualiser process
				if (lightUpPattern == QUAD_STOP) {
					p <: 0; // Turn off all LEDs.
					running = 0;
				} else {
					p <: lightUpPattern; //send pattern to LEDs
				}
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
	int j, p; //helper variable
	int goingShut = 0;
	int particleFlag[noParticles];
	int shutCount = 0;
	int finCount = 0;
	int paused = 1;
	int partWorking;
	cledR <: 1;

	// Switch off all LEDs.
	for (int i = 0; i < noParticles; i++) {
		display[i] = 12;
	}

	for (int i = 0; i < noParticles; i++) {
		particleFlag[i] = RUNNING;
		display[i] = 12;
		partWorking = 1;

		show[i] <: i == 0 ? NO_BOUND : display[i-1];
		show[i] <: i == 0 ? NO_BOUND : mod12(display[0] - (noParticles - i - 1));
		show[i] :> display[i];

		while (partWorking) {
			// Display particle.
			for (int l=0;l<4;l++) {
				j = 0;
				for (int k=0;k<noParticles;k++) {
					if (display[k] < 12) {
						j += (16<<(display[k]%3))*(display[k]/3==l);
					}
				}
				toQuadrant[l] <: j;
			}

			toButtons :> p;
			switch (p) {
				case BTN_L:
					show[i] <: BTN_L;
					show[i] :> p;
					if (p < 12) {
						display[i] = p;
					} else {
						playSound(20000,20,speaker);
					}
					break;
				case BTN_R:
					show[i] <: BTN_R;
					show[i] :> p;
					if (p < 12) {
						display[i] = p;
					} else {
						playSound(20000,20,speaker);
					}
					break;
				case BTN_CONF:
					show[i] <: BTN_CONF;
					show[i] :> p;
					display[i] = p;
					playSound(200000,20,speaker);
					partWorking = 0;
					break;
			}

			waitMoment(50000000);
		}
	}
	while (running) {
		// Debugging check of particle ordering.
		if (noParticles > 2 && display[1] < display[0] && display[1] > display[2]) {
			printf("very bad\n");
		}
		for (int k=0;k<noParticles;k++) {
			if (!paused) {
				select {
				case show[k] :> j:
					if (goingShut && particleFlag[k] == RUNNING) {
						// We've been asked to shutdown, inform the current particle it should prepare to quit.
						show[k] <: PARTICLE_PREP_STOP;
						particleFlag[k] = SHUTDOWNPENDING;
						shutCount++;
					} else if (j<12) {
						// Sent a valid position.
						display[k] = j;
					} else if (j < 15) {
						// Sent a reserved message value.
						printf("INVALID\n");
					} else {
						// Sent a high, play a sound.
						playSound(20000,20,speaker);
					}
				break;
				default:
				break;
				}
			}
			select {
				case toButtons :> p:
					switch(p) {
					    case BTN_STOP:
					    	goingShut = 1;
					    break;
					    case BTN_PAUSERES:
					    	paused = !paused;
					    break;
					}
				break;
				default:
					if (finCount == noParticles) {
						running = 0;
					} else if (goingShut && shutCount == noParticles && particleFlag[k] != SHUTDOWN) {
						show[k] <: PARTICLE_STOP;
						particleFlag[k] = SHUTDOWN;
						finCount++;
					}
				break;
			}
			//visualise particles
			for (int i=0;i<4;i++) {
				j = 0;
				for (int k=0;k<noParticles;k++) {
					if (display[k] < 12) {
						j += (16<<(display[k]%3))*(display[k]/3==i);
					}
				}
				toQuadrant[i] <: j;
			}
		}
	}
	for (int i=0;i<4;i++) {
		toQuadrant[i] <: QUAD_STOP;
	}
}

//READ BUTTONS and send commands to Visualiser
void buttonListener(in port buttons, chanend toVisualiser) {
	int buttonInput; //button pattern currently pressed
	unsigned int running = 1; //helper variable to determine system shutdown
	int paused = 1;
	int setupCount = noParticles;
	while (setupCount > 0) {
		// User is choosing starting positions of particles
		buttons when pinsneq(15) :> buttonInput;
		buttons when pinseq(15) :> void;
		switch (buttonInput) {
		case BTNA:
			// A = move left
			toVisualiser <: BTN_L;
			break;
		#pragma fallthrough
		case BTNB:
		case BTNC:
			// B/C = confirm
			toVisualiser <: BTN_CONF;
			setupCount--;
			break;
		case BTND:
			// D = move right
			toVisualiser <: BTN_R;
			break;
		}
	}
	while (running) {
		buttons when pinsneq(15) :> buttonInput;
		buttons when pinseq(15) :> void;
		switch (buttonInput) {
		case BTNA:
			// A = Start
			if (paused) {
				paused = 0;
				toVisualiser <: BTN_PAUSERES;
			}
			break;
		case BTNB:
			// B = Pause
			if (!paused) {
				toVisualiser <: BTN_PAUSERES;
				paused = 1;
			}
			break;
		case BTNC:
			// C = Quit
			if (paused) {
				toVisualiser <: BTN_PAUSERES;
			}
			toVisualiser <: BTN_STOP;
			running = 0;
			paused = 0;
			break;
		case BTND:
			// D = Noop
			break;
		}
	}
}

//unsigned int vToT(int velocity) {
//	return 10000000 / velocity;
//}

unsigned int sanitiseVelocity(unsigned int vel) {
	if (vel <= 1000000) {
		// If more than 10 times faster, revert to 10x speed.
		return 1000000;
	} else if (vel >= 100000000) {
		// If less than 10 times slower, revert.
		return 100000000;
	} else {
		return vel;
	}
}

//PARTICLE...thread to represent a particle - to be replicated noParticle-times
void particle(streaming chanend left, streaming chanend right, chanend toVisualiser, int startPosition, int startDirection, unsigned int startVelocity) {
	unsigned int moveCounter = 0; //overall no of moves performed by particle so far
	int position = startPosition; //the current particle position
	int attemptedPosition; //the next attempted position after considering move direction
	int currentDirection = startDirection; //the current direction the particle is moving
	int leftMoveForbidden = 0; //the verdict of the left neighbour if move is allowed
	int rightMoveForbidden = 0; //the verdict of the right neighbour if move is allowed
	unsigned int currentVelocity = startVelocity; //the current particle velocity (old default = 10000000)
	int waitingOn = NO_DIR; // -1 if waiting for left resp, 1 if right, 0 if no req sent
	int rcvTemp; //temp var to hold messagesy
	timer tmr;
	unsigned int t, waitTime;
	int shutdownRequested = 0;
	int live = 0;
	int leftBound, rightBound;

	toVisualiser :> leftBound;
	toVisualiser :> rightBound;
	position = mod12(leftBound + 1);
	toVisualiser <: position;

	while (!live) {
		toVisualiser :> rcvTemp;
		switch (rcvTemp) {
		case BTN_L:
			attemptedPosition = mod12(position + LEFT);
			if (leftBound == NO_BOUND || attemptedPosition != leftBound) {
				position = attemptedPosition; //TODO: make a beep
				toVisualiser <: position;
			} else {
				toVisualiser <: 10000; // Make a beep.
			}
			break;
		case BTN_R:
			attemptedPosition = mod12(position + RIGHT);
			if (rightBound == NO_BOUND || attemptedPosition != rightBound) {
				position = attemptedPosition;
				toVisualiser <: position;
			} else {
				toVisualiser <: 10000; // Make a beep.
			}
			break;
		case BTN_CONF:
			startPosition = position;
			live = 1;
			toVisualiser <: position;
			break;
		default:
			toVisualiser <: position;
			break;
		}
	}

	toVisualiser <: startPosition;
	tmr :> waitTime; //First move is now.

	while (live) {
		// TODO: Prioritise reading responses over checking new requests.
		select {
			case toVisualiser :> rcvTemp:
				if (rcvTemp == PARTICLE_PREP_STOP) {
					shutdownRequested = 1;
				} else if (rcvTemp == PARTICLE_STOP) {
					live = 0;
				}
				break;
			case left :> rcvTemp:
				switch (waitingOn) {
				case LEFT:
					// Waiting for response from left, message from left.
					if (!shutdownRequested) {
						// Only act on response if we're not shutting down.
						if (rcvTemp == MOVE_OK) {
							position = attemptedPosition;
							// Increment move counter.
							moveCounter++;
						} else if (rcvTemp == MOVE_FAIL_CRASH) {
							// We have crashed, change direction.
							currentDirection *= -1;
						} else {
							// We have rear ended, change direction and slow down.
							currentVelocity = sanitiseVelocity(currentVelocity + 200000);
						}
						toVisualiser <: position;
						tmr :> t;
						waitTime = t + currentVelocity;
					}
					waitingOn = NO_DIR;
					break;
				case RIGHT:
					// Waiting for response from right, left is requesting.
					if (rcvTemp > 11) {
						printf("Left responding when we aren't waiting!\n");
					}
					if (rcvTemp == position) {
						// The left particle is trying to move into us, crash it. We are moving away from it already, so we simply continue.
						left <: MOVE_FAIL_REAR;
					} else {
						left <: MOVE_OK;
					}
					break;
				default:
					// We're not waiting for anyone. We must be waiting to send a move request. We are being sent a request.
					if (rcvTemp > 11) {
						printf("Right responding when we aren't waiting! (No wait)\n");
					}
					if (rcvTemp == position && currentDirection == LEFT) {
						// Head on collision. Bounce.
						currentDirection *= -1;
						attemptedPosition = position;
						left <: MOVE_FAIL_CRASH;
					} else if (rcvTemp == position) {
						// Rear ended. Push back the other but stay on course.
						currentVelocity = sanitiseVelocity(currentVelocity - 200000);
						left <: MOVE_FAIL_REAR;
					} else {
						// Left is in the clear.
						left <: MOVE_OK;
					}
					break;
				}
			break; // LEFT RCV
			case right :> rcvTemp:
				// This should always reflect the left case, but with mirrored directions.
				switch (waitingOn) {
					case RIGHT:
						if (!shutdownRequested) {
							// Only act on response if we're not shutting down.
							// Waiting for response from right, message from right.
							if (rcvTemp == MOVE_OK) {
								position = attemptedPosition;
								// Increment move counter.
								moveCounter++;
							} else if (rcvTemp == MOVE_FAIL_CRASH) {
								// We have crashed, change direction.
								currentDirection *= -1;
							} else {
								// We have rear ended, change direction and slow down.
								currentVelocity = sanitiseVelocity(currentVelocity + 200000);
							}
							toVisualiser <: position;
							tmr :> t;
							waitTime = t + currentVelocity;

						}
						waitingOn = NO_DIR;
						break;
					case LEFT:
						// Waiting for response from left, right is requesting.
						if (rcvTemp > 11) {
							printf("Right responding when we aren't waiting!\n");
						}
						if (rcvTemp == position) {
							// The left particle is trying to move into us, crash it. We are moving away from it already, so we simply continue.
							right <: MOVE_FAIL_REAR;
						} else {
							right <: MOVE_OK;
						}
						break;
					default:
						// We're not waiting for anyone. We must be waiting to send a move request. We are being sent a request.
						if (rcvTemp > 11) {
							printf("Right responding when we aren't waiting! (No wait)\n");
						}
						if (rcvTemp == position && currentDirection == RIGHT) {
							// Head on collision. Bounce.
							currentDirection *= -1;
							attemptedPosition = position;
							right <: MOVE_FAIL_CRASH;
						} else if (rcvTemp == position) {
							// Rear ended. Push back the other but stay on course.
							currentVelocity = sanitiseVelocity(currentVelocity + 200000);
							right <: MOVE_FAIL_REAR;
						} else {
							// Right is in the clear.
							right <: MOVE_OK;
						}
						break;
					}
				break; // RIGHT RCV
				default:
					tmr :> t;

					//if (t >= waitTime && waitingOn != NO_DIR) {
						//printf("particle %d in pos %d has timed out waiting for %d\n", startPosition, position, waitingOn);
					//}
					// If we're waiting to shutdown, we should never send.
					if (t >= waitTime && waitingOn == NO_DIR && !shutdownRequested) {
						// Request to move.
						attemptedPosition = mod12(position + currentDirection);

						switch (currentDirection) {
						case LEFT:
							left <: attemptedPosition;
							waitingOn = LEFT;
							break;
						case RIGHT:
							right <: attemptedPosition;
							waitingOn = RIGHT;
							break;
						default:
							printf("Error invalid direction.\n");
							break;
						}
					}
				break; // DEFAULT
		}
	}

	printf("Shutting down particle %d\n", startPosition);
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
			on stdcore[i%4]: particle(neighbours[i], neighbours[(i+1) % noParticles], show[i], ((12/noParticles)*i) % 12, (i & 1) ? -1 : 1, 10000000 + i*200000);
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
