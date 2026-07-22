class_name Story
extends RefCounted

# Deepwood's scripted story beats, kept in one place (canon: GAME_BIBLE §2/§9,
# reworked 2026-07-20 with the dev's new story draft -- tone pass delegated).
# Delivered via DialogueBox in brief exchanges -- the story is EARNED through the
# loop, not told in long cutscenes. Tone: epic & mythic. The player is addressed
# only as a nameless hunter -- their true nature (the Shadow Monarch) stays
# sealed and unspoken until the very end.
#
# NEW CANON (dev decisions, 2026-07-20):
# - The player is a CALAMITY ORPHAN: born after the fall, raised fighting
#   despair's armies; his only motive is the rumored safe place "where he can
#   close his eyes for long without a thought."
# - The Shadow Monarch's soul found its soulmate YEARS ago, too weak to merge,
#   and followed him -- his improbable survivals were never luck. The choking
#   at Deepwood's gate is the bond completing, not a first meeting.
# - The finale: floor 100 is EMPTY; the false victory pumps the village to its
#   peak; Orin reveals himself AT THE FEAST; the Harvest is fought at home.

# THE PROLOGUE -- plays once at the start of a new game. The narrator carries
# the before/after of Deepwood; then the choking beat: the bond completing.
const PROLOGUE = [
	{"speaker": "", "text": "There was a village the whole broken world whispered about. Deepwood — scholars and builders, forges and full tables, the brightest place of the age. When the calamity came for everything else, Deepwood held. For YEARS, it held."},
	{"speaker": "", "text": "You were born after the world ended. The dark took your family before you could name them. You were raised by the road and the blade, fighting the armies of despair because there was never anything else."},
	{"speaker": "", "text": "You walked toward Deepwood for one reason only. Not glory. Not answers. A place where a man could close his eyes for a long time — without a thought."},
	{"speaker": "", "text": "At the treeline, something finds you. It has been following you your whole life — through every escape you never should have survived. Tonight it is done waiting. It pours into you like a held breath finally let go."},
	{"speaker": "You", "text": "(choking) — what — what did I just swallow—"},
	{"speaker": "You", "text": "...No. No time. Something's screaming up ahead."},
]

# THE TRAP EXPLAINED (2.4.1 beat 2) -- the wave the player helped break was the
# trio's hundredth. With the field quiet, they say the thing that makes the
# whole game happen HERE: there is no way out.
const ARRIVAL_TRAP = [
	{"speaker": "Roland", "text": "Easy — breathe. That was the last of tonight's. You swing like someone worth keeping."},
	{"speaker": "Wren", "text": "Don't thank us yet, stranger. We've been stuck in this valley for weeks. There is no way out."},
	{"speaker": "Castor", "text": "We tried. Every road out — the horde grows to meet you. Ten becomes a hundred. A hundred becomes a wall."},
	{"speaker": "Wren", "text": "It's not a siege. It's a cage. Whatever is below sends exactly as much dark as it takes to keep us in."},
	{"speaker": "Roland", "text": "So we hold this ruin, because there is nothing else to hold. And if you ever want out of this valley alive—"},
	{"speaker": "Castor", "text": "—there's only one direction left. Down. Through the root of it."},
]

# THE REVEAL OF THE RUIN (new canon: the 180-degree reality check). The four
# were all chasing the same rumour of a safe haven -- and a frightened survivor
# tells them they are already standing in it.
const DEEPWOOD_REVEAL = [
	{"speaker": "", "text": "A figure creeps from the wreckage — thin, hollow-eyed, flinching at his own footsteps. He has watched the whole fight from a broken doorway."},
	{"speaker": "A Survivor", "text": "Wait— WAIT. Don't go looking for the road, travellers. There is nothing out there for you."},
	{"speaker": "A Survivor", "text": "You're searching for Deepwood, aren't you. Everyone who still breathes is searching for Deepwood. The safe place. The bright place."},
	{"speaker": "A Survivor", "text": "...Look around you. This IS Deepwood. This is what they left of it. They dragged the strong down into the dark, alive — and killed everyone else."},
	{"speaker": "", "text": "The word lands like a blade. The haven you crossed a dying world to find — the place where you were finally going to rest — is the ruin you are standing in."},
	{"speaker": "Roland", "text": "...Then we hold what's left. Friend — one thing before we dig in. That dark. Does it ever come at us from the east road? Both sides at once?"},
	{"speaker": "A Survivor", "text": "No. Never the east — that road's been dead quiet since the fall. It only ever claws UP out of the pit, from the deep in the west. Guard the dungeon mouth and you've guarded Deepwood."},
	{"speaker": "Castor", "text": "One front, then. Small mercy. We watch the west, and we watch it well."},
]

