class_name GameState
extends RefCounted

const DISTRICTS := ["North", "Central", "South"]
const COMMODITIES := ["Food", "Medicine", "Shelter"]
const SCENARIOS := ["Standard", "Checkpoint delay", "Fuel shortage"]
const NODES := {
	"Depot": Vector2(0.10, 0.50),
	"West Gate": Vector2(0.38, 0.28),
	"East Gate": Vector2(0.38, 0.72),
	"North": Vector2(0.82, 0.18),
	"Central": Vector2(0.83, 0.49),
	"South": Vector2(0.82, 0.81),
}
const EDGES := [
	{"a": "Depot", "b": "West Gate", "time": 22, "risk": 0.13, "fuel": 8},
	{"a": "Depot", "b": "East Gate", "time": 34, "risk": 0.04, "fuel": 9},
	{"a": "West Gate", "b": "East Gate", "time": 17, "risk": 0.06, "fuel": 4},
	{"a": "West Gate", "b": "North", "time": 23, "risk": 0.13, "fuel": 6},
	{"a": "East Gate", "b": "North", "time": 34, "risk": 0.04, "fuel": 8},
	{"a": "West Gate", "b": "Central", "time": 27, "risk": 0.17, "fuel": 7},
	{"a": "East Gate", "b": "Central", "time": 24, "risk": 0.07, "fuel": 6},
	{"a": "West Gate", "b": "South", "time": 42, "risk": 0.21, "fuel": 10},
	{"a": "East Gate", "b": "South", "time": 32, "risk": 0.11, "fuel": 8},
]

var day := 1
var scenario := 0
var stock: Dictionary = {}
var demand: Dictionary = {}
var delivered: Dictionary = {}
var fuel := 0
var plans: Array[Dictionary] = []
var history: Array[Dictionary] = []
var log_lines: Array[String] = []
var rng := RandomNumberGenerator.new()

func _init(scenario_index: int = 0) -> void:
	reset(scenario_index)

func reset(scenario_index: int = 0) -> void:
	scenario = clampi(scenario_index, 0, SCENARIOS.size() - 1)
	day = 1
	stock = {"Food": 210, "Medicine": 110, "Shelter": 130}
	fuel = 110 if scenario == 2 else 150
	demand = {
		"North": {"Food": 80, "Medicine": 30, "Shelter": 35},
		"Central": {"Food": 95, "Medicine": 40, "Shelter": 45},
		"South": {"Food": 115, "Medicine": 50, "Shelter": 55},
	}
	delivered = {"North": 0, "Central": 0, "South": 0}
	plans.clear()
	history.clear()
	log_lines = ["Day 1: choose a district and queue up to two convoys."]
	rng.seed = 12012 + scenario * 101

func event_text() -> String:
	if scenario == 1 and day == 2:
		return "West Gate delay: +30 min on routes through it."
	if scenario == 2:
		return "Fuel shortage: lower starting fuel and daily refill."
	return "No special event today."

func find_route(target: String, strategy: int) -> Dictionary:
	if not DISTRICTS.has(target):
		return {}
	var candidates: Array[Dictionary] = []
	_search_routes("Depot", target, ["Depot"], candidates)
	var best: Dictionary = {}
	var best_score := INF
	for path in candidates:
		var score: float = path["time"] + path["fuel"] * 0.7 + path["risk"] * 50.0
		if strategy == 1:
			score = path["risk"] * 350.0 + path["time"] * 0.3 + path["fuel"]
		if score < best_score:
			best_score = score
			best = path
	return best.duplicate(true)

func _search_routes(current: String, target: String, visited: Array[String], results: Array[Dictionary]) -> void:
	if current == target:
		var total_time := 0
		var total_fuel := 0
		var safe_probability := 1.0
		for index in range(visited.size() - 1):
			var edge := _edge(visited[index], visited[index + 1])
			total_time += edge["time"]
			total_fuel += edge["fuel"]
			safe_probability *= 1.0 - edge["risk"]
		if scenario == 1 and day == 2 and visited.has("West Gate"):
			total_time += 30
		results.append({"nodes": visited.duplicate(), "time": total_time, "fuel": total_fuel, "risk": 1.0 - safe_probability})
		return
	for edge in EDGES:
		var next := ""
		if edge["a"] == current:
			next = edge["b"]
		elif edge["b"] == current:
			next = edge["a"]
		if next != "" and not visited.has(next) and (not DISTRICTS.has(next) or next == target):
			var expanded: Array[String] = visited.duplicate()
			expanded.append(next)
			_search_routes(next, target, expanded, results)

