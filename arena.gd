extends Node2D

const Rules = preload("res://rules.gd")
const Match = preload("res://match.gd")
const CombatView = preload("res://assets/robot/combat_view.gd")
const SkillEffects = preload("res://skill_effects.gd")
const INK := Color("#09131d")
const MINT := Color("#79f2db")
const AMBER := Color("#ffa574")
const GRAVITY_TINT := Color("#c98bea")
const TACKLE_TINT := Color("#a5dcff")
const COMBAT_VIEW := Rect2(28, 101, 1384, 670)
const ARROW_FRAME := Rect2(48, 121, 1344, 630)
const COMBAT_ZOOM := 1.12

var state: Dictionary = {}
var own_id := 1
var preview_slot := -1
var menu := true
var clock := 0.0
var fighter_positions: Dictionary = {}
var fighter_motion: Dictionary = {}
var fighter_steps: Dictionary = {}
var tackle_trails: Dictionary = {}
var combat_views: Dictionary = {}
var shot_positions: Dictionary = {}
var last_epoch := -1
var followed_id := 0
var camera_focus := Vector2.ZERO
var backdrop := Node2D.new()
var deck_tiles: Array[Texture2D] = []
var pulse_texture: Texture2D
var gravity_texture: Texture2D
var glow_texture: GradientTexture2D
var skill_effects: SkillEffects


func _ready() -> void:
	deck_tiles = make_deck_tiles()
	add_child(backdrop)
	backdrop.show_behind_parent = true
	backdrop.draw.connect(draw_backdrop)
	pulse_texture = make_pulse_texture()
	gravity_texture = make_gravity_texture()
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0, 0.16, 0.42, 1.0])
	falloff.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.76),
		Color(1, 1, 1, 0.21), Color(1, 1, 1, 0.0)])
	glow_texture = GradientTexture2D.new()
	glow_texture.gradient = falloff
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	skill_effects = SkillEffects.new(self, glow_texture, pulse_texture)


func world_target() -> Vector2:
	return get_local_mouse_position()