# THE OATH (new canon: the four swear it together). The plan the whole game
# executes, said aloud once.
const THE_OATH = [
	{"speaker": "Roland", "text": "Then there's nothing left to search for. It was always going to end here."},
	{"speaker": "Wren", "text": "The world out there is ash. If a safe place is going to exist... someone has to build it."},
	{"speaker": "You", "text": "Then we build THIS one. Free the taken. Raise the walls. Make Deepwood what the rumour promised — and when it stands, I'm going down after the thing that did this."},
	{"speaker": "Castor", "text": "Down through a hundred floors of the dark. ...Aye. I've followed worse plans."},
	{"speaker": "", "text": "No parchment, no ceremony. Four strangers in a dead village, swearing the only oath that matters: it lives again, or none of us leave."},
]

# THE FAILED ESCAPE (2.4.1 beat 3) -- the player tries the road out himself and
# barely survives it. One-shot.
const FAILED_ESCAPE = [
	{"speaker": "", "text": "The moment you turn for the open road, the treeline MOVES. Not a patrol. Not a wave. The whole dark rises to meet you — twice as many for every step you take."},
	{"speaker": "You", "text": "...The three weren't cowards. The way out isn't blocked. It's bait."},
	{"speaker": "", "text": "You crawl back inside the ruin of Deepwood with your life and nothing else. The exit is not an option. The only way out is THROUGH — down, to the root of it."},
]

# THE DOCTOR'S ACCOUNT (2.4.1 beat 5 + 2.5.1 beat 1) -- the Law of Despair told
# by a survivor, and the rumour of the lost wizard (dramatic irony's opening
# move: she mourns Orin as another dead hero).
const DOCTOR_ACCOUNT = [
	{"speaker": "Doctor Maren Hollis", "text": "Hold still. I've stitched all three of those fools at that wall more times than I can count — one more stranger is no trouble."},
	{"speaker": "Doctor Maren Hollis", "text": "You should have seen Deepwood before. Scholars. Builders. The brightest village of the age. We held for YEARS after the calamity began — we thought being clever would save us."},
	{"speaker": "Doctor Maren Hollis", "text": "Then the waves grew wrong. Monstrous. They took the strong-willed alive, down into the deep — and the weak-willed... turned. The thing at our gates wears our neighbours' faces."},
	{"speaker": "Doctor Maren Hollis", "text": "Heroes came, over the months. Good blades, brave hearts. Every one went down after our people; not one came back. But the wizard — weeks ago now — he was different. Stronger. I could FEEL it. We hoped hardest for him."},
	{"speaker": "Doctor Maren Hollis", "text": "No one returns from the deep. I set a candle for him with all the rest. So it falls to you and those three out there — bring my people home, hunter. I'll keep every one of you breathing as long as I have thread."},
]

# THE PACT (2.5.1 beats 2+3) -- Orin's return and the introductions. Every word
# of his is a lie shaped to mirror the player's own arrival -- and his last line
# is the game's whole betrayal hidden in plain sight.
const ORIN_PACT = [
	{"speaker": "", "text": "At the wall stands a stranger in a traveler's robe — whole, unhurried, as though returning from a long walk. The Doctor waves you over."},
	{"speaker": "Doctor Maren Hollis", "text": "Hunter — this is Orin. The wizard I set a candle for. Four days ago he walked out of the deep, alive. I have checked him twice for wounds. There are none."},
	{"speaker": "Orin", "text": "A wandering mage, nothing grander. I chased the same rumour you all did — a brilliant village, a haven at the edge of the dark. I came, found it emptied... and went down after its people."},
	{"speaker": "Orin", "text": "I cleared one of their levels. Then the dark closed the way, and it cost me weeks to climb back out. Believe me, hunter — I know exactly how deep you've gotten. I keep count."},
	{"speaker": "Roland Ashmark", "text": "We held the wall while you were down there, stranger. If you can throw fire, the nights are where we bleed."},
	{"speaker": "Orin", "text": "Then the nights are mine. Meteors ask less of me than climbing does."},
	{"speaker": "Doctor Maren Hollis", "text": "Then say it plain, all of us. The world beyond is ash. This village — its tools, its people — is the only way anyone here outlasts what is coming."},
	{"speaker": "You", "text": "Rebuild Deepwood. Free the taken. Grow strong enough to reach the root."},
	{"speaker": "Orin", "text": "...To the root. Yes. Build it all back, hunter — the forges, the walls, the people. I want to see this village at its very peak."},
	{"speaker": "", "text": "(He smiles like a man who has already read the ending. The pact is struck — from tonight, Orin holds the watch.)"},
]

# The GLIMPSE (2.5.1 beat 2, the dungeon half): the floor-15 boss falls, and
# for one breath he is simply THERE.
const ORIN_GLIMPSE = [
	{"speaker": "", "text": "The boss falls — and at the far gate, for one breath, a robed figure stands watching. Unhurried. Unhurt. When you blink, the gate is empty."},
]

