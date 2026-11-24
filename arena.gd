extends Node2D

const Rules = preload("res://rules.gd")
const Match = preload("res://match.gd")
const CombatView = preload("res://assets/robot/combat_view.gd")
const INK := Color("#09131d")
const MINT := Color("#79f2db")
const AMBER := Color("#ffa574")
const COMBAT_VIEW := Rect2(28, 101, 1384, 670)
const ARROW_FRAME := Rect2(48, 121, 1344, 630)
const COMBAT_ZOOM := 1.12

var state: Dictionary = {}
var own_id := 1
var menu := true
var clock := 0.0
var fighter_positions: Dictionary = {}
var fighter_steps: Dictionary = {}
var combat_views: Dictionary = {}
var shot_positions: Dictionary = {}
var last_epoch := -1
var followed_id := 0
var camera_focus := Vector2.ZERO
var backdrop := Node2D.new()


func _ready() -> void:
	add_child(backdrop)
	backdrop.show_behind_parent = true
	backdrop.draw.connect(draw_backdrop)


func world_target() -> Vector2:
	return get_local_mouse_position()


func _process(delta: float) -> void:
	clock += delta
	var epoch: int = state.get("epoch", -1)
	var phase: int = state.get("phase", Match.LOBBY)
	if epoch != last_epoch:
		if phase != Match.FIGHT:
			fighter_positions.clear()
			fighter_steps.clear()
		shot_positions.clear()
		last_epoch = epoch
	var blend := 1.0 - exp(-delta * 29.0)
	var players: Dictionary = state.get("players", {})
	var current_steps := {}
	for id: int in players:
		if concealed(id, players[id]):
			fighter_positions.erase(id)
			continue
		var pos: Vector2 = players[id].p
		var shown: Vector2 = fighter_positions.get(id, pos)
		fighter_positions[id] = pos if shown.distance_squared_to(pos) > 240.0 * 240.0 else shown.lerp(pos, blend)
		if phase == Match.FIGHT and players[id].alive:
			var walk: Vector2 = players[id].walk
			var step: float = fighter_steps.get(id, 0.0)
			current_steps[id] = fposmod(step + walk.length() * delta * TAU / 64.0, TAU)
	fighter_steps = current_steps
	if DisplayServer.get_name() != "headless":
		update_combat_views(phase, players)
	update_camera(phase, players, delta)
	var current_shots := {}
	for shot: Dictionary in state.get("shots", []):
		var shown: Vector2 = shot_positions.get(shot.id, shot.p)
		current_shots[shot.id] = shown.lerp(shot.p, blend)
	shot_positions = current_shots
	queue_redraw()


func update_combat_views(phase: int, players: Dictionary) -> void:
	for id: int in combat_views.keys():
		var player: Dictionary = players.get(id, {})
		if phase not in [Match.COUNTDOWN, Match.FIGHT] or not player.get("alive", false) or concealed(id, player):
			combat_views[id].queue_free()
			combat_views.erase(id)
	if phase not in [Match.COUNTDOWN, Match.FIGHT]:
		return
	for id: int in players:
		var player: Dictionary = players[id]
		if not player.alive or concealed(id, player):
			continue
		var view: CombatView = combat_views.get(id)
		if view == null:
			view = CombatView.new()
			view.variant = player.character
			add_child(view)
			combat_views[id] = view
		var point: Vector2 = fighter_positions.get(id, player.p)
		view.update_pose(player, fighter_facing(id, player, point, phase),
			fighter_steps.get(id, 0.0), clock, state.elapsed)


func fighter_facing(id: int, player: Dictionary, point: Vector2, phase: int) -> Vector2:
	if id == own_id and phase == Match.FIGHT and not world_target().is_equal_approx(point):
		return point.direction_to(world_target())
	var facing: Vector2 = player.aim
	return Vector2.DOWN if facing.is_zero_approx() else facing


func concealed(id: int, player: Dictionary) -> bool:
	return id != own_id and player.get("cloak", 0.0) > 0.0 and \
		not Match.same_team(state.players.get(own_id, {}), player)