func _process(delta: float) -> void:
	clock += delta
	var epoch: int = state.get("epoch", -1)
	var phase: int = state.get("phase", Match.LOBBY)
	if epoch != last_epoch:
		tackle_trails.clear()
		if phase != Match.FIGHT:
			fighter_positions.clear()
			fighter_motion.clear()
			fighter_steps.clear()
		shot_positions.clear()
		last_epoch = epoch
	var blend := 1.0 - exp(-delta * 29.0)
	var players: Dictionary = state.get("players", {})
	var portal_positions := {}
	for fx: Dictionary in state.get("effects", []):
		if fx.get("vfx", Rules.Vfx.NONE) in [Rules.Vfx.SWAP_PORTAL, Rules.Vfx.ANCHOR_RETURN] and fx.duration - fx.left < 0.12:
			portal_positions[fx.p] = true
	var current_steps := {}
	var current_trails := {}
	for id: int in players:
		if concealed(id, players[id]):
			fighter_positions.erase(id)
			fighter_motion.erase(id)
			continue
		var pos: Vector2 = players[id].p
		var shown: Vector2 = fighter_positions.get(id, pos)
		var snapped := shown.distance_squared_to(pos) > 240.0 * 240.0 or portal_positions.has(pos)
		var point := pos if snapped else shown.lerp(pos, blend)
		fighter_positions[id] = point
		fighter_motion[id] = Vector2.ZERO if snapped else (point - shown) / maxf(delta, 0.001)
		if phase == Match.FIGHT and players[id].alive:
			var walk: Vector2 = players[id].walk
			var step: float = fighter_steps.get(id, 0.0)
			current_steps[id] = fposmod(step + walk.length() * delta * TAU / 64.0, TAU)
			if players[id].charge > 0.0:
				var trail: PackedVector2Array = tackle_trails.get(id, PackedVector2Array([shown, shown]))
				if snapped:
					trail = PackedVector2Array([point, point])
				trail[0] = trail[0].lerp(point, 1.0 - exp(-delta * 19.0))
				trail[1] = trail[1].lerp(trail[0], 1.0 - exp(-delta * 13.0))
				current_trails[id] = trail
	fighter_steps = current_steps
	tackle_trails = current_trails
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
	if tackle_trails.has(id):
		var trail: PackedVector2Array = tackle_trails[id]
		if trail[1].distance_squared_to(point) > 4.0:
			return trail[1].direction_to(point)
		return player.aim
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
	var extent := Rules.MAP_HALF_SIDE
	var scatter := RandomNumberGenerator.new()
	scatter.seed = 39
	backdrop.draw_rect(square(extent), Color("#080f17"))
	for index in range(168):
		var point := Vector2(scatter.randf_range(-extent, extent), scatter.randf_range(-extent, extent))
		if Rules.square_extent(point) > half + 45.0:
			backdrop.draw_circle(point, 0.8 + (index % 3) * 0.35, Color("#263a48"), true, -1.0, true)
	backdrop.draw_rect(square(extent), Color("#334650"), false, 2.0, true)
	backdrop.draw_rect(square(half + 31.0).grow_individual(4, 2, 6, 17), Color("#04080d"))
	backdrop.draw_rect(square(half + 31.0), Color("#263541"))
	backdrop.draw_rect(square(half + 26.0), Color("#101923"))
	backdrop.draw_rect(square(half + 12.0), Color("#384850"))
	backdrop.draw_rect(square(half), Color("#101923"))

	var panels := maxi(1, roundi(half * 2.0 / 100.0))
	var span := half * 2.0 / panels
	for row in range(panels):
		for column in range(panels):
			var index := (row * 7 + column * 13 + row * column) % deck_tiles.size()
			var point := Vector2(column * span - half, row * span - half)
			backdrop.draw_texture_rect(deck_tiles[index], Rect2(point, Vector2.ONE * span), false)

	for wall in range(4):
		var outward := Vector2.from_angle(wall * PI * 0.5)
		var along := outward.orthogonal()
		for bay: float in [-0.78, -0.31, 0.31, 0.78]:
			var point := outward * (half + 19.0) + along * (half * bay)
			backdrop.draw_line(point - along * 24.0, point + along * 24.0, Color("#0a1018"), 11.0, true)
			for notch in range(-2, 3):
				var slat := point + along * notch * 8.3
				backdrop.draw_line(slat - outward * 3.5, slat + outward * 3.5 + along * 3.0,
					Color("#a67d52") if notch in [-2, 2] else Color("#3d505a"), 2.1, true)
		for side: float in [-1.0, 1.0]:
			var led := outward * (half + 9.0) + along * side * (half - 38.0)
			backdrop.draw_line(led - along * 20.0, led + along * 20.0, Color("#44777d"), 3.0, true)
		for band in [0.33, 0.66]:
			var a: Vector2 = outward * (half * float(band) - 20.0)
			var b: Vector2 = a + outward * 42.0
			backdrop.draw_line(a, b, Color("#1a2a34"), 11.0, true)
			backdrop.draw_line(a, b, Color("#4a6570"), 1.3, true)
		draw_deck_drain(outward * (half * 0.74) + along * (half * 0.42), outward)
	draw_deck_hatch()


