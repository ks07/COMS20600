/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20600 - WEEKS 3 and 4
// ASSIGNMENT 1
// CODE SKELETON
// TITLE: "LED Ant Defender Game"
//
// - this is the first assessed piece of coursework in the unit
// - this assignment is to be completed in pairs during week 3 and 4
// - it is worth 10% of the unit (i.e. 20% of the course work component)
//
// OBJECTIVE: given a code skeleton with threads and channels setup for you,
// implement a basic concurrent system on the XC-1A board
//
// NARRATIVE: You are given an XC code skeleton that provides you with
// the structure and helper routines to implement a basic game on the
// XC-1A board. Your task is to extend the given skeleton code to implement
// the following game:
//
// An “LED Ant” is represented by a position on the clock wheel of the
// XC-1A board. Each “LED Ant” is visualised by one active red LED on
// the 12-position LED clock marked with LED labels I, II, II,…, XII.
// No two LED Ants can have the same position on the clock. During the
// game, the user has to defend LED positions I, XII and XI from an
// LED Attacker Ant by controlling one LED Defender Ant and blocking the
// attacker's path.
//
// Defender Ant
// The user controls one “LED Ant” by pressing either button A (moving
// 1 position clockwise) or button D (moving 1 position anti-clockwise).
// The defender ant can only move to a position that is not already occupied
// by the attacker ant. The defender’s starting position is LED XII. A sound
// is played when the user presses a button.
//
// Attacker Ant
// A second “LED Ant” is controlled by the system and starts at LED position VI.
// It then attempts moving in one direction (either clockwise or anti-clockwise).
// This attempt is denied if the defender ant is already located there, in this
// case the attacker ant changes direction. To make the game more interesting:
// before attempting the nth move, the attacker ant will change direction if n is
// divisible by 23, 37 or 41. The game ends when the attacker has reached any one
// of the LED positions I, XII or XI.
//
/////////////////////////////////////////////////////////////////////////////////////////

#include <stdio.h>
#include <platform.h>

#define MOVE_GAME_OVER 16
#define ATK_PAUSE 17

#define BTN_STOP 0
#define BTN_GO 1

// Constants to define ant pos to signify special states.
#define USR_RESET 16
#define USR_END 17

// Pick a value out of valid position range
#define VIS_STOP 16

// Pick a value outside valid LED patterns
#define LED_STOP 15

// (Un)comment the following line to (hide)/print debug messages.
//#define DEBUG

out port cled0 = PORT_CLOCKLED_0;
out port cled1 = PORT_CLOCKLED_1;
out port cled2 = PORT_CLOCKLED_2;
out port cled3 = PORT_CLOCKLED_3;
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;
in port buttons = PORT_BUTTON;
out port speaker = PORT_SPEAKER;

/////////////////////////////////////////////////////////////////////////////////////////
//
// Helper Functions provided for you
//
/////////////////////////////////////////////////////////////////////////  ////////////////

