extends RefCounted

const Rules = preload("res://rules.gd")
const Vfx = Rules.Vfx
const WHITE := Color("#f4fcff")
const STEEL := Color("#273344")
const BLUE := Color("#83cdff")
const GOLD := Color("#ffdf82")
const AMBER := Color("#ffad72")

var canvas: Node2D
var glow: Texture2D
var plume: Texture2D
var clock := 0.0


func _init(surface: Node2D, glow_texture: Texture2D, plume_texture: Texture2D) -> void:
	canvas = surface
	glow = glow_texture
	plume = plume_texture


func light(point: Vector2, radius: float, tint: Color, alpha: float) -> void:
	var extent := Vector2.ONE * radius
	canvas.draw_texture_rect(glow, Rect2(point - extent, extent * 2.0), false, Color(tint, alpha))


func streak(point: Vector2, heading: Vector2, length: float, width: float, tint: Color, alpha: float) -> void:
	canvas.draw_set_transform(point, heading.angle())
	canvas.draw_texture_rect(plume, Rect2(-length, -width * 0.5, length * 1.25, width), false, Color(tint, alpha))
	canvas.draw_set_transform(Vector2.ZERO)


func plate(point: Vector2, heading: Vector2, length: float, width: float, tint: Color) -> void:
	var side := heading.orthogonal()
	canvas.draw_colored_polygon(PackedVector2Array([point + heading * length * 0.62,
		point + side * width, point - heading * length, point - side * width]), tint)


func sparks(point: Vector2, heading: Vector2, progress: float, reach: float, tint: Color,
		count: int, spread: float = TAU) -> void:
	var fade := 1.0 - progress
	for index in range(count):
		var bias := fposmod(index * 0.618 + 0.13, 1.0)
		var ray := heading.rotated((bias - 0.5) * spread)
		var distance := reach * lerpf(0.33, 1.0, fposmod(index * 0.73 + 0.31, 1.0))
		var tip := point + ray * distance * (1.0 - fade * fade)
		var end := tip - ray * minf(distance * (1.0 - fade * fade), (3.0 + 5.0 * bias) * fade)
		canvas.draw_line(end, tip, Color(tint.lerp(WHITE, fade * fade * 0.45), fade), 1.0 + bias, true)


