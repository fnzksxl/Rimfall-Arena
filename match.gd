extends RefCounted

const Rules = preload("res://rules.gd")
const AIM_REACH := Vector2.ONE * 1200.0
enum { LOBBY, SHOP, COUNTDOWN, FIGHT, RESULTS }

var phase := LOBBY
var epoch := 0
var round_no := 0
var left := 0.0
var elapsed := 0.0
var half_side := Rules.HALF_SIDE
var players: Dictionary = {}
var shots: Array[Dictionary] = []
var strikes: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var rankings: Array[Dictionary] = []
var winners: Array[String] = []
var round_winner := ""
var feed: Array[String] = []
var feed_revision := 0
var serial := 0


func add_player(id: int, nickname: String) -> void:
	if phase != LOBBY or players.has(id) or players.size() >= Rules.CAPACITY:
		return
	var used: Array = players.values().map(func(player: Dictionary): return player.color)
	var color := 0
	while color in used:
		color += 1
	players[id] = {"name": nickname, "color": color, "wins": 0, "total_kills": 0,
		"total_damage": 0, "ready": false}
	reset_loadout(players[id])
	reset_player(players[id], Vector2.ZERO)


func remove_player(id: int) -> void:
	if not players.has(id):
		return
	var nickname: String = players[id].name
	players.erase(id)
	if phase in [SHOP, COUNTDOWN, FIGHT]:
		push_feed("%s 님의 연결이 종료됐습니다." % nickname)
		if players.size() < 2:
			enter_results()


func reset_loadout(player: Dictionary) -> void:
	player.gold = Rules.START_GOLD
	player.levels = Rules.BASE_LEVELS.duplicate()
	player.choices = Rules.BASE_CHOICES.duplicate()
	player.equipment = []
	player.wins = 0
	player.total_kills = 0
	player.total_damage = 0


func reset_player(player: Dictionary, spawn: Vector2) -> void:
	player.merge({"p": spawn, "walk": Vector2.ZERO, "kick": Vector2.ZERO,
		"move": Vector2.ZERO, "aim": -spawn.normalized(), "input_at": -1.0,
		"hp": 100.0, "impact": 0.0, "alive": true, "kills": 0, "damage": 0,
		"guard": 0.0, "charge": 0.0, "flash": 0.0, "reflect": 0.0,
		"gear_time": 0.0, "gear_used": false, "last_hit": 0, "last_hit_at": -99.0,
		"anchor_left": 0.0, "anchor_pos": Vector2.ZERO, "step_left": 0.0,
		"surge_wait": 0.0, "surge_left": 0.0, "windup": 0.0, "windup_aim": Vector2.RIGHT,
		"cooldowns": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]}, true)


func start_match() -> void:
	if phase != LOBBY or players.size() < 2:
		return
	round_no = 1
	rankings.clear()
	winners.clear()
	round_winner = ""
	feed.clear()
	for player: Dictionary in players.values():
		reset_loadout(player)
	enter_shop()


func return_to_lobby() -> void:
	if phase == RESULTS:
		change_phase(LOBBY, 0.0)
		half_side = Rules.HALF_SIDE
		round_no = 0


func change_phase(next: int, seconds: float) -> void:
	phase = next
	left = seconds
	epoch += 1


func enter_shop() -> void:
	change_phase(SHOP, Rules.SHOP_TIME)
	for id: int in players:
		var player: Dictionary = players[id]
		player.ready = false
		if id < 0:
			for slot in ([Rules.Q, Rules.MOVE] if round_no == 1 else [Rules.E, Rules.R, Rules.F, Rules.BASIC, Rules.Q, Rules.MOVE]):
				buy(id, slot)
			player.ready = true


func buy(id: int, slot: int, choice := 0) -> void:
	if phase != SHOP or not players.has(id) or slot < 0 or slot >= Rules.SLOTS.size():
		return
	if choice < 0 or choice >= Rules.SLOTS[slot].options.size():
		return
	var player: Dictionary = players[id]
	if player.ready:
		return
	if slot == Rules.GEAR:
		var price := Rules.price(slot, 0, choice)
		if player.gold >= price and choice not in player.equipment and player.equipment.size() < Rules.EQUIPMENT_CAP:
			player.gold -= price
			player.equipment.append(choice)
		return
	var level: int = player.levels[slot]
	var cost := Rules.price(slot, level, choice)
	if level > 0 and choice != player.choices[slot]:
		return
	if level < Rules.level_cap(slot) and player.gold >= cost:
		player.gold -= cost
		player.levels[slot] += 1
		player.choices[slot] = choice


