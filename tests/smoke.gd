extends SceneTree

const Scene = preload("res://main.tscn")
const Match = preload("res://match.gd")
const Rules = preload("res://rules.gd")
const Motion = preload("res://motion.gd")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)
	return condition


func wait_for(condition: Callable, message: String) -> bool:
	var deadline := Time.get_ticks_msec() + 4500
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await physics_frame
	return check(condition.call(), message)


func new_room_tree(label: String) -> Node:
	var parent := Node.new()
	parent.name = label
	root.add_child(parent)
	set_multiplayer(SceneMultiplayer.new(), parent.get_path())
	var game := Scene.instantiate()
	parent.add_child(game)
	return game


func test_rules() -> void:
	check(pow(2.0 * Rules.HALF_SIDE, 2.0) > 4.0 * PI * pow(390.0, 2.0), "map area is over four times v0.2")
	check(Rules.half_side_at(26.0) == 700.0 and Rules.half_side_at(50.5) == 460.0
		and Rules.half_side_at(75.0) == 220.0 and Rules.half_side_at(90.0) == 220.0,
		"safe area shrinks steadily and stays 440 units wide after 75 seconds")
	check(is_equal_approx(Rules.knockback_multiplier(0.0), 1.24)
		and Rules.knockback_multiplier(120.0) > 1.24
		and Rules.knockback_multiplier(240.0) - Rules.knockback_multiplier(120.0)
			< Rules.knockback_multiplier(120.0) - 1.24,
		"knockback starts stronger and its gains taper at higher impact")
	var game := Match.new()
	game.add_player(1, "One")
	game.add_player(2, "Two")
	game.add_player(3, "Three")
	game.start_match()
	game.buy(1, Rules.GEAR)
	game.buy(1, Rules.GEAR)
	check(game.players[1].gold == 130 and game.players[1].equipment == [0], "equipped gear cannot be purchased twice")
	game.buy(1, Rules.R)
	check(game.players[1].levels[Rules.R] == 0 and game.players[1].gold == 130, "unaffordable purchase")
	game.buy(1, 0)
	check(game.players[1].levels[0] == 2 and game.players[1].gold == 40, "base skill upgrade")
	game.advance(Rules.SHOP_TIME)
	game.advance(3.0)
	check((game.players[1].p as Vector2).distance_to(game.players[2].p) >= Rules.SPAWN_DISTANCE,
		"players spawn farther apart")
	game.hit(1, 2, 13, 255, Vector2.RIGHT)
	check(game.players[2].hp == 87.0 and game.players[2].impact > 13.0, "health damage and impact accumulate")
	var first: float = game.players[2].kick.length()
	game.players[2].kick = Vector2.ZERO
	game.hit(1, 2, 13, 255, Vector2.RIGHT)
	check(game.players[2].kick.length() > first, "higher impact increases knockback")
	game.players[2].kick = Vector2.ZERO
	game.players[2].guard = 1.0
	game.hit(1, 2, 13, 255, Vector2.RIGHT)
	check(game.players[2].kick.length() < first, "guard reduces knockback")
	var half := Rules.HALF_SIDE
	game.players[1].p = Vector2(0, half + 5)
	game.players[2].p = Vector2(-half - 5, 0)
	game.players[3].p = Vector2(half - 1, half - 1)
	game.players[2].kick = Vector2.ZERO
	game.advance(0.25)
	check(is_equal_approx(game.players[1].hp, 97.375) and is_equal_approx(game.players[2].hp, 57.5),
		"hazard damage and passive mitigation")
	check(game.players[3].alive and game.players[3].hp == 100.0, "inner corner remains inside the square")
	game.players[1].p = Vector2.ZERO
	game.players[2].p = Vector2(half + 140, half - 1.0)
	for step in range(90):
		game.steer(2, Vector2.LEFT, Vector2.ZERO)
		game.advance(1.0 / 60.0)
	check(game.players[2].alive and Rules.square_extent(game.players[2].p) <= half and game.players[2].hp > 38.0,
		"can survive beyond the former drop line and walk back")
	check(is_equal_approx(game.players[2].walk.length(), Rules.WALK_SPEED), "movement uses the lower top speed")
	game.hit(1, 2, 80, 255, Vector2.RIGHT)
	check(game.players[1].kills == 1 and not game.players[2].alive and "격파" in game.feed[0],
		"skill damage can defeat and credit a player inside the arena")
	game.players[3].damage = 400
	game.players[3].p = Vector2(-half - 140.0, 0)
	game.players[3].hp = 0.1
	game.advance(0.016)
	check(game.phase == Match.SHOP and game.round_no == 2 and game.players[1].wins == 1, "last survivor advances the round")
	check(not game.players[3].alive and "장외 탈락" in game.feed[0], "outside defeat occurs at zero health")
	check(game.rankings[0].id == 1 and game.rankings[0].award == 145 and game.rankings[1].id == 3,
		"kills take priority over damage for gold")


