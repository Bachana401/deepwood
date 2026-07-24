extends Node
# DoT-KILL MID-FRAME (dev 2026-07-23). Every meleeing enemy runs tick_statuses at the
# TOP of _physics_process; a burn/poison tick there can bring health to 0 and call die()
# mid-frame. enemy.gd re-checks `if is_dead: return` right after, so a corpse doesn't fall,
# march, or land a FINAL attack -- but siege_enemy.gd and special_mob.gd (which got the
# same DoT substrate ported in later) were missing that guard. This locks all three: the
# is_dead re-check must sit immediately after the tick_statuses(delta) call.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	for f in ["enemy.gd", "siege_enemy.gd", "special_mob.gd"]:
		var src := FileAccess.open("res://" + f, FileAccess.READ).get_as_text()
		var i := src.find("tick_statuses(delta)")
		var guarded := false
		if i != -1:
			# the very next statement after the call must re-check is_dead and return
			var after := src.substr(i + len("tick_statuses(delta)"), 150)
			guarded = after.contains("is_dead") and after.contains("return")
		check("%s re-checks is_dead right after tick_statuses (no corpse acting on a DoT kill)" % f,
			guarded, "next: %s" % (src.substr(i, 60) if i != -1 else "<no tick_statuses>"))
	printerr("test_dotdeath : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