func make_deck_tiles() -> Array[Texture2D]:
	const RESOLUTION := 128
	var tiles: Array[Texture2D] = []
	var noise := FastNoiseLite.new()
	noise.seed = 4307
	noise.frequency = 0.082
	var grain := RandomNumberGenerator.new()
	grain.seed = 175
	for variant in range(5):
		var tile := Image.create_empty(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
		var steel := Color("#26363f").lerp(Color("#2a3b45"), variant / 4.0)
		for y in range(RESOLUTION):
			for x in range(RESOLUTION):
				var inset_x := mini(x, RESOLUTION - 1 - x)
				var inset_y := mini(y, RESOLUTION - 1 - y)
				var edge := mini(inset_x, inset_y)
				if edge < 1 or inset_x + inset_y < 5:
					tile.set_pixel(x, y, Color("#1b2730"))
					continue
				var brushing := grain.randf_range(-0.017, 0.017)
				var weathering := noise.get_noise_2d(x * 0.32 + variant * 137.0, y * 1.12) * 0.082
				var slope := 0.027 - y / float(RESOLUTION) * 0.065
				var shade := steel * (1.0 + weathering + brushing + slope)
				shade.a = 1.0
				if edge < 3 or inset_x + inset_y < 8:
					shade = shade.lightened(0.062) if x + y < RESOLUTION else shade.darkened(0.12)
				tile.set_pixel(x, y, shade)
		for point in [Vector2i(6, 13), Vector2i(121, 13), Vector2i(6, 114), Vector2i(121, 114)]:
			tile.set_pixelv(point, Color("#101923"))
			tile.set_pixelv(point + Vector2i(1, 0), Color("#101923"))
			tile.set_pixelv(point + Vector2i(0, 1), Color("#405056"))
		for scuff in range(6):
			var x := grain.randi_range(13, 102)
			var y := grain.randi_range(15, 113)
			for length in range(grain.randi_range(3, 18)):
				var point := Vector2i(x + length, y + floori(length / 6.0))
				tile.set_pixelv(point, tile.get_pixelv(point).lightened(0.032))
		tiles.append(ImageTexture.create_from_image(tile))
	return tiles


func draw_deck_hatch() -> void:
	for index in range(4):
		var ray := Vector2.from_angle(index * PI * 0.5)
		for offset: float in [-5.5, 5.5]:
			var inset := ray.orthogonal() * offset
			backdrop.draw_line(ray * 79.0 + inset, ray * 123.0 + inset, Color("#1c2a33"), 3.5, true)
			backdrop.draw_line(ray * 83.0 + inset, ray * 118.0 + inset, Color("#415862"), 1.0, true)
	var hatch := PackedVector2Array([
		Vector2(-53, -35), Vector2(-35, -53), Vector2(35, -53), Vector2(53, -35),
		Vector2(53, 35), Vector2(35, 53), Vector2(-35, 53), Vector2(-53, 35)])
	backdrop.draw_colored_polygon(hatch, Color("#202f39"))
	hatch.append(hatch[0])
	backdrop.draw_polyline(hatch, Color("#101a22"), 4.0, true)
	backdrop.draw_polyline(hatch, Color("#415360"), 1.5, true)
	for side: float in [-1.0, 1.0]:
		var port := Vector2(36.0 * side, 0.0)
		backdrop.draw_line(port - Vector2(0, 16), port + Vector2(0, 16), Color("#476970"), 3.0, true)
		for slit in range(-2, 3):
			var center := Vector2(slit * 11.0, side * 25.0)
			backdrop.draw_line(center - Vector2(3, 0), center + Vector2(3, 0), Color("#101c25"), 5.0, true)
	backdrop.draw_line(Vector2(0, -17), Vector2(0, 17), Color("#0d1921"), 3.0, true)


func draw_deck_drain(point: Vector2, direction: Vector2) -> void:
	var along := direction.orthogonal()
	backdrop.draw_line(point - along * 27.0, point + along * 27.0, Color("#41535e"), 16.0, true)
	backdrop.draw_line(point - along * 25.0, point + along * 25.0, Color("#19262f"), 12.0, true)
	for index in range(-3, 4):
		var vent := point + along * index * 6.2
		backdrop.draw_line(vent - direction * 3.5, vent + direction * 3.5, Color("#33434d"), 2.2, true)


func draw_boundary(half_side: float) -> void:
	var outer := Rules.HALF_SIDE
	var boundary := AMBER if half_side < outer - 2.0 else MINT
	if half_side < outer:
		var tint := Color(0.79, 0.21, 0.12, 0.15)
		var width := outer - half_side
		draw_rect(Rect2(-outer, -outer, outer * 2.0, width), tint)
		draw_rect(Rect2(-outer, half_side, outer * 2.0, width), tint)
		draw_rect(Rect2(-outer, -half_side, width, half_side * 2.0), tint)
		draw_rect(Rect2(half_side, -half_side, width, half_side * 2.0), tint)
	draw_rect(square(half_side), Color(boundary, 0.12), false, 10.0)
	draw_rect(square(half_side), Color(boundary, 0.29), false, 4.0)
	draw_rect(square(half_side), Color(boundary, 0.96), false, 1.7)
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			var corner := Vector2(x, y) * half_side
			draw_polyline(PackedVector2Array([corner - Vector2(x * 26.0, 0.0), corner,
				corner - Vector2(0.0, y * 26.0)]), boundary.lightened(0.40), 3.5, true)


func _draw() -> void:
	skill_effects.clock = clock
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
	for fx: Dictionary in state.effects:
		var style: int = fx.get("vfx", Rules.Vfx.NONE)
		var progress := clampf(1.0 - fx.left / fx.duration, 0.0, 1.0)
		if style == Rules.Vfx.GRAVITY:
			draw_gravity_collapse(fx.p, fx.size, progress)
		elif style in [Rules.Vfx.MARK, Rules.Vfx.REPEL, Rules.Vfx.FISSURE] or (
				style == Rules.Vfx.SCATTER and fx.damage == 0):
			skill_effects.draw_event(fx, progress)
	for strike: Dictionary in state.strikes:
		var tint: Color = Rules.SLOTS[strike.slot].color
		var progress: float = clampf(1.0 - strike.left / strike.duration, 0.0, 1.0)
		if strike.pull:
			draw_gravity_cracks(strike.p, strike.size, lerpf(0.22, 0.84, progress))
			draw_circle(strike.p, strike.size, Color(tint, 0.64 + progress * 0.29), false, 1.6, true)
			continue
		if skill_effects.draw_strike(strike, progress, tint):
			continue
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
	for shot: Dictionary in state.shots:
		draw_shot(shot)
	for id: int in state.players:
		var source: Dictionary = state.players[id]
		var target_id: int = source.link_target
		var target: Dictionary = state.players.get(target_id, {})
		if source.alive and target.get("alive", false) and not concealed(id, source) and not concealed(target_id, target):
			var start: Vector2 = fighter_positions.get(id, source.p)
			var end: Vector2 = fighter_positions.get(target_id, target.p)
			var elapsed: float = state.elapsed
			skill_effects.draw_link(start, end, elapsed, source.get("link_at", elapsed + Rules.LINK_INTERVAL))
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
			skill_effects.draw_anchor(player.anchor_pos, player.anchor_left, player.levels[Rules.F])
		if player.windup > 0.0:
			var slot: int = player.windup_slot
			var charge_color: Color = Rules.SLOTS[slot].color
			var duration := Rules.cast_delay(slot, player.choices[slot])
			var progress := clampf(1.0 - player.windup / duration, 0.0, 1.0)
			var aim: Vector2 = player.windup_aim
			var skill_id: String = Rules.skill(slot, player.choices[slot]).id
			if skill_id == "repel":
				var radius: float = Rules.AREA_RADII.repel + 5.0 * (player.levels[slot] - 1)
				skill_effects.draw_repel_warning(point, radius, progress)
			else:
				draw_dashed_line(point + aim * 23.0, point + aim * 130.0, charge_color, 2.5, 8.0)
				if skill_id == "windup":
					skill_effects.draw_charge(point, aim, progress)
			draw_arc(point, 25.0, -PI * 0.5, -PI * 0.5 + TAU * progress,
				22, charge_color, 2.1, true)
		var outside: bool = Rules.square_extent(player.p) > half_side
		if outside:
			draw_circle(point, 26.0 + sin(clock * 13.0) * 2.0, Color("#ff8a68"), false, 2.0, true)
		if tackle_trails.has(id):
			draw_tackle_trail(point, tackle_trails[id], view)
		if player.gear_time > 0.0:
			draw_circle(point, 32.0, Rules.SLOTS[Rules.GEAR].color, false, 2.1, true)
		skill_effects.draw_fighter_fx(point, player, fighter_motion.get(id, Vector2.ZERO), outside)
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
					player.walk, fighter_steps.get(id, 0.0), view, 0.52 if own else 1.0)
				draw_tag(point + offset, player, decoy_tint)
		draw_fighter(point, facing, tint, player.guard, player.flash,
			player.walk, fighter_steps.get(id, 0.0), view,
			0.42 + sin(clock * 11.0) * 0.08 if player.cloak > 0.0 else 1.0)
		if view != null and player.windup <= 0.0 and clock - view.fire_clock < CombatView.MUZZLE_TIME:
			draw_muzzle(point, player.fire_aim, view)
		draw_tag(point, player, tint)
	for fx: Dictionary in state.effects:
		var progress := clampf(1.0 - fx.left / fx.duration, 0.0, 1.0)
		var cue: int = fx.get("cue", Rules.Cue.HIT if fx.damage > 0 else -1)
		var vfx: int = fx.get("vfx", Rules.Vfx.NONE)
		if vfx in [Rules.Vfx.GRAVITY, Rules.Vfx.MARK, Rules.Vfx.REPEL, Rules.Vfx.FISSURE] or (
				vfx == Rules.Vfx.SCATTER and fx.damage == 0):
			continue
		var painted := skill_effects.draw_event(fx, progress)
		if vfx == Rules.Vfx.TACKLE_LAUNCH or vfx == Rules.Vfx.TACKLE_HIT:
			draw_tackle_flash(fx, progress, vfx == Rules.Vfx.TACKLE_HIT)
		if cue == Rules.Cue.HIT or cue == Rules.Cue.CLASH:
			draw_impact(fx, progress, cue == Rules.Cue.CLASH)
		elif not painted and vfx != Rules.Vfx.TACKLE_LAUNCH:
			draw_circle(fx.p, lerpf(5.0, fx.size, progress), Color(fx.color, (1.0 - progress) * 0.85), false, 2.3, true)
		var heal: int = fx.get("value", 0) if vfx == Rules.Vfx.REPAIR else 0
		if fx.damage > 0 or heal > 0:
			var text := "+%d" % heal if heal > 0 else "−%d" % fx.damage
			var color := Color("#bdffa3") if heal > 0 else AMBER.lightened(0.27)
			draw_string(ThemeDB.fallback_font, fx.p + Vector2(23, 52 - progress * 15), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(color, clampf(1.5 - progress, 0.0, 1.0)))
	var local: Dictionary = state.players.get(own_id, {})
	if phase == Match.FIGHT and local.get("alive", false):
		if COMBAT_VIEW.has_point(get_global_mouse_position()):
			var target := world_target()
			if preview_slot >= 0 and Match.can_cast(local, preview_slot):
				draw_cast_preview(local, target)
			draw_circle(target, 7.0, Color(MINT, 0.75), false, 1.3, true)
			for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
				var direction := Vector2.from_angle(angle)
				draw_line(target + direction * 8.0, target + direction * 12.0, MINT, 1.0, true)
	draw_opponent_arrows()


