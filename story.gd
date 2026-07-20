class_name Story
extends RefCounted

# Deepwood's scripted story beats, kept in one place (see STORY.md, the canon).
# Delivered via DialogueBox in brief exchanges -- the story is EARNED through the
# loop, not told in long cutscenes. Tone: epic & mythic. The player is addressed
# only as a nameless hunter -- their true nature (the Shadow Monarch) stays
# sealed and unspoken until the very end.

# THE OPENING -- one of the taken, lucid enough to plead, greets you in the ruins.
# Establishes: the calamity, the taken, Orin the "hero", the dungeon root, and
# the mandate to free everyone and rebuild. (Fires once on a new game.)
const OPENING = [
	{"speaker": "A Frozen Villager", "text": "You there — with the blade. You walked in willingly. No one comes to Deepwood willingly anymore."},
	{"speaker": "A Frozen Villager", "text": "This was a good place, once. Then the calamity found us — the dark that is unmaking the world, city by city. It does not kill. It TAKES. It left me... like this. Neither breathing nor buried."},
	# (2.5.1 canon: Orin is ABSENT at the start -- at this point he is only the
	# rumour of a wizard who went down and never returned.)
	{"speaker": "A Frozen Villager", "text": "A wizard came, once — a stranger who swore he'd bring the taken back. He went down into the dark after them... and the dark kept him too."},
	{"speaker": "A Frozen Villager", "text": "But you have hunted this evil across a lifetime, haven't you? I see it on you. Its root is below us — a hundred floors down, in the dark it nests in."},
	{"speaker": "A Frozen Villager", "text": "To end it you must first undo what it has done. Free the taken. Rebuild what's left. Make Deepwood live again — and it will make you strong enough to reach the thing itself."},
	{"speaker": "A Frozen Villager", "text": "Please. We are all that is left. Deepwood is worth saving — even now."},
]

# THE FAILED ESCAPE (2.4.1 beat 3) -- the player tries the road out himself and
# barely survives it. The lesson lands as gameplay first (mauled to the brink,
# hurled back); these lines land the meaning. One-shot.
const FAILED_ESCAPE = [
	{"speaker": "", "text": "The moment you turn for the open road, the treeline MOVES. Not a patrol. Not a wave. The whole dark rises to meet you — twice as many for every step you take."},
	{"speaker": "You", "text": "...The three weren't cowards. The way out isn't blocked. It's bait."},
	{"speaker": "", "text": "You crawl back inside the ruin of Deepwood with your life and nothing else. The exit is not an option. The only way out is THROUGH — down, to the root of it."},
]

# THE PACT (2.5.1 beats 2+3) -- Orin's return and the introductions. Plays on
# the first village visit after carving to floor 15. Every word of his is a lie
# shaped to mirror the player's own arrival -- and his last line is the game's
# whole betrayal hidden in plain sight: he wants Deepwood at its PEAK because
# he intends to turn everything you built against you.
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

# The GLIMPSE (2.5.1 beat 2, the dungeon half): his return lands "right after a
# boss". The floor-15 boss falls, and for one breath he is simply THERE.
const ORIN_GLIMPSE = [
	{"speaker": "", "text": "The boss falls — and at the far gate, for one breath, a robed figure stands watching. Unhurried. Unhurt. When you blink, the gate is empty."},
]

# THE DOCTOR'S ACCOUNT (2.4.1 beat 5 + 2.5.1 beat 1) -- her first real talk.
# The Law of Despair told by a survivor, and the rumour of the lost wizard --
# dramatic irony's opening move: she mourns Orin as another dead hero, and
# neither she nor the player knows the "lost saviour" is the enemy itself.
const DOCTOR_ACCOUNT = [
	{"speaker": "Doctor Maren Hollis", "text": "Hold still. I've stitched all three of those fools at that wall more times than I can count — one more stranger is no trouble."},
	{"speaker": "Doctor Maren Hollis", "text": "You should have seen Deepwood before. Scholars. Builders. The brightest village of the age. We held for YEARS after the calamity began — we thought being clever would save us."},
	{"speaker": "Doctor Maren Hollis", "text": "Then the waves grew wrong. Monstrous. They took the strong-willed alive, down into the deep — and the weak-willed... turned. The thing at our gates wears our neighbours' faces."},
	{"speaker": "Doctor Maren Hollis", "text": "A wizard passed through, weeks ago. Kind eyes. He swore he'd bring our people back, and went down after them. No one returns from the deep. I set a candle for him with the rest."},
	{"speaker": "Doctor Maren Hollis", "text": "So it falls to you and those three out there. Bring my people home, hunter. I'll keep every one of you breathing as long as I have thread."},
]

