extends Control

const MapView = preload("res://scripts/map_view.gd")
const TEXT := Color("e8f1f2")
const MUTED := Color("9db0b8")
const ACCENT := Color("70ddbe")

var game := GameState.new()
var selected_district := "Central"
var district_picker: OptionButton
var cargo_picker: OptionButton
var route_picker: OptionButton
var scenario_picker: OptionButton
var amount_input: SpinBox
var route_label: Label
var stock_label: Label
var fuel_label: Label
var day_label: Label
var outcome_label: Label
var queue_label: Label
var demand_label: Label
var log_label: Label
var map_view: Control
var queue_button: Button
var undo_button: Button
var simulate_button: Button
var mobile_layout := false
var dispatch_feedback: Label

func _ready() -> void:
	mobile_layout = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if not mobile_layout:
		get_window().min_size = Vector2i(980, 690)
	else:
		theme = Theme.new()
		theme.default_font_size = 20
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0d1b24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_%s" % side, 16)
	add_child(margins)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margins.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	_label(brand, "CORRIDOR 12", 30, ACCENT)
	_label(brand, "Plan aid convoys" if mobile_layout else "Plan aid convoys. Balance impact, equity and safety.", 14, MUTED)
	var scenario_box := VBoxContainer.new()
	header.add_child(scenario_box)
	_label(scenario_box, "SCENARIO", 11, MUTED)
	scenario_picker = _picker(scenario_box, GameState.SCENARIOS)
	scenario_picker.custom_minimum_size.x = 170
	scenario_picker.item_selected.connect(_on_scenario_selected)
	var restart := _button(header, "Restart", false)
	restart.pressed.connect(_on_restart)

	var body: Container = TabContainer.new() if mobile_layout else HBoxContainer.new()
	if mobile_layout:
		(body as TabContainer).get_tab_bar().custom_minimum_size.y = 48
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)

	var left := _panel(body, 282, "Dispatch")
	_label(left, "DISPATCH", 20, TEXT)
	day_label = _label(left, "", 14, ACCENT)
	_separator(left)
	var actions := left
	if mobile_layout:
		var dispatch_columns := HBoxContainer.new()
		dispatch_columns.add_theme_constant_override("separation", 24)
		left.add_child(dispatch_columns)
		left = VBoxContainer.new()
		left.add_theme_constant_override("separation", 10)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dispatch_columns.add_child(left)
		actions = VBoxContainer.new()
		actions.add_theme_constant_override("separation", 12)
		actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dispatch_columns.add_child(actions)
		_label(actions, "CONVOY PLAN", 20, TEXT)
	_label(left, "DESTINATION", 11, MUTED)
	district_picker = _picker(left, GameState.DISTRICTS)
	district_picker.select(1)
	district_picker.item_selected.connect(_on_destination_selected)
	_label(left, "CARGO", 11, MUTED)
	cargo_picker = _picker(left, GameState.COMMODITIES)
	cargo_picker.item_selected.connect(_on_plan_changed)
	_label(left, "UNITS", 11, MUTED)
	amount_input = SpinBox.new()
	amount_input.min_value = 10
	amount_input.max_value = 60
	amount_input.step = 5
	amount_input.value = 40
	if mobile_layout:
		amount_input.custom_minimum_size.y = 48
	amount_input.value_changed.connect(_on_amount_changed)
	left.add_child(amount_input)
	_label(left, "ROUTE PRIORITY", 11, MUTED)
	route_picker = _picker(left, ["Balanced", "Safest"])
	route_picker.item_selected.connect(_on_plan_changed)
	route_label = _label(left, "", 13, MUTED)
	route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if mobile_layout:
		dispatch_feedback = _label(actions, "", 16, ACCENT)
		dispatch_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	queue_button = _button(actions, "Queue convoy", true)
	queue_button.pressed.connect(_on_queue)
	undo_button = _button(actions, "Undo last convoy", false)
	undo_button.pressed.connect(_on_undo)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	simulate_button = _button(actions, "SIMULATE DAY", true)
	simulate_button.pressed.connect(_on_simulate)

	var middle := _panel(body, 350, "Map")
	middle.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(middle, "OPERATIONS MAP", 20, TEXT)
	_label(middle, "Click a district to set the destination.", 13, MUTED)
	map_view = MapView.new()
	if mobile_layout:
		map_view.custom_minimum_size.y = 260
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.district_selected.connect(_on_map_selected)
	middle.add_child(map_view)
	_label(middle, "Green: low risk | Amber: medium | Red: high | Mint: queued", 12, MUTED)

	var right := _panel(body, 290, "Situation")
	_label(right, "SITUATION", 20, TEXT)
	stock_label = _label(right, "", 13, TEXT)
	fuel_label = _label(right, "", 13, TEXT)
	_separator(right)
	_label(right, "SELECTED DISTRICT", 11, MUTED)
	demand_label = _label(right, "", 14, TEXT)
	_separator(right)
	_label(right, "TODAY'S CONVOYS", 11, MUTED)
	queue_label = _label(right, "", 13, TEXT)
	queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_separator(right)
	_label(right, "RESULTS", 11, MUTED)
	outcome_label = _label(right, "", 14, ACCENT)
	_separator(right)
	_label(right, "FIELD LOG", 11, MUTED)
	log_label = _label(right, "", 13, MUTED)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(layout, "Prototype • 3 days • 2 convoys per day • click Restart to try another plan", 12, MUTED)