func test_projectiles() -> void:
	var game := Match.new()
	game.add_player(1, "Pulse")
	game.add_player(2, "Wave")
	game.start_match()
	game.buy(2, 1)
	game.advance(Rules.SHOP_TIME)
	game.advance(3.0)
	game.players[1].p = Vector2(-120, 0)
	game.players[2].p = Vector2(120, 0)
	game.cast(1, 0, game.players[2].p)
	game.cast(2, 1, game.players[1].p)
	check(game.players[1].cooldowns[0] == 4.0 and game.players[2].cooldowns[1] == 6.5, "attack cooldowns")
	check(is_equal_approx(game.shots[0].v.length(), 384.0) and game.shots[0].damage == 8, "pulse travels slower")
	game.advance(0.30)
	check(game.shots.is_empty() and game.players[1].hp == 100.0 and game.players[2].hp == 100.0,
		"opposing swept projectiles are removed before either can hit")
	game.cast(1, 0, game.players[2].p)
	check(game.shots.is_empty(), "cannot recast a projectile while it is cooling down")
	game.players[1].cooldowns[0] = 0.0
	game.players[2].cooldowns[0] = 0.0
	game.players[2].p.y = 30.0
	game.cast(1, 0, Vector2(120, 0))
	game.cast(2, 0, Vector2(-120, 30))
	game.advance(0.30)
	check(game.shots.size() == 2, "separated projectiles pass without colliding")
	game.shots.clear()
	game.reset_player(game.players[1], Vector2(-120, 34))
	game.reset_player(game.players[2], Vector2(120, 0))
	game.cast(2, Rules.Q, Vector2(-120, 0))
	game.advance(0.90)
	check(game.players[1].hp == 100.0, "narrower shockwave misses outside its new width")
	game.shots.clear()
	game.reset_player(game.players[1], Vector2(-120, 0))
	game.reset_player(game.players[2], Vector2(120, 21))
	game.cast(1, Rules.BASIC, Vector2(120, 0))
	game.advance(0.70)
	check(game.players[2].hp == 92.0, "wider pulse hits within its new width")
	game.reset_player(game.players[1], Vector2(-120, 0))
	game.reset_player(game.players[2], Vector2(120, 22.5))
	game.cast(1, Rules.BASIC, Vector2(120, 0))
	game.advance(0.70)
	check(game.players[2].hp == 100.0, "pulse grazes past the smaller fighter hitbox")
	game.shots.clear()
	game.half_side = 220.0
	var pulse: Dictionary = Rules.skill(Rules.BASIC, 0).shot
	game.shoot(1, Rules.BASIC, Vector2.RIGHT, Vector2.ZERO, pulse, 1)
	game.resolve_projectiles(3.0, {})
	check(game.shots.size() == 1 and is_equal_approx(game.shots[0].p.x, 1152.0),
		"shots pass their former range and both the moving and original safe lines")
	game.resolve_projectiles(0.75, {})
	check(game.shots.is_empty(), "straight shot disappears at the fixed map boundary")
	var edge := Rules.MAP_HALF_SIDE
	var corner := Vector2(edge, -edge)
	game.shoot(1, Rules.BASIC, Vector2(1, -1).normalized(), corner - Vector2(50, -50), pulse, 1)
	game.resolve_projectiles(0.1, {})
	check(game.shots.size() == 1, "diagonal shot survives just inside a corner")
	game.resolve_projectiles(0.1, {})
	check(game.shots.is_empty(), "diagonal shot disappears at the map corner")


func test_loadouts() -> void:
	var game := Match.new()
	game.add_player(1, "One")
	game.add_player(2, "Two")
	game.start_match()
	var pilot: Dictionary = game.players[1]
	var rival: Dictionary = game.players[2]
	game.buy(1, Rules.Q, 2)
	check(pilot.gold == 100 and pilot.choices[Rules.Q] == 2, "buy a specific variant")
	game.buy(1, Rules.Q, 1)
	check(pilot.gold == 100 and pilot.choices[Rules.Q] == 2 and pilot.levels[Rules.Q] == 1, "first choice locks the slot")
	game.buy(1, Rules.Q, 3)
	check(pilot.choices[Rules.Q] == 2, "reject an unknown variant")
	pilot.gold = 1000
	var upgrade_cost := Rules.price(Rules.Q, 1)
	game.buy(1, Rules.Q, 2)
	check(pilot.levels[Rules.Q] == 2 and pilot.gold == 1000 - upgrade_cost, "equipped skill can upgrade")
	for slot in [Rules.E, Rules.R, Rules.F]:
		game.buy(1, slot)
	game.buy(1, Rules.MOVE, 2)
	game.toggle_ready(1)
	game.buy(1, Rules.MOVE, 0)
	check(pilot.choices[Rules.MOVE] == 2, "ready blocks loadout changes")
	game.advance(Rules.SHOP_TIME)
	game.advance(3.0)
	game.reset_player(pilot, Vector2(-23, 0))
	game.reset_player(rival, Vector2(23, 0))
	game.cast(1, Rules.MOVE, rival.p)
	for step in range(24):
		game.advance(1.0 / 60.0)
	var fast_damage: float = 100.0 - rival.hp
	game.reset_player(pilot, Vector2(-85, 0))
	game.reset_player(rival, Vector2(85, 0))
	game.cast(1, Rules.MOVE, rival.p)
	for step in range(24):
		game.advance(1.0 / 60.0)
	check(fast_damage == 11.0 and rival.hp > 89.0 and rival.hp < 100.0 and pilot.charge == 0.0,
		"tackle hits once and speed affects damage")
	game.reset_player(pilot, Vector2(-85, 0))
	game.reset_player(rival, Vector2(85, 0))
	game.cast(1, Rules.MOVE, rival.p)
	game.cast(2, Rules.BASIC, pilot.p)
	for step in range(24):
		game.advance(1.0 / 60.0)
	check(pilot.hp == 92.0 and pilot.charge == 0.0 and rival.hp == 100.0, "projectile damages and stops a tackle")
	for slot in [Rules.Q, Rules.E, Rules.R, Rules.F, Rules.MOVE]:
		for choice in range(Rules.SLOTS[slot].options.size()):
			game.reset_player(pilot, Vector2(-85, 0))
			game.shots.clear()
			game.strikes.clear()
			game.effects.clear()
			pilot.choices[slot] = choice
			game.cast(1, slot, Vector2(85, 0))
			check(pilot.cooldowns[slot] > 0.0 and (
				not game.shots.is_empty() or not game.strikes.is_empty() or not game.effects.is_empty() or pilot.mirror_mask != 0),
				"cast %s variant %d" % [Rules.SLOTS[slot].key, choice + 1])
			if slot == Rules.E and choice == 2:
				check(game.strikes.size() == 3 and game.strikes[0].left < game.strikes[2].left,
					"fissure explosions are staggered")
			elif slot == Rules.R and choice == 2:
				check(pilot.kick.x < 0.0, "recoil cannon pushes the caster backward")
	game.reset_player(pilot, Vector2(Rules.HALF_SIDE + 90.0, 0))
	pilot.choices[Rules.MOVE] = 1
	game.cast(1, Rules.MOVE, Vector2(2000, 0))
	check(pilot.kick.x < 0.0, "emergency recovery pushes toward safety")
	pilot.hp = 92.0
	pilot.choices[Rules.F] = 1
	game.cast(1, Rules.F, Vector2.ZERO)
	check(pilot.hp == 100.0, "repair respects max health")
	pilot.choices[Rules.Q] = 2
	game.finish_round(1)
	var before_purchase: int = pilot.gold
	game.buy(1, Rules.Q, 0)
	check(pilot.choices[Rules.Q] == 2 and pilot.levels[Rules.Q] == 2 and pilot.gold == before_purchase,
		"next-round shop cannot change the selected skill")
	game.enter_results()
	game.return_to_lobby()
	game.start_match()
	game.buy(1, Rules.Q, 0)
	check(pilot.levels[Rules.Q] == 1 and pilot.choices[Rules.Q] == 0, "new match can select a different skill")


