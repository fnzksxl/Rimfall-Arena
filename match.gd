extends RefCounted

const Rules = preload("res://rules.gd")
const AIM_REACH := Vector2.ONE * 1200.0
const MAP_EDGE := Vector2.ONE * Rules.MAP_HALF_SIDE
enum { LOBBY, SHOP, COUNTDOWN, FIGHT, RESULTS }
enum { FREE_FOR_ALL, TEAM_MATCH }

var phase := LOBBY
var mode := FREE_FOR_ALL
var team_wins := [0, 0]
var team_forfeit := false
var epoch := 0
var round_no := 0
var round_limit := Rules.ROUNDS
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
var audio_serial := 0


static func team_counts(roster: Dictionary) -> Array[int]:
	var counts: Array[int] = [0, 0]
	for player: Dictionary in roster.values():
		if player.team >= 0:
			counts[player.team] += 1
	return counts


static func can_start(roster: Dictionary, game_mode: int) -> bool:
	if game_mode == FREE_FOR_ALL:
		return roster.size() >= 2
	var counts := team_counts(roster)
	return counts[0] > 0 and counts[1] > 0 and absi(counts[0] - counts[1]) <= 1


static func same_team(a: Dictionary, b: Dictionary) -> bool:
	var team: int = a.get("team", -1)
	return team >= 0 and team == b.get("team", -1)


func opponents(a: int, b: int) -> bool:
	return a != b and not same_team(players.get(a, {}), players.get(b, {}))


func add_player(id: int, nickname: String) -> void:
	if phase != LOBBY or players.has(id) or players.size() >= Rules.CAPACITY:
		return
	var used: Array = players.values().map(func(player: Dictionary): return player.color)
	var color := 0
	while color in used:
		color += 1
	var team := -1
	if mode == TEAM_MATCH:
		var counts := team_counts(players)
		team = 0 if counts[0] <= counts[1] else 1
	players[id] = {"name": nickname, "color": color, "character": color % Rules.CHARACTER_NAMES.size(),
		"team": team, "wins": 0, "total_kills": 0,
		"total_damage": 0, "ready": false}
	reset_loadout(players[id])
	reset_player(players[id], Vector2.ZERO)


func select_character(id: int, choice: int) -> bool:
	if phase != LOBBY or not players.has(id) or choice < 0 or choice >= Rules.CHARACTER_NAMES.size():
		return false
	players[id].character = choice
	return true


func set_round_limit(limit: int) -> bool:
	if phase != LOBBY or limit < 1 or limit > Rules.MAX_ROUNDS:
		return false
	round_limit = limit
	return true


func switch_team(id: int) -> void:
	if phase != LOBBY or mode != TEAM_MATCH or not players.has(id):
		return
	var other: int = 1 - players[id].team
	if team_counts(players)[other] < Rules.TEAM_SIZE:
		players[id].team = other


func remove_player(id: int) -> void:
	if not players.has(id):
		return
	var nickname: String = players[id].name
	players.erase(id)
	if phase in [SHOP, COUNTDOWN, FIGHT]:
		push_feed("%s 님의 연결이 종료됐습니다." % nickname)
		shots = shots.filter(func(shot: Dictionary): return shot.owner != id)
		strikes = strikes.filter(func(strike: Dictionary): return strike.owner != id)
		if mode == TEAM_MATCH:
			var counts := team_counts(players)
			if counts.has(0):
				team_forfeit = true
				enter_results()
		elif players.size() < 2:
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
	player.merge({"p": spawn, "walk": Vector2.ZERO, "kick": Vector2.ZERO, "kick_decay": Rules.PROPULSION_DECAY,
		"move": Vector2.ZERO, "aim": -spawn.normalized(), "input_at": -1.0,
		"hp": 100.0, "impact": 0.0, "alive": true, "kills": 0, "damage": 0,
		"guard": 0.0, "charge": 0.0, "flash": 0.0, "reflect": 0.0,
		"propulsion": 0.0,
		"gear_time": 0.0, "gear_used": false, "shield_used": false, "last_hit": 0, "last_hit_at": -99.0,
		"anchor_left": 0.0, "anchor_pos": Vector2.ZERO, "step_left": 0.0,
		"surge_wait": 0.0, "surge_left": 0.0, "windup": 0.0, "windup_aim": Vector2.RIGHT,
		"windup_slot": -1, "windup_target": Vector2.ZERO,
		"fire_id": 0, "fire_at": -99.0, "fire_aim": Vector2.RIGHT,
		"root": 0.0, "jam": 0.0, "cloak": 0.0, "mirror": 0.0, "mirror_mask": 0, "mirror_axis": Vector2.RIGHT,
		"link_target": 0, "link_ticks": 0, "link_at": 0.0, "link_damage": 0,
		"cooldowns": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]}, true)


func start_match() -> void:
	if phase != LOBBY or not can_start(players, mode):
		return
	round_no = 1
	rankings.clear()
	winners.clear()
	round_winner = ""
	feed.clear()
	team_wins = [0, 0]
	team_forfeit = false
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
			for slot in ([Rules.Q] if round_no == 1 else [Rules.E, Rules.R, Rules.F, Rules.BASIC, Rules.Q, Rules.MOVE]):
				var choice: int = player.choices[slot]
				if player.levels[slot] == 0 and slot == Rules.Q:
					choice = [0, 2, 3, 4, 6][-id - 1]
				elif player.levels[slot] == 0 and slot == Rules.MOVE:
					choice = (-id - 1) % 2
				buy(id, slot, choice)
			player.ready = true


func buy(id: int, slot: int, choice := 0) -> void:
	if phase != SHOP or not players.has(id) or slot < 0 or slot >= Rules.SLOTS.size():
		return
	if not Rules.shop_slot_open(round_no, slot) or choice < 0 or choice >= Rules.SLOTS[slot].options.size():
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
	var counts := team_counts(players)
	var team_index := [0, 0]
	for id: int in players:
		var player: Dictionary = players[id]
		var angle := (round_no - 1) * 0.6
		var spawn := Vector2.from_angle(PI + TAU * float(index) / players.size() + angle) * Rules.SPAWN_DISTANCE
		if player.team >= 0:
			var team: int = player.team
			var row: float = team_index[team] - (counts[team] - 1.0) * 0.5
			spawn = Vector2(Rules.SPAWN_DISTANCE * (-1 if team == 0 else 1), row * 126.0).rotated(angle)
			team_index[team] += 1
		reset_player(player, spawn)
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
	return not player.is_empty() and player.alive and player.levels[slot] > 0 and cast_block(player, slot).is_empty() and (
		player.cooldowns[slot] <= 0.0 or recast_window(player, slot) > 0.0)