//DISPLAYS an LED pattern in one quadrant of the clock LEDs
int showLED(out port p, chanend fromVisualiser) {
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
	printf("LED quad finished\n");
	return 0;
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
void visualiser(chanend fromUserAnt, chanend fromAttackerAnt, chanend toQuadrant0, chanend toQuadrant1, chanend
	toQuadrant2, chanend toQuadrant3) {
	unsigned int userAntToDisplay = 11;
	unsigned int attackerAntToDisplay = 5;
	int i, j, c;
	int userRun = 1;
	int atkRun = 1;
	timer tmr;
	unsigned int t;
	int lights[12];
	cledR <: 1;
	// Only turn off the visualiser when both attacker and user are finished.
	while (userRun || atkRun) {
		select {
			case fromUserAnt :> userAntToDisplay:
				break;
			case fromAttackerAnt :> attackerAntToDisplay:
				break;
		}

		if (userAntToDisplay == VIS_STOP) {
			// userAnt no longer needs our services.
			printf("user asked to stop vis\n"); // TODO: I get called twice?
			userRun = 0;
		}
		if (attackerAntToDisplay == VIS_STOP) {
			// attackerAnt no longer needs our services.
			printf("atk asked to stop vis\n");
			atkRun = 0;
		}
		if (userAntToDisplay < 12 && attackerAntToDisplay < 12){
			j = 16<<(userAntToDisplay%3);
			i = 16<<(attackerAntToDisplay%3);
			toQuadrant0 <: (j*(userAntToDisplay/3==0)) + (i*(attackerAntToDisplay/3==0)) ;
			toQuadrant1 <: (j*(userAntToDisplay/3==1)) + (i*(attackerAntToDisplay/3==1)) ;
			toQuadrant2 <: (j*(userAntToDisplay/3==2)) + (i*(attackerAntToDisplay/3==2)) ;
			toQuadrant3 <: (j*(userAntToDisplay/3==3)) + (i*(attackerAntToDisplay/3==3)) ;
//			tarr[0] = userAntToDisplay;
//			tarr[1] = attackerAntToDisplay;
//			showPattern(tarr, 2, toQuadrant0, toQuadrant1, toQuadrant2, toQuadrant3);
		}
	}

	// Flash some lights when shutting down.
	// Initialise lights array to turn on all LEDs
	for (i = 0; i < 12; i++) {
		lights[i] = i;
	}

	// Use j to hold toggle
	j = 0;

	// Colour toggle
	c = 0;

	// The game is over, blink LEDs & switch off after some time
	for (i = 0; i <= 8; i++) {
		tmr :> t;
		t += 100000000;
		tmr when timerafter(t) :> void; // Feed into void to throw away value.
		showPattern(lights, (j ? 12 : 0), toQuadrant0, toQuadrant1, toQuadrant2, toQuadrant3);
		j = !j;

		if (i & 1 == 1) {
			cledR <: c;
			c = !c;
			cledG <: c;
		}
	}

	// Shut off LED processes
	toQuadrant0 <: LED_STOP;
	toQuadrant1 <: LED_STOP;
	toQuadrant2 <: LED_STOP;
	toQuadrant3 <: LED_STOP;

	#ifdef DEBUG
	printf("output finished\n");
	#endif
}

//PLAYS a short sound (pls use with caution and consideration to other students in the labs!)
void playSound(unsigned int wavelength, out port speaker) {
	timer tmr;
	int t, isOn = 1;
	tmr :> t;
	for (int i=0; i<2; i++) {
		isOn = !isOn;
		t += wavelength;
		tmr when timerafter(t) :> void;
		speaker <: isOn;
	}
}

//READ BUTTONS and send to userAnt
void buttonListener(in port b, out port spkr, chanend toUserAnt) {
	int r;
	int btnState = BTN_GO;

	while (btnState == BTN_GO) {
		b when pinsneq(15) :> r; // check if some buttons are pressed
		playSound(2000000,spkr); // play sound
		toUserAnt <: r; // send button pattern to userAnt

		toUserAnt :> r; // retrieve game state.
		if (r == BTN_STOP) {
			// Game is over.
			btnState = BTN_STOP;
		}
	}

	#ifdef DEBUG
	printf("input finished\n");
	#endif
}

//WAIT function
void waitMoment() {
	timer tmr;
	unsigned int waitTime;
	tmr :> waitTime;
	waitTime += 10000000;
	tmr when timerafter(waitTime) :> void;
}



/////////////////////////////////////////////////////////////////////////////////////////
//
// RELEVANT PART OF CODE TO EXPAND FOR YOU
//
/////////////////////////////////////////////////////////////////////////////////////////

//DEFENDER PROCESS... The defender is controlled by this process userAnt,
// which has channels to a buttonListener, visualiser and controller
void userAnt(chanend fromButtons, chanend toVisualiser, chanend toController) {
	unsigned int userAntPosition = 11; //the current defender position
	int buttonInput; //the input pattern from the buttonListener
	unsigned int attemptedAntPosition = 0; //the next attempted defender position after considering button
	int moveResponse; //the verdict of the controller if move is allowed
	int running = 1;
	int waitingReset = 0;
	toVisualiser <: userAntPosition; //show initial position
	while (running) {
		fromButtons :> buttonInput;

		if (waitingReset) {
			if (buttonInput == 11) {
				// Centre-Right button
				printf("Shutting down!\n");

				toController <: USR_END;
				// We want to stop, inform buttonListener/visualiser.
				fromButtons <: BTN_STOP;
				running = 0;
				toVisualiser <: VIS_STOP;
			} else if (buttonInput == 13) {
				// Centre-Left button
				fromButtons <: BTN_GO; // Tell buttons to continue.
				toController <: USR_RESET;
				waitingReset = 0;
				// Reset our position.
				userAntPosition = 11;
				attemptedAntPosition = 0;
				toVisualiser <: userAntPosition;
			} else {
				fromButtons <: BTN_GO; // Continue
				// If other buttons pressed, skip this input.
			}
		} else {
			if (buttonInput == 14) {
				attemptedAntPosition = (userAntPosition + 1) % 12;
			} else if (buttonInput == 7) {
				attemptedAntPosition = userAntPosition == 0 ? 11 : userAntPosition - 1;
			} else {
				attemptedAntPosition = userAntPosition;
			}

			if (buttonInput == 14 || buttonInput == 7) {
				toController <: attemptedAntPosition;
				toController :> moveResponse;

				if (moveResponse == attemptedAntPosition) {
					// Move was valid, update position.
					userAntPosition = attemptedAntPosition;
					toVisualiser <: userAntPosition;
					// Keep going
					//fromButtons <: BTN_GO;
				} else if (moveResponse == MOVE_GAME_OVER) {
					// Current game has ended, wait for a reset or shutdown button to send.
					waitingReset = 1;
					//fromButtons <: BTN_GO;
				} else if (moveResponse < 12) {
					// Move failed, or game just started. Move to given location (usually our previous position).
					userAntPosition = moveResponse;
					toVisualiser <: userAntPosition;
					//fromButtons <: BTN_GO; // Buttons should continue.
				} else {
					// ASSERTION FAILED!!11!1111!!!
					printf("WARNING: User received invalid moveResponse (%d)", moveResponse);
				}
			}

			fromButtons <: BTN_GO;

			//waitMoment();
		}
	}

	#ifdef DEBUG
	printf("user finished\n");
	#endif
}

//ATTACKER PROCESS... The attacker is controlled by this process attackerAnt,
// which has channels to the visualiser and controller
void attackerAnt(chanend toVisualiser, chanend toController) {
	int moveCounter = 0; //moves of attacker so far
	unsigned int attackerAntPosition = 5; //the current attacker position
	unsigned int attemptedAntPosition; //the next attempted position after considering move direction
	int currentDirection = 1; //the current direction the attacker is moving
	int moveResponse; //the verdict of the controller of our position after our attempted move, or game state
	int run = 1;
	int isPaused = 0;
//	toVisualiser <: attackerAntPosition; //show initial position
	while (run) {
		if (moveCounter % 31 == 0 || moveCounter % 37 == 0 || moveCounter % 43 == 0) {
			currentDirection = !currentDirection;
		}

		attemptedAntPosition = attackerAntPosition + (currentDirection ? 1 : -1);
//		if (!isPaused)
			toController <: attemptedAntPosition;
		toController :> moveResponse;
		isPaused = 0;

		if (moveResponse == attemptedAntPosition) {
			// Move was allowed.
			attackerAntPosition = attemptedAntPosition;
			toVisualiser <: attackerAntPosition;
		} else if (moveResponse == ATK_PAUSE) {
			// We win. The game has ended.
			attackerAntPosition = attemptedAntPosition; // Move to the winning position, so the user can see.
			toVisualiser <: attackerAntPosition;
			isPaused = 1;
		} else if (moveResponse < 12) {
			// Move failed, or game just started. Move to given location (usually our previous position)
			currentDirection = !currentDirection; // Has the super fun effect of switching the direction at start of game.
			attackerAntPosition = moveResponse;
			toVisualiser <: attackerAntPosition;
		} else if (moveResponse == MOVE_GAME_OVER) {
			// After winning, user has chosen to shutdown.
			run = 0;
		} else {
			// ASSERTION FAILED!!11!1111!!!
			printf("WARNING: Attacker received invalid moveResponse (%d)", moveResponse);
		}

		moveCounter++;
		waitMoment();
	}

	toVisualiser <: VIS_STOP;

	#ifdef DEBUG
	printf("attacker finished\n");
	#endif
}

int attackerWins(int attackerAntPos) {
	switch (attackerAntPos) {
	case 0:
	case 10:
	case 11:
		return 1;
		break;
	default:
		return 0;
	}
}

//COLLISION DETECTOR... the controller process responds to “permission-to-move” requests
// from attackerAnt and userAnt. The process also checks if an attackerAnt
// has moved to LED positions I, XII and XI.
void controller(chanend fromAttacker, chanend fromUser) {
	unsigned int lastReportedUserAntPosition; //position last reported by userAnt
	unsigned int lastReportedAttackerAntPosition; //position last reported by attackerAnt
	unsigned int attempt;
	int running = 1;
	int reset = 1;
	int timeWin = 0;
	timer tmr;
	unsigned int t, endtime;
	while (reset) {
		// Disregard the attacker's first move, instead tell it to move to starting position.
		fromAttacker :> attempt;
		lastReportedAttackerAntPosition = 5;
		fromAttacker <: lastReportedAttackerAntPosition;

		fromUser :> attempt; //start game when user moves
		lastReportedUserAntPosition = 11;
		fromUser <: lastReportedUserAntPosition; //forbid first move
		tmr :> t;
		endtime = t + 1000000000; // define when game should end from now

		while (running) {
			select {
				case fromAttacker :> attempt:
					/////////////////////////////////////////////////////////////
					//
					// !!! place your code here to give permission/deny attacker move or to end game
					//
					/////////////////////////////////////////////////////////////
					tmr :> t;
					if (t > endtime) {
						// Attacker wins, send signals to all processes to shut off.
						fromAttacker <: ATK_PAUSE;
						lastReportedAttackerAntPosition = attempt;
						// Before we inform userAnt, we should make sure it is not blocking on us.
						fromUser :> attempt;
						// Read and dump value
						fromUser <: MOVE_GAME_OVER;
						running = 0;
						timeWin = 1;
					} else if (lastReportedUserAntPosition == attempt) {
						fromAttacker <: lastReportedAttackerAntPosition;
					} else if (attackerWins(attempt)) {
						// Attacker wins, send signals to all processes to shut off.
						fromAttacker <: ATK_PAUSE;
						lastReportedAttackerAntPosition = attempt;
						// Before we inform userAnt, we should make sure it is not blocking on us.
						fromUser :> attempt;
						// Read and dump value
						fromUser <: MOVE_GAME_OVER;
						running = 0;
						timeWin = 0;
					} else {
						fromAttacker <: attempt;
						lastReportedAttackerAntPosition = attempt;
					}
					break;
				case fromUser :> attempt:
					/////////////////////////////////////////////////////////////
					//
					// !!! place your code here to give permission/deny user move
					//
					/////////////////////////////////////////////////////////////
					if (lastReportedAttackerAntPosition == attempt) {
						// Move failed, send user back.
						fromUser <: lastReportedUserAntPosition;
					} else {
						// Move ok.
						fromUser <: attempt;
						lastReportedUserAntPosition = attempt;
					}
					break;
			}
		}

		// Ask userAnt if we should reset or shutdown.
		fromUser :> attempt;

		if (attempt == USR_RESET) {
			reset = 1;
			running = 1;
			// Tell attackerAnt to reset position.

		} else if (attempt == USR_END) {
			reset = 0;
			// Tell attackerAnt to shutdown.
			fromAttacker :> attempt; //Clear the channel
			fromAttacker <: MOVE_GAME_OVER;
		}
	}

	#ifdef DEBUG
	printf("controller finished\n");
	#endif
}

//MAIN PROCESS defining channels, orchestrating and starting the processes
int main(void) {
	chan buttonsToUserAnt, //channel from buttonListener to userAnt
	userAntToVisualiser, //channel from userAnt to Visualiser
	attackerAntToVisualiser, //channel from attackerAnt to Visualiser
	attackerAntToController, //channel from attackerAnt to Controller
	userAntToController; //channel from userAnt to Controller
	chan quadrant0,quadrant1,quadrant2,quadrant3; //helper channels for LED visualisation

	par{
		//PROCESSES FOR YOU TO EXPAND
		on stdcore[1]: userAnt(buttonsToUserAnt,userAntToVisualiser,userAntToController);
		on stdcore[2]: attackerAnt(attackerAntToVisualiser,attackerAntToController);
		on stdcore[3]: controller(attackerAntToController, userAntToController);

		//HELPER PROCESSES
		on stdcore[0]: buttonListener(buttons, speaker,buttonsToUserAnt);
		on stdcore[0]: visualiser(userAntToVisualiser,attackerAntToVisualiser,quadrant0,quadrant1,quadrant2,quadrant3);
		on stdcore[0]: showLED(cled0,quadrant0);
		on stdcore[1]: showLED(cled1,quadrant1);
		on stdcore[2]: showLED(cled2,quadrant2);
		on stdcore[3]: showLED(cled3,quadrant3);
	}
	return 0;
}