func test_projectile_tactics() -> void:
	var game := Match.new()
	game.add_player(1, "Disc")
	game.add_player(2, "Reflect")
	game.start_match()
	game.players[1].gold = 300
	game.buy(1, Rules.Q, 3)
	game.buy(1, Rules.R, 1)
	game.buy(2, Rules.F, 3)
	game.advance(Rules.SHOP_TIME)
	game.advance(3.0)
	var pilot: Dictionary = game.players[1]
	var rival: Dictionary = game.players[2]
	game.reset_player(pilot, Vector2(-85, 0))
	game.reset_player(rival, Vector2(85, 0))
	game.cast(1, Rules.Q, rival.p)
	for frame in range(82):
		game.advance(1.0 / 60.0)
		rival.kick = Vector2.ZERO
	check(rival.hp == 84.0 and game.shots.size() == 1 and game.shots[0].v.x < 0.0,
		"disc hits once on each pass and continues with reduced damage")
	game.shots.clear()
	game.reset_player(pilot, Vector2(-85, 0))
	game.reset_player(rival, Vector2(85, 0))
	game.cast(2, Rules.F, pilot.p)
	game.cast(1, Rules.BASIC, rival.p)
	game.advance(0.36)
	check(rival.hp == 100.0 and rival.reflect == 0.0 and game.shots.size() == 1 and game.shots[0].owner == 2,
		"reflect protects against the first projectile and transfers ownership")
	game.advance(0.45)
	check(pilot.hp == 95.0, "reflected projectile hits the original caster with reduced damage")
	game.reset_player(pilot, Vector2(-205, 0))
	game.reset_player(rival, Vector2(205, 0))
	game.cast(1, Rules.R, Vector2.ZERO)
	game.strikes[0].left = 0.001
	game.shoot(2, Rules.BASIC, Vector2.RIGHT, Vector2(0, 26), Rules.skill(Rules.BASIC, 0).shot, 1)
	game.advance(1.0 / 60.0)
	check(game.shots.size() == 1 and game.shots[0].v.y < 0.0 and is_equal_approx(game.shots[0].v.length(), 384.0),
		"gravity bends the projectile toward the impact point at the same speed")


func test_equipment() -> void:
	var game := Match.new()
	for id in range(1, 4):
		game.add_player(id, "Pilot %d" % id)
	game.start_match()
	var light: Dictionary = game.players[1]
	var heavy: Dictionary = game.players[2]
	var rescue: Dictionary = game.players[3]
	heavy.gold = 500
	game.buy(1, Rules.GEAR, 2)
	game.buy(2, Rules.GEAR, 3)
	game.buy(2, Rules.GEAR, 0)
	game.buy(2, Rules.GEAR, 4)
	game.buy(2, Rules.GEAR, 1)
	game.buy(3, Rules.GEAR, 1)
	check(heavy.gold == 185 and heavy.equipment == [3, 0, 4], "only three distinct items can be equipped")
	game.sell_gear(2, 0)
	game.sell_gear(2, 0)
	game.sell_gear(2, 4)
	game.buy(2, Rules.GEAR, 2)
	game.sell_gear(2, 2)
	check(heavy.equipment == [3] and heavy.gold == 224, "selling frees a slot and refunds half the original price once")
	game.advance(Rules.SHOP_TIME)
	game.advance(3.0)
	for frame in range(12):
		game.steer(1, Vector2.RIGHT, Vector2.ZERO)
		game.advance(1.0 / 60.0)
	check(is_equal_approx(light.walk.length(), Rules.WALK_SPEED * 1.12), "light frame increases base movement")
	game.hit(3, 1, 8, 255, Vector2.RIGHT)
	game.hit(3, 2, 8, 255, Vector2.RIGHT)
	check(is_equal_approx(light.kick.length() / heavy.kick.length(), 1.20 / 0.82), "gear modifies incoming knockback")
	game.cast(2, Rules.BASIC, Vector2.ZERO)
	check(is_equal_approx(game.shots[0].v.length(), 384.0 * 0.85), "heavy frame trades projectile speed for knockback resistance")
	game.shots.clear()
	rescue.p = Vector2(Rules.HALF_SIDE + 30.0, 100.0)
	game.advance(0.2)
	check(rescue.gear_used and is_equal_approx(rescue.hp, 98.88), "emergency capsule limits initial outside damage")
	rescue.p = Vector2.ZERO
	game.advance(2.5)
	rescue.p = Vector2(Rules.HALF_SIDE + 30.0, 100.0)
	game.advance(0.2)
	check(rescue.gear_time == 0.0 and is_equal_approx(rescue.hp, 96.08), "emergency capsule is single-use per round")
	game.finish_round(3)
	game.begin_countdown()
	check(not rescue.gear_used and rescue.equipment == [1], "equipment stays equipped and protection resets for the new round")


