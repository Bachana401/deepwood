extends RichTextEffect

# THE MONARCH NAME CYCLE (2026-07-30, dev reference clip: Terraria's Rainbow
# rarity).
#
# The reference matters in a specific way. Terraria colours the WHOLE NAME one
# hue at a time and walks that hue around the wheel -- frame to frame the word
# is entirely purple, then entirely blue. BBCode's built-in [rainbow] does
# something different: it spreads the spectrum ACROSS the letters and scrolls
# it, so you get a striped word. Both are "a rainbow"; only one is the thing in
# the clip.
#
# The difference is one term. Hue is driven by elapsed_time ALONE -- every
# glyph in the span is asked at the same instant, so every glyph agrees. Adding
# anything derived from char_fx.range would stripe it again.
#
# "Little more colours" than the reference: the clip's cycle sits in a fairly
# narrow purple-blue band and reads dim. This walks the entire wheel at full
# value, so a Monarch name passes through gold, green and rose as well.

var bbcode := "monarch"

const CYCLE_SPEED := 0.28    # wheel turns per second; slow enough to read
const SATURATION := 0.72     # the clip is duller than this on purpose
const VALUE := 1.0

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	char_fx.color = Color.from_hsv(
		fposmod(char_fx.elapsed_time * CYCLE_SPEED, 1.0), SATURATION, VALUE)
	return true