func sell_gear(id: int, choice: int) -> void:
	if phase != SHOP or not players.has(id):
		return
	var player: Dictionary = players[id]
	if not player.ready and choice in player.equipment:
		player.equipment.erase(choice)
		player.gold += Rules.resale(choice)


func toggle_ready(id: int) -> void:
	if phase == SHOP and players.has(id):
		players[id].ready = not players[id].ready


func begin_countdown() -> void:
	change_phase(COUNTDOWN, 3.0)
	elapsed = 0.0
	half_side = Rules.HALF_SIDE
	shots.clear()
	strikes.clear()
	effects.clear()
	feed.clear()
	var index := 0
	for id: int in players:
		var angle := PI + TAU * (float(index) / players.size()) + (round_no - 1) * 0.6
		reset_player(players[id], Vector2.from_angle(angle) * Rules.SPAWN_DISTANCE)
		index += 1


func steer(id: int, direction: Vector2, target: Vector2) -> void:
	if phase != FIGHT or not players.has(id) or not direction.is_finite() or not target.is_finite():
		return
	var player: Dictionary = players[id]
	player.move = direction.clamp(Vector2(-1, -1), Vector2.ONE).limit_length()
	player.input_at = elapsed
	var aim: Vector2 = (target - player.p).clamp(-AIM_REACH, AIM_REACH)
	if aim.length_squared() > 4.0:
		player.aim = aim.normalized()


static func recast_window(player: Dictionary, slot: int) -> float:
	if slot == Rules.F:
		return player.anchor_left
	if slot == Rules.MOVE:
		return player.step_left
	return 0.0


static func can_cast(player: Dictionary, slot: int) -> bool:
	return not player.is_empty() and player.alive and player.levels[slot] > 0 and (
		player.cooldowns[slot] <= 0.0 or recast_window(player, slot) > 0.0)