func test_combat_gear() -> void:
	var game := Match.new()
	game.add_player(1, "Siphon")
	game.add_player(2, "Shield")
	game.start_match()
	game.players[1].gold = 300
	game.players[2].gold = 300
	game.buy(1, Rules.GEAR, 5)
	game.buy(1, Rules.GEAR, 7)
	game.buy(2, Rules.GEAR, 6)
	game.buy(2, Rules.GEAR, Rules.SHIELD_GEAR)
	game.advance(Rules.SHOP_TIME)
	game.advance(3.0)
	var siphon: Dictionary = game.players[1]
	var shield: Dictionary = game.players[2]
	siphon.hp = 70.0
	game.hit(1, 2, 22, 200, Vector2.RIGHT)
	check(shield.shield_used and shield.hp == 88.0 and is_equal_approx(siphon.hp, 72.4), "shield and armor reduce damage before lifesteal")
	shield.kick = Vector2.ZERO
	game.hit(1, 2, 22, 200, Vector2.RIGHT)
	check(shield.hp == 68.0 and is_equal_approx(siphon.hp, 76.4), "the shield absorbs only the first hit")
	game.hit(2, 1, 22, 200, Vector2.LEFT)
	check(is_equal_approx(siphon.hp, 54.4), "lifesteal item increases received damage after the attacker's armor penalty")
	siphon.kick = Vector2.ZERO
	game.advance(2.9)
	check(is_equal_approx(siphon.hp, 54.4), "cloak waits three seconds after a hit")
	game.advance(1.1)
	check(is_equal_approx(siphon.hp, 55.9), "cloak regenerates while in the safe zone")
	siphon.p = Vector2(Rules.HALF_SIDE + 50.0, 0)
	game.advance(1.0)
	check(is_equal_approx(siphon.hp, 41.9), "cloak does not regenerate outside the safe zone")
	game.begin_countdown()
	check(not shield.shield_used, "shield refreshes each round")


func test_extended_casts() -> void:
	var game := Match.new()
	game.add_player(1, "Pilot")
	game.add_player(2, "Rival")
	game.start_match()
	var pilot: Dictionary = game.players[1]
	var rival: Dictionary = game.players[2]
	pilot.gold = 1000
	game.buy(1, Rules.Q, 4)
	game.buy(1, Rules.E, 3)
	game.buy(1, Rules.R, 3)
	game.buy(1, Rules.F, 4)
	game.buy(1, Rules.MOVE, 3)
	game.advance(Rules.SHOP_TIME)
	game.advance(3.0)
	game.reset_player(pilot, Vector2(-180, 0))
	game.reset_player(rival, Vector2(100, 90))
	game.cast(1, Rules.Q, Vector2.ZERO)
	game.advance(0.05)
	check(game.shots.size() == 1 and game.shots[0].v.y < 0.0, "orbit bolt bends left")
	game.shots.clear()
	pilot.choices[Rules.Q] = 5
	pilot.cooldowns[Rules.Q] = 0.0
	game.cast(1, Rules.Q, Vector2.ZERO)
	game.advance(0.21)
	check(is_zero_approx(game.shots[0].v.y), "seeker has an arming delay")
	game.advance(0.05)
	check(game.shots[0].v.y > 0.0 and game.shots[0].v.angle() < 0.08, "seeker follows a target with a turn limit")
	game.shots.clear()
	game.cast(1, Rules.E, Vector2.ZERO)
	game.advance(0.75)
	check(game.strikes.is_empty() and game.shots.size() == 4, "split marker emits four projectiles")
	game.advance(0.016)
	check(game.shots.size() == 4, "split projectiles spread with no spawn collision")
	game.shots.clear()
	game.cast(1, Rules.R, Vector2.ZERO)
	game.hit(2, 1, 8, 255, Vector2.RIGHT)
	game.advance(0.76)
	check(game.shots.is_empty() and pilot.windup == 0.0, "hit interrupts the charged bolt")
	game.reset_player(pilot, Vector2(-180, 0))
	game.cast(1, Rules.R, Vector2.ZERO)
	game.steer(1, Vector2.ZERO, Vector2(-500, 80))
	game.advance(0.76)
	check(game.shots.size() == 1 and (game.shots[0].v as Vector2).normalized().is_equal_approx(Vector2.RIGHT),
		"charged bolt retains its telegraphed direction")
	game.shots.clear()
	var anchor: Vector2 = pilot.p
	game.cast(1, Rules.F, Vector2.ZERO)
	pilot.p = Vector2(15, 50)
	game.hit(2, 1, 8, 255, Vector2.RIGHT)
	game.cast(1, Rules.F, Vector2.ZERO)
	check(pilot.p == anchor and pilot.hp == 92.0 and pilot.impact > 0.0 and pilot.cooldowns[Rules.F] > 0.0
		and not Match.can_cast(pilot, Rules.F), "anchor recast restores position only and cannot be repeated")
	game.reset_player(pilot, Vector2(-180, 0))
	pilot.choices[Rules.F] = 5
	game.cast(1, Rules.F, Vector2.ZERO)
	game.hit(2, 1, 8, 255, Vector2.RIGHT)
	check(pilot.surge_wait == 0.0 and pilot.surge_left > 0.0 and pilot.hp == 92.0, "surge triggers on damage")
	game.cast(1, Rules.MOVE, Vector2.ZERO)
	game.cast(1, Rules.MOVE, Vector2(-180, -100))
	check(pilot.kick.y < 0.0 and pilot.step_left == 0.0 and not Match.can_cast(pilot, Rules.MOVE), "double step gives one directed recast")


func test_repel() -> void:
	var game := Match.new()
	for id in range(1, 4):
		game.add_player(id, "Pilot %d" % id)
	game.start_match()
	game.buy(1, Rules.E, 1)
	game.advance(Rules.SHOP_TIME)
	game.advance(3.0)
	game.players[1].p = Vector2.ZERO
	game.players[2].p = Vector2(148.0, 0)
	game.players[3].p = Vector2(0, 105.0)
	game.cast(1, Rules.E, Vector2.RIGHT)
	game.players[1].p = Vector2(60.0, 0)
	game.resolve_strikes(0.10)
	check(game.strikes[0].p == game.players[1].p and game.players[2].hp == 100.0,
		"repel telegraph follows the caster before firing")
	game.resolve_strikes(0.07)
	check(game.players[2].hp < 100.0 and game.players[2].kick.x > 0.0
		and game.players[1].hp == 100.0 and game.players[3].hp == 100.0,
		"repel pushes nearby enemies from the new center and misses distant targets")