static func cast_block(player: Dictionary, slot: int) -> String:
	if player.get("windup", 0.0) > 0.0:
		return "시전 중"
	if slot != Rules.BASIC and player.get("jam", 0.0) > 0.0:
		return "교란"
	if slot == Rules.MOVE and player.get("root", 0.0) > 0.0:
		return "구속"
	return ""


static func mirror_offset(player: Dictionary, mirror_index: int) -> Vector2:
	var axis: Vector2 = player.mirror_axis
	return axis.rotated(-1.05 if mirror_index == 0 else 2.18) * (59.0 if mirror_index == 0 else 74.0)


static func cast_aim_point(origin: Vector2, offset: Vector2, skill_id: String) -> Vector2:
	match skill_id:
		"mark":
			return origin + offset.limit_length(330.0)
		"crossfire":
			return origin + offset.limit_length(275.0)
		"impact_burst":
			return origin + offset.limit_length(300.0)
		"scatter":
			return origin + offset.limit_length(250.0)
		"repeater":
			return (origin + offset.limit_length(235.0)).clamp(-MAP_EDGE, MAP_EDGE)
		"gravity":
			return origin + offset.limit_length(300.0)
	return origin + offset


func cast(id: int, slot: int, target: Vector2) -> void:
	if phase != FIGHT or not players.has(id) or slot < 0 or slot >= Rules.ACTIVE_SLOTS or not target.is_finite():
		return
	var player: Dictionary = players[id]
	if not can_cast(player, slot):
		return
	player.cloak = 0.0
	var offset: Vector2 = (target - player.p).clamp(-AIM_REACH, AIM_REACH)
	var direction: Vector2 = offset.normalized() if offset.length_squared() > 4.0 else player.aim
	player.aim = direction
	var choice: int = player.choices[slot]
	var tint: Color = Rules.SLOTS[slot].color
	var level: int = player.levels[slot]
	if recast_window(player, slot) > 0.0:
		if slot == Rules.F:
			player.anchor_left = 0.0
			effect(player.p, tint, 31.0, 0.28, 0, -1, Vector2.ZERO, Rules.Vfx.ANCHOR_RETURN)
			player.p = player.anchor_pos
			player.kick = Vector2.ZERO
			player.propulsion = 0.0
			player.walk = Vector2.ZERO
			effect(player.p, tint, 40.0, 0.32, 0, -1, Vector2.ZERO, Rules.Vfx.ANCHOR_RETURN)
		else:
			player.step_left = 0.0
			player.kick = direction * (505.0 + (level - 1) * 65.0)
			player.kick_decay = Rules.PROPULSION_DECAY
			player.propulsion = 0.28
			effect(player.p, tint, 40.0, 0.28, 0, -1, direction, Rules.Vfx.DOUBLE_RECAST)
		return
	player.cooldowns[slot] = Rules.cooldown(slot, choice, level, player)
	var delay := Rules.cast_delay(slot, choice)
	var aim_point := cast_aim_point(player.p, offset, Rules.skill(slot, choice).id)
	if delay > 0.0:
		player.windup = delay
		player.windup_slot = slot
		player.windup_aim = direction
		player.windup_target = aim_point
		player.walk = Vector2.ZERO
	else:
		release_cast(id, slot, direction, aim_point)


func release_pending_cast(id: int) -> void:
	var player: Dictionary = players[id]
	var slot: int = player.windup_slot
	player.windup = 0.0
	player.windup_slot = -1
	release_cast(id, slot, player.windup_aim, player.windup_target)


