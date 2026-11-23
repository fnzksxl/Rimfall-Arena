extends Control

var skill_id := ""
var tint := Color.WHITE


func show_skill(id: String, color: Color) -> void:
	if skill_id == id and tint == color:
		return
	skill_id = id
	tint = color
	queue_redraw()


func stroke(points: Array, width := 2.6) -> void:
	draw_polyline(PackedVector2Array(points), tint, width, true)


func arrow(origin: Vector2, tip: Vector2) -> void:
	var direction := origin.direction_to(tip)
	var back := tip - direction * 8.0
	var side := direction.orthogonal() * 5.0
	draw_line(origin, tip, tint, 2.6, true)
	stroke([back + side, tip, back - side])


func _draw() -> void:
	draw_set_transform(size * 0.5)
	match skill_id:
		"wave":
			for offset in [-9, 0, 9]:
				draw_arc(Vector2(offset - 10, 0), 16, -0.88, 0.88, 18, tint, 2.4, true)
		"lance":
			arrow(Vector2(-15, 12), Vector2(15, -12))
			draw_line(Vector2(-15, 4), Vector2(-6, -3), tint, 2.1, true)
		"ricochet":
			stroke([Vector2(-17, 10), Vector2(-6, -9), Vector2(4, 4)])
			arrow(Vector2(4, 4), Vector2(17, -11))
			draw_circle(Vector2(-6, -9), 3, tint, true, -1.0, true)
		"snare":
			draw_rect(Rect2(-15, -15, 30, 30), tint, false, 2.4)
			for sign_value in [-1, 1]:
				arrow(Vector2(sign_value * 12, 0), Vector2(sign_value * 4, 0))
		"link":
			stroke([Vector2(-14, 10), Vector2(-4, -2), Vector2(1, 3), Vector2(14, -10)])
			draw_circle(Vector2(-14, 10), 4, tint)
			draw_circle(Vector2(14, -10), 4, tint)
		"repeater":
			draw_rect(Rect2(-12, -10, 13, 20), tint, false, 2.4)
			for y in [-8, 0, 8]:
				draw_line(Vector2(4, y), Vector2(16, y), tint, 2.2, true)
		"swap":
			arrow(Vector2(-16, -7), Vector2(15, -7))
			arrow(Vector2(16, 7), Vector2(-15, 7))
		"jam":
			stroke([Vector2(-16, 3), Vector2(-7, -6), Vector2(-2, 3)])
			stroke([Vector2(2, -2), Vector2(8, 6), Vector2(16, -3)])
			draw_line(Vector2(-4, 13), Vector2(5, -13), tint, 2.4, true)
		"mirror":
			draw_circle(Vector2(-9, -6), 8, tint, false, 2)
			draw_circle(Vector2(9, -6), 8, tint, false, 2)
			draw_circle(Vector2(0, 8), 6, tint, false, 2)
		"cloak":
			draw_arc(Vector2.ZERO, 13, -0.4, 3.6, 28, tint, 2.2, true)
			draw_line(Vector2(-14, 10), Vector2(15, -10), tint, 2.4, true)
		"disc":
			draw_arc(Vector2.ZERO, 14.0, -2.65, 2.38, 28, tint, 2.6, true)
			stroke([Vector2(-16, 4), Vector2(-10, 9), Vector2(-3, 6)])
			draw_circle(Vector2.ZERO, 4, tint, false, 2.0, true)
		"curve":
			draw_arc(Vector2(-6, 10), 19, -1.60, 0.32, 24, tint, 2.5, true)
			var tip := Vector2(-6, 10) + Vector2.from_angle(-1.60) * 19
			draw_circle(tip, 3.4, tint, true, -1, true)
		"seeker":
			draw_circle(Vector2(8, -7), 7, tint, false, 1.9, true)
			stroke([Vector2(-16, 12), Vector2(-6, 9), Vector2(0, 0)])
			arrow(Vector2(0, 0), Vector2(8, -7))
		"mark":
			draw_circle(Vector2.ZERO, 12, tint, false, 2.6, true)
			for index in range(4):
				var axis := Vector2.from_angle(index * PI * 0.5)
				draw_line(axis * 8, axis * 17, tint, 2.1, true)
			draw_circle(Vector2.ZERO, 3.4, tint, true, -1.0, true)
		"repel":
			draw_circle(Vector2.ZERO, 6, tint, true, -1.0, true)
			draw_circle(Vector2.ZERO, 13, tint, false, 2.2, true)
			for index in range(4):
				var axis := Vector2.from_angle(index * PI * 0.5)
				draw_line(axis * 16, axis * 19, tint, 2.3, true)
		"fissure":
			stroke([Vector2(-16, 14), Vector2(-6, 5), Vector2(0, 8), Vector2(5, -6), Vector2(11, -4), Vector2(16, -15)])
			for point in [Vector2(-14, 8), Vector2(-3, 0), Vector2(10, -11)]:
				draw_circle(point, 2.8, tint, true, -1.0, true)
		"scatter":
			draw_circle(Vector2.ZERO, 6, tint, false, 2.2, true)
			for index in range(4):
				var ray := Vector2.from_angle(PI * 0.25 + index * PI * 0.5)
				draw_line(ray * 8, ray * 17, tint, 2.4, true)
				draw_circle(ray * 17, 2.3, tint, true, -1.0, true)
		"heavy":
			draw_circle(Vector2(4, 0), 12, tint, false, 2.7, true)
			draw_circle(Vector2(4, 0), 5, tint, true, -1.0, true)
			draw_line(Vector2(-18, -7), Vector2(-10, -7), tint, 2.3, true)
			draw_line(Vector2(-19, 6), Vector2(-11, 6), tint, 2.3, true)
		"gravity":
			for angle in [0.1, PI + 0.1]:
				draw_arc(Vector2.ZERO, 14.5, angle, angle + 2.3, 24, tint, 2.5, true)
				var tip := Vector2.from_angle(angle + 2.3) * 14.5
				arrow(tip, tip * 0.47)
			draw_circle(Vector2.ZERO, 2.8, tint, true, -1.0, true)
		"recoil":
			arrow(Vector2(-9, -6), Vector2(17, -6))
			arrow(Vector2(6, 8), Vector2(-16, 8))
		"windup":
			draw_arc(Vector2(-3, 0), 13, -PI * 0.5, PI * 1.03, 24, tint, 2.3, true)
			arrow(Vector2(-8, 0), Vector2(17, 0))
		"guard":
			stroke([Vector2(0, -16), Vector2(13, -10), Vector2(11, 6), Vector2(0, 16), Vector2(-11, 6), Vector2(-13, -10), Vector2(0, -16)])
			stroke([Vector2(-5, -1), Vector2(-1, 4), Vector2(6, -5)])
		"repair":
			draw_circle(Vector2.ZERO, 16, tint, false, 2.2, true)
			draw_line(Vector2(-8, 0), Vector2(8, 0), tint, 3.0, true)
			draw_line(Vector2(0, -8), Vector2(0, 8), tint, 3.0, true)
		"cleanse":
			stroke([Vector2(-3, -16), Vector2(1, -4), Vector2(13, 0), Vector2(1, 4),
				Vector2(-3, 16), Vector2(-7, 4), Vector2(-16, 0), Vector2(-7, -4), Vector2(-3, -16)])
			draw_circle(Vector2(13, -10), 2, tint, true, -1.0, true)
		"reflect":
			draw_line(Vector2(3, -17), Vector2(3, 17), tint, 2.6, true)
			draw_line(Vector2(-14, -12), Vector2(3, 0), tint, 2.0, true)
			arrow(Vector2(3, 0), Vector2(-14, 13))
		"anchor":
			draw_arc(Vector2.ZERO, 14, -PI * 0.5, PI, 24, tint, 2.4, true)
			arrow(Vector2(9, -14), Vector2(0, -14))
			draw_circle(Vector2.ZERO, 4, tint, true, -1.0, true)
		"surge":
			stroke([Vector2(2, -16), Vector2(-10, 2), Vector2(0, 2), Vector2(-2, 16), Vector2(12, -4), Vector2(2, -4), Vector2(2, -16)])
		"dash":
			for offset in [-7, 4]:
				stroke([Vector2(offset, -10), Vector2(offset + 9, 0), Vector2(offset, 10)])
			draw_line(Vector2(-17, 0), Vector2(-9, 0), tint, 2.2, true)
		"recover":
			stroke([Vector2(-15, 7), Vector2(-15, -8), Vector2(-6, -8)])
			arrow(Vector2(15, 8), Vector2(-8, 8))
			draw_line(Vector2(15, 8), Vector2(15, -8), tint, 2.6, true)
		"tackle":
			arrow(Vector2(-16, 0), Vector2(8, 0))
			for offset in [-10, 0, 10]:
				draw_line(Vector2(12, offset), Vector2(17, offset * 1.35), tint, 2.6, true)
		"double":
			arrow(Vector2(-15, 9), Vector2(-2, 1))
			arrow(Vector2(2, 0), Vector2(9, -14))
		"coil":
			stroke([Vector2(-17, 0), Vector2(-11, 0), Vector2(-8, -10), Vector2(-2, 10),
				Vector2(4, -10), Vector2(10, 10), Vector2(13, 0), Vector2(17, 0)])
		"capsule":
			draw_rect(Rect2(-15, -11, 30, 22), tint, false, 2.3)
			stroke([Vector2(-12, 0), Vector2(-5, 0), Vector2(-1, -6), Vector2(4, 6), Vector2(8, 0), Vector2(13, 0)], 2.1)
		"light":
			stroke([Vector2(-13, 13), Vector2(-7, 4), Vector2(3, -8), Vector2(16, -14), Vector2(11, -1),
				Vector2(3, 7), Vector2(-7, 4)])
		"heavy_frame":
			for offset in [-8, 0, 8]:
				stroke([Vector2(-15, offset - 2), Vector2(0, offset + 4), Vector2(15, offset - 2)], 2.5)
		"damper":
			stroke([Vector2(-12, -12), Vector2(12, -12)])
			stroke([Vector2(-12, 12), Vector2(12, 12)])
			stroke([Vector2(-7, -12), Vector2(8, -6), Vector2(-8, 0), Vector2(8, 6), Vector2(-7, 12)], 2.1)
		"mantle":
			stroke([Vector2(-6, -14), Vector2(-13, -6), Vector2(-16, 14), Vector2(16, 14), Vector2(13, -6), Vector2(6, -14)])
			stroke([Vector2(-5, 1), Vector2(5, 1)])
			stroke([Vector2(0, -4), Vector2(0, 6)])
		"warden":
			stroke([Vector2(-14, -11), Vector2(-6, -15), Vector2(0, -9), Vector2(6, -15), Vector2(14, -11),
				Vector2(10, 12), Vector2(-10, 12), Vector2(-14, -11)])
			stroke([Vector2(-5, 1), Vector2(5, 1)])
		"siphon":
			stroke([Vector2(-15, -10), Vector2(15, -10), Vector2(11, 4), Vector2(0, 13), Vector2(-11, 4), Vector2(-15, -10)])
			draw_circle(Vector2(-6, -2), 2.4, tint, true, -1.0, true)
			draw_circle(Vector2(6, -2), 2.4, tint, true, -1.0, true)
		"shield_cell":
			stroke([Vector2(0, -16), Vector2(13, -10), Vector2(11, 6), Vector2(0, 16), Vector2(-11, 6), Vector2(-13, -10), Vector2(0, -16)])
			stroke([Vector2(2, -8), Vector2(-4, 1), Vector2(3, 1), Vector2(-2, 8)])