func _edge(a: String, b: String) -> Dictionary:
	for edge in EDGES:
		if (edge["a"] == a and edge["b"] == b) or (edge["a"] == b and edge["b"] == a):
			return edge
	return {}

func queue_convoy(target: String, commodity: String, amount: int, strategy: int) -> String:
	if day > 3:
		return "The three-day scenario is complete."
	if plans.size() >= 2:
		return "Only two convoys can depart each day."
	if not DISTRICTS.has(target) or not COMMODITIES.has(commodity):
		return "Choose a valid destination and cargo."
	if amount < 10 or amount > 60:
		return "Cargo must be between 10 and 60 units."
	var route := find_route(target, strategy)
	if route.is_empty():
		return "No route is available."
	var reserved_stock := 0
	var reserved_fuel := 0
	var reserved_demand := 0
	for plan in plans:
		reserved_fuel += plan["route"]["fuel"]
		if plan["commodity"] == commodity:
			reserved_stock += plan["amount"]
		if plan["target"] == target and plan["commodity"] == commodity:
			reserved_demand += plan["amount"]
	if stock[commodity] - reserved_stock < amount:
		return "Not enough %s in the depot." % commodity.to_lower()
	if demand[target][commodity] - reserved_demand < amount:
		return "%s has less unmet %s demand." % [target, commodity.to_lower()]
	if fuel - reserved_fuel < route["fuel"]:
		return "Not enough fuel for this route."
	plans.append({"target": target, "commodity": commodity, "amount": amount, "route": route})
	return ""

func remove_last_plan() -> void:
	if not plans.is_empty():
		plans.pop_back()

func simulate_day() -> Dictionary:
	if day > 3:
		return {}
	var report := {"day": day, "sent": plans.size(), "delivered": 0, "incidents": 0, "on_time": 0, "cold_breaches": 0, "fuel_used": 0, "lines": []}
	var lines: Array[String] = []
	if plans.is_empty():
		lines.append("No convoys departed. Demand continued to grow.")
	for plan in plans:
		var route: Dictionary = plan["route"]
		var target: String = plan["target"]
		var commodity: String = plan["commodity"]
		var amount: int = plan["amount"]
		stock[commodity] -= amount
		fuel -= route["fuel"]
		report["fuel_used"] += route["fuel"]
		var incident: bool = rng.randf() < float(route["risk"])
		if incident:
			report["incidents"] += 1
			lines.append("%s convoy to %s was held; cargo returned to depot." % [commodity, target])
			stock[commodity] += amount
		else:
			demand[target][commodity] -= amount
			delivered[target] += amount
			report["delivered"] += amount
			var late: bool = route["time"] > 75
			if not late:
				report["on_time"] += 1
			if commodity == "Medicine" and route["time"] > 65:
				report["cold_breaches"] += 1
			lines.append("%d %s reached %s in %d min%s." % [amount, commodity.to_lower(), target, route["time"], " (late)" if late else ""])
	report["lines"] = lines
	history.append(report)
	if day < 3:
		for district in DISTRICTS:
			for commodity in COMMODITIES:
				var growth := 12 if commodity == "Food" else 5
				demand[district][commodity] += growth
		stock["Food"] += 75
		stock["Medicine"] += 35
		stock["Shelter"] += 40
		fuel += 28 if scenario == 2 else 45
	plans.clear()
	log_lines = lines
	day += 1
	return report

func total_delivered() -> int:
	var total := 0
	for value in delivered.values():
		total += value
	return total

func coverage_gap() -> int:
	var values: Array[float] = []
	for district in DISTRICTS:
		var outstanding := 0
		for commodity in COMMODITIES:
			outstanding += demand[district][commodity]
		values.append(float(delivered[district]) / float(delivered[district] + outstanding))
	return roundi((values.max() - values.min()) * 100.0)