func draw_shot(kind: int, point: Vector2, forward: Vector2, radius: float, stage: int) -> bool:
	var side := forward.orthogonal()
	var angle := forward.angle()
	match kind:
		Vfx.WAVE:
			light(point, radius * 1.35, AMBER, 0.42)
			for layer in range(3):
				var crest := point - forward * (layer * 4.0)
				canvas.draw_arc(crest, radius - layer * 2.5, angle - 1.60, angle + 1.60,
					24, Color(AMBER.lerp(WHITE, 0.64), 0.84 - layer * 0.28), 2.8 - layer * 0.4, true)
			for index in range(5):
				var arc := angle + (index - 2.0) * 0.62
				var mote := point + Vector2.from_angle(arc) * (radius - fposmod(clock * 29.0 + index * 3.6, 7.0))
				light(mote, 3.4, AMBER, 0.73)
		Vfx.LANCE:
			streak(point, forward, 57.0, 8.0, AMBER, 0.86)
			plate(point, forward, radius * 2.8, radius * 0.42, WHITE)
		Vfx.RICOCHET:
			var energy := 1.0 - stage * 0.22
			streak(point, forward, 25.0, 12.0, AMBER, energy)
			var spin := Vector2.from_angle(clock * 11.0)
			plate(point, spin, radius, radius * 0.75, Color("#e09a60"))
			plate(point, spin, radius * 0.66, radius * 0.45, Color(WHITE, energy))
		Vfx.DISC:
			var energy := 0.54 if stage == 1 else 0.94
			streak(point, forward, 22.0, 12.0, AMBER, energy)
			canvas.draw_circle(point, radius, STEEL, true, -1.0, true)
			for blade in range(3):
				var spin := clock * 18.0 + blade * TAU / 3.0
				canvas.draw_arc(point, radius, spin, spin + 1.20, 9, Color(AMBER.lerp(WHITE, 0.48), energy), 2.4, true)
			light(point, radius * 0.68, AMBER, energy)
		Vfx.CURVE:
			var path := PackedVector2Array()
			for index in range(6, -1, -1):
				var length := index * 5.4
				path.append(point - forward * length - side * length * length * 0.011 * stage)
			canvas.draw_polyline(path, Color(AMBER, 0.30), 5.4, true)
			canvas.draw_polyline(path, Color("#ffd7b6"), 1.6, true)
			plate(point, forward, radius * 1.5, radius * 0.54, WHITE)
		Vfx.SEEKER:
			streak(point - forward * 4.0, forward, 22.0, 8.0, BLUE, 0.78)
			plate(point, forward, radius * 1.65, radius * 0.93, STEEL)
			plate(point, forward, radius * 1.38, radius * 0.48, Color("#f1b18b"))
			if stage > 0:
				for nozzle: float in [-1.0, 1.0]:
					streak(point - forward * 3.0 + side * nozzle * 3.0, forward - side * nozzle * 0.62,
						10.0, 5.5, BLUE, 0.70 + sin(clock * 57.0) * 0.22)
		Vfx.SNARE:
			streak(point, forward, 22.0, 11.0, GOLD, 0.68)
			plate(point, forward, radius * 1.3, radius * 0.62, STEEL)
			for arm: float in [-1.0, 1.0]:
				var tip := point + side * radius * arm
				canvas.draw_line(tip - forward * 6.0, tip + forward * 5.0, GOLD, 2.0, true)
		Vfx.LINK:
			streak(point, forward, 24.0, 11.0, BLUE, 0.86)
			plate(point, forward, radius, radius * 0.8, Color("#a7baff"))
			light(point + side * sin(clock * 32.0) * 2.8, radius, WHITE, 0.92)
		Vfx.SCATTER:
			streak(point, forward, 14.0, 8.0, Color("#a398ff"), 0.91)
			plate(point, forward, radius * 1.4, radius * 0.62, Color("#d6ccff"))
		Vfx.REPEATER:
			streak(point, forward, 18.0, 6.6, AMBER, 0.82)
			plate(point, forward, radius * 1.7, radius * 0.52, Color("#ffdb9b"))
		Vfx.HEAVY:
			streak(point, forward, 48.0, 30.0, Color("#f87576"), 0.77)
			light(point, radius * 1.34, Color("#ff736f"), 0.71)
			plate(point, forward, radius * 0.86, radius * 0.83, Color("#381f29"))
			for index in range(5):
				var fissure := Vector2.from_angle(index * TAU / 5.0 + sin(clock * 8.0) * 0.2)
				var end := point + fissure * radius * 0.66
				canvas.draw_polyline(PackedVector2Array([point, point.lerp(end, 0.52) + fissure.orthogonal() * 2.0, end]),
					Color("#ff9672"), 1.8, true)
			light(point, radius * 0.38, AMBER, 0.86)
		Vfx.RECOIL, Vfx.WINDUP:
			var charged := kind == Vfx.WINDUP
			var tint := Color("#cdb6ff") if charged else AMBER
			streak(point, forward, 48.0 if charged else 41.0, 18.0 if charged else 13.0, tint, 0.96)
			plate(point, forward, radius * 2.8, radius * 0.60, WHITE)
			if charged:
				for rail: float in [-1.0, 1.0]:
					var offset := side * rail * (5.0 + sin(clock * 39.0) * 1.2)
					streak(point + offset, forward, 33.0, 5.7, tint, 0.78)
		Vfx.SWAP:
			streak(point, forward, 23.0, 15.0, Color("#e882d9"), 0.71)
			for pole: float in [-1.0, 1.0]:
				var core := point + Vector2.from_angle(clock * 12.0) * radius * 0.54 * pole
				light(core, radius, Color("#f399e8"), 0.90)
				plate(core, forward, 4.0, 2.6, WHITE)
		Vfx.JAM:
			streak(point, forward, 24.0, 10.0, Color("#e77ba0"), 0.78)
			for index in range(3):
				var glitch := point - forward * index * 4.0 + side * sin(clock * 41.0 + index * 3.8) * index * 2.3
				canvas.draw_rect(Rect2(glitch - Vector2(3, 2), Vector2(6, 4)), Color("#ffb1c4", 0.92 - index * 0.26))
		_:
			return false
	return true