func _panel(parent: Container, width: float, tab_name: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 0 if mobile_layout else width
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142a34")
	style.border_color = Color("2c4d54")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 17
	style.content_margin_right = 17
	style.content_margin_top = 17
	style.content_margin_bottom = 17
	panel.add_theme_stylebox_override("panel", style)
	if mobile_layout:
		var scroll := ScrollContainer.new()
		scroll.name = tab_name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		parent.add_child(scroll)
		scroll.add_child(panel)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column

func _label(parent: Container, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", maxi(16, font_size + 2) if mobile_layout else font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _picker(parent: Container, options: Array) -> OptionButton:
	var picker := OptionButton.new()
	if mobile_layout:
		picker.custom_minimum_size.y = 48
	for option in options:
		picker.add_item(option)
	parent.add_child(picker)
	return picker

func _button(parent: Container, value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 56 if mobile_layout else 42
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("258674") if primary else Color("26414c")
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate()
	hover.bg_color = Color("30aa91") if primary else Color("365869")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", TEXT)
	parent.add_child(button)
	return button

func _separator(parent: Container) -> void:
	var rule := HSeparator.new()
	parent.add_child(rule)

func _refresh() -> void:
	if dispatch_feedback != null:
		dispatch_feedback.text = "%d / 2 convoys queued\n%s" % [game.plans.size(), "\n".join(game.log_lines)]
	day_label.text = "DAY %d / 3   •   %s" % [mini(game.day, 3), "Complete" if game.day > 3 else "Planning"]
	stock_label.text = "Depot stock\nFood  %d     Medicine  %d\nShelter  %d" % [game.stock["Food"], game.stock["Medicine"], game.stock["Shelter"]]
	fuel_label.text = "Fuel available  %d" % game.fuel
	var need: Dictionary = game.demand[selected_district]
	demand_label.text = "%s\nFood  %d   Medicine  %d\nShelter  %d" % [selected_district, need["Food"], need["Medicine"], need["Shelter"]]
	var queue_lines: Array[String] = []
	for index in range(game.plans.size()):
		var plan: Dictionary = game.plans[index]
		queue_lines.append("%d. %d %s -> %s" % [index + 1, plan["amount"], plan["commodity"].to_lower(), plan["target"]])
	queue_label.text = "\n".join(queue_lines) if not queue_lines.is_empty() else "No convoys queued."
	var last_report: Dictionary = game.history.back() if not game.history.is_empty() else {}
	if last_report.is_empty():
		outcome_label.text = "Delivered: 0\nCoverage gap: 0 pp"
	else:
		outcome_label.text = "Delivered: %d total\nCoverage gap: %d pp\nLast day: %d delivered, %d held\nOn time: %d / %d   •   Cold breaches: %d" % [game.total_delivered(), game.coverage_gap(), last_report["delivered"], last_report["incidents"], last_report["on_time"], last_report["sent"], last_report["cold_breaches"]]
	log_label.text = game.event_text() + "\n\n" + "\n".join(game.log_lines)
	var route := game.find_route(selected_district, route_picker.selected)
	if not route.is_empty():
		route_label.text = "%s\n%d min  •  %d fuel  •  %d%% incident risk" % [" > ".join(route["nodes"]), route["time"], route["fuel"], roundi(route["risk"] * 100.0)]
	queue_button.disabled = game.day > 3 or game.plans.size() >= 2
	undo_button.disabled = game.plans.is_empty()
	simulate_button.disabled = game.day > 3
	map_view.set_display(game, selected_district)

func _on_destination_selected(index: int) -> void:
	selected_district = GameState.DISTRICTS[index]
	_refresh()

func _on_map_selected(district: String) -> void:
	selected_district = district
	district_picker.select(GameState.DISTRICTS.find(district))
	_refresh()

func _on_plan_changed(_index: int) -> void:
	_refresh()

func _on_amount_changed(_value: float) -> void:
	_refresh()

func _on_queue() -> void:
	var error := game.queue_convoy(selected_district, GameState.COMMODITIES[cargo_picker.selected], int(amount_input.value), route_picker.selected)
	if error != "":
		game.log_lines = [error]
	else:
		game.log_lines = ["Convoy queued. Add another or simulate the day."]
	_refresh()

func _on_undo() -> void:
	game.remove_last_plan()
	game.log_lines = ["Last convoy removed from today's plan."]
	_refresh()

func _on_simulate() -> void:
	game.simulate_day()
	_refresh()

func _on_scenario_selected(index: int) -> void:
	game.reset(index)
	_refresh()

func _on_restart() -> void:
	game.reset(scenario_picker.selected)
	_refresh()
