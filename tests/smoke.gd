extends SceneTree

const Scene = preload("res://main.tscn")
const Match = preload("res://match.gd")
const Rules = preload("res://rules.gd")

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
	check(Rules.half_side_at(26.0) == Rules.HALF_SIDE and Rules.half_side_at(75.0) == 68.0,
		"square closes before overload")
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
	check(is_equal_approx(game.shots[0].v.length() * game.shots[0].life, 544.0), "projectile keeps its previous maximum travel distance")
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
				not game.shots.is_empty() or not game.strikes.is_empty() or not game.effects.is_empty()),
				"cast %s variant %d" % [Rules.SLOTS[slot].key, choice + 1])
			if slot == Rules.Q and choice == 2:
				game.advance(1.0 / 60.0)
				check(game.shots.size() == 3, "fan rounds do not collide with each other on launch")
			elif slot == Rules.E and choice == 2:
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
	check(rival.hp == 84.0 and game.shots.is_empty(), "disc hits once on each pass and returns with reduced damage")
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
	game.buy(2, Rules.GEAR, 5)
	check(heavy.equipment == [3, 5] and heavy.gold == 167, "selling frees a slot and refunds half the original price once")
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
	check(is_equal_approx(game.shots[0].life * game.shots[0].v.length(), 544.0 * 0.85 * 1.18)
		and is_equal_approx(game.shots[0].v.length(), 384.0 * 0.90), "projectile equipment modifiers combine")
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
	game.advance(0.24)
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
		elif round_no == 2:
			var gold_before: int = client.state.players[client_id].gold
			client.buy_slot(Rules.GEAR, 0)
			await wait_for(func(): return client.state.players[client_id].equipment == [0], "client can equip gear in the next shop")
			client.sell_gear(0)
			await wait_for(func(): return client.state.players[client_id].equipment.is_empty() and client.state.players[client_id].gold == gold_before - 45,
				"client sale clears equipment and replicates half the purchase price")
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


func run() -> void:
	test_rules()
	test_projectiles()
	test_loadouts()
	test_projectile_tactics()
	test_equipment()
	test_extended_casts()
	await test_network()
	if failures == 0:
		print("RIMFALL RULES + ENET MATCH PASSED")
	quit(1 if failures else 0)