func update_camera(phase: int, players: Dictionary, delta: float) -> void:
	var anchor := Vector2(540, 438)
	var zoom := 0.78
	if menu:
		anchor = Vector2(970, 445)
		zoom = 0.41
	if phase in [Match.COUNTDOWN, Match.FIGHT]:
		anchor = COMBAT_VIEW.get_center()
		zoom = COMBAT_ZOOM
		if players.get(own_id, {}).get("alive", false):
			followed_id = own_id
			camera_focus = fighter_positions[own_id]
		else:
			if not players.get(followed_id, {}).get("alive", false) or concealed(followed_id, players[followed_id]):
				followed_id = 0
				for id: int in players:
					if players[id].alive and not concealed(id, players[id]):
						if followed_id == 0:
							followed_id = id
						if Match.same_team(players.get(own_id, {}), players[id]):
							followed_id = id
							break
			if followed_id != 0:
				camera_focus = camera_focus.lerp(fighter_positions[followed_id], 1.0 - exp(-delta * 9.0))
	else:
		camera_focus = Vector2.ZERO
		followed_id = 0
	position = anchor - camera_focus * zoom
	scale = Vector2.ONE * zoom


func square(half_side: float) -> Rect2:
	var corner := Vector2.ONE * half_side
	return Rect2(-corner, corner * 2.0)


func draw_backdrop() -> void:
	var half := Rules.HALF_SIDE
	var footprint := square(half)
	var scatter := RandomNumberGenerator.new()
	scatter.seed = 39
	for index in range(240):
		var extent := Rules.MAP_HALF_SIDE
		var point := Vector2(scatter.randf_range(-extent, extent), scatter.randf_range(-extent, extent))
		if Rules.square_extent(point) > half + 30.0:
			backdrop.draw_circle(point, 1.2 + (index % 3) * 0.5, Color("#31505f"), true, -1.0, true)
	backdrop.draw_rect(square(Rules.MAP_HALF_SIDE), Color("#526c78"), false, 3.0, true)
	backdrop.draw_rect(square(half + 28.0).grow_individual(0, 0, 0, 18), Color("#040b12"))
	backdrop.draw_rect(square(half + 28.0), Color("#203642"))
	backdrop.draw_rect(square(half + 22.0), Color("#122530"))
	backdrop.draw_rect(footprint, Color("#192f39"))
	var sector := Vector2.ONE * half
	backdrop.draw_rect(Rect2(-sector, sector), Color("#1b333f"))
	backdrop.draw_rect(Rect2(Vector2.ZERO, sector), Color("#1b333f"))
	for offset in range(-600, 601, 100):
		var grid_color := Color("#36515b") if offset % 300 == 0 else Color("#29434f")
		backdrop.draw_line(Vector2(offset, -half), Vector2(offset, half), grid_color, 1.0, true)
		backdrop.draw_line(Vector2(-half, offset), Vector2(half, offset), grid_color, 1.0, true)
	for offset in range(-650, 651, 50):
		var tint := AMBER.darkened(0.12) if offset % 100 == 0 else Color("#466271")
		for side_sign: float in [-1.0, 1.0]:
			var outer := (half + 22.0) * side_sign
			var inner := (half + 13.0) * side_sign
			backdrop.draw_line(Vector2(offset, inner), Vector2(offset, outer), tint, 2.0, true)
			backdrop.draw_line(Vector2(inner, offset), Vector2(outer, offset), tint, 2.0, true)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			var corner := Vector2(x, y) * (half + 15.0)
			backdrop.draw_polyline(PackedVector2Array([corner - Vector2(x * 32, 0), corner,
				corner - Vector2(0, y * 32)]), MINT.darkened(0.30), 3.0, true)
	backdrop.draw_circle(Vector2.ZERO, 29, Color("#10222c"), true, -1.0, true)
	backdrop.draw_circle(Vector2.ZERO, 28, Color("#4d727a"), false, 1.0, true)
	backdrop.draw_line(Vector2(-18, 0), Vector2(18, 0), MINT.darkened(0.40), 1.5, true)
	backdrop.draw_line(Vector2(0, -18), Vector2(0, 18), MINT.darkened(0.40), 1.5, true)