func release_cast(id: int, slot: int, direction: Vector2, target: Vector2) -> void:
	var player: Dictionary = players[id]
	var level: int = player.levels[slot]
	var skill := Rules.skill(slot, player.choices[slot])
	var vfx: int = Rules.SKILL_VFX.get(skill.id, Rules.Vfx.NONE)
	var tint: Color = Rules.SLOTS[slot].color
	if slot <= Rules.R:
		serial += 1
		player.merge({"fire_id": serial, "fire_at": elapsed, "fire_aim": direction}, true)
		var cue: int = [Rules.Cue.FIRE, Rules.Cue.POWER, Rules.Cue.MARK, Rules.Cue.POWER][slot]
		var cast_vfx := Rules.Vfx.MUZZLE if vfx != Rules.Vfx.NONE and vfx != Rules.Vfx.GRAVITY else Rules.Vfx.NONE
		effect(player.p + direction * 21.0, tint, 27.0, 0.19, 0, cue, direction, cast_vfx)
	match skill.id:
		"pulse", "wave", "lance", "heavy", "recoil", "disc", "curve", "seeker", \
		"ricochet", "snare", "link", "swap", "jam":
			shoot(id, slot, direction, player.p + direction * 20.0, skill.shot, level, vfx)
			if skill.id == "recoil":
				player.kick = player.kick * 0.5 - direction * 410.0
				player.kick_decay = Rules.PROPULSION_DECAY
				effect(player.p, tint, 31.0, 0.24, 0, -1, -direction, vfx)
		"twin_shot":
			for side: float in [-1.0, 1.0]:
				var aim := direction.rotated(side * Rules.TWIN_SHOT_SPREAD)
				shoot(id, slot, aim, player.p + aim * 20.0, skill.shot, level, vfx)
		"mark":
			add_strike(id, slot, target, Rules.AREA_RADII.mark, 0.70 - Rules.AREA_WINDUP, 24, 505.0, level, vfx)
		"crossfire":
			for side: float in [-1.0, 1.0]:
				var point := target + direction.orthogonal() * Rules.CROSSFIRE_OFFSET * side
				add_strike(id, slot, point, Rules.AREA_RADII.crossfire, 0.42, 16, 365.0, level, vfx)
		"repel":
			add_strike(id, slot, player.p, Rules.AREA_RADII.repel, Rules.REPEL_RELEASE_DELAY, 14, 420.0, level, vfx, true)
		"fissure":
			for index in range(3):
				var pos: Vector2 = player.p + direction * Rules.FISSURE_STEP * (index + 1)
				add_strike(id, slot, pos, Rules.AREA_RADII.fissure, 0.42 - Rules.AREA_WINDUP + index * 0.16, 12, 325.0, level, vfx)
		"scatter":
			var delay := 0.74 - Rules.AREA_WINDUP
			strikes.append({"owner": id, "slot": slot, "p": target,
				"left": delay, "duration": delay, "size": Rules.AREA_RADII.scatter, "pull": false,
				"scatter": true, "angle": direction.angle(), "skill": skill, "level": level, "vfx": vfx})
		"repeater":
			var delay := Rules.REPEATER_FIRST_SHOT - Rules.AREA_WINDUP
			strikes.append({"owner": id, "slot": slot, "p": target, "left": delay, "duration": delay,
				"size": Rules.AREA_RADII.repeater, "pull": false, "repeats": 3, "angle": direction.angle(),
				"skill": skill, "level": level, "vfx": vfx})
		"gravity":
			add_strike(id, slot, target, Rules.AREA_RADII.gravity, 0.85, 27, 685.0, level, vfx)
		"impact_burst":
			add_strike(id, slot, target, Rules.AREA_RADII.impact_burst, 0.46, 20, 390.0, level, vfx)
		"windup":
			shoot(id, slot, direction, player.p + direction * 20.0, skill.shot, level, vfx)
			player.kick = player.kick * 0.65 - direction * 255.0
			player.kick_decay = Rules.PROPULSION_DECAY
		"guard":
			player.guard = 0.85 + (level - 1) * 0.25
			effect(player.p, tint, 40.0, 0.30, 0, -1, Vector2.ZERO, vfx)
		"repair":
			var old_hp: float = player.hp
			player.hp = minf(100.0, player.hp + 16.0 + (level - 1) * 5.0)
			effect(player.p, Color("#adf097"), 46.0, 0.47, 0, -1, Vector2.ZERO, vfx, ceili(player.hp - old_hp))
		"cleanse":
			player.impact = maxf(0.0, player.impact - 32.0 - (level - 1) * 10.0)
			player.kick *= 0.28
			effect(player.p, Color("#ffb473"), 56.0, 0.38, 0, -1, Vector2.ZERO, vfx)
		"brake":
			player.kick = Vector2.ZERO
			player.propulsion = 0.0
			player.guard = maxf(player.guard, 0.32 + (level - 1) * 0.12)
			effect(player.p, tint, 35.0, 0.32, 0, Rules.Cue.GUARD, Vector2.ZERO, vfx)
		"reflect":
			player.reflect = 0.9 + (level - 1) * 0.25
			effect(player.p, tint, 35.0, 0.22, 0, -1, Vector2.ZERO, vfx)
		"anchor":
			player.anchor_pos = player.p
			player.anchor_left = 2.0 + (level - 1) * 0.20
			effect(player.p, tint, 34.0, 0.27, 0, -1, Vector2.ZERO, vfx)
		"surge":
			player.surge_wait = 2.3
			effect(player.p, tint, 37.0, 0.30, 0, -1, Vector2.ZERO, vfx)
		"mirror":
			player.mirror = 2.10 + (level - 1) * 0.18
			player.mirror_mask = 3
			player.mirror_axis = direction
			effect(player.p, tint, 25.0, 0.22, 0, -1, Vector2.ZERO, vfx)
			for index in range(2):
				var copy: Vector2 = player.p + mirror_offset(player, index)
				if Rules.square_extent(copy) <= Rules.MAP_HALF_SIDE:
					effect(copy, tint, 25.0, 0.22, 0, -1, Vector2.ZERO, vfx)
		"cloak":
			player.cloak = 2.0 + (level - 1) * 0.22
			player.mirror_mask = 0
			player.link_target = 0
			player.windup = 0.0
			effect(player.p, tint, 31.0, 0.25, 0, -1, Vector2.ZERO, vfx)
		"double":
			player.step_left = 0.90
			player.kick = player.kick * 0.18 + direction * (505.0 + (level - 1) * 65.0)
			player.kick_decay = Rules.PROPULSION_DECAY
			player.propulsion = 0.24
			effect(player.p, tint, 38.0, 0.26, 0, -1, player.kick.normalized(), vfx)
		"backstep":
			player.kick = -direction * (460.0 + (level - 1) * 55.0)
			player.kick_decay = Rules.PROPULSION_DECAY
			player.propulsion = 0.26
			effect(player.p, tint, 38.0, 0.26, 0, Rules.Cue.DASH, -direction, vfx)
		"dash", "recover", "tackle":
			var speed := 875.0 if skill.id == "dash" else 825.0
			if skill.id == "recover":
				var edge := Vector2.ONE * (half_side - 30.0)
				var pos: Vector2 = player.p
				var outside := Rules.square_extent(pos) > half_side
				var destination := pos.clamp(-edge, edge) if outside else Vector2.ZERO
				if not pos.is_equal_approx(destination):
					direction = pos.direction_to(destination)
				speed = 930.0 if outside else 540.0
				if outside:
					vfx = Rules.Vfx.RECOVER_OUTSIDE
			elif skill.id == "tackle":
				speed = 775.0
				player.charge = 0.37
			player.kick = player.kick * 0.24 + direction * (speed + (level - 1) * 75.0)
			player.kick_decay = Rules.PROPULSION_DECAY
			if skill.id == "tackle":
				effect(player.p, tint, 45.0, 0.20, 0, -1, player.kick.normalized(), vfx)
			else:
				player.propulsion = 0.39 if vfx == Rules.Vfx.RECOVER_OUTSIDE else 0.30
				effect(player.p, tint, 45.0, 0.32, 0, -1, player.kick.normalized(), vfx)


