extends Area2D

var player_inside = false
var player_ref: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# The zone's old placeholder slab: a plain white ColorRect that stood in
	# for the shop when there was no shop. shop_stall.gd draws the real
	# storefront now, so the slab is just a white box sitting on top of it.
	var slab := get_node_or_null("ColorRect")
	if slab != null:
		slab.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		player_ref = body
		var shop = $"../CanvasLayer/ShopUI"
		if shop.has_method("refresh_prices"):
			shop.refresh_prices()   # prices/affordability are live on every visit
		shop.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		$"../CanvasLayer/ShopUI".visible = false