func draw_boundary(half_side: float) -> void:
	var outer := Rules.HALF_SIDE
	var boundary := AMBER if half_side < outer - 2.0 else MINT
	if half_side < outer:
		var tint := Color(0.84, 0.21, 0.12, 0.17)
		var width := outer - half_side
		draw_rect(Rect2(-outer, -outer, outer * 2.0, width), tint)
		draw_rect(Rect2(-outer, half_side, outer * 2.0, width), tint)
		draw_rect(Rect2(-outer, -half_side, width, half_side * 2.0), tint)
		draw_rect(Rect2(half_side, -half_side, width, half_side * 2.0), tint)
	draw_rect(square(half_side), Color(boundary, 0.10), false, 10.0)
	draw_rect(square(half_side), Color(boundary, 0.24), false, 4.0)
	draw_rect(square(half_side), boundary, false, 1.7)


func _draw() -> void:
	var phase: int = state.get("phase", Match.LOBBY)
	var fight := phase in [Match.FIGHT, Match.COUNTDOWN]
	var half_side: float = state.half_side if fight else Rules.HALF_SIDE
	draw_boundary(half_side)
	if not fight:
		if menu:
			for index in range(3):
				var angle := clock * 0.30 + index * TAU / 3.0
				var point := Vector2.from_angle(angle) * (360.0 + 50 * index)
				draw_fighter(point, Vector2.from_angle(angle + 1.65), Rules.COLORS[index], 0.0, 0.0)
		return
	for strike: Dictionary in state.strikes:
		var tint: Color = Rules.SLOTS[strike.slot].color
		var progress: float = clampf(1.0 - strike.left / strike.duration, 0.0, 1.0)
		draw_circle(strike.p, strike.size, Color(tint, 0.12 + progress * 0.16), true, -1.0, true)
		draw_circle(strike.p, strike.size, tint, false, 2.0, true)
		draw_circle(strike.p, maxf(1.0, strike.size * (1 - progress)), Color(tint, 0.65), false, 2.0, true)
		if strike.get("scatter", false):
			for spoke in range(4):
				var ray := Vector2.from_angle(strike.angle + spoke * PI * 0.5)
				draw_dashed_line(strike.p + ray * 20.0, strike.p + ray * 54.0, Color(tint, 0.7), 2.0, 5.0)
		if strike.has("repeats"):
			var aim := Vector2.from_angle(strike.angle)
			draw_line(strike.p, strike.p + aim * 36.0, tint, 4.0, true)
			for remaining in range(strike.repeats):
				draw_circle(strike.p - aim * 9.0 + aim.orthogonal() * (remaining - 1) * 7.0, 2.0, tint)
		if strike.pull:
			for index in range(4):
				var inward := Vector2.from_angle(index * TAU / 4.0 + progress)
				draw_line(strike.p + inward * strike.size * 0.65, strike.p + inward * strike.size * 0.30, tint, 1.8, true)
	for shot: Dictionary in state.shots:
		draw_shot(shot)
	for id: int in state.players:
		var source: Dictionary = state.players[id]
		var target_id: int = source.link_target
		var target: Dictionary = state.players.get(target_id, {})
		if source.alive and target.get("alive", false) and not concealed(id, source) and not concealed(target_id, target):
			var start: Vector2 = fighter_positions.get(id, source.p)
			var end: Vector2 = fighter_positions.get(target_id, target.p)
			var color: Color = Rules.SLOTS[Rules.E].color
			draw_line(start, end, Color(color, 0.28), 6.0, true)
			draw_dashed_line(start, end, color, 2.0, 9.0)
	for id: int in state.players:
		var player: Dictionary = state.players[id]
		if not player.alive or concealed(id, player):
			continue
		var point: Vector2 = fighter_positions.get(id, player.p)
		var own := id == own_id
		var facing := fighter_facing(id, player, point, phase)
		var view: CombatView = combat_views.get(id)
		var tint: Color = Rules.TEAM_COLORS[player.team] if player.team >= 0 else Rules.COLORS[player.color]
		if player.anchor_left > 0.0:
			var anchor_color: Color = Rules.SLOTS[Rules.F].color
			draw_circle(player.anchor_pos, 18.0, Color(anchor_color, 0.17), true, -1.0, true)
			draw_circle(player.anchor_pos, 16.0, anchor_color, false, 2.2, true)
			draw_circle(player.anchor_pos, 3.0, anchor_color, true, -1.0, true)
		if player.windup > 0.0:
			var slot: int = player.windup_slot
			var charge_color: Color = Rules.SLOTS[slot].color
			var duration := Rules.cast_delay(slot, player.choices[slot])
			var aim: Vector2 = player.windup_aim
			if slot == Rules.E and Rules.skill(slot, player.choices[slot]).id == "repel":
				var radius: float = Rules.REPEL_RADIUS + 5.0 * (player.levels[slot] - 1)
				draw_circle(point, radius, Color(charge_color, 0.64), false, 2.0, true)
			else:
				draw_dashed_line(point + aim * 23.0, point + aim * 130.0, charge_color, 2.5, 8.0)
			draw_arc(point, 25.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(1.0 - player.windup / duration, 0.0, 1.0),
				22, charge_color, 2.1, true)
		if player.surge_left > 0.0 or player.surge_wait > 0.0:
			var surge_color: Color = Rules.SLOTS[Rules.F].color
			draw_arc(point, 25.0, clock * 3.2, clock * 3.2 + 2.4, 18, surge_color, 2.0, true)
		if Rules.square_extent(player.p) > half_side:
			draw_circle(point, 26.0 + sin(clock * 13.0) * 2.0, Color("#ff8a68"), false, 2.0, true)
		if player.charge > 0.0:
			var charge_color: Color = Rules.SLOTS[Rules.MOVE].color
			draw_circle(point, 29.0, Color(charge_color, 0.36), false, 6.0, true)
			draw_circle(point, 27.0, charge_color, false, 1.8, true)
		if player.reflect > 0.0:
			var reflect_color: Color = Rules.SLOTS[Rules.F].color
			for side in range(6):
				var angle := side * TAU / 6.0 + clock * 2.0
				draw_arc(point, 27.0, angle, angle + 0.64, 10, reflect_color, 2.5, true)
		if player.gear_time > 0.0:
			draw_circle(point, 32.0, Rules.SLOTS[Rules.GEAR].color, false, 2.1, true)
		if player.root > 0.0:
			draw_rect(Rect2(point - Vector2(23, 23), Vector2(46, 46)), Rules.SLOTS[Rules.Q].color, false, 1.8, true)
		if player.jam > 0.0:
			draw_arc(point, 32.0, clock * 3.0, clock * 3.0 + 4.6, 26, Rules.SLOTS[Rules.R].color, 2.2, true)
		if player.cloak > 0.0:
			tint = tint.darkened(0.38)
		if player.mirror_mask != 0:
			for index in range(2):
				if not (player.mirror_mask & (1 << index)):
					continue
				var offset := Match.mirror_offset(player, index)
				if Rules.square_extent(player.p + offset) > Rules.MAP_HALF_SIDE:
					continue
				var decoy_tint := tint.darkened(0.35) if own else tint
				draw_fighter(point + offset, facing, decoy_tint, player.guard, player.flash,
					player.walk, fighter_steps.get(id, 0.0), view)
				draw_tag(point + offset, player, decoy_tint)
		draw_fighter(point, facing, tint, player.guard, player.flash,
			player.walk, fighter_steps.get(id, 0.0), view)
		if view != null and player.windup <= 0.0 and clock - view.fire_clock < CombatView.MUZZLE_TIME:
			draw_muzzle(point, player.fire_aim, view)
		draw_tag(point, player, tint)
	for fx: Dictionary in state.effects:
		var progress: float = 1.0 - fx.left / fx.duration
		draw_circle(fx.p, lerpf(5.0, fx.size, progress), Color(fx.color, (1.0 - progress) * 0.85), false, 2.3, true)
		if fx.damage > 0:
			var text := "−%d" % fx.damage
			draw_string(ThemeDB.fallback_font, fx.p + Vector2(23, 52 - progress * 15), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(AMBER.lightened(0.27), clampf(1.5 - progress, 0.0, 1.0)))
	var local: Dictionary = state.players.get(own_id, {})
	if phase == Match.FIGHT and local.get("alive", false):
		if COMBAT_VIEW.has_point(get_global_mouse_position()):
			var target := world_target()
			draw_circle(target, 7.0, Color(MINT, 0.75), false, 1.3, true)
			for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
				var direction := Vector2.from_angle(angle)
				draw_line(target + direction * 8.0, target + direction * 12.0, MINT, 1.0, true)
	draw_opponent_arrows()