func test_tactical_casts() -> void:
	var game := Match.new()
	for id in range(1, 5):
		game.add_player(id, "Pilot %d" % id)
	game.start_match()
	game.players[1].gold = 900
	game.players[2].gold = 900
	game.buy(1, Rules.Q, 2)
	game.buy(1, Rules.E, 4)
	game.buy(1, Rules.R, 4)
	game.buy(1, Rules.F, 6)
	game.buy(1, Rules.MOVE, 4)
	game.buy(2, Rules.Q, 6)
	game.buy(2, Rules.E, 5)
	game.buy(2, Rules.R, 5)
	game.advance(Rules.SHOP_TIME)
	game.advance(3.0)
	var pilot: Dictionary = game.players[1]
	var rival: Dictionary = game.players[2]
	game.reset_player(pilot, Vector2(-200, 0))
	game.reset_player(rival, Vector2(-15, 0))
	game.reset_player(game.players[3], Vector2(115, 100))
	game.reset_player(game.players[4], Vector2(225, 170))
	game.cast(1, Rules.Q, Vector2.ZERO)
	game.advance(0.50)
	game.advance(0.70)
	game.advance(0.60)
	check(rival.hp == 90.0 and game.players[3].hp == 93.0 and game.players[4].hp == 95.0 and game.shots.is_empty(),
		"ricochet hits three distinct opponents with decreasing damage")

	game.reset_player(pilot, Vector2(-160, 0))
	game.reset_player(rival, Vector2(80, 0))
	game.reset_player(game.players[3], Vector2(400, 400))
	game.reset_player(game.players[4], Vector2(520, 510))
	game.cast(1, Rules.R, rival.p)
	game.advance(0.80)
	check(pilot.p == Vector2(80, 0) and rival.p == Vector2(-160, 0) and pilot.kick == Vector2.ZERO and rival.kick == Vector2.ZERO,
		"swap exchanges positions without carrying momentum")
	game.cast(2, Rules.Q, pilot.p)
	game.advance(0.80)
	check(pilot.root > 0.0 and pilot.kick != Vector2.ZERO and not Match.can_cast(pilot, Rules.MOVE)
		and Match.can_cast(pilot, Rules.BASIC), "root blocks movement skill but allows knockback and basic attacks")
	game.steer(1, Vector2.UP, Vector2.ZERO)
	game.advance(0.10)
	check(pilot.walk == Vector2.ZERO, "root suppresses walking input")

	game.reset_player(pilot, Vector2(-130, 0))
	game.reset_player(rival, Vector2(100, 0))
	game.cast(2, Rules.R, pilot.p)
	game.advance(0.75)
	check(pilot.jam > 0.0 and not Match.can_cast(pilot, Rules.F) and Match.can_cast(pilot, Rules.BASIC),
		"jam blocks skill slots and keeps the basic attack available")

	game.reset_player(pilot, Vector2(-145, 0))
	game.reset_player(rival, Vector2(95, 0))
	game.cast(1, Rules.E, rival.p)
	game.advance(0.75)
	check(pilot.link_target == 2 and rival.hp == 96.0, "link attaches on projectile hit in range")
	rival.kick = Vector2.ZERO
	game.advance(0.66)
	check(rival.hp == 93.0 and rival.kick == Vector2.ZERO, "tether ticks without additional knockback")
	game.advance(1.30)
	check(rival.hp == 87.0 and pilot.link_target == 0, "tether deals three ticks and ends")
	pilot.cooldowns[Rules.E] = 0.0
	game.cast(1, Rules.E, rival.p)
	game.advance(0.75)
	rival.p = Vector2(450, 0)
	rival.kick = Vector2.ZERO
	game.advance(0.80)
	check(rival.hp == 83.0 and pilot.link_target == 0, "tether snaps before dealing a tick when the target leaves range")

	game.reset_player(pilot, Vector2(-150, 0))
	game.cast(1, Rules.F, Vector2.ZERO)
	var decoy: Vector2 = pilot.p + Match.mirror_offset(pilot, 0)
	game.reset_player(rival, decoy - Vector2(130, 0))
	game.cast(2, Rules.BASIC, decoy)
	game.advance(0.40)
	check(pilot.mirror_mask == 2 and pilot.hp == 100.0 and game.shots.is_empty(), "a mirror takes one projectile for the caster")
	game.cast(1, Rules.MOVE, Vector2.ZERO)
	game.steer(1, Vector2.UP, Vector2.ZERO)
	game.advance(0.13)
	check(pilot.cloak > 0.0 and pilot.mirror_mask == 0 and is_equal_approx(pilot.walk.length(), Rules.WALK_SPEED * 1.22),
		"cloak hides existing images and increases walking speed")
	var hidden := game.snapshot(2).duplicate(true)
	Motion.apply(Motion.encode(game, 2), hidden)
	check(hidden.players[1].p == Vector2.ZERO and game.snapshot(1).players[1].p == pilot.p,
		"opponents do not receive the concealed position")
	game.cast(1, Rules.BASIC, Vector2(0, 400))
	check(pilot.cloak == 0.0, "a successful attack reveals the cloaked caster")
	pilot.cooldowns[Rules.MOVE] = 0.0
	game.cast(1, Rules.MOVE, Vector2.ZERO)
	game.hit(2, 1, 4, 100.0, Vector2.RIGHT)
	check(pilot.cloak == 0.0, "a direct hit reveals the cloaked target")
	game.shots.clear()

	game.reset_player(rival, Vector2(80, 0))
	game.cast(2, Rules.E, Vector2(200, 0))
	game.advance(0.57)
	check(game.strikes.size() == 1 and game.shots.is_empty(), "repeater telegraphs before firing")
	game.advance(0.02)
	game.steer(2, Vector2.ZERO, Vector2(80, 300))
	game.advance(0.44)
	game.advance(0.43)
	check(game.strikes.is_empty() and game.shots.size() == 3 and game.shots.all(func(shot: Dictionary): return shot.v.x > 0.0 and shot.v.y == 0.0),
		"repeater fires three times from its placed position in its original direction")