func cast(id: int, slot: int, target: Vector2) -> void:
	if phase != FIGHT or not players.has(id) or slot < 0 or slot >= Rules.ACTIVE_SLOTS or not target.is_finite():
		return
	var player: Dictionary = players[id]
	if not can_cast(player, slot):
		return
	var level: int = player.levels[slot]
	var offset: Vector2 = (target - player.p).clamp(-AIM_REACH, AIM_REACH)
	var direction: Vector2 = offset.normalized() if offset.length_squared() > 4.0 else player.aim
	player.aim = direction
	var choice: int = player.choices[slot]
	var skill := Rules.skill(slot, choice)
	var tint: Color = Rules.SLOTS[slot].color
	if recast_window(player, slot) > 0.0:
		if slot == Rules.F:
			player.anchor_left = 0.0
			effect(player.p, tint, 31.0, 0.28)
			player.p = player.anchor_pos
			player.kick = Vector2.ZERO
			player.walk = Vector2.ZERO
		else:
			player.step_left = 0.0
			player.kick = direction * (505.0 + (level - 1) * 65.0)
		effect(player.p, tint, 40.0, 0.32)
		return
	player.cooldowns[slot] = Rules.cooldown(slot, choice, level)
	match skill.id:
		"pulse", "wave", "lance", "heavy", "recoil", "disc", "curve", "seeker":
			shoot(id, slot, direction, player.p + direction * 20.0, skill.shot, level)
			if skill.id == "recoil":
				player.kick = player.kick * 0.5 - direction * 410.0
			effect(player.p + direction * 21.0, tint, 27.0, 0.19)
		"fan":
			for spread in [-1.0, 0.0, 1.0]:
				var aim := direction.rotated(spread * 0.19)
				var origin: Vector2 = player.p + direction * 20.0 + direction.orthogonal() * (spread * 13.0)
				shoot(id, slot, aim, origin, skill.shot, level)
			effect(player.p + direction * 21.0, tint, 33.0, 0.19)
		"mark":
			add_strike(id, slot, player.p + offset.limit_length(330.0), 46.0, 0.70, 24, 505.0, level)
		"repel":
			add_strike(id, slot, player.p, 64.0, 0.33, 16, 525.0, level)
		"fissure":
			for index in range(3):
				var pos: Vector2 = player.p + direction * (85.0 + index * 85.0)
				add_strike(id, slot, pos, 29.0, 0.42 + index * 0.16, 12, 325.0, level)
		"scatter":
			var delay := 0.74
			strikes.append({"owner": id, "slot": slot, "p": player.p + offset.limit_length(250.0),
				"left": delay, "duration": delay, "size": 30.0, "pull": false,
				"scatter": true, "angle": direction.angle(), "skill": skill, "level": level})
		"gravity":
			add_strike(id, slot, player.p + offset.limit_length(300.0), 64.0, 1.05, 27, 685.0, level, true)
		"windup":
			player.windup = 0.75
			player.windup_aim = direction
			effect(player.p, tint, 30.0, 0.30)
		"guard":
			player.guard = 0.85 + (level - 1) * 0.25
			effect(player.p, tint, 40.0, 0.30)
		"repair":
			player.hp = minf(100.0, player.hp + 16.0 + (level - 1) * 5.0)
			effect(player.p, Color("#adf097"), 46.0, 0.47)
		"cleanse":
			player.impact = maxf(0.0, player.impact - 32.0 - (level - 1) * 10.0)
			player.kick *= 0.28
			effect(player.p, tint, 56.0, 0.38)
		"reflect":
			player.reflect = 0.9 + (level - 1) * 0.25
			effect(player.p, tint, 35.0, 0.22)
		"anchor":
			player.anchor_pos = player.p
			player.anchor_left = 2.0 + (level - 1) * 0.20
			effect(player.p, tint, 34.0, 0.27)
		"surge":
			player.surge_wait = 2.3
			effect(player.p, tint, 37.0, 0.30)
		"double":
			player.step_left = 0.90
			player.kick = player.kick * 0.18 + direction * (505.0 + (level - 1) * 65.0)
			effect(player.p, tint, 38.0, 0.26)
		"dash", "recover", "tackle":
			var speed := 700.0 if skill.id == "dash" else 825.0
			if skill.id == "recover":
				var edge := Vector2.ONE * (half_side - 30.0)
				var pos: Vector2 = player.p
				var outside := Rules.square_extent(pos) > half_side
				var destination := pos.clamp(-edge, edge) if outside else Vector2.ZERO
				if not pos.is_equal_approx(destination):
					direction = pos.direction_to(destination)
				speed = 930.0 if outside else 540.0
			elif skill.id == "tackle":
				player.charge = 0.37
			player.kick = player.kick * 0.24 + direction * (speed + (level - 1) * 75.0)
			effect(player.p, tint, 45.0, 0.32)


func shoot(id: int, slot: int, direction: Vector2, origin: Vector2, profile: Dictionary, level: int) -> void:
	serial += 1
	var shooter: Dictionary = players.get(id, {})
	var speed_factor := Rules.PROJECTILE_SPEED_SCALE * Rules.equipment_factor(shooter, "shot_speed")
	shots.append({"id": serial, "owner": id, "p": origin,
		"v": direction * profile.speed * speed_factor, "age": 0.0,
		"size": profile.size, "life": profile.life / speed_factor * Rules.equipment_factor(shooter, "range"),
		"damage": Rules.attack_damage(profile.damage + (level - 1) * profile.gain),
		"force": profile.force + (level - 1) * 38.0, "slot": slot, "style": profile.style,
		"curve": profile.get("curve", 0.0), "seeks": profile.get("seeks", false),
		"pierce": profile.get("pierce", false), "returns": profile.get("returns", false), "hit": []})


func add_strike(id: int, slot: int, pos: Vector2, size: float, delay: float,
	damage: int, force: float, level: int, pull := false) -> void:
	strikes.append({"owner": id, "slot": slot, "p": pos, "left": delay, "duration": delay, "pull": pull,
		"size": size + (level - 1) * 5.0, "damage": Rules.attack_damage(damage + (level - 1) * 4),
		"force": force + (level - 1) * 35.0})