func offscreen_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	if state.get("phase") != Match.FIGHT:
		return markers
	var positions: Array[Vector2] = []
	var visible_area := COMBAT_VIEW.grow_individual(28, 8, 28, 8).grow(Rules.BODY_RADIUS * scale.x)
	var local: Dictionary = state.players.get(own_id, {})
	for id: int in state.players:
		var player: Dictionary = state.players[id]
		if id == own_id or id == followed_id or not player.alive or concealed(id, player) or Match.same_team(local, player):
			continue
		var projected := to_global(fighter_positions.get(id, player.p))
		if visible_area.has_point(projected):
			continue
		var offset := projected - ARROW_FRAME.get_center()
		var direction := offset.normalized()
		var ratios := offset.abs() / (ARROW_FRAME.size * 0.5)
		var point := ARROW_FRAME.get_center() + offset / maxf(ratios.x, ratios.y)
		while positions.any(func(other: Vector2): return other.distance_squared_to(point) < 324.0):
			point -= direction * 19.0
		positions.append(point)
		var tint: Color = Rules.TEAM_COLORS[player.team] if player.team >= 0 else Rules.COLORS[player.color]
		markers.append({"point": point, "direction": direction, "color": tint})
	return markers


func draw_opponent_arrows() -> void:
	for marker: Dictionary in offscreen_markers():
		var point := to_local(marker.point)
		var forward: Vector2 = marker.direction / scale.x
		var side := forward.orthogonal()
		var outline := PackedVector2Array([point + forward * 10, point - forward * 7 + side * 6.5,
			point - forward * 3, point - forward * 7 - side * 6.5])
		draw_colored_polygon(outline, marker.color)
		outline.append(outline[0])
		draw_polyline(outline, INK, 1.6 / scale.x, true)