func test_cloak_collision() -> void:
	var game := Match.new()
	game.mode = Match.TEAM_MATCH
	for id in range(1, 5):
		game.add_player(id, "Pilot %d" % id)
	game.start_match()
	game.buy(1, Rules.MOVE, 4)
	game.advance(Rules.SHOP_TIME)
	game.advance(3.0)
	var pilot: Dictionary = game.players[1]
	var target: Dictionary = game.players[2]
	var ally: Dictionary = game.players[3]
	var second_target: Dictionary = game.players[4]
	game.reset_player(pilot, Vector2.ZERO)
	game.reset_player(target, Vector2(110, 0))
	game.reset_player(ally, Vector2(56, 0))
	game.reset_player(second_target, Vector2(117, 11))
	game.cast(1, Rules.MOVE, Vector2.RIGHT * 300.0)
	game.steer(1, Vector2.RIGHT, Vector2.RIGHT * 300.0)
	game.advance(0.25)
	check(pilot.cloak > 0.0 and pilot.p.distance_to(ally.p) < 2.0 * Rules.BODY_RADIUS and ally.hp == 100.0,
		"cloak continues through allies with no friendly fire")
	for step in range(3):
		game.steer(1, Vector2.RIGHT, Vector2.RIGHT * 300.0)
		game.advance(0.25)
	check(pilot.cloak == 0.0 and target.hp == 94.0 and target.kick.x > 0.0 and second_target.hp == 100.0,
		"walking into the first enemy deals damage and knockback and reveals the caster once")
	game.reset_player(pilot, Vector2.ZERO)
	game.reset_player(target, Vector2(60, 0))
	game.cast(1, Rules.MOVE, Vector2.RIGHT * 300.0)
	pilot.cloak = 0.05
	game.steer(1, Vector2.RIGHT, Vector2.RIGHT * 300.0)
	game.advance(0.25)
	check(pilot.cloak == 0.0 and target.hp == 100.0, "an enemy reached after cloak expires is not hit")


func test_practice_bots() -> void:
	var room := new_room_tree("Practice")
	room.practice("연습", 5)
	var game: RefCounted = room.sim
	check(game.phase == Match.LOBBY, "practice opens character selection before the shop")
	room.hud.character_buttons[4].pressed.emit()
	check(game.players[1].character == 4, "War Machine button sets the practice player's appearance")
	room.primary_action()
	check(game.players[1].character == 4 and not game.select_character(1, 3),
		"appearance persists and is locked after the lobby")
	check(game.players.size() == 6 and game.phase == Match.SHOP, "five sparring bots fill a solo room")
	for id in range(1, 6):
		check(game.players[-id].ready and game.players[-id].levels[Rules.Q] == 1, "every bot shops and readies")
	game.toggle_ready(1)
	game.advance(0.01)
	game.advance(3.0)
	game.reset_player(game.players[-1], Vector2(-220, 0))
	game.reset_player(game.players[-2], Vector2(-60, 0))
	game.reset_player(game.players[1], Vector2(400, 350))
	game.players[1].alive = false
	game.elapsed = 1.0
	game.advance(0.10)
	check(game.phase == Match.FIGHT and game.players[-1].aim.x > 0.90 and game.players[-2].aim.x < -0.90,
		"bots keep targeting each other after the human is eliminated")
	check(game.shots.any(func(shot: Dictionary): return shot.owner == -1) and
		game.shots.any(func(shot: Dictionary): return shot.owner == -2), "multiple bots cast independently")
	room.leave_game()
	room.practice("연습", 5, Match.TEAM_MATCH)
	check(Match.team_counts(room.sim.players) == [3, 3], "team practice balances five bots and one human")
	room.leave_game()
	room.get_parent().queue_free()


func test_team_rules() -> void:
	var game := Match.new()
	game.mode = Match.TEAM_MATCH
	for id in range(1, 5):
		game.add_player(id, "Pilot %d" % id)
	check(Match.team_counts(game.players) == [2, 2] and game.players[1].team == game.players[3].team, "team assignment is balanced")
	game.switch_team(4)
	game.start_match()
	check(game.phase == Match.LOBBY and Match.team_counts(game.players) == [3, 1], "unbalanced online teams cannot start")
	game.switch_team(4)
	game.start_match()
	game.advance(Rules.SHOP_TIME)
	game.advance(3.0)
	check(game.players[1].p.x < 0.0 and game.players[3].p.x < 0.0 and game.players[2].p.x > 0.0, "teams spawn on opposite sides")
	game.switch_team(3)
	check(game.players[3].team == 0, "team switching is limited to the lobby")
	game.reset_player(game.players[1], Vector2(-120, 0))
	game.reset_player(game.players[3], Vector2.ZERO)
	game.reset_player(game.players[2], Vector2(110, 0))
	game.reset_player(game.players[4], Vector2(0, 200))
	game.cast(1, Rules.BASIC, game.players[2].p)
	game.advance(0.60)
	check(game.players[3].hp == 100.0 and game.players[2].hp == 92.0, "shots pass through teammates and damage opponents")
	game.add_strike(1, Rules.E, Vector2.ZERO, 55.0, 0.01, 15, 300.0, 1)
	game.advance(0.02)
	check(game.players[3].hp == 100.0 and game.players[3].kick == Vector2.ZERO, "area hits also ignore teammates")
	game.players[3].p = Vector2(0, 80)
	game.players[3].cloak = 1.0
	check(game.snapshot(1).players[3].p == game.players[3].p and game.snapshot(2).players[3].p == Vector2.ZERO,
		"cloak shares position with teammates only")
	game.players[2].alive = false
	game.players[4].alive = false
	game.advance(0.02)
	check(game.phase == Match.SHOP and game.round_winner == "블루 팀" and game.team_wins == [1, 0] and game.players[3].wins == 1,
		"multiple allied survivors win a single round for their whole team")
	game.round_no = Rules.ROUNDS
	game.finish_round(1)
	check(game.phase == Match.RESULTS and game.winners == ["블루 팀"] and game.team_wins == [2, 0], "team rounds determine the champion")
	game.return_to_lobby()
	game.start_match()
	game.remove_player(2)
	game.remove_player(4)
	check(game.phase == Match.RESULTS and game.team_forfeit and game.winners == ["블루 팀"], "departing team forfeits the match")