func draw_cast_preview(player: Dictionary, target: Vector2) -> void:
	var origin: Vector2 = player.p
	var offset := (target - origin).clamp(-Match.AIM_REACH, Match.AIM_REACH)
	var aim := offset.normalized() if offset.length_squared() > 4.0 else player.aim as Vector2
	if aim.is_zero_approx():
		return
	var skill := Rules.skill(preview_slot, player.choices[preview_slot])
	var tint: Color = Rules.SLOTS[preview_slot].color
	if skill.has("shot") and skill.id not in ["scatter", "repeater"]:
		draw_projectile_preview(player, origin, aim, skill.shot, tint)
		return
	var radius: float = Rules.AREA_RADII[skill.id]
	if skill.id not in ["scatter", "repeater"]:
		radius += 5.0 * (player.levels[preview_slot] - 1)
	if skill.id == "fissure":
		for index in range(1, 4):
			draw_aim_area(origin + aim * Rules.FISSURE_STEP * index, radius, tint)
		return
	var center := origin if skill.id == "repel" else Match.cast_aim_point(origin, offset, skill.id)
	draw_aim_area(center, radius, tint)
	if skill.id == "scatter":
		for spoke in range(4):
			var ray := aim.rotated(spoke * PI * 0.5)
			draw_dashed_line(center + ray * 18.0, center + ray * 105.0, tint, 1.8, 8.0)
	elif skill.id == "repeater":
		draw_dashed_line(center, center + aim * 120.0, tint, 2.0, 8.0)