func draw_shot(shot: Dictionary) -> void:
	var point: Vector2 = shot_positions.get(shot.id, shot.p)
	var direction: Vector2 = shot.v.normalized()
	var tint: Color = Rules.SLOTS[shot.slot].color
	var radius: float = shot.size
	if shot.style == Rules.BOLT:
		draw_line(point - direction * (20.0 + radius * 3.0), point, Color(tint, 0.24), radius * 1.8, true)
		draw_line(point - direction * (12.0 + radius * 2.0), point, tint, radius * 0.70, true)
		draw_circle(point, radius * 0.9, tint.lightened(0.65), true, -1.0, true)
	elif shot.style == Rules.WAVE:
		var angle := direction.angle()
		draw_circle(point, radius, Color(tint, 0.17), true, -1.0, true)
		draw_arc(point, radius - 1.3, angle - 1.45, angle + 1.45, 24, tint, 2.6, true)
		draw_arc(point, radius * 0.64, angle - 1.15, angle + 1.15, 18, Color(tint, 0.56), 1.8, true)
	elif shot.style == Rules.DISC:
		var angle := direction.angle()
		draw_line(point - direction * 24.0, point, Color(tint, 0.38), 3.4, true)
		draw_circle(point, radius, tint.lightened(0.22), false, 2.3, true)
		draw_arc(point, radius + 3.0, angle - 0.70, angle + 0.70, 14, tint, 1.8, true)
	else:
		draw_line(point - direction * 45.0, point, Color(tint, 0.22), radius * 1.25, true)
		draw_circle(point, radius, tint.darkened(0.54), true, -1.0, true)
		draw_circle(point, radius, tint, false, 3.0, true)
		draw_circle(point, radius * 0.44, tint.lightened(0.6), true, -1.0, true)


func draw_fighter(point: Vector2, facing: Vector2, tint: Color, guard: float, flash: float,
		walk := Vector2.ZERO, step := 0.0, view: CombatView = null) -> void:
	if view != null:
		var size := Vector2.ONE * CombatView.MODEL_SIZE
		var modulation := Color.WHITE.lerp(Color("#ffa7a4"), 0.55) if flash > 0.0 else Color.WHITE
		draw_texture_rect(view.get_texture(), Rect2(point - size * 0.5, size), false, modulation)
	else:
		draw_flat_robot(point, facing, tint, flash, walk, step)
	if guard > 0.0:
		draw_circle(point, 29, Color(Rules.SLOTS[Rules.F].color, 0.17), true, -1.0, true)
		draw_circle(point, 29, Rules.SLOTS[Rules.F].color, false, 2.5, true)


