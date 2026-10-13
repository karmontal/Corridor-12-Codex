extends SceneTree

var failures := 0

func _initialize() -> void:
	for scenario in range(GameState.SCENARIOS.size()):
		var game := GameState.new(scenario)
		var balanced := game.find_route("North", 0)
		var safest := game.find_route("North", 1)
		_check(not balanced.is_empty(), "Balanced route must exist")
		_check(float(safest["risk"]) < float(balanced["risk"]), "Safest route must reduce incident risk")
		_check(game.queue_convoy("North", "Food", 50, 0) == "", "First convoy should queue")
		_check(game.queue_convoy("North", "Food", 50, 0) != "", "Cannot overfill district demand")
		_check(game.queue_convoy("Central", "Medicine", 35, 1) == "", "Second convoy should queue")
		_check(game.queue_convoy("South", "Food", 20, 0) != "", "Daily fleet limit should apply")
		var before_fuel := game.fuel
		var first := game.simulate_day()
		_check(first["sent"] == 2, "Both planned convoys must be simulated")
		_check(game.fuel < before_fuel + 45, "Convoys must consume fuel")
		_check(game.plans.is_empty(), "New day must clear yesterday's plan")
		for _day in range(2):
			_check(game.queue_convoy("South", "Food", 40, 1) == "", "Later day convoy should queue")
			game.simulate_day()
		_check(game.day == 4 and game.history.size() == 3, "Scenario must complete three days")
		_check(game.queue_convoy("North", "Food", 10, 0) != "", "Completed scenario must reject new convoys")
		_check(game.total_delivered() > 0, "At least one convoy should deliver in deterministic smoke run")
		_check(game.coverage_gap() >= 0 and game.coverage_gap() <= 100, "Coverage gap must be a valid percentage")
		print("PASS: %s, delivered %d units over three days" % [GameState.SCENARIOS[scenario], game.total_delivered()])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
