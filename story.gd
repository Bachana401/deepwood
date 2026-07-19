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
	{"speaker": "Orin", "text": "...There. That look. For a moment you almost remembered. No matter. Come then, hunter. Let us see what a mortal can do against a god that cannot die."},
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
