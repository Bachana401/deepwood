extends CanvasLayer
# THE INTERACTIVE TUTORIAL CARD (dev 2026-07-22: "show, don't tell"). Instead of a
# wall of dialogue, a live card walks the player through raising their first three
# buildings by DOING: it names the building and why, then prompts the EXACT next
# action -- open the Ledger, then pick + place -- reading GameState.tutorial_step
# and the Ledger's own visibility to know which sub-step they're on. tutorial_note
# advances the step as each building goes up; the closing tells the rest, after.

const TEACH := {
	"Wall": "The dark climbs out of the PIT to the WEST. Raise a WALL there — the gate that needs stone.",
	"Farm": "Now a FARM, so the whole village eats.",
	"Cottage": "A COTTAGE, so the next soul you save has a bed.",
}
const ICON := {"Wall": "🧱", "Farm": "🌾", "Cottage": "🏠"}

var _card: PanelContainer = null
var _title: Label = null
var _teach: Label = null
var _action: Label = null
var _menu: Node = null      # cached Builder's Ledger, found once

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("cutscene_hides")     # step aside for any scripted beat, like the HUD
	_build()

func _build() -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", _bg())
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 0.0
	_card.offset_top = 54.0            # sits just under the objective-banner slot
	_card.offset_left = -300.0
	_card.offset_right = 300.0
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 14)
	_card.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	m.add_child(vb)
	_title = _mk(vb, 17, Color(1.0, 0.86, 0.4))
	_teach = _mk(vb, 14, Color(0.92, 0.92, 0.86))
	_action = _mk(vb, 15, Color(0.6, 1.0, 0.72))
	_teach.autowrap_mode = TextServer.AUTOWRAP_WORD
	_action.autowrap_mode = TextServer.AUTOWRAP_WORD
	_card.visible = false

func _mk(parent: Node, size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func _process(_d: float) -> void:
	var step: int = GameState.tutorial_step
	if step < 0 or step >= GameState.TUTORIAL_STEPS.size():
		_card.visible = false
		return
	_card.visible = true
	var want := str(GameState.TUTORIAL_STEPS[step]["want"])
	var total: int = GameState.TUTORIAL_STEPS.size()
	_title.text = "%s  BUILD THE %s      (%d / %d)" % [ICON.get(want, "•"), want.to_upper(), step + 1, total]
	_teach.text = str(TEACH.get(want, ""))
	# the sub-step: have they opened the Ledger yet? Show the exact next action.
	if _ledger_open():
		_action.text = "▶ Pick %s from the list, then LEFT-CLICK where the ghost glows GREEN.  (Right-click cancels.)" % want.to_upper()
	else:
		_action.text = "▶ Press [B] to open the Builder's Ledger."

func _ledger_open() -> bool:
	if _menu == null or not is_instance_valid(_menu):
		for n in get_tree().current_scene.get_children():
			if n.get_script() != null and str(n.get_script().resource_path).ends_with("build_menu.gd"):
				_menu = n
				break
	return _menu != null and "panel" in _menu and _menu.panel != null and _menu.panel.visible

func _bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.13, 0.9)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.95, 0.8, 0.35, 0.7)
	return sb