func hit(owner: int, victim: int, damage: int, force: float, direction: Vector2) -> void:
	var player: Dictionary = players[victim]
	var health_lost := mini(damage, ceili(player.hp))
	player.hp = maxf(0.0, player.hp - damage)
	player.impact = minf(Rules.MAX_IMPACT, player.impact + damage * 1.35 * Rules.equipment_factor(player, "impact"))
	player.charge = 0.0
	player.windup = 0.0
	if player.surge_wait > 0.0:
		player.surge_wait = 0.0
		player.surge_left = 1.45 + (player.levels[Rules.F] - 1) * 0.24
		effect(player.p, Rules.SLOTS[Rules.F].color, 48.0, 0.40)
	var resistance: float = (0.30 if player.guard > 0.0 else 1.0) * Rules.equipment_factor(player, "knockback")
	player.kick = (player.kick * 0.55 + direction * force *
		Rules.knockback_multiplier(player.impact) * resistance).limit_length(1800.0)
	player.flash = 0.16
	player.last_hit = owner
	player.last_hit_at = elapsed
	if players.has(owner):
		players[owner].damage += health_lost
	effect(player.p, Rules.COLORS[player.color], 36.0, 0.24, health_lost)
	if player.hp <= 0.0:
		eliminate(victim, "격파")


func eliminate(id: int, cause: String) -> void:
	var player: Dictionary = players[id]
	player.alive = false
	player.hp = 0.0
	var attacker: int = player.last_hit
	if players.has(attacker) and elapsed - player.last_hit_at <= 10.0:
		players[attacker].kills += 1
		push_feed("%s  →  %s %s" % [players[attacker].name, player.name, cause])
	else:
		push_feed("%s %s" % [player.name, cause])
	effect(player.p, Color("#ffa574"), 55.0, 0.50)


func push_feed(message: String) -> void:
	feed_revision += 1
	feed.push_front(message)
	if feed.size() > 4:
		feed.pop_back()


func effect(pos: Vector2, tint: Color, size: float, duration: float, damage := 0) -> void:
	if effects.size() >= 16:
		effects.pop_front()
	effects.append({"p": pos, "color": tint, "size": size, "left": duration,
		"duration": duration, "damage": damage})


func advance(delta: float) -> void:
	for index in range(effects.size() - 1, -1, -1):
		effects[index].left -= delta
		if effects[index].left <= 0.0:
			effects.remove_at(index)
	match phase:
		SHOP:
			left = maxf(0.0, left - delta)
			if left <= 0 or players.values().all(func(player: Dictionary): return player.ready):
				begin_countdown()
		COUNTDOWN:
			left = maxf(0.0, left - delta)
			if left <= 0:
				change_phase(FIGHT, 0.0)
		FIGHT:
			step_fight(delta)


func step_fight(delta: float) -> void:
	elapsed += delta
	half_side = Rules.half_side_at(elapsed)
	if players.has(-1):
		drive_bot()
	var previous_positions := {}
	for id: int in players:
		var player: Dictionary = players[id]
		if not player.alive:
			continue
		previous_positions[id] = player.p
		player.guard = maxf(0.0, player.guard - delta)
		player.reflect = maxf(0.0, player.reflect - delta)
		player.flash = maxf(0.0, player.flash - delta)
		player.anchor_left = maxf(0.0, player.anchor_left - delta)
		player.step_left = maxf(0.0, player.step_left - delta)
		player.surge_wait = maxf(0.0, player.surge_wait - delta)
		player.surge_left = maxf(0.0, player.surge_left - delta)
		for slot in range(Rules.ACTIVE_SLOTS):
			player.cooldowns[slot] = maxf(0.0, player.cooldowns[slot] - delta)
		var intent: Vector2 = player.move if elapsed - player.input_at < 0.3 else Vector2.ZERO
		var speed := Rules.WALK_SPEED * Rules.equipment_factor(player, "walk") * (1.24 if player.surge_left > 0.0 else 1.0)
		player.walk = player.walk.move_toward(intent * speed, 1100.0 * delta)
		player.p += (player.walk + player.kick) * delta
		player.kick *= exp(-4.7 * delta)
	resolve_projectiles(delta, previous_positions)
	resolve_strikes(delta)
	resolve_charges(delta, previous_positions)
	var alive: Array[int] = []
	for id: int in players:
		var player: Dictionary = players[id]
		if not player.alive:
			continue
		if player.windup > 0.0:
			player.windup = maxf(0.0, player.windup - delta)
			if player.windup <= 0.0:
				var aim: Vector2 = player.windup_aim
				var skill := Rules.skill(Rules.R, player.choices[Rules.R])
				shoot(id, Rules.R, aim, player.p + aim * 20.0, skill.shot, player.levels[Rules.R])
				player.kick = player.kick * 0.65 - aim * 255.0
				effect(player.p + aim * 22.0, Rules.SLOTS[Rules.R].color, 35.0, 0.24)
		var outside := Rules.square_extent(player.p) > half_side
		if outside and Rules.EMERGENCY_GEAR in player.equipment and not player.gear_used:
			player.gear_time = Rules.EMERGENCY_DURATION
			player.gear_used = true
			effect(player.p, Rules.SLOTS[Rules.GEAR].color, 52.0, 0.38)
		var protected_fraction := minf(delta, player.gear_time) / delta
		player.gear_time = maxf(0.0, player.gear_time - delta)
		var rate := Rules.OUTSIDE_DPS * Rules.equipment_factor(player, "outside") * (
			1.0 - Rules.EMERGENCY_REDUCTION * protected_fraction) if outside else 0.0
		var overload := Rules.OVERLOAD_DPS if elapsed >= 75.0 else 0.0
		player.hp -= maxf(rate, overload) * delta
		if player.hp <= 0.0:
			eliminate(id, "장외 탈락" if outside else "과부하 탈락")
		else:
			alive.append(id)
	if alive.size() <= 1:
		finish_round(alive[0] if not alive.is_empty() else 0)