func draw_strike(strike: Dictionary, progress: float, tint: Color) -> bool:
	var kind: int = strike.get("vfx", Vfx.NONE)
	var point: Vector2 = strike.p
	var radius: float = strike.size
	match kind:
		Vfx.REPEL:
			draw_repel_warning(point, radius, 1.0)
		Vfx.MARK:
			light(point, radius, BLUE, 0.16 + progress * 0.23)
			canvas.draw_circle(point, radius, Color(tint, 0.88), false, 1.6, true)
			for index in range(6):
				var ray := Vector2.from_angle(index * TAU / 6.0 + clock * 1.8)
				light(point + ray * radius * (0.86 - progress * 0.62), 4.1, BLUE, 0.70)
		Vfx.FISSURE:
			light(point, radius, Color("#ed9c79"), 0.22 + progress * 0.18)
			canvas.draw_circle(point, radius, Color(tint, 0.82), false, 1.4, true)
			draw_cracks(point, radius * 0.81, progress * 0.65 + 0.23)
		Vfx.SCATTER:
			var aim := Vector2.from_angle(strike.angle)
			plate(point, aim, 10.0, 8.5, STEEL)
			light(point, 13.0, tint, 0.52 + progress * 0.40)
			for index in range(4):
				var ray := aim.rotated(index * PI * 0.5)
				var muzzle := point + ray * 11.0
				plate(muzzle, ray, 6.6, 4.2, Color("#777ca0"))
				canvas.draw_dashed_line(muzzle + ray * 6.0, point + ray * 65.0,
					Color(tint, 0.50 + progress * 0.32), 1.5, 5.0)
		Vfx.REPEATER:
			var aim := Vector2.from_angle(strike.angle)
			var side := aim.orthogonal()
			light(point, 20.0, tint, 0.32)
			plate(point, aim, 18.0, 12.0, STEEL)
			plate(point + aim * 4.0, aim, 17.0, 6.0, Color("#68788c"))
			light(point + aim * 14.0, 6.0, AMBER, progress * 0.87)
			canvas.draw_dashed_line(point + aim * 22.0, point + aim * 62.0, Color(tint, 0.67), 1.3, 5.0)
			for lamp in range(3):
				var led := point - aim * 9.0 + side * ((lamp - 1) * 6.0)
				light(led, 3.8, AMBER if lamp < strike.repeats else STEEL, 0.94)
		_:
			return false
	return true


func draw_repel_warning(point: Vector2, radius: float, progress: float) -> void:
	light(point, radius, BLUE, 0.18 + progress * 0.29)
	canvas.draw_circle(point, radius, Color(BLUE, 0.64 + progress * 0.29), false, 1.8, true)
	for index in range(8):
		var ray := Vector2.from_angle(index * TAU / 8.0)
		var grit := point + ray * radius * (0.91 - progress * 0.73)
		streak(grit, -ray, 9.0 + progress * 9.0, 5.0, BLUE, 0.33 + progress * 0.42)


func draw_cracks(point: Vector2, radius: float, alpha: float) -> void:
	for index in range(5):
		var ray := Vector2.from_angle(index * 2.4)
		var end := point + ray * radius * lerpf(0.56, 1.0, fposmod(index * 0.37 + 0.3, 1.0))
		var branch := point.lerp(end, 0.45) + ray.orthogonal() * 4.0
		var fissure := PackedVector2Array([point, branch, end, end + ray.orthogonal() * 3.0])
		canvas.draw_polyline(fissure, Color("#211b2b", alpha), 3.3, true)
		canvas.draw_polyline(fissure, Color(AMBER, alpha * 0.81), 1.0, true)


func draw_link(start: Vector2, end: Vector2, elapsed: float, next_tick: float) -> void:
	var side := start.direction_to(end).orthogonal()
	var arc := PackedVector2Array([start])
	for index in range(1, 9):
		var fraction := index / 9.0
		var jump := sin(clock * 45.0 + index * 8.7) * 4.3
		arc.append(start.lerp(end, fraction) + side * jump)
	arc.append(end)
	canvas.draw_polyline(arc, Color("#717aff", 0.35), 6.0, true)
	canvas.draw_polyline(arc, Color("#c1d4ff", 0.82), 1.4, true)
	var progress := 1.0 - clampf((next_tick - elapsed) / Rules.LINK_INTERVAL, 0.0, 1.0)
	light(start.lerp(end, progress), 12.0, BLUE, 0.72)