func shoot(id: int, slot: int, direction: Vector2, origin: Vector2, profile: Dictionary, level: int,
		vfx := Rules.Vfx.NONE) -> void:
	serial += 1
	var shooter: Dictionary = players.get(id, {})
	var speed_factor := Rules.PROJECTILE_SPEED_SCALE * Rules.equipment_factor(shooter, "shot_speed")
	var speed: float = profile.speed * speed_factor
	shots.append({"id": serial, "owner": id, "p": origin.clamp(-MAP_EDGE, MAP_EDGE),
		"v": direction * speed, "age": 0.0, "size": profile.size,
		"damage": Rules.attack_damage(profile.damage + (level - 1) * profile.gain),
		"force": 0.0 if profile.force == 0.0 else profile.force + (level - 1) * 38.0, "slot": slot, "style": profile.style,
		"curve": profile.get("curve", 0.0), "guidance": profile.get("guidance", {}),
		"proc": profile.get("proc", Rules.NO_PROC), "level": level, "bounces": 2,
		"pierce": profile.get("pierce", false), "turn_at": profile.get("turn_distance", 0.0) / speed,
		"hit": [], "vfx": vfx, "visual_step": int(vfx == Rules.Vfx.CURVE)})


func add_strike(id: int, slot: int, pos: Vector2, size: float, delay: float,
	damage: int, force: float, level: int, vfx := Rules.Vfx.NONE, follow_owner := false) -> void:
	strikes.append({"owner": id, "slot": slot, "p": pos, "left": delay, "duration": delay,
		"pull": vfx == Rules.Vfx.GRAVITY, "vfx": vfx,
		"follow_owner": follow_owner,
		"size": size + (level - 1) * 5.0, "damage": Rules.attack_damage(damage + (level - 1) * 4),
		"force": force + (level - 1) * 35.0})


func hit(owner: int, victim: int, damage: int, force: float, direction: Vector2, interrupt := true,
		vfx := Rules.Vfx.NONE) -> void:
	if not opponents(owner, victim):
		return
	var player: Dictionary = players[victim]
	var attacker: Dictionary = players.get(owner, {})
	var flat := Rules.equipment_amount(attacker, "damage_offset") + Rules.equipment_amount(player, "damage_offset")
	var shield: bool = Rules.SHIELD_GEAR in player.equipment and not player.shield_used
	var protection := 0.60 if shield else 1.0
	damage = maxi(1, roundi((damage + flat) * Rules.equipment_factor(player, "incoming") * protection))
	if shield:
		player.shield_used = true
		effect(player.p, Rules.SLOTS[Rules.GEAR].color, 47.0, 0.33, 0, Rules.Cue.DEFLECT)
	var health_lost := minf(damage, player.hp)
	player.hp = maxf(0.0, player.hp - damage)
	player.impact = minf(Rules.MAX_IMPACT, player.impact + damage * Rules.IMPACT_PER_DAMAGE * Rules.equipment_factor(player, "impact"))
	player.cloak = 0.0
	if interrupt:
		player.charge = 0.0
		player.propulsion = 0.0
		if player.windup_slot == Rules.R and Rules.skill(Rules.R, player.choices[Rules.R]).id == "windup":
			effect(player.p + player.windup_aim * 21.0, Rules.SLOTS[Rules.R].color, 25.0, 0.23,
				0, -1, player.windup_aim, Rules.Vfx.WINDUP_BREAK)
			player.windup = 0.0
			player.windup_slot = -1
	if player.surge_wait > 0.0:
		player.surge_wait = 0.0
		player.surge_left = 1.45 + (player.levels[Rules.F] - 1) * 0.24
		effect(player.p, Rules.SLOTS[Rules.F].color, 48.0, 0.40, 0, -1, Vector2.ZERO, Rules.Vfx.SURGE_ACTIVE)
	var resistance: float = protection * (0.30 if player.guard > 0.0 else 1.0) * Rules.equipment_factor(player, "knockback")
	if force > 0.0:
		var speed := force * Rules.knockback_multiplier(player.impact) * resistance * Rules.KNOCKBACK_SPEED_SCALE
		player.kick = (player.kick * 0.55 + direction * speed).limit_length(1800.0 * Rules.KNOCKBACK_SPEED_SCALE)
		player.kick_decay = Rules.knockback_decay(player.hp) * Rules.equipment_factor(player, "kick_decay")
	player.flash = 0.16
	player.last_hit = owner
	player.last_hit_at = elapsed
	if not attacker.is_empty():
		attacker.damage += ceili(health_lost)
		if attacker.alive:
			attacker.hp = minf(100.0, attacker.hp + health_lost * Rules.equipment_amount(attacker, "lifesteal"))
	effect(player.p, Rules.COLORS[player.color], 36.0, 0.24, ceili(health_lost), Rules.Cue.HIT, direction, vfx)
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
	effect(player.p, Color("#ffa574"), 55.0, 0.50, 0, Rules.Cue.KNOCKOUT)


func push_feed(message: String) -> void:
	feed_revision += 1
	feed.push_front(message)
	if feed.size() > 4:
		feed.pop_back()