func draw_aim_area(center: Vector2, radius: float, tint: Color) -> void:
	draw_circle(center, radius, Color(tint, 0.17), true, -1.0, true)
	draw_circle(center, radius, Color(tint, 0.88), false, 2.0, true)


func draw_projectile_preview(player: Dictionary, origin: Vector2, heading: Vector2, shot: Dictionary, tint: Color) -> void:
	var edge := Match.MAP_EDGE
	var start := (origin + heading * 20.0).clamp(-edge, edge)
	var curve: float = shot.get("curve", 0.0)
	if curve > 0.0:
		var points := PackedVector2Array([start])
		var segment_time := Rules.CURVE_TIME / 24.0
		var step: float = shot.speed * Rules.PROJECTILE_SPEED_SCALE * Rules.equipment_factor(player, "shot_speed") * segment_time
		for index in range(24):
			var next_heading := heading.rotated(-curve * segment_time)
			var direction := heading.slerp(next_heading, 0.5)
			var distance := Match.map_exit_time(start, direction)
			start += direction * minf(step, distance)
			points.append(start)
			if distance <= step:
				break
			heading = next_heading
		draw_polyline(points, Color(tint, 0.21), shot.size * 2.0, true)
		draw_polyline(points, Color(tint, 0.85), 2.0, true)
	var distance := Match.map_exit_time(start, heading)
	var turn_distance: float = shot.get("turn_distance", INF)
	var finish := start + heading * minf(distance, turn_distance)
	draw_line(start, finish, Color(tint, 0.21), shot.size * 2.0, true)
	draw_dashed_line(start, finish, Color(tint, 0.85), 2.0, 8.0)
	if turn_distance < distance:
		draw_circle(finish, 6.0, tint, false, 2.0, true)
		var returned := start - heading * Match.map_exit_time(start, -heading)
		draw_dashed_line(start, returned, Color(tint, 0.46), 2.0, 8.0)


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
	if shot.slot == Rules.BASIC:
		draw_set_transform(point, direction.angle())
		draw_texture_rect(pulse_texture, Rect2(-36, -12, 44, 24), false)
		draw_set_transform(Vector2.ZERO)
	elif skill_effects.draw_shot(shot.get("vfx", Rules.Vfx.NONE), point, direction, radius, shot.get("visual_step", 0)):
		return
	elif shot.style == Rules.BOLT:
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