func test_network() -> void:
	var server := new_room_tree("Host")
	var client := new_room_tree("Client")
	var join_port := "27410"
	if not OS.get_cmdline_user_args().is_empty():
		join_port = OS.get_cmdline_user_args()[0]
	server.host_game("호스트", join_port)
	if not check(server.host, "host binds UDP socket"):
		return
	client.join_game("친구", "127.0.0.1:%s" % join_port, "7410")
	if not await wait_for(func(): return client.state.get("players", {}).size() == 2, "lobby replication over ENet"):
		return
	var client_id: int = client.own_id
	client.hud.character_buttons[5].pressed.emit()
	await wait_for(func(): return (client.state.players[client_id].character == 5
		and server.sim.players[client_id].character == 5), "Black Panther choice replicates through the lobby")
	server.hud.change_button.pressed.emit()
	if not await wait_for(func(): return client.state.phase == Match.SHOP, "host starts shop"):
		return
	var late := new_room_tree("Late")
	late.join_game("늦은 친구", "127.0.0.1", join_port)
	await wait_for(func(): return "대전이 진행 중" in late.status, "late join is rejected")
	server.buy_slot(Rules.GEAR, 1)
	server.buy_slot(Rules.F, 4)
	await wait_for(func(): return client.state.players[1].equipment == [1], "equipment purchase replicates")
	client.hud.shop_rows[Rules.Q].pressed.emit()
	if not await wait_for(func(): return client.hud.picker.visible, "client opens the skill picker"):
		return
	client.hud.option_actions[0].pressed.emit()
	if not await wait_for(func(): return client.state.players[client_id].levels[Rules.Q] == 1, "chosen variant replicates"):
		return
	client.hud.shop_rows[Rules.Q].pressed.emit()
	await wait_for(func(): return client.hud.picker.visible, "client reopens the skill picker")
	check(client.hud.option_actions[2].disabled and client.hud.option_actions[2].text == "선택 불가",
		"other choices are disabled in the client shop")
	client.buy_slot(Rules.Q, 2)
	client.buy_slot(Rules.MOVE, 2)
	if not await wait_for(func(): return client.state.players[client_id].levels[Rules.MOVE] == 1, "client buys a movement variant"):
		return
	check(client.state.players[client_id].gold == 0 and client.state.players[client_id].choices[Rules.Q] == 0,
		"server rejects later changes to an equipped slot")
	client.hud.change_button.pressed.emit()
	server.hud.change_button.pressed.emit()
	if not await wait_for(func(): return client.state.phase == Match.FIGHT, "ready signals and countdown"):
		return
	client.set_physics_process(false)
	check(is_equal_approx((client.state.players[client_id].p as Vector2).distance_to(client.state.players[1].p),
		Rules.SPAWN_DISTANCE * 2.0), "wider two-player spawn spacing replicates")
	var old_pos: Vector2 = client.state.players[client_id].p
	var direction := -old_pos.normalized()
	var moving := await wait_for(func():
		client.request_move.rpc_id(1, client.state.epoch, direction, Vector2.ZERO)
		return (client.state.players[client_id].p as Vector2).distance_to(old_pos) > 8.0,
		"movement replicates")
	if not moving:
		print("Movement state: old=", old_pos, " client=", client.state.players[client_id].p,
			" host=", server.sim.players[client_id].p, " host move=", server.sim.players[client_id].move,
			" host elapsed=", server.sim.elapsed, " client elapsed=", client.state.elapsed,
			" input_at=", server.sim.players[client_id].input_at)
	server.sim.reset_player(server.sim.players[1], Vector2(-100, 0))
	server.sim.reset_player(server.sim.players[client_id], Vector2(100, 0))
	client.request_cast.rpc_id(1, client.state.epoch, 1, server.sim.players[1].p)
	var hit_synced := await wait_for(func(): return client.state.players[1].impact >= 15.0 and client.state.players[1].hp == 89.0,
		"projectile hits and syncs both damage and accumulated impact")
	if not hit_synced:
		return
	check(client.state.effects.any(func(effect: Dictionary): return effect.cue == Rules.Cue.HIT and effect.audio_id > 0),
		"projectile hit cue and sequence reach the remote client")
	check(server.sim.players[1].kick.length() > 0.0, "projectile applies host-authoritative knockback")
	client.request_cast.rpc_id(1, client.state.epoch, Rules.MOVE, Vector2.ZERO)
	await wait_for(func(): return client.state.players[client_id].cooldowns[Rules.MOVE] > 0.0 and client.state.players[client_id].charge > 0.0,
		"tackle cue and cooldown replicate")
	server.sim.cast(1, Rules.F, Vector2.ZERO)
	await wait_for(func(): return (client.state.players[1].anchor_left > 0.0
		and (client.state.players[1].anchor_pos as Vector2).is_equal_approx(server.sim.players[1].anchor_pos)),
		"anchor position and recast window replicate")
	server.sim.players[1].p = Vector2(Rules.HALF_SIDE + 30.0, 0)
	server.sim.players[1].kick = Vector2.ZERO
	await wait_for(func(): return client.state.players[1].gear_time > 0.0 and client.state.players[1].gear_used,
		"emergency protection replicates in combat")
	for round_no in range(1, Rules.ROUNDS + 1):
		server.sim.players[1].p = Vector2(Rules.HALF_SIDE + 180.0, 0)
		server.sim.players[1].kick = Vector2.ZERO
		server.sim.players[1].hp = 0.1
		if round_no == Rules.ROUNDS:
			await wait_for(func(): return client.state.phase == Match.RESULTS, "final results replicate")
			break
		if not await wait_for(func(): return client.state.phase == Match.SHOP and client.state.round == round_no + 1,
			"round %d ends and opens the next shop" % round_no):
			return
		if round_no == 1:
			check(client.state.rankings[0].id == client_id and client.state.players[client_id].gold == 145,
				"client receives performance gold")
			client.buy_slot(Rules.E)
			await wait_for(func(): return client.state.players[client_id].levels[Rules.E] == 1, "round gold can buy a new skill")
			server.buy_slot(Rules.MOVE, 4)
		elif round_no == 2:
			var gold_before: int = client.state.players[client_id].gold
			client.buy_slot(Rules.GEAR, 0)
			await wait_for(func(): return client.state.players[client_id].equipment == [0], "client can equip gear in the next shop")
			client.sell_gear(0)
			await wait_for(func(): return client.state.players[client_id].equipment.is_empty() and client.state.players[client_id].gold == gold_before - 45,
				"client sale clears equipment and replicates half the purchase price")
			server.buy_slot(Rules.GEAR, Rules.SHIELD_GEAR)
			await wait_for(func(): return Rules.SHIELD_GEAR in client.state.players[1].equipment, "new gear purchase replicates")
		client.primary_action()
		server.primary_action()
		if not await wait_for(func(): return client.state.phase == Match.FIGHT, "next round starts"):
			return
		if round_no == 1:
			server.sim.reset_player(server.sim.players[1], Vector2(-100, 0))
			server.sim.reset_player(server.sim.players[client_id], Vector2(100, 0))
			var target: Vector2 = server.sim.players[1].p
			client.request_cast.rpc_id(1, client.state.epoch, Rules.E, target)
			await wait_for(func(): return client.state.strikes.size() == 1, "delayed strike telegraph replicates")
			check(client.state.players[client_id].cooldowns[Rules.E] > 8.5, "long strike cooldown is encoded without overflow")
			await wait_for(func(): return client.state.players[1].impact >= 24.0 and client.state.players[1].hp == 82.0,
				"delayed strike lands and syncs")
			server.sim.cast(1, Rules.MOVE, Vector2.ZERO)
			await wait_for(func(): return client.state.players[1].cloak > 0.0 and client.state.players[1].p == Vector2.ZERO,
				"motion updates conceal a remote opponent's position")
			server.broadcast_state(true)
			var expected_stamp: int = server.ticks
			await wait_for(func(): return client.reliable_stamp >= expected_stamp and (
				client.state.players[1].cloak > 0.0 and client.state.players[1].p == Vector2.ZERO), "reliable state keeps the opponent concealed")
			server.sim.cast(1, Rules.BASIC, Vector2(0, 400))
			await wait_for(func(): return client.state.players[1].cloak == 0.0 and client.state.players[1].p != Vector2.ZERO,
				"revealed opponent position resumes replicating")
		elif round_no == 2:
			server.sim.reset_player(server.sim.players[1], Vector2(-400, 0))
			server.sim.reset_player(server.sim.players[client_id], Vector2(400, 0))
			client.request_cast.rpc_id(1, client.state.epoch, Rules.BASIC, Vector2(-400, 0))
			await wait_for(func(): return client.state.players[1].shield_used and client.state.players[1].hp == 95.0,
				"shot lands beyond its old range and shield mitigation replicates")
			server.sim.reset_player(server.sim.players[1], Vector2(-100, 0))
			server.sim.reset_player(server.sim.players[client_id], Vector2(-66, 0))
			server.sim.cast(1, Rules.MOVE, Vector2.ZERO)
			await wait_for(func(): return client.state.players[1].cloak > 0.0, "cloak activates before contact")
			server.sim.players[client_id].kick = Vector2(-200, 0)
			await wait_for(func(): return (client.state.players[1].cloak == 0.0 and client.state.players[1].p != Vector2.ZERO
				and client.state.players[client_id].hp == 94.0), "cloak contact damage and reveal replicate together")
	check(client.state.winners == ["친구"] and client.state.players[client_id].wins == 5, "match champion")
	server.primary_action()
	await wait_for(func(): return client.state.phase == Match.LOBBY, "back to lobby for rematch")
	client.leave_game()
	await wait_for(func(): return server.state.players.size() == 1, "client disconnect removes roster entry")
	client.set_physics_process(true)
	client.join_game("친구", "127.0.0.1", join_port)
	await wait_for(func(): return client.state.get("players", {}).size() == 2, "client rejoins in lobby")
	server.leave_game()
	await wait_for(func(): return client.state.is_empty() and "호스트 연결이 종료" in client.status,
		"host shutdown returns the client to the menu")