func contact_time(offset: Vector2, travel: Vector2, reach: float) -> float:
	var clearance := offset.length_squared() - reach * reach
	if clearance <= 0.0:
		return 0.0
	var approach := offset.dot(travel)
	var speed_squared := travel.length_squared()
	var discriminant := approach * approach - speed_squared * clearance
	if approach >= 0.0 or discriminant < 0.0:
		return INF
	return (-approach - sqrt(discriminant)) / speed_squared


func resolve_projectiles(delta: float, previous_positions: Dictionary) -> void:
	if shots.is_empty():
		return
	var active_until: Array[float] = []
	for shot: Dictionary in shots:
		if shot.curve != 0.0:
			shot.v = shot.v.rotated(-shot.curve * delta)
		if shot.seeks and shot.age >= 0.22:
			steer_projectile(shot, delta)
		if shot.returns and shot.age >= shot.life * 0.5:
			shot.returns = false
			shot.v = -shot.v
			shot.damage = maxi(1, roundi(shot.damage * 0.55))
			shot.force *= 0.65
			shot.hit.clear()
			effect(shot.p, Rules.SLOTS[shot.slot].color, 19.0, 0.21)
		active_until.append(minf(1.0, (shot.life - shot.age) / delta))
	var contacts: Array[Dictionary] = []
	for index in range(shots.size()):
		var shot := shots[index]
		var origin: Vector2 = shot.p
		var travel: Vector2 = shot.v * delta
		for other in range(index + 1, shots.size()):
			var candidate := shots[other]
			var at := contact_time(origin - candidate.p, travel - candidate.v * delta, shot.size + candidate.size)
			if at <= minf(active_until[index], active_until[other]):
				contacts.append({"at": at, "shot": index, "other": other})
		for id: int in previous_positions:
			if id == shot.owner or id in shot.hit:
				continue
			var previous: Vector2 = previous_positions[id]
			var at := contact_time(origin - previous, travel - (players[id].p - previous), Rules.BODY_RADIUS + shot.size)
			if at <= active_until[index]:
				contacts.append({"at": at, "shot": index, "victim": id})
	# Resolve clashes first on ties so an intercepted projectile cannot also land a hit.
	contacts.sort_custom(func(a: Dictionary, b: Dictionary):
		return a.has("other") and not b.has("other") if a.at == b.at else a.at < b.at)
	var destroyed := {}
	var reflected: Array[Dictionary] = []
	for contact: Dictionary in contacts:
		var index: int = contact.shot
		var shot := shots[index]
		if contact.has("other"):
			var other: int = contact.other
			if destroyed.get(index, INF) < contact.at or destroyed.get(other, INF) < contact.at:
				continue
			var candidate := shots[other]
			var contact_at: Vector2 = shot.p + shot.v * delta * contact.at
			var other_at: Vector2 = candidate.p + candidate.v * delta * contact.at
			effect(contact_at.lerp(other_at, 0.5), Color("#e8faf8"), 29.0, 0.24)
			destroyed[index] = contact.at
			destroyed[other] = contact.at
		elif not destroyed.has(index) and players[contact.victim].alive:
			var target: Dictionary = players[contact.victim]
			if target.reflect > 0.0:
				target.reflect = 0.0
				reflected.append(reflect_shot(shot, contact.victim, delta * contact.at))
				destroyed[index] = contact.at
			else:
				hit(shot.owner, contact.victim, shot.damage, shot.force, shot.v.normalized())
				if not shot.pierce:
					destroyed[index] = contact.at
				else:
					shot.hit.append(contact.victim)
	for index in range(shots.size() - 1, -1, -1):
		var shot := shots[index]
		if destroyed.has(index) or shot.age + delta >= shot.life:
			shots.remove_at(index)
		else:
			shot.p += shot.v * delta
			shot.age += delta
	shots.append_array(reflected)