func make_pulse_texture() -> Texture2D:
	var sprite := Image.create_empty(128, 40, false, Image.FORMAT_RGBA8)
	var teal := Color("#42dbca")
	var core := Color("#effff9")
	for x in range(sprite.get_width()):
		var along := float(x) / (sprite.get_width() - 1)
		var envelope := smoothstep(0.0, 0.80, along) * (1.0 - smoothstep(0.82, 0.99, along))
		var width := lerpf(0.04, 0.29, smoothstep(0.26, 0.83, along))
		var turbulence := sin(along * 33.0) * 0.05 * (1.0 - along)
		for y in range(sprite.get_height()):
			var cross := float(y) / (sprite.get_height() - 1) * 2.0 - 1.0
			var distance := absf(cross - turbulence)
			var hot := envelope * exp(-pow(distance / width, 2.0))
			var halo := envelope * exp(-pow(distance / (width * 2.1), 2.0))
			var filament := exp(-pow((distance - width * 1.35) / 0.06, 2.0))
			filament *= pow(0.5 + 0.5 * sin(along * 52.0 + cross * 6.0), 3.0) * envelope
			var alpha := clampf(hot * 1.35 + halo * 0.39 + filament * 0.28, 0.0, 1.0)
			sprite.set_pixel(x, y, Color(teal.lerp(core, smoothstep(0.24, 0.9, hot)), alpha))
	return ImageTexture.create_from_image(sprite)


func make_gravity_texture() -> Texture2D:
	var sprite := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	var darkness := Color("#090612")
	var energy := Color("#ad5cc3")
	for y in range(sprite.get_height()):
		for x in range(sprite.get_width()):
			var offset := (Vector2(x, y) + Vector2(0.5, 0.5)) / 64.0 - Vector2.ONE
			var radius := offset.length()
			if radius >= 1.0:
				continue
			var angle := offset.angle()
			var phase := angle * 4.0 + log(maxf(0.035, radius)) * 8.0
			var strands := pow(0.5 + 0.5 * sin(phase + sin(angle * 7.0 + radius * 34.0) * 0.58), 3.5)
			var rim_radius := 0.66 + 0.055 * sin(angle * 5.0) + 0.026 * sin(angle * 13.0)
			var rim := exp(-pow((radius - rim_radius) / 0.041, 2.0))
			var inner := smoothstep(0.17, 0.36, radius)
			var outer := 1.0 - smoothstep(0.69, 1.0, radius)
			var light := (strands * 0.53 + rim * (0.24 + strands * 0.52)) * inner * outer
			var alpha := clampf(1.0 - smoothstep(0.42, 0.95, radius) + light * 0.62, 0.0, 1.0)
			var color := darkness.lerp(energy, light).lerp(GRAVITY_TINT, smoothstep(0.53, 1.0, light))
			sprite.set_pixel(x, y, Color(color, alpha))
	return ImageTexture.create_from_image(sprite)