func draw_event(fx: Dictionary, progress: float) -> bool:
	var kind: int = fx.get("vfx", Vfx.NONE)
	var point: Vector2 = fx.p
	var size: float = fx.size
	var direction: Vector2 = fx.get("direction", Vector2.ZERO)
	var forward := Vector2.RIGHT if direction.is_zero_approx() else direction
	var fade := 1.0 - progress
	var flash := 1.0 - smoothstep(0.03, 0.57, progress)
	match kind:
		Vfx.MARK:
			light(point, size, BLUE, fade * 0.90)
			draw_lightning(point, flash)
			sparks(point, Vector2.RIGHT, progress, size, BLUE, 11)
		Vfx.REPEL:
			var radius := size * (1.0 - fade * fade)
			light(point, size, BLUE, flash * 0.48)
			canvas.draw_arc(point, maxf(1.0, radius), 0.0, TAU, 48, Color(BLUE, fade * 0.72), 3.2, true)
			for index in range(12):
				var ray := Vector2.from_angle(index * TAU / 12.0)
				var dust := point + ray * radius * (0.87 + sin(index * 4.0) * 0.12)
				light(dust, 7.0 + progress * 6.0, Color("#a9bacc"), fade * 0.45)
			sparks(point, Vector2.RIGHT, progress, size, BLUE, 10)
		Vfx.FISSURE:
			draw_cracks(point, size * 0.82, fade)
			light(point, size * 0.76, AMBER, flash * 0.82)
			for index in range(7):
				var ray := Vector2.from_angle(index * 2.4)
				var base := point + ray * (4.0 + size * progress * (0.42 + fposmod(index * 0.31, 1.0) * 0.5))
				var lifted := base - Vector2(0.0, sin(progress * PI) * (6.0 + index))
				plate(lifted, ray.rotated(progress * 4.2), 5.0, 3.3, Color("#927779", fade))
			sparks(point, Vector2.RIGHT, progress, size, AMBER, 8)
		Vfx.SCATTER:
			if fx.damage > 0:
				return false
			light(point, 24.0, Color("#bca9ff"), flash * 0.92)
			for index in range(4):
				var ray := forward.rotated(index * PI * 0.5)
				streak(point + ray * (10.0 + progress * 20.0), ray, 12.0, 8.0, Color("#cbb2ff"), fade)
		Vfx.LINK_TICK, Vfx.LINK_END, Vfx.LINK:
			light(point, 19.0, Color("#a3b8ff"), flash)
			sparks(point, -forward, progress, 26.0, BLUE, 6)
		Vfx.BOUNCE_TURN, Vfx.DISC_TURN, Vfx.REFLECT_HIT:
			var tint := GOLD if kind == Vfx.REFLECT_HIT else AMBER
			light(point, 17.0, tint, flash)
			streak(point + forward * 10.0, forward, 23.0, 10.0, tint, fade)
			sparks(point, forward, progress, 25.0, tint, 7, 2.9)
		Vfx.WAVE, Vfx.HEAVY, Vfx.LANCE:
			var weight := 1.33 if kind == Vfx.HEAVY else 1.0
			var contact := point - forward * Rules.BODY_RADIUS * 0.72
			light(contact, 17.0 * weight, AMBER, flash * 0.83)
			sparks(contact, forward, progress, 32.0 * weight, AMBER, 8, 1.55)
			if kind != Vfx.LANCE:
				for index in range(4):
					var ray := forward.rotated((index - 1.5) * 0.40)
					plate(contact + ray * progress * 34.0 * weight, ray.rotated(progress * 3.6),
						4.4 * weight, 2.9 * weight, Color("#be8574", fade))
		Vfx.MUZZLE, Vfx.REPEATER_FIRE:
			streak(point, forward, 18.0, 10.0, fx.color, flash * 0.84)
			light(point, 12.0, fx.color, flash)
		Vfx.WINDUP_BREAK:
			light(point, 15.0, Color("#d4baff"), flash * 0.68)
			sparks(point, -forward, progress, 28.0, Color("#c3a7ff"), 9, 2.5)
		Vfx.SWAP_PORTAL, Vfx.ANCHOR_RETURN:
			draw_portal(point, size, progress, Color("#ee91d4") if kind == Vfx.SWAP_PORTAL else GOLD)
		Vfx.REPAIR:
			for index in range(9):
				var ray := Vector2.from_angle(index * 2.4)
				var motes := point + ray * lerpf(size * 0.78, 5.0, progress) - Vector2(0.0, progress * 9.0)
				light(motes, 5.2, fx.color, fade * 0.83)
		Vfx.CLEANSE:
			light(point, 22.0, AMBER, flash * 0.58)
			sparks(point, Vector2.RIGHT, progress, size, AMBER, 13)
		Vfx.GUARD, Vfx.REFLECT, Vfx.ANCHOR, Vfx.SURGE, Vfx.SURGE_ACTIVE:
			light(point, size * 0.67, GOLD, flash * 0.68)
			if kind == Vfx.SURGE_ACTIVE:
				sparks(point, Vector2.RIGHT, progress, 31.0, GOLD, 9)
		Vfx.MIRROR, Vfx.MIRROR_BREAK, Vfx.CLOAK, Vfx.CLOAK_REVEAL:
			var tint := BLUE if kind in [Vfx.CLOAK, Vfx.CLOAK_REVEAL] else GOLD
			var reach := size * (0.38 if kind == Vfx.MIRROR else 1.0)
			light(point, 21.0, tint, flash * 0.69)
			sparks(point, forward, progress, reach, tint, 9)
		Vfx.CLOAK_HIT:
			var contact := point - forward * Rules.BODY_RADIUS * 0.72
			light(contact, 20.0, BLUE, flash * 0.94)
			sparks(contact, -forward, progress, 35.0, BLUE, 8, 1.8)
		Vfx.RECOIL:
			# The launch event uses the recoil direction; a tagged hit already has contact sparks.
			if fx.damage == 0:
				draw_thruster(point, forward, progress, AMBER, 22.0)
		Vfx.DASH, Vfx.RECOVER, Vfx.RECOVER_OUTSIDE, Vfx.DOUBLE, Vfx.DOUBLE_RECAST:
			var tint := Color("#acecff") if kind in [Vfx.RECOVER, Vfx.RECOVER_OUTSIDE] else BLUE
			var length := 42.0 if kind == Vfx.RECOVER_OUTSIDE else (27.0 if kind == Vfx.DOUBLE_RECAST else 21.0)
			draw_thruster(point, forward, progress, tint, length)
		_:
			return false
	return true