func draw_muzzle(point: Vector2, direction: Vector2, view: CombatView) -> void:
	var fade := 1.0 - (clock - view.fire_clock) / CombatView.MUZZLE_TIME
	var origin := point + view.muzzle_offset()
	var end := point + direction * 22.0
	var tint: Color = CombatView.FLASH_COLORS[view.variant]
	if view.robot.look == CombatView.Robot.Look.SPIDER_MAN:
		for strand: float in [-1.0, 1.0]:
			draw_line(origin, end + direction.orthogonal() * strand * 4.0, Color(tint, fade), 1.4, true)
	elif view.robot.look == CombatView.Robot.Look.BLACK_PANTHER:
		var angle := direction.angle()
		for claw in range(3):
			draw_arc(origin - direction * 5.0, 8.0 + claw * 3.0, angle - 0.85,
				angle + 0.79, 10, Color(tint, fade), 1.5, true)
	else:
		draw_circle(origin, 4.5 + (1.0 - fade) * 5.0, Color(tint, fade * 0.38), true, -1.0, true)
		draw_line(origin, end, Color(tint, fade), 2.6 if view.robot.look == CombatView.Robot.Look.VISION else 3.7, true)
		draw_circle(origin, 2.1, Color(tint.lightened(0.55), fade), true, -1.0, true)


func draw_flat_robot(point: Vector2, facing: Vector2, tint: Color, flash: float, walk: Vector2, step: float) -> void:
	var side := facing.orthogonal()
	var stride := clampf(walk.length() / Rules.WALK_SPEED, 0.0, 1.0)
	var travel := walk.normalized()
	var armor_color := Color("#f7ffff") if flash > 0.0 else tint
	for leg: float in [-1.0, 1.0]:
		var hip := point + side * (leg * 7.0) - facing * 3.0
		var foot := point + side * (leg * 9.0) - facing * 5.0 + travel * (cos(step) * leg * stride * 7.0)
		var lift := maxf(0.0, sin(step) * leg) * stride
		draw_line(hip, foot, Color("#303946"), 4.0, true)
		draw_line(foot - facing * 3.0, foot + facing * 3.0, armor_color.darkened(0.45 - lift * 0.23), 5.0, true)
	var torso := point + travel * (sin(step * 2.0) * stride)
	for shoulder: float in [-1.0, 1.0]:
		var joint := torso + side * (shoulder * 9.0)
		draw_line(joint - facing * 4.0, joint + facing * 3.0, armor_color, 4.5, true)
		draw_circle(joint, 1.5, Color("#303946"), true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([torso + facing * 15.0,
		torso + facing * 5.0 + side * 6.0, torso - facing * 6.0 + side * 5.0,
		torso - facing * 9.0, torso - facing * 6.0 - side * 5.0,
		torso + facing * 5.0 - side * 6.0]), Color("#9aabb6") if flash > 0.0 else Color("#414c58"))
	for eye: float in [-1.0, 1.0]:
		draw_line(torso + facing * 8.0 + side * (eye * 1.8),
			torso + facing * 6.0 + side * (eye * 4.5), Color("#ff665f"), 1.5, true)


func draw_tag(point: Vector2, player: Dictionary, tint: Color) -> void:
	var label := "%s   %d%%" % [player.name, roundi(player.impact)]
	if player.team >= 0:
		label = ("%s " % ["●", "◆"][player.team]) + label
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var origin := point + Vector2(-width * 0.5, -29)
	draw_rect(Rect2(origin - Vector2(5, 14), Vector2(width + 10, 19)), Color(INK, 0.90))
	draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tint.lightened(0.46))
	draw_rect(Rect2(point + Vector2(-16, 25), Vector2(32, 3)), Color("#0a151d"))
	draw_rect(Rect2(point + Vector2(-16, 25), Vector2(32 * player.hp / 100.0, 3)), tint)