func steer_projectile(shot: Dictionary, delta: float) -> void:
	var heading: Vector2 = shot.v.normalized()
	var best_distance := 315.0 * 315.0
	var correction := 0.0
	for id: int in players:
		if id == shot.owner or not players[id].alive:
			continue
		var offset: Vector2 = players[id].p - shot.p
		var distance := offset.length_squared()
		var angle := heading.angle_to(offset)
		if distance < best_distance and absf(angle) < 0.85:
			best_distance = distance
			correction = angle
	var turn := 1.40 * delta
	shot.v = shot.v.rotated(clampf(correction, -turn, turn))


func reflect_shot(shot: Dictionary, owner: int, time: float) -> Dictionary:
	serial += 1
	var location: Vector2 = shot.p + shot.v * time
	effect(location, Rules.SLOTS[Rules.F].color, 39.0, 0.28)
	var reflected := shot.duplicate()
	reflected.merge({"id": serial, "owner": owner, "p": location, "v": -shot.v,
		"age": 0.0, "life": maxf(0.45, shot.life - shot.age - time),
		"damage": maxi(1, roundi(shot.damage * 0.60)), "force": shot.force * 0.65,
		"pierce": false, "returns": false, "curve": 0.0, "seeks": false, "hit": []}, true)
	return reflected


func resolve_strikes(delta: float) -> void:
	for index in range(strikes.size() - 1, -1, -1):
		var strike := strikes[index]
		strike.left -= delta
		if strike.left > 0.0:
			continue
		if strike.get("scatter", false):
			for spoke in range(4):
				var aim := Vector2.from_angle(strike.angle + spoke * PI * 0.5)
				shoot(strike.owner, strike.slot, aim, strike.p + aim * 13.0, strike.skill.shot, strike.level)
			effect(strike.p, Rules.SLOTS[strike.slot].color, 43.0, 0.30)
			strikes.remove_at(index)
			continue
		if strike.pull:
			for shot: Dictionary in shots:
				var toward: Vector2 = strike.p - shot.p
				if toward.length_squared() <= strike.size * strike.size and not toward.is_zero_approx():
					var direction: Vector2 = shot.v.normalized() * 0.55 + toward.normalized() * 0.65
					shot.v = direction.normalized() * shot.v.length()
		for id: int in players:
			var player: Dictionary = players[id]
			var offset: Vector2 = player.p - strike.p
			if id != strike.owner and player.alive and offset.length() <= strike.size + Rules.BODY_RADIUS:
				var direction := offset.normalized()
				if offset.is_zero_approx():
					direction = (player.p as Vector2).normalized() if not player.p.is_zero_approx() else Vector2.RIGHT
				if strike.pull:
					direction = -offset.normalized()
				hit(strike.owner, id, strike.damage, strike.force, direction)
		effect(strike.p, Rules.SLOTS[strike.slot].color, strike.size, 0.42)
		strikes.remove_at(index)


func resolve_charges(delta: float, previous_positions: Dictionary) -> void:
	var hits: Array[Dictionary] = []
	for id: int in previous_positions:
		var player: Dictionary = players[id]
		if not player.alive or player.charge <= 0.0:
			continue
		var start: Vector2 = previous_positions[id]
		var travel: Vector2 = player.p - start
		var end := minf(1.0, player.charge / delta)
		var target := 0
		var closest := INF
		player.charge = maxf(0.0, player.charge - delta)
		for other: int in previous_positions:
			if id == other or not players[other].alive:
				continue
			var opponent_start: Vector2 = previous_positions[other]
			var opponent_travel: Vector2 = players[other].p - opponent_start
			var at := contact_time(start - opponent_start, travel - opponent_travel, Rules.BODY_RADIUS * 2.0)
			if at <= end and at < closest:
				target = other
				closest = at
		if target != 0:
			var strength := clampf(travel.length() / (delta * 720.0), 0.35, 1.0)
			player.charge = 0.0
			player.kick *= 0.44
			hits.append({"owner": id, "target": target, "direction": travel.normalized(),
				"damage": Rules.attack_damage(roundi((15 + (player.levels[Rules.MOVE] - 1) * 4) * strength)),
				"force": 520.0 * strength})
	for contact: Dictionary in hits:
		if players[contact.target].alive:
			hit(contact.owner, contact.target, contact.damage, contact.force, contact.direction)


