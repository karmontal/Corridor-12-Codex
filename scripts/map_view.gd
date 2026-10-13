extends Control

signal district_selected(district: String)

const GameStateScript = preload("res://scripts/game_state.gd")
const INK := Color("dce8ed")
const MUTED := Color("869ca8")
const ACCENT := Color("70ddbe")

var selected := "Central"
var plans: Array[Dictionary] = []
var state: GameState

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(350, 350)
	resized.connect(queue_redraw)

func set_display(game: GameState, district: String) -> void:
	state = game
	selected = district
	plans = game.plans
	queue_redraw()

func _node_position(node: String) -> Vector2:
	var point: Vector2 = GameStateScript.NODES[node]
	return Vector2(30.0 + point.x * (size.x - 60.0), 30.0 + point.y * (size.y - 60.0))

func _draw() -> void:
	var grid_color := Color("24404a")
	for x in range(30, int(size.x), 42):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
	for y in range(25, int(size.y), 42):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
	for edge in GameStateScript.EDGES:
		var risk: float = edge["risk"]
		var color := Color("578f8c") if risk < 0.10 else Color("bc995e") if risk < 0.17 else Color("b46d65")
		draw_line(_node_position(edge["a"]), _node_position(edge["b"]), color, 5.0, true)
	for plan in plans:
		var route: Dictionary = plan["route"]
		var nodes: Array = route["nodes"]
		for index in range(nodes.size() - 1):
			draw_line(_node_position(nodes[index]), _node_position(nodes[index + 1]), ACCENT, 9.0, true)
	for node in GameStateScript.NODES:
		var point := _node_position(node)
		var district: bool = GameStateScript.DISTRICTS.has(node)
		var color := ACCENT if node == selected else Color("638da0") if district else Color("d9ac70")
		draw_circle(point, 19.0 if district else 14.0, Color("11262d"))
		draw_circle(point, 14.0 if district else 10.0, color)
		if district and node == selected:
			draw_arc(point, 23.0, 0.0, TAU, 32, ACCENT, 2.0)
		var font := get_theme_default_font()
		var label_size := font.get_string_size(node, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, point + Vector2(-label_size.x / 2.0, -27.0), node, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
		if district and state != null:
			var demand: Dictionary = state.demand[node]
			var total: int = demand["Food"] + demand["Medicine"] + demand["Shelter"]
			var subtitle := "%d needed" % total
			var subtitle_size := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
			draw_string(font, point + Vector2(-subtitle_size.x / 2.0, 36.0), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for district in GameStateScript.DISTRICTS:
			if event.position.distance_to(_node_position(district)) <= 30.0:
				district_selected.emit(district)
				accept_event()
				return