func effect(pos: Vector2, tint: Color, size: float, duration: float, damage := 0, cue := -1,
		direction := Vector2.ZERO, vfx := Rules.Vfx.NONE, value := 0) -> void:
	if effects.size() >= 16:
		effects.pop_front()
	if cue >= 0:
		audio_serial += 1
	effects.append({"p": pos, "color": tint, "size": size, "left": duration,
		"duration": duration, "damage": damage, "cue": cue, "audio_id": audio_serial,
		"direction": direction, "vfx": vfx, "value": value})


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
	for id: int in players:
		if id < 0:
			drive_bot(id)
	var previous_positions := {}
	for id: int in players:
		var player: Dictionary = players[id]
		if not player.alive:
			continue
		previous_positions[id] = player.p
		player.guard = maxf(0.0, player.guard - delta)
		player.reflect = maxf(0.0, player.reflect - delta)
		player.propulsion = maxf(0.0, player.propulsion - delta)
		player.flash = maxf(0.0, player.flash - delta)
		player.anchor_left = maxf(0.0, player.anchor_left - delta)
		player.step_left = maxf(0.0, player.step_left - delta)
		player.surge_wait = maxf(0.0, player.surge_wait - delta)
		player.surge_left = maxf(0.0, player.surge_left - delta)
		player.root = maxf(0.0, player.root - delta)
		player.jam = maxf(0.0, player.jam - delta)
		player.mirror = maxf(0.0, player.mirror - delta)
		if player.mirror == 0.0:
			player.mirror_mask = 0
		for slot in range(Rules.ACTIVE_SLOTS):
			player.cooldowns[slot] = maxf(0.0, player.cooldowns[slot] - delta)
		var intent: Vector2 = player.move if elapsed - player.input_at < 0.3 else Vector2.ZERO
		var speed := Rules.WALK_SPEED * Rules.equipment_factor(player, "walk") * (1.24 if player.surge_left > 0.0 else 1.0)
		if player.cloak > 0.0:
			speed *= 1.22
		if player.root > 0.0 or player.windup > 0.0:
			speed = 0.0
		player.walk = player.walk.move_toward(intent * speed, 1100.0 * delta)
		player.p = (player.p + (player.walk + player.kick) * delta).clamp(-MAP_EDGE, MAP_EDGE)
		player.kick *= exp(-player.kick_decay * delta)
	resolve_projectiles(delta, previous_positions)
	resolve_strikes(delta)
	resolve_charges(delta, previous_positions)
	resolve_links()
	var alive: Array[int] = []
	for id: int in players:
		var player: Dictionary = players[id]
		if not player.alive:
			continue
		if player.windup > 0.0:
			player.windup = maxf(0.0, player.windup - delta)
			if player.windup <= 0.000001:
				release_pending_cast(id)
		var outside := Rules.square_extent(player.p) > half_side
		if outside and Rules.EMERGENCY_GEAR in player.equipment and not player.gear_used:
			player.gear_time = Rules.EMERGENCY_DURATION
			player.gear_used = true
			effect(player.p, Rules.SLOTS[Rules.GEAR].color, 52.0, 0.38)
		var protected_fraction := minf(delta, player.gear_time) / delta
		player.gear_time = maxf(0.0, player.gear_time - delta)
		var rate := Rules.OUTSIDE_DPS * Rules.equipment_factor(player, "outside") * (
			1.0 - Rules.EMERGENCY_REDUCTION * protected_fraction) if outside else 0.0
		player.hp -= rate * delta
		if not outside:
			var regen_time := clampf(elapsed - player.last_hit_at - 3.0, 0.0, delta)
			player.hp = minf(100.0, player.hp + regen_time * Rules.equipment_amount(player, "regen"))
		if player.hp <= 0.0:
			eliminate(id, "장외 탈락")
		else:
			alive.append(id)
	if alive.size() <= 1 or (mode == TEAM_MATCH and alive.all(func(id: int): return players[id].team == players[alive[0]].team)):
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


static func map_exit_time(origin: Vector2, travel: Vector2) -> float:
	var x_time := INF if travel.x == 0.0 else (signf(travel.x) * Rules.MAP_HALF_SIDE - origin.x) / travel.x
	var y_time := INF if travel.y == 0.0 else (signf(travel.y) * Rules.MAP_HALF_SIDE - origin.y) / travel.y
	return minf(x_time, y_time)


func resolve_projectiles(delta: float, previous_positions: Dictionary) -> void:
	if shots.is_empty():
		return
	var exit_times: Array[float] = []
	for shot: Dictionary in shots:
		if shot.curve != 0.0:
			shot.v = shot.v.rotated(-shot.curve * clampf(Rules.CURVE_TIME - shot.age, 0.0, delta))
			shot.visual_step = int(shot.age + delta < Rules.CURVE_TIME)
		var guidance: Dictionary = shot.guidance
		if not guidance.is_empty():
			var steer_time := minf(shot.age + delta, guidance.end) - maxf(shot.age, guidance.start)
			shot.visual_step = int(steer_time > 0.0 and steer_projectile(shot, guidance, steer_time))
		if shot.turn_at > 0.0 and shot.age >= shot.turn_at:
			shot.turn_at = 0.0
			shot.v = -shot.v
			shot.damage = maxi(1, roundi(shot.damage * 0.55))
			shot.force *= 0.65
			shot.hit.clear()
			shot.visual_step = 1
			effect(shot.p, Rules.SLOTS[shot.slot].color, 19.0, 0.21, 0, -1,
				shot.v.normalized(), Rules.Vfx.DISC_TURN)
		exit_times.append(map_exit_time(shot.p, shot.v * delta))
	var contacts: Array[Dictionary] = []
	for index in range(shots.size()):
		var shot := shots[index]
		var origin: Vector2 = shot.p
		var travel: Vector2 = shot.v * delta
		for other in range(index + 1, shots.size()):
			var candidate := shots[other]
			if shot.owner != candidate.owner and not opponents(shot.owner, candidate.owner):
				continue
			var at := contact_time(origin - candidate.p, travel - candidate.v * delta, shot.size + candidate.size)
			if at <= minf(1.0, minf(exit_times[index], exit_times[other])):
				contacts.append({"at": at, "shot": index, "other": other})
		for id: int in previous_positions:
			if not opponents(shot.owner, id) or id in shot.hit:
				continue
			var previous: Vector2 = previous_positions[id]
			var target: Dictionary = players[id]
			var relative: Vector2 = travel - (target.p - previous)
			var reach: float = Rules.BODY_RADIUS + shot.size
			var at := contact_time(origin - previous, relative, reach)
			if at <= minf(1.0, exit_times[index]):
				contacts.append({"at": at, "shot": index, "victim": id})
			if target.mirror_mask != 0:
				for mirror_index in range(2):
					if not (target.mirror_mask & (1 << mirror_index)):
						continue
					var offset := mirror_offset(target, mirror_index)
					if Rules.square_extent(target.p + offset) > Rules.MAP_HALF_SIDE:
						continue
					var mirror_at := contact_time(origin - previous - offset, relative, reach)
					if mirror_at <= minf(1.0, exit_times[index]):
						contacts.append({"at": mirror_at, "shot": index, "victim": id, "mirror": mirror_index})
	# Resolve clashes first on ties so an intercepted projectile cannot also land a hit.
	contacts.sort_custom(func(a: Dictionary, b: Dictionary):
		return a.has("other") and not b.has("other") if a.at == b.at else a.at < b.at)
	var destroyed := {}
	var continued: Array[Dictionary] = []
	var swaps: Array[Vector2i] = []
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
			effect(contact_at.lerp(other_at, 0.5), Color("#e8faf8"), 29.0, 0.24, 0, Rules.Cue.CLASH,
				other_at.direction_to(contact_at))
			destroyed[index] = contact.at
			destroyed[other] = contact.at
		elif not destroyed.has(index) and players[contact.victim].alive:
			var target: Dictionary = players[contact.victim]
			if contact.has("mirror"):
				var mask: int = 1 << contact.mirror
				if target.mirror_mask & mask:
					target.mirror_mask &= ~mask
					effect(target.p + mirror_offset(target, contact.mirror), Rules.SLOTS[Rules.F].color,
						26.0, 0.22, 0, Rules.Cue.DEFLECT, shot.v.normalized(), Rules.Vfx.MIRROR_BREAK)
					if not shot.pierce:
						destroyed[index] = contact.at
				continue
			if target.reflect > 0.0:
				target.reflect = 0.0
				continued.append(reflect_shot(shot, contact.victim, delta * contact.at))
				destroyed[index] = contact.at
			else:
				hit(shot.owner, contact.victim, shot.damage, shot.force, shot.v.normalized(), true, shot.vfx)
				if shot.proc == Rules.BOUNCE:
					var next_shot := ricochet(shot, contact.victim, delta * contact.at)
					if not next_shot.is_empty():
						continued.append(next_shot)
				elif target.alive and shot.proc != Rules.NO_PROC:
					if shot.proc == Rules.SWAP:
						swaps.append(Vector2i(shot.owner, contact.victim))
					else:
						projectile_status(shot, target, contact.victim)
				if not shot.pierce:
					destroyed[index] = contact.at
				else:
					shot.hit.append(contact.victim)
	for index in range(shots.size() - 1, -1, -1):
		var shot := shots[index]
		if destroyed.has(index) or exit_times[index] <= 1.0:
			shots.remove_at(index)
		else:
			shot.p += shot.v * delta
			shot.age += delta
	shots.append_array(continued)
	# Resolve swaps after swept contacts, then rebase charge sweeps at the new positions.
	for pair in swaps:
		if players.get(pair.x, {}).get("alive", false) and players[pair.y].alive:
			swap_positions(players[pair.x], players[pair.y])
			previous_positions[pair.x] = players[pair.x].p
			previous_positions[pair.y] = players[pair.y].p