func draw_gravity_cracks(point: Vector2, radius: float, intensity: float) -> void:
	for index in range(7):
		var angle := index * TAU / 7.0 + sin(index * 5.9) * 0.21
		var ray := Vector2.from_angle(angle)
		var kink := ray.orthogonal() * radius * sin(index * 4.7) * 0.13
		var joint := point + ray * radius * 0.48 + kink
		var edge := radius * lerpf(0.68, 0.96, fposmod(index * 0.38 + 0.26, 1.0))
		var crack := PackedVector2Array([point + ray * radius * 0.08, point + ray * radius * 0.30,
			joint, point + ray * edge + kink * 0.25])
		draw_polyline(crack, Color("#090915", intensity * 0.91), 3.5, true)
		draw_polyline(crack, Color(GRAVITY_TINT, intensity * 0.63), 1.0, true)
		draw_line(joint, joint + ray.rotated(0.78 * signf(kink.dot(ray.orthogonal()))) * radius * 0.22,
			Color(GRAVITY_TINT, intensity * 0.32), 0.9, true)


func draw_gravity_collapse(point: Vector2, radius: float, progress: float) -> void:
	var fade := 1.0 - smoothstep(0.42, 1.0, progress)
	draw_gravity_cracks(point, radius, fade * 0.92)
	var disk := radius * lerpf(0.98, 0.37, pow(progress, 1.65))
	draw_set_transform(point, progress * 3.4)
	draw_texture_rect(gravity_texture, Rect2(-disk, -disk, disk * 2.0, disk * 2.0),
		false, Color(Color.WHITE, fade))
	draw_set_transform(Vector2.ZERO)
	for index in range(18):
		var phase := clampf((progress - fposmod(index * 0.31, 1.0) * 0.16) / 0.84, 0.0, 1.0)
		var angle := index * 2.4 + phase * 2.6
		var distance := radius * lerpf(0.56, 0.97, fposmod(index * 0.618 + 0.31, 1.0))
		var travel := Vector2.from_angle(angle) * distance * lerpf(1.0, 0.06, phase * phase)
		var fragment := point + travel
		var ray := Vector2.from_angle(angle + phase * 4.1)
		if index % 3 == 0:
			var shard := radius * (0.060 + 0.018 * sin(index * 2.1)) * (1.0 - phase * 0.62)
			var side := ray.orthogonal()
			var lift := Vector2(0.0, -sin(phase * PI) * radius * 0.15)
			var top := fragment + lift
			draw_colored_polygon(PackedVector2Array([top + ray * shard * 1.4, top + side * shard,
				top - ray * shard, top - side * shard * 0.72]), Color("#252334", fade))
			draw_colored_polygon(PackedVector2Array([top + ray * shard * 1.4, top + side * shard,
				top - ray * shard]), Color("#8b6a9a", fade * 0.90))
		else:
			var tail := point + travel.rotated(-0.13) * 1.03
			draw_line(tail, fragment, Color(GRAVITY_TINT.lightened(0.32), fade * (0.42 + phase * 0.52)),
				1.1, true)


func draw_tackle_trail(point: Vector2, trail: PackedVector2Array, view: CombatView) -> void:
	var travel := point - trail[1]
	var stretch := clampf(travel.length() / 38.0, 0.0, 1.0)
	if stretch < 0.09:
		return
	var direction := travel.normalized()
	var side := direction.orthogonal()
	if view != null:
		var size := Vector2.ONE * CombatView.MODEL_SIZE
		draw_texture_rect(view.get_texture(), Rect2(trail[1] - size * 0.5, size), false, Color(TACKLE_TINT, 0.16 * stretch))
		draw_texture_rect(view.get_texture(), Rect2(trail[0] - size * 0.5, size), false, Color(TACKLE_TINT, 0.29 * stretch))
	for index in range(6):
		var shift := fposmod(index * 0.618, 1.0)
		var lane := (8.0 + shift * 13.0) * (1.0 if index % 2 == 0 else -1.0)
		var point_on_trail := point.lerp(trail[1], 0.12 + shift * 0.85) + side * lane
		var flicker := 0.73 + 0.27 * sin(clock * 66.0 + index * 3.3)
		var length := (18.0 + shift * 20.0) * stretch
		draw_set_transform(point_on_trail, direction.angle())
		draw_texture_rect(pulse_texture, Rect2(-length, -3.8, length + 3.0, 7.6), false,
			Color("#b0ddff", flicker * stretch * (1.0 - shift * 0.52)))
		draw_set_transform(Vector2.ZERO)