# THE EMPTY THRONE (new canon 9.2): floor 100 holds... nothing. The player
# searches, and the silence is the trap's final move.
const EMPTY_THRONE = [
	{"speaker": "", "text": "The last gate opens on — silence. No horde. No throne-guard. A hall built for a king of the dark, and it is EMPTY."},
	{"speaker": "You", "text": "...Hello? I came a hundred floors for you. Show yourself."},
	{"speaker": "", "text": "You search every shadow, every seam of the stone. Nothing lives here. Nothing has for days. As if the whole deep simply... finished."},
	{"speaker": "You", "text": "It's over, then. The root is dead — or fled. Either way..."},
	{"speaker": "You", "text": "...either way, they need to hear this. All of them. Tonight, Deepwood SLEEPS without fear."},
]

# THE FALSE VICTORY -- home with the news; the village erupts. This is the
# moment the whole game bought: hope, complete, at its peak. (Orin's design:
# the higher the hope, the harder the fall.)
const FALSE_VICTORY = [
	{"speaker": "You", "text": "PEOPLE OF DEEPWOOD — the deep is EMPTY. A hundred floors, and nothing left alive in the dark. It's over. We won."},
	{"speaker": "", "text": "For one heartbeat, no one dares believe it. Then the square ERUPTS. Farmers drop their tools. The forge falls quiet. Someone is ringing the tower bell for joy alone."},
	{"speaker": "", "text": "Tables drag into the square. Casks open. The children are allowed up past dark. Deepwood — rebuilt from ash by your own hands — laughs under its lanterns for the first time in years."},
	{"speaker": "", "text": "Every face you saved is here. Every hope you kept alive burns at its brightest. It is, at last, the safe place the whole world whispered about."},
]

# THE REVEAL AT THE FEAST (new canon 9.2/9.3): lightning; the beloved defender
# turns at the height of the joy he engineered. Ilo's line joins when he's free.
const REVEAL_AT_FEAST = [
	{"speaker": "", "text": "Lightning tears the sky above the square — and the lanterns die all at once. In the sudden dark, only one figure is still smiling."},
	{"speaker": "Orin", "text": "Magnificent, isn't it. I have waited SO patiently for this exact evening — the tables full, the walls finished, every heart at its brightest. A harvest is only worth reaping at its peak."},
	{"speaker": "Orin", "text": "You came so far, little hunter. It's almost a pity you never understood whose dungeon you were clearing. The deep wasn't empty because you won. It was empty because EVERYTHING I own was already here."},
	{"speaker": "Orin", "text": "I am the end of the living. I am the Monarch of Despair. Deepwood was never being defended. It was being harvested — slowly, so the crop would never fail."},
	{"speaker": "???", "text": "(Something stirs in the bond behind your ribs — not a memory, a FLASH. You have faced this power before. You have LOST to it before.)"},
	{"speaker": "Orin", "text": "...There. That look. Do you know, for a moment you stood like a king. Where WOULD a stray hunter learn to stand like that, I wonder."},
	{"speaker": "You", "text": "You talk like a man who's already won. The ones who taught me to stand talked the same way. I buried the lesson with them."},
	{"speaker": "Orin", "text": "Courteous to the last. I have genuinely enjoyed this, hunter — the building most of all. Now watch closely. Watch what everything you built does when the truth arrives."},
	{"speaker": "", "text": "The truth lands like a blade in every heart at once: their hero IS the thing that took their families. Around you, the people of Deepwood sink to their knees — kneeling to him as the last of their hope dies — and begin to TURN."},
]

# THE RESUMED HARVEST -- the player quit (or the world crashed) mid-fight and
# came back. The half-turned town cannot be left half-turned: while its master
# lives, the turning does not stay down.
const HARVEST_RESUME = [
	{"speaker": "Orin", "text": "...Back so soon? Did you imagine the feast would clean itself up if you looked away long enough?"},
	{"speaker": "Orin", "text": "The turning does not stay down while its master lives, hunter. Come. We were IN THE MIDDLE of something."},
]

# THE ENDING -- the soul is divided, the deathless made mortal for one instant,
# and the blow lands. The bond completes; the Shadow Monarch wakes fully.
const ENDING = [
	{"speaker": "", "text": "His soul, scattered across a hundred failing echoes to survive the assault of a village that would not fall — thin, divided, and for the first time in an age: MORTAL."},
	{"speaker": "You", "text": "An undivided soul cannot be destroyed. So I divide it. This is the end of Despair."},
	{"speaker": "", "text": "The blow lands on the soul itself. And in the same instant, the thing that has followed you your whole life — the quiet weight behind your ribs, the luck that was never luck — finally, fully, WAKES."},
	{"speaker": "The Shadow Monarch", "text": "I remember now. The throne. The name. The war that broke the first world. I searched the ages for the one soul shaped like mine — and found him already fighting my war, alone, with a mortal's hands."},
	{"speaker": "The Shadow Monarch", "text": "But I saved Deepwood as a man. I will keep it as one. One Monarch is ended. Somewhere beyond this world, another still waits — they say the strongest of us now. Let him wait a little longer."},
]