func ricochet(shot: Dictionary, victim: int, time: float) -> Dictionary:
	if shot.bounces <= 0:
		return {}
	var location: Vector2 = shot.p + shot.v * time
	var best := 330.0 * 330.0
	var chosen := Vector2.ZERO
	for id: int in players:
		var target: Dictionary = players[id]
		if not opponents(shot.owner, id) or id == victim or id in shot.hit or not target.alive or target.cloak > 0.0:
			continue
		var distance := location.distance_squared_to(target.p)
		if distance < best:
			best = distance
			chosen = location.direction_to(target.p)
	if chosen.is_zero_approx():
		return {}
	shot.hit.append(victim)
	shot.merge({"p": location, "v": chosen * shot.v.length(), "bounces": shot.bounces - 1,
		"damage": maxi(1, roundi(shot.damage * 0.72)), "force": shot.force * 0.75}, true)
	shot.visual_step = 2 - shot.bounces
	effect(location, Rules.SLOTS[shot.slot].color, 24.0, 0.22, 0, -1, chosen, Rules.Vfx.BOUNCE_TURN)
	return shot


func swap_positions(source: Dictionary, target: Dictionary) -> void:
	var position: Vector2 = source.p
	source.p = target.p
	target.p = position
	for player in [source, target]:
		player.walk = Vector2.ZERO
		player.kick = Vector2.ZERO
		player.charge = 0.0
		player.propulsion = 0.0
		player.cloak = 0.0
		effect(player.p, Rules.SLOTS[Rules.R].color, 42.0, 0.32, 0, -1, Vector2.ZERO, Rules.Vfx.SWAP_PORTAL)


func projectile_status(shot: Dictionary, target: Dictionary, victim: int) -> void:
	match shot.proc:
		Rules.ROOT:
			target.root = maxf(target.root, 0.95 + (shot.level - 1) * 0.16)
			target.walk = Vector2.ZERO
		Rules.JAM:
			target.jam = maxf(target.jam, 1.90 + (shot.level - 1) * 0.25)
		Rules.LINK:
			var caster: Dictionary = players.get(shot.owner, {})
			if caster.get("alive", false) and caster.cloak <= 0.0 and (caster.p as Vector2).distance_to(target.p) <= Rules.LINK_RANGE:
				caster.link_target = victim
				caster.link_ticks = 3
				caster.link_at = elapsed + Rules.LINK_INTERVAL
				caster.link_damage = 1 + shot.level


func resolve_links() -> void:
	for id: int in players:
		var caster: Dictionary = players[id]
		if caster.link_target == 0:
			continue
		var target: Dictionary = players.get(caster.link_target, {})
		if not caster.alive or caster.cloak > 0.0 or not target.get("alive", false) or target.cloak > 0.0 or \
			(caster.p as Vector2).distance_to(target.p) > Rules.LINK_RANGE:
			if caster.alive and caster.cloak <= 0.0:
				effect(caster.p, Rules.SLOTS[Rules.E].color, 23.0, 0.24, 0, -1, Vector2.ZERO, Rules.Vfx.LINK_END)
			if target.get("alive", false) and target.cloak <= 0.0:
				effect(target.p, Rules.SLOTS[Rules.E].color, 23.0, 0.24, 0, -1, Vector2.ZERO, Rules.Vfx.LINK_END)
			caster.link_target = 0
			continue
		while caster.link_ticks > 0 and target.alive and elapsed >= caster.link_at:
			hit(id, caster.link_target, caster.link_damage, 0.0, Vector2.ZERO, false, Rules.Vfx.LINK_TICK)
			caster.link_at += Rules.LINK_INTERVAL
			caster.link_ticks -= 1
		if caster.link_ticks == 0 or not target.alive:
			caster.link_target = 0