func draw_tackle_flash(fx: Dictionary, progress: float, impact: bool) -> void:
	var direction: Vector2 = fx.get("direction", Vector2.ZERO)
	var origin: Vector2 = fx.p - direction * Rules.BODY_RADIUS * (0.72 if impact else 1.0)
	var flash := 1.0 - smoothstep(0.03, 0.57, progress)
	var fade := 1.0 - progress
	var size := 25.0 if impact else 17.0
	draw_set_transform(origin, direction.angle())
	draw_texture_rect(glow_texture, Rect2(-size, -size * 0.62, size * 2.0, size * 1.24),
		false, Color(TACKLE_TINT, flash * 0.91))
	draw_texture_rect(glow_texture, Rect2(-size * 0.72, -3.5, size * 1.44, 7.0),
		false, Color(Color.WHITE, flash))
	draw_set_transform(Vector2.ZERO)
	if not impact:
		for index in range(4):
			var ray := -direction.rotated((index - 1.5) * 0.51)
			var point := origin + ray * (4.0 + progress * (12.0 + index * 3.0))
			var dust := Vector2.ONE * (6.0 + progress * 10.0)
			draw_texture_rect(glow_texture, Rect2(point - dust, dust * 2.0), false,
				Color("#a3b6c5", fade * fade * 0.27))


func draw_impact(fx: Dictionary, progress: float, clash: bool) -> void:
	var direction: Vector2 = fx.get("direction", Vector2.ZERO)
	var point: Vector2 = fx.p if clash else fx.p - direction * Rules.BODY_RADIUS * 0.72
	var tint := Color("#95f5ff") if clash else Color("#ffb473")
	var flash := 1.0 - smoothstep(0.04, 0.63, progress)
	var fade := 1.0 - progress
	var radius := lerpf(12.0, 24.0 if clash else 29.0, progress)
	draw_texture_rect(glow_texture, Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0),
		false, Color(tint, flash * 0.88))
	draw_texture_rect(glow_texture, Rect2(point - Vector2(6, 6), Vector2(12, 12)),
		false, Color(Color.WHITE, flash))
	for index in range(12 if clash else 10):
		var jitter := fposmod(index * 0.618, 1.0)
		var bearing := -direction
		if direction.is_zero_approx():
			bearing = Vector2.from_angle(index * 2.4)
		elif clash:
			bearing = direction.orthogonal() * (1.0 if index % 2 == 0 else -1.0)
		var ray := bearing.rotated(lerpf(-1.06, 1.06, jitter))
		var distance := lerpf(12.0, 37.0 if clash else 48.0, fposmod(index * 0.382 + 0.31, 1.0))
		var tip := point + ray * distance * (1.0 - fade * fade)
		var tail := tip - ray * minf(tip.distance_to(point), (3.0 + jitter * 8.0) * fade)
		var heat := tint.lerp(Color("#fff7e1"), fade * fade * (0.75 if clash else 0.55))
		draw_line(tail, tip, Color(heat, fade * 0.9), (1.0 + jitter * 1.6) * fade, true)
		if not clash and index % 3 == 0:
			var chip := tip - ray * 4.0
			var edge := ray.orthogonal() * fade * 2.3
			draw_colored_polygon(PackedVector2Array([chip + ray * 3.0, chip - edge,
				chip - ray * 2.0 + edge]), Color(tint.darkened(0.25), fade))


func draw_fighter(point: Vector2, facing: Vector2, tint: Color, guard: float, flash: float,
		walk := Vector2.ZERO, step := 0.0, view: CombatView = null, opacity := 1.0) -> void:
	if view != null:
		draw_texture_rect(glow_texture, Rect2(point + Vector2(-22, 4), Vector2(44, 24)),
			false, Color("#030810", 0.76 * opacity))
		var size := Vector2.ONE * CombatView.MODEL_SIZE
		var modulation := Color.WHITE.lerp(Color("#ffa7a4"), 0.55) if flash > 0.0 else Color.WHITE
		draw_texture_rect(view.get_texture(), Rect2(point - size * 0.5, size), false, Color(modulation, opacity))
	else:
		draw_flat_robot(point, facing, tint, flash, walk, step)
	if guard > 0.0:
		skill_effects.draw_guard(point, flash)


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