func finish_round(winner: int) -> void:
	round_winner = ""
	if players.has(winner):
		players[winner].wins += 1
		round_winner = players[winner].name
	var order: Array = players.keys()
	order.sort_custom(func(a: int, b: int): return outperforms(players[a], players[b], false))
	rankings.clear()
	var rank := 1
	for index in range(order.size()):
		var player: Dictionary = players[order[index]]
		if index > 0 and outperforms(players[order[index - 1]], player, false):
			rank = index + 1
		var reward := Rules.award(rank) if round_no < Rules.ROUNDS else 0
		player.gold += reward
		player.total_kills += player.kills
		player.total_damage += player.damage
		rankings.append({"id": order[index], "rank": rank, "name": player.name,
			"kills": player.kills, "damage": player.damage, "award": reward})
	shots.clear()
	strikes.clear()
	if round_no >= Rules.ROUNDS:
		enter_results()
	else:
		round_no += 1
		enter_shop()


func outperforms(a: Dictionary, b: Dictionary, total: bool) -> bool:
	if total and a.wins != b.wins:
		return a.wins > b.wins
	var kills_key := "total_kills" if total else "kills"
	var damage_key := "total_damage" if total else "damage"
	if a[kills_key] != b[kills_key]:
		return a[kills_key] > b[kills_key]
	return a[damage_key] > b[damage_key]


func enter_results() -> void:
	change_phase(RESULTS, 0.0)
	winners.clear()
	var order: Array = players.values()
	order.sort_custom(func(a: Dictionary, b: Dictionary): return outperforms(a, b, true))
	for player: Dictionary in order:
		if not outperforms(order[0], player, true):
			winners.append(player.name)
	shots.clear()
	strikes.clear()


func drive_bot() -> void:
	var bot: Dictionary = players[-1]
	var human: Dictionary = players[1]
	if not bot.alive or not human.alive:
		return
	var pos: Vector2 = bot.p
	var offset: Vector2 = human.p - pos
	var toward := offset.normalized()
	var orbit := toward.orthogonal() * sin(elapsed * 1.8) * 0.85
	var move := toward * clampf((offset.length() - 145.0) / 50.0, -0.65, 1.0) + orbit
	var extent := Rules.square_extent(pos)
	if extent > maxf(half_side * 0.67, half_side - 115.0):
		move = -pos.normalized()
		if extent > half_side + 8.0:
			cast(-1, Rules.MOVE, Vector2.ZERO)
	var aim: Vector2 = human.p + human.walk * 0.13 + orbit * 18.0
	steer(-1, move, aim)
	var distance := offset.length()
	var projectile_active := shots.any(func(shot: Dictionary): return shot.owner == -1)
	if not projectile_active:
		if elapsed > 1.7 and distance < 280.0 and bot.levels[Rules.R] > 0 and bot.cooldowns[Rules.R] <= 0.0:
			cast(-1, Rules.R, aim)
		elif elapsed > 1.7 and distance < 250.0 and bot.levels[Rules.Q] > 0 and bot.cooldowns[Rules.Q] <= 0.0:
			cast(-1, Rules.Q, aim)
		elif elapsed > 0.8 and distance < 410.0:
			cast(-1, Rules.BASIC, aim)
	if elapsed > 1.7 and distance < 250.0:
		cast(-1, Rules.E, aim)
	if bot.impact >= 45 and distance < 260.0:
		cast(-1, Rules.F, aim)


func snapshot() -> Dictionary:
	return {"phase": phase, "epoch": epoch, "round": round_no, "left": left,
		"elapsed": elapsed, "half_side": half_side, "players": players, "shots": shots,
		"strikes": strikes, "effects": effects, "rankings": rankings, "winners": winners,
		"round_winner": round_winner, "feed": feed}