func steer_projectile(shot: Dictionary, guidance: Dictionary, delta: float) -> bool:
	var heading: Vector2 = shot.v.normalized()
	var best_distance: float = guidance.distance * guidance.distance
	var correction := 0.0
	for id: int in players:
		if not opponents(shot.owner, id) or not players[id].alive or players[id].cloak > 0.0:
			continue
		var offset: Vector2 = players[id].p - shot.p
		var distance := offset.length_squared()
		var angle := heading.angle_to(offset)
		if distance < best_distance and absf(angle) < guidance.cone:
			best_distance = distance
			correction = angle
	var turn: float = guidance.rate * delta
	shot.v = shot.v.rotated(clampf(correction, -turn, turn))
	return absf(correction) > 0.015


func reflect_shot(shot: Dictionary, owner: int, time: float) -> Dictionary:
	serial += 1
	var location: Vector2 = shot.p + shot.v * time
	effect(location, Rules.SLOTS[Rules.F].color, 39.0, 0.28, 0, Rules.Cue.DEFLECT,
		-shot.v.normalized(), Rules.Vfx.REFLECT_HIT)
	var reflected := shot.duplicate()
	reflected.merge({"id": serial, "owner": owner, "p": location, "v": -shot.v,
		"age": 0.0,
		"damage": maxi(1, roundi(shot.damage * 0.60)), "force": shot.force * 0.65,
		"pierce": false, "turn_at": 0.0, "curve": 0.0, "guidance": {}, "proc": Rules.NO_PROC, "hit": []}, true)
	if reflected.vfx in [Rules.Vfx.SEEKER, Rules.Vfx.REPEATER, Rules.Vfx.CURVE]:
		reflected.visual_step = 0
	return reflected


func resolve_strikes(delta: float) -> void:
	for index in range(strikes.size() - 1, -1, -1):
		var strike := strikes[index]
		if strike.get("follow_owner", false):
			var caster: Dictionary = players.get(strike.owner, {})
			if not caster.get("alive", false):
				strikes.remove_at(index)
				continue
			strike.p = caster.p
		strike.left -= delta
		if strike.left > 0.0:
			continue
		if strike.has("repeats"):
			if players.get(strike.owner, {}).get("alive", false):
				var aim := Vector2.from_angle(strike.angle)
				shoot(strike.owner, strike.slot, aim, strike.p + aim * 16.0, strike.skill.shot, strike.level, strike.vfx)
				effect(strike.p + aim * 16.0, Rules.SLOTS[strike.slot].color, 28.0, 0.20, 0, Rules.Cue.FIRE,
					aim, Rules.Vfx.REPEATER_FIRE)
				strike.repeats -= 1
				if strike.repeats > 0:
					strike.duration = Rules.REPEATER_INTERVAL
					strike.left += Rules.REPEATER_INTERVAL
					continue
			strikes.remove_at(index)
			continue
		if strike.get("scatter", false):
			for spoke in range(4):
				var aim := Vector2.from_angle(strike.angle + spoke * PI * 0.5)
				shoot(strike.owner, strike.slot, aim, strike.p + aim * 13.0, strike.skill.shot, strike.level, strike.vfx)
			effect(strike.p, Rules.SLOTS[strike.slot].color, 43.0, 0.30, 0, Rules.Cue.STRIKE,
				Vector2.from_angle(strike.angle), strike.vfx)
			strikes.remove_at(index)
			continue
		if strike.pull:
			for shot: Dictionary in shots:
				if mode == TEAM_MATCH and not opponents(strike.owner, shot.owner):
					continue
				var toward: Vector2 = strike.p - shot.p
				if toward.length_squared() <= strike.size * strike.size and not toward.is_zero_approx():
					var direction: Vector2 = shot.v.normalized() * 0.55 + toward.normalized() * 0.65
					shot.v = direction.normalized() * shot.v.length()
		for id: int in players:
			var player: Dictionary = players[id]
			var offset: Vector2 = player.p - strike.p
			if opponents(strike.owner, id) and player.alive and offset.length() <= strike.size + Rules.BODY_RADIUS:
				var direction := offset.normalized()
				if offset.is_zero_approx():
					direction = (player.p as Vector2).normalized() if not player.p.is_zero_approx() else Vector2.RIGHT
				if strike.pull:
					direction = -offset.normalized()
				var damage: int = strike.damage
				if strike.vfx == Rules.Vfx.IMPACT_BURST:
					damage += roundi(clampf(player.impact / 120.0, 0.0, 1.0) * 18.0)
				hit(strike.owner, id, damage, strike.force, direction)
		effect(strike.p, Rules.SLOTS[strike.slot].color, strike.size, 0.42, 0, Rules.Cue.STRIKE,
			Vector2.ZERO, strike.vfx)
		strikes.remove_at(index)


func resolve_charges(delta: float, previous_positions: Dictionary) -> void:
	var hits: Array[Dictionary] = []
	for id: int in previous_positions:
		var player: Dictionary = players[id]
		var cloaked: bool = player.cloak > 0.0
		var window: float = player.cloak if cloaked else player.charge
		if not player.alive or window <= 0.0:
			continue
		var start: Vector2 = previous_positions[id]
		var travel: Vector2 = player.p - start
		var end := minf(1.0, window / delta)
		var target := 0
		var closest := INF
		var target_at_contact := Vector2.ZERO
		player.charge = maxf(0.0, player.charge - delta)
		player.cloak = maxf(0.0, player.cloak - delta)
		for other: int in previous_positions:
			if not opponents(id, other) or not players[other].alive:
				continue
			var opponent_start: Vector2 = previous_positions[other]
			var opponent_travel: Vector2 = players[other].p - opponent_start
			var at := contact_time(start - opponent_start, travel - opponent_travel, Rules.BODY_RADIUS * 2.0)
			if at <= end and at < closest:
				target = other
				closest = at
				target_at_contact = opponent_start + opponent_travel * at
		if target != 0:
			if cloaked:
				player.cloak = 0.0
				var contact := start + travel * closest
				var away := contact.direction_to(target_at_contact)
				if away.is_zero_approx():
					away = travel.normalized() if not travel.is_zero_approx() else Vector2.RIGHT
				hits.append({"owner": id, "target": target, "direction": away,
					"damage": Rules.attack_damage(8), "force": 240.0, "vfx": Rules.Vfx.CLOAK_HIT})
			else:
				var strength := clampf(travel.length() / (delta * 720.0), 0.35, 1.0)
				player.charge = 0.0
				player.kick *= 0.44
				hits.append({"owner": id, "target": target, "direction": travel.normalized(),
					"damage": Rules.attack_damage(roundi((15 + (player.levels[Rules.MOVE] - 1) * 4) * strength)),
					"force": 590.0 * strength, "vfx": Rules.Vfx.TACKLE_HIT})
		elif cloaked and player.cloak <= 0.0:
			effect(player.p, Rules.SLOTS[Rules.MOVE].color, 26.0, 0.23, 0, -1, Vector2.ZERO, Rules.Vfx.CLOAK_REVEAL)
	for contact: Dictionary in hits:
		if players[contact.target].alive:
			hit(contact.owner, contact.target, contact.damage, contact.force, contact.direction, true,
				contact.get("vfx", Rules.Vfx.NONE))


