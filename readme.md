Overview
- Weeds grow up from the ground and roots grow deep / wide underground
- Player needs to remove as many weeds as possible before the all reach the top of the screen
- The player can pull weeds out using button 1
- Weeds that reach the top of the screen can't be pulled out at all
- Weeds with long roots are harder to pull out
- Score accumulates based on size and quantity of weeds removed 
- Pulling a weed will randomly produce a powerup
- Powerups are:
	- Faster movement
	- Faster weed-pulling
	- Lawn-mower to clear-cut anything except full-height weeds
		- Weeds that are clear-cut grow back quickly since roots are present
	- Weed-killer kills weeds and roots
	- Flame-thrower can remove one full-height weed but not the root

Essential
. Player moves left and right
. Basic sky / ground
. Weeds
. Weeds grow up
. Weeds grow down
. Weed generator
. Highlight active weed
. Player can pull weeds
	. Pulling shifts weed Y coordinate
	. Once root tip is above ground, weed is out
	. Player pull animation
	. Weed retracts over time
. Score-keeping
. Score display
. Game-over detection
. Game-over state
. Game restart
. Player drawn in front of weeds
- Difficulty over time
	. If not enough open columns to increase weeds / batch, increase growth rate
	- Score multiplier for chaining different columns?
	- Score multiplier for stalling plants?
- Balance
	- Growth rates
	- Stay alive forever by sitting in one spot

Important
. Title screen
. Track weeds pulled in addition to score
. Disable debug text
. Weed top becomes bigger as it gets taller
. Multiple 'tops' of weeds (aesthetic only)
. Animated player walk

Nice-to-have
. Gradient static sky
. Animated background elements (clouds, etc.)
. More varied ground map
- Sound FX for weed pull
- Multiple types / grow patterns for weeds
- Powerup: Faster weed pulling
- Powerup: Faster movement
- Weed bends if too tall
- Disabled state for highlighter
- Interesting setting 
- High score
- Sunrise / sunset fades
- Camera shake when the weed is removed
- Animated roots
- Powerup: Flame thrower
- Powerup: Lawn mower
- Weed root branching underground
- Background music