func draw_lightning(point: Vector2, flash: float) -> void:
	var bolt := PackedVector2Array([point - Vector2(13, 68), point - Vector2(18, 51),
		point - Vector2(2, 39), point - Vector2(10, 24), point + Vector2(4, -13), point])
	canvas.draw_polyline(bolt, Color(BLUE, flash * 0.45), 11.0, true)
	canvas.draw_polyline(bolt, Color(WHITE, flash), 3.3, true)


func draw_portal(point: Vector2, radius: float, progress: float, tint: Color) -> void:
	var fade := 1.0 - progress
	var span := radius * lerpf(0.65, 1.0, progress)
	light(point, span, tint, fade * 0.78)
	for index in range(3):
		var phase := index * TAU / 3.0 + progress * 3.5
		canvas.draw_arc(point, span * 0.64, phase, phase + 1.24, 12, Color(tint, fade), 2.2, true)
	sparks(point, Vector2.RIGHT, progress, span, tint, 9)


func draw_thruster(point: Vector2, direction: Vector2, progress: float, tint: Color, length: float) -> void:
	var fade := 1.0 - progress
	var exhaust := point - direction * (8.0 + progress * 10.0)
	streak(exhaust, direction, length, 14.0, tint, fade)
	for nozzle: float in [-1.0, 1.0]:
		var side := direction.orthogonal() * nozzle * (4.0 + progress * 9.0)
		var dust := exhaust - direction * (7.0 + progress * 16.0) + side
		light(dust, 7.0 + progress * 5.0, tint, fade * 0.35)
	sparks(exhaust, -direction, progress, length + 9.0, tint, 6, 1.4)