func finish_round(winner: int) -> void:
	round_winner = ""
	if players.has(winner):
		var winning_player: Dictionary = players[winner]
		if mode == TEAM_MATCH:
			var team: int = winning_player.team
			team_wins[team] += 1
			round_winner = Rules.TEAM_NAMES[team]
			for player: Dictionary in players.values():
				if player.team == team:
					player.wins += 1
		else:
			winning_player.wins += 1
			round_winner = winning_player.name
	var order: Array = players.keys()
	order.sort_custom(func(a: int, b: int): return outperforms(players[a], players[b], false))
	rankings.clear()
	var rank := 1
	for index in range(order.size()):
		var player: Dictionary = players[order[index]]
		if index > 0 and outperforms(players[order[index - 1]], player, false):
			rank = index + 1
		var last_place := rank > 1 and not outperforms(player, players[order.back()], false)
		var reward := Rules.award(rank, last_place) if round_no < round_limit else 0
		player.gold += reward
		player.total_kills += player.kills
		player.total_damage += player.damage
		rankings.append({"id": order[index], "rank": rank, "name": player.name, "team": player.team,
			"kills": player.kills, "damage": player.damage, "award": reward})
	shots.clear()
	strikes.clear()
	if round_no >= round_limit:
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
	if mode == TEAM_MATCH:
		var counts := team_counts(players)
		for team in range(Rules.TEAM_NAMES.size()):
			if (counts[team] > 0 if team_forfeit else team_wins[team] >= team_wins[1 - team]):
				winners.append(Rules.TEAM_NAMES[team])
	else:
		var order: Array = players.values()
		order.sort_custom(func(a: Dictionary, b: Dictionary): return outperforms(a, b, true))
		for player: Dictionary in order:
			if not outperforms(order[0], player, true):
				winners.append(player.name)
	shots.clear()
	strikes.clear()


func drive_bot(id: int) -> void:
	var bot: Dictionary = players[id]
	if not bot.alive:
		return
	var pos: Vector2 = bot.p
	var target := {}
	var nearest := INF
	for other: int in players:
		var candidate: Dictionary = players[other]
		if not opponents(id, other) or not candidate.alive or candidate.cloak > 0.0:
			continue
		var distance := pos.distance_squared_to(candidate.p)
		if distance < nearest:
			target = candidate
			nearest = distance
	if target.is_empty():
		steer(id, -pos.normalized(), Vector2.ZERO)
		return
	var offset: Vector2 = target.p - pos
	var toward := offset.normalized()
	var orbit := toward.orthogonal() * sin(elapsed * 1.8 + (-id - 1) * 1.4) * 0.85
	var move := toward * clampf((offset.length() - 145.0) / 50.0, -0.65, 1.0) + orbit
	var extent := Rules.square_extent(pos)
	if extent > maxf(half_side * 0.67, half_side - 115.0):
		move = -pos.normalized()
		if extent > half_side + 8.0:
			cast(id, Rules.MOVE, Vector2.ZERO)
	var aim: Vector2 = target.p + target.walk * 0.13 + orbit * 18.0
	steer(id, move, aim)
	var distance := offset.length()
	var projectile_active := shots.any(func(shot: Dictionary): return shot.owner == id and shot.age < 1.0)
	if not projectile_active:
		if elapsed > 1.7 and distance < 280.0 and bot.levels[Rules.R] > 0 and bot.cooldowns[Rules.R] <= 0.0:
			cast(id, Rules.R, aim)
		elif elapsed > 1.7 and distance < 250.0 and bot.levels[Rules.Q] > 0 and bot.cooldowns[Rules.Q] <= 0.0:
			cast(id, Rules.Q, aim)
		elif elapsed > 0.8 and distance < 410.0:
			cast(id, Rules.BASIC, aim)
	if elapsed > 1.7 and distance < 250.0:
		cast(id, Rules.E, aim)
	if bot.impact >= 45 and distance < 260.0:
		cast(id, Rules.F, aim)


func snapshot(viewer := 0) -> Dictionary:
	var visible_players := players
	if viewer != 0:
		for id: int in players:
			var player: Dictionary = players[id]
			if not opponents(viewer, id) or player.cloak <= 0.0:
				continue
			if is_same(visible_players, players):
				visible_players = players.duplicate()
			var hidden := player.duplicate()
			hidden.erase("fire_id")
			hidden.erase("fire_at")
			hidden.erase("fire_aim")
			hidden.merge({"p": Vector2.ZERO, "aim": Vector2.RIGHT, "walk": Vector2.ZERO, "kick": Vector2.ZERO,
				"move": Vector2.ZERO, "anchor_left": 0.0, "anchor_pos": Vector2.ZERO}, true)
			visible_players[id] = hidden
	return {"phase": phase, "epoch": epoch, "round": round_no, "round_limit": round_limit, "left": left,
		"mode": mode, "team_wins": team_wins, "team_forfeit": team_forfeit,
		"elapsed": elapsed, "half_side": half_side, "players": visible_players, "shots": shots,
		"strikes": strikes, "effects": effects, "rankings": rankings, "winners": winners,
		"round_winner": round_winner, "feed": feed}