func test_network_teams() -> void:
	var server := new_room_tree("TeamServer")
	var client := new_room_tree("TeamClient")
	var port_number := "27439"
	server.host_game("블루", port_number, Match.TEAM_MATCH)
	client.join_game("오렌지", "127.0.0.1", port_number)
	if not await wait_for(func(): return client.state.get("mode") == Match.TEAM_MATCH and client.state.players.size() == 2,
		"online room mode and two teams replicate"):
		return
	var client_id: int = client.own_id
	client.switch_team()
	await wait_for(func(): return client.state.players[client_id].team == client.state.players[1].team,
		"online client team switch replicates")
	server.primary_action()
	check(server.sim.phase == Match.LOBBY, "host cannot start with an empty opposing team")
	client.switch_team()
	await wait_for(func(): return client.state.players[client_id].team != client.state.players[1].team,
		"client restores the opposing team")
	server.primary_action()
	if not await wait_for(func(): return client.state.phase == Match.SHOP, "team match starts"):
		return
	server.primary_action()
	client.primary_action()
	if not await wait_for(func(): return client.state.phase == Match.FIGHT, "team match enters combat"):
		return
	server.sim.players[client_id].p = Vector2(1100, 0)
	server.sim.players[client_id].hp = 0.1
	await wait_for(func(): return client.state.phase == Match.SHOP and client.state.team_wins == [1, 0] and client.state.round_winner == "블루 팀",
		"team victory and score replicate to the client")
	client.leave_game()
	await wait_for(func(): return server.state.phase == Match.RESULTS and server.state.winners == ["블루 팀"],
		"online team forfeits when its last member disconnects")
	server.leave_game()


func run() -> void:
	test_rules()
	test_projectiles()
	test_loadouts()
	test_projectile_tactics()
	test_equipment()
	test_combat_gear()
	test_extended_casts()
	test_repel()
	test_tactical_casts()
	test_cloak_collision()
	test_practice_bots()
	test_team_rules()
	await test_network()
	await test_network_teams()
	if failures == 0:
		print("RIMFALL RULES + ENET MATCH PASSED")
	quit(1 if failures else 0)