func draw_guard(point: Vector2, flash: float) -> void:
	light(point + Vector2(0, 9), 27.0, GOLD, 0.27 + flash * 1.7)
	for index in range(3):
		var ray := Vector2.from_angle(PI * 0.5 + index * TAU / 3.0)
		var foot := point + ray * 18.0
		plate(foot, ray, 5.6, 5.0, Color("#736b4b"))
		light(foot, 5.8, GOLD, 0.67 + flash * 1.5)
		canvas.draw_line(foot, foot + ray * (8.0 + flash * 35.0), Color(GOLD, 0.55 + flash * 2.3), 1.6, true)


func draw_anchor(point: Vector2, left: float, level: int) -> void:
	var level_time := 2.0 + (level - 1) * 0.20
	plate(point, Vector2.UP, 9.0, 9.0, STEEL)
	light(point, 18.0, GOLD, 0.60 + sin(clock * 17.0) * 0.25)
	canvas.draw_line(point + Vector2(0, 2), point - Vector2(0, 15), Color(GOLD, 0.82), 2.5, true)
	canvas.draw_arc(point, 15.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(left / level_time, 0.0, 1.0),
		22, Color(GOLD, 0.85), 1.7, true)


func draw_charge(point: Vector2, aim: Vector2, progress: float) -> void:
	var muzzle := point + aim * 19.0
	light(muzzle, 6.0 + progress * 17.0, Color("#ceaeff"), 0.45 + progress * 0.55)
	light(muzzle, 3.0 + progress * 5.0, WHITE, progress * 0.94)
	for index in range(4):
		var ray := aim.rotated(index * TAU / 4.0 + clock * (4.0 + progress * 5.0))
		light(muzzle + ray * (21.0 - progress * 12.0), 3.5, Color("#c3a4ff"), 0.80)


func draw_fighter_fx(point: Vector2, player: Dictionary, motion: Vector2, outside: bool) -> void:
	if player.root > 0.0:
		for side: float in [-1.0, 1.0]:
			var jaw := point + Vector2(side * 14.0, 12.0)
			plate(jaw, Vector2(-side, 0.0), 10.0, 6.6, STEEL)
			light(jaw + Vector2(-4.0 * side, -2.0), 7.0, AMBER, 0.80)
	if player.jam > 0.0:
		for index in range(4):
			var phase := clock * 12.0 + index * 3.66
			var glitch := point + Vector2(sin(phase) * 17.0, -11.0 + index * 7.0)
			canvas.draw_rect(Rect2(glitch, Vector2(4.0 + sin(phase * 2.0) * 2.0, 2.0)),
				Color("#f084a8", 0.66 + sin(phase * 3.0) * 0.28))
	if player.reflect > 0.0:
		light(point, 32.0, Color("#bbdfff"), 0.28)
		for index in range(5):
			var angle := index * TAU / 5.0 + clock * 1.9
			canvas.draw_arc(point, 25.0, angle, angle + 1.05, 12, Color("#c6ebff", 0.62), 2.0, true)
			light(point + Vector2.from_angle(angle) * 25.0, 4.0, GOLD, 0.84)
	if player.surge_wait > 0.0:
		light(point + Vector2(11.0, 12.0), 7.4, GOLD, 0.70 + sin(clock * 14.0) * 0.19)
	if player.step_left > 0.0:
		light(point + Vector2(0.0, 17.0), 9.0, BLUE, 0.74 + sin(clock * 26.0) * 0.18)
	if motion.length_squared() < 100.0:
		return
	var heading := motion.normalized()
	if player.get("propulsion", 0.0) > 0.0:
		var energy: float = clampf(player.propulsion / 0.22, 0.0, 1.0)
		var length := clampf(motion.length() * 0.073, 8.0, 44.0 if outside else 31.0)
		streak(point - heading * 9.0, heading, length, 13.0, BLUE, energy * 0.82)
	if player.surge_left > 0.0:
		var aft := point - heading * (12.0 + fposmod(clock * 73.0, 14.0))
		streak(aft, heading, 17.0, 6.0, GOLD, 0.79)
