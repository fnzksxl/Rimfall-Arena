extends Node2D

const Rules = preload("res://rules.gd")
const Match = preload("res://match.gd")
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
		shot_positions.clear()
		last_epoch = epoch
	var blend := 1.0 - exp(-delta * 29.0)
	var players: Dictionary = state.get("players", {})
	for id: int in players:
		var pos: Vector2 = players[id].p
		var shown: Vector2 = fighter_positions.get(id, pos)
		fighter_positions[id] = shown.lerp(pos, blend)
	update_camera(phase, players, delta)
	var current_shots := {}
	for shot: Dictionary in state.get("shots", []):
		var shown: Vector2 = shot_positions.get(shot.id, shot.p)
		current_shots[shot.id] = shown.lerp(shot.p, blend)
	shot_positions = current_shots
	queue_redraw()


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
			if not players.get(followed_id, {}).get("alive", false):
				followed_id = 0
				for id: int in players:
					if players[id].alive:
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
		var point := Vector2(scatter.randf_range(-1440, 1440), scatter.randf_range(-1440, 1440))
		if Rules.square_extent(point) > half + 30.0:
			backdrop.draw_circle(point, 1.2 + (index % 3) * 0.5, Color("#31505f"), true, -1.0, true)
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


func draw_boundary(half_side: float, danger: bool) -> void:
	var outer := Rules.HALF_SIDE
	var boundary := AMBER if half_side < outer - 2.0 else MINT
	if danger:
		boundary = Color("#ff806b").lerp(AMBER, (sin(clock * 9.0) + 1.0) * 0.5)
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
	var danger: bool = fight and state.get("elapsed", 0.0) >= 75.0
	draw_boundary(half_side, danger)
	if not fight:
		if menu:
			for index in range(3):
				var angle := clock * 0.30 + index * TAU / 3.0
				var point := Vector2.from_angle(angle) * (360.0 + 50 * index)
				draw_fighter(point, Vector2.from_angle(angle + 1.65), Rules.COLORS[index], false, 0.0, 0.0)
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
		if strike.pull:
			for index in range(4):
				var inward := Vector2.from_angle(index * TAU / 4.0 + progress)
				draw_line(strike.p + inward * strike.size * 0.65, strike.p + inward * strike.size * 0.30, tint, 1.8, true)
	for shot: Dictionary in state.shots:
		draw_shot(shot)
	for id: int in state.players:
		var player: Dictionary = state.players[id]
		if not player.alive:
			continue
		var point: Vector2 = fighter_positions.get(id, player.p)
		var own := id == own_id
		var facing: Vector2 = player.aim
		if own and phase == Match.FIGHT and not world_target().is_equal_approx(point):
			facing = point.direction_to(world_target())
		var tint: Color = Rules.COLORS[player.color]
		if player.anchor_left > 0.0:
			var anchor_color: Color = Rules.SLOTS[Rules.F].color
			draw_circle(player.anchor_pos, 18.0, Color(anchor_color, 0.17), true, -1.0, true)
			draw_circle(player.anchor_pos, 16.0, anchor_color, false, 2.2, true)
			draw_circle(player.anchor_pos, 3.0, anchor_color, true, -1.0, true)
		if player.windup > 0.0:
			var charge_color: Color = Rules.SLOTS[Rules.R].color
			var aim: Vector2 = player.windup_aim
			draw_dashed_line(point + aim * 23.0, point + aim * 130.0, charge_color, 2.5, 8.0)
			draw_arc(point, 25.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - player.windup / 0.75),
				22, charge_color, 2.1, true)
		if player.surge_left > 0.0 or player.surge_wait > 0.0:
			var surge_color: Color = Rules.SLOTS[Rules.F].color
			draw_arc(point, 25.0, clock * 3.2, clock * 3.2 + 2.4, 18, surge_color, 2.0, true)
		if Rules.square_extent(player.p) > half_side or danger:
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
		draw_fighter(point, facing, tint, own, player.guard, player.flash)
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
	for id: int in state.players:
		var player: Dictionary = state.players[id]
		if id == own_id or id == followed_id or not player.alive:
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
		markers.append({"point": point, "direction": direction, "color": Rules.COLORS[player.color]})
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


func draw_fighter(point: Vector2, facing: Vector2, tint: Color, own: bool, guard: float, flash: float) -> void:
	var side := facing.orthogonal()
	draw_circle(point + Vector2(0, 5), 20, Color(0.01, 0.035, 0.05, 0.78), true, -1.0, true)
	draw_circle(point, 22, Color(tint, 0.12), true, -1.0, true)
	draw_circle(point, 17, tint.darkened(0.63), true, -1.0, true)
	draw_circle(point, 17, Color(tint, 0.83), false, 1.5, true)
	var armor := PackedVector2Array([point + facing * 19, point + facing * 3 + side * 10,
		point - facing * 9 + side * 9, point - facing * 13, point - facing * 9 - side * 9, point + facing * 3 - side * 10])
	draw_colored_polygon(armor, Color("#f7ffff") if flash > 0.0 else tint)
	draw_colored_polygon(PackedVector2Array([point + facing * 9, point + side * 5, point - facing * 5,
		point - side * 5]), tint.darkened(0.73))
	if own:
		draw_arc(point, 23, facing.angle() - 0.55, facing.angle() + 0.55, 16, Color("#ecfff9"), 2.8, true)
	if guard > 0.0:
		draw_circle(point, 29, Color(Rules.SLOTS[Rules.F].color, 0.17), true, -1.0, true)
		draw_circle(point, 29, Rules.SLOTS[Rules.F].color, false, 2.5, true)


func draw_tag(point: Vector2, player: Dictionary, tint: Color) -> void:
	var label := "%s   %d%%" % [player.name, roundi(player.impact)]
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var origin := point + Vector2(-width * 0.5, -29)
	draw_rect(Rect2(origin - Vector2(5, 14), Vector2(width + 10, 19)), Color(INK, 0.90))
	draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tint.lightened(0.46))
	draw_rect(Rect2(point + Vector2(-16, 25), Vector2(32, 3)), Color("#0a151d"))
	draw_rect(Rect2(point + Vector2(-16, 25), Vector2(32 * player.hp / 100.0, 3)), tint)