# THE REVEAL -- at the gate of Level 100 the dungeon turns on you and kneels to
# Orin; the mask falls and a sealed memory stirs. (Wired when the L100 gate beat
# is built.) Kept here so the writing lives with the rest of the canon.
const L100_REVEAL = [
	{"speaker": "", "text": "The horde stops. Every enemy in the deep turns from you at once — and kneels. Toward Orin."},
	{"speaker": "Orin", "text": "You came so far, little hunter. Further than any of the others. It's almost a pity you never understood whose dungeon you were clearing."},
	{"speaker": "Orin", "text": "I am the end of the living. I am the Monarch of Despair. Deepwood was never being defended. It was being harvested — slowly, so the crop would never fail."},
	{"speaker": "???", "text": "(Something stirs behind the seal in your mind — not a memory, a FLASH. You have faced this power before. You have LOST to it before.)"},
	# the quiet, almost courteous beat (9.2): two monarchs recognizing each
	# other at last -- though only one of them knows it
	{"speaker": "Orin", "text": "...There. That look. Do you know, for a moment you stood like a king. Where WOULD a stray hunter learn to stand like that, I wonder."},
	{"speaker": "You", "text": "You talk like a man who's already won. The ones who taught me to stand talked the same way. I buried the lesson with them."},
	{"speaker": "Orin", "text": "Courteous to the last. I have genuinely enjoyed this, hunter — the building most of all. Come then. Let us see what a mortal can do against a god that cannot die."},
]

# THE ENDING -- the soul is divided, the deathless made mortal for one instant,
# and the blow lands. The seal breaks; the Shadow Monarch returns.
const ENDING = [
	{"speaker": "", "text": "His soul, scattered across a hundred failing echoes to survive the assault of a village that would not fall — thin, divided, and for the first time in an age: MORTAL."},
	{"speaker": "You", "text": "An undivided soul cannot be destroyed. So I divide it. This is the end of Despair."},
	{"speaker": "", "text": "The blow lands on the soul itself. In the same instant, something long sealed inside you breaks open — power, and memory, flooding back."},
	{"speaker": "The Shadow Monarch", "text": "I remember now. The throne. The name. The war that broke the world. I was a monarch once... and I am again."},
	{"speaker": "The Shadow Monarch", "text": "But I saved Deepwood as a man. I will keep it as one. One Monarch is ended. Somewhere beyond this world, another still waits — but that reckoning is for another day."},
]

# THE TRAP EXPLAINED (GAME_BIBLE 2.4.1, beat 2) -- the wave the player helped
# break was the trio's HUNDREDTH. With the field quiet, they say the thing
# that makes the whole game happen HERE: there is no way out. Every road out
# of the Deepwood grows an army to meet whoever walks it. The exit is not
# blocked -- it is GUARDED, by exactly as much dark as it takes.
const ARRIVAL_TRAP = [
	{"speaker": "Roland", "text": "Easy — breathe. That was the last of tonight's. You swing like someone worth keeping."},
	{"speaker": "Wren", "text": "Don't thank us yet, stranger. We've been stuck in this valley for weeks. There is no way out."},
	{"speaker": "Castor", "text": "We tried. Every road out of the Deepwood — the horde grows to meet you. Ten becomes a hundred. A hundred becomes a wall."},
	{"speaker": "Wren", "text": "It's not a siege. It's a cage. Whatever is below sends exactly as much dark as it takes to keep us in."},
	{"speaker": "Roland", "text": "So we hold this village, because there is nothing else to hold. And if you ever want out of this valley alive—"},
	{"speaker": "Castor", "text": "—there's only one direction left. Down. Through the root of it."},
]
