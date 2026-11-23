extends Node3D

const LEG_LENGTH := 0.49
const STANCE := 0.60

enum Look { ROBOT, ULTRON, IRON_MAN, VISION, SPIDER_MAN, WAR_MACHINE, BLACK_PANTHER }

@export var autoplay := true
@export var look := Look.ROBOT
@export var preview_attack := false

var pelvis: Node3D
var torso: Node3D
var hips: Array[Node3D] = []
var knees: Array[Node3D] = []
var ankles: Array[Node3D] = []
var shoulders: Array[Node3D] = []
var elbows: Array[Node3D] = []
var hands: Array[Node3D] = []
var head: Node3D
var cannon: Node3D
var cannon_tip: Node3D
var time := 0.0

var armor := material(Color("#424e59"), 0.65)
var frame := material(Color("#1b232e"), 0.42)
var accent := material(Color("#63d8ba"), 0.32)
var visor := material(Color("#ff514b"), 0.0, true)


func _ready() -> void:
	match look:
		Look.ULTRON:
			armor = material(Color("#a2a7af"), 0.72)
			accent = material(Color("#783039"), 0.4)
		Look.IRON_MAN:
			armor = material(Color("#9a1725"), 0.58)
			frame = material(Color("#541820"), 0.4)
			accent = material(Color("#dca74d"), 0.52)
			visor = material(Color("#9cecff"), 0.0, true)
		Look.VISION:
			armor = material(Color("#397d68"), 0.32)
			frame = material(Color("#204c47"), 0.28)
			accent = material(Color("#d8b258"), 0.35)
			visor = material(Color("#edf5df"), 0.0, true)
		Look.SPIDER_MAN:
			armor = material(Color("#b82232"), 0.12)
			frame = material(Color("#122c53"), 0.12)
			accent = frame
			visor = material(Color("#eef6ff"), 0.0, true)
		Look.WAR_MACHINE:
			armor = material(Color("#555b65"), 0.70)
			frame = material(Color("#222732"), 0.50)
			accent = material(Color("#8c969b"), 0.63)
		Look.BLACK_PANTHER:
			armor = material(Color("#292438"), 0.24)
			frame = material(Color("#171421"), 0.14)
			accent = material(Color("#a89dbb"), 0.65)
			visor = material(Color("#c79dff"), 0.0, true)
	pelvis = joint(self, Vector3(0, 1.03, 0))
	part(pelvis, Vector3.ZERO, Vector3(0.37, 0.21, 0.23), frame)
	torso = joint(pelvis, Vector3(0, 0.13, 0))
	part(torso, Vector3(0, 0.13, 0), Vector3(0.28, 0.28, 0.20), frame)
	part(torso, Vector3(0, 0.32, 0.02), Vector3(0.46, 0.29, 0.27), armor)
	part(torso, Vector3(0, 0.48, 0), Vector3(0.12, 0.13, 0.12), frame)
	head = joint(torso, Vector3(0, 0.65, 0.018))
	build_face_and_chest(head)
	for side: float in [-1.0, 1.0]:
		build_limbs(side)
	pose_walk(0.0)


func build_face_and_chest(head: Node3D) -> void:
	part(head, Vector3.ZERO, Vector3(0.27, 0.29, 0.24), armor)
	match look:
		Look.IRON_MAN, Look.WAR_MACHINE:
			part(head, Vector3(0, -0.005, 0.12), Vector3(0.215, 0.23, 0.061), accent)
			part(head, Vector3(0, -0.071, 0.153), Vector3(0.11, 0.013, 0.009), frame)
			var core := MeshInstance3D.new()
			var disk := CylinderMesh.new()
			disk.top_radius = 0.048
			disk.bottom_radius = 0.048
			disk.height = 0.023
			core.mesh = disk
			core.material_override = visor
			torso.add_child(core)
			core.position = Vector3(0, 0.31, 0.165)
			core.rotation.x = PI / 2.0
			if look == Look.WAR_MACHINE:
				cannon = joint(torso, Vector3(0.22, 0.46, -0.055))
				part(cannon, Vector3(0, 0, 0.09), Vector3(0.107, 0.109, 0.26), frame)
				part(cannon, Vector3(0, 0, 0.237), Vector3(0.072, 0.072, 0.085), accent)
				cannon_tip = joint(cannon, Vector3(0, 0, 0.282))
		Look.VISION:
			var burgundy := material(Color("#9b3957"), 0.21)
			part(head, Vector3(0, -0.017, 0.116), Vector3(0.226, 0.248, 0.051), burgundy)
			var gem := part(head, Vector3(0, 0.089, 0.145), Vector3(0.046, 0.046, 0.022), accent)
			gem.rotation.z = PI / 4.0
			for side: float in [-1.0, 1.0]:
				part(torso, Vector3(side * 0.14, 0.36, 0.158), Vector3(0.047, 0.114, 0.023), accent)
		Look.SPIDER_MAN:
			part(head, Vector3(0, 0, 0.126), Vector3(0.008, 0.27, 0.008), frame)
			for row: float in [-0.078, 0.089]:
				part(head, Vector3(0, row, 0.126), Vector3(0.25, 0.008, 0.008), frame)
			part(torso, Vector3(0, 0.31, 0.164), Vector3(0.038, 0.082, 0.018), frame)
			for side: float in [-1.0, 1.0]:
				for row: float in [-1.0, 1.0]:
					var leg := part(torso, Vector3(side * 0.035, 0.31 + row * 0.025, 0.165),
						Vector3(0.058, 0.012, 0.018), frame)
					leg.rotation.z = side * row * 0.62
		Look.BLACK_PANTHER:
			part(head, Vector3(0, -0.067, 0.119), Vector3(0.195, 0.115, 0.047), frame)
			for side: float in [-1.0, 1.0]:
				var ear := part(head, Vector3(side * 0.099, 0.146, -0.025),
					Vector3(0.053, 0.101, 0.069), armor)
				ear.rotation.z = -side * 0.25
			for index in range(-2, 3):
				var tooth := part(torso, Vector3(index * 0.064, 0.405 + absf(index) * 0.024, 0.16),
					Vector3(0.029, 0.052, 0.015), accent)
				tooth.rotation.z = index * 0.17
		_:
			part(head, Vector3(0, -0.069, 0.116), Vector3(0.18, 0.12, 0.075), frame)
			part(torso, Vector3(0, 0.29, 0.157), Vector3(0.17, 0.065, 0.023), accent)
			if look == Look.ULTRON:
				part(head, Vector3(0, -0.078, 0.156), Vector3(0.15, 0.027, 0.009), visor)
	for side: float in [-1.0, 1.0]:
		var eye_size := Vector3(0.101, 0.029, 0.027)
		var eye_z := 0.145
		var tilt := 0.18
		if look in [Look.IRON_MAN, Look.WAR_MACHINE]:
			eye_z = 0.158
			tilt = 0.06
		elif look == Look.VISION:
			eye_size = Vector3(0.063, 0.017, 0.022)
		elif look == Look.BLACK_PANTHER:
			eye_size = Vector3(0.083, 0.021, 0.018)
			tilt = 0.31
		elif look == Look.SPIDER_MAN:
			eye_size = Vector3(0.075, 0.082, 0.025)
			tilt = 0.29
			var outline := part(head, Vector3(side * 0.067, 0.025, 0.127),
				eye_size + Vector3(0.024, 0.024, 0), frame)
			outline.rotation.z = side * tilt
		var eye := part(head, Vector3(side * 0.063, 0.025, eye_z), eye_size, visor)
		eye.rotation.z = side * tilt


func _process(delta: float) -> void:
	if autoplay:
		time = fposmod(time + delta, 2.30 if preview_attack else 1.04)
		if preview_attack and time >= 1.04:
			pose_attack((time - 1.04) / 1.26)
		else:
			pose_walk(time / 1.04)


func build_limbs(side: float) -> void:
	var hip := joint(pelvis, Vector3(side * 0.122, 0, 0))
	var knee := joint(hip, Vector3(0, -LEG_LENGTH, 0))
	var ankle := joint(knee, Vector3(0, -LEG_LENGTH, 0))
	hips.append(hip)
	knees.append(knee)
	ankles.append(ankle)
	part(hip, Vector3(0, -0.21, 0), Vector3(0.16, 0.42, 0.16), armor)
	part(knee, Vector3.ZERO, Vector3(0.16, 0.12, 0.17), frame)
	part(knee, Vector3(0, -0.19, 0.014), Vector3(0.145, 0.33, 0.15), armor)
	part(knee, Vector3(0, -0.414, 0), Vector3(0.086, 0.17, 0.085), frame)
	part(knee, Vector3(0, -0.23, 0.095), Vector3(0.06, 0.15, 0.022), accent)
	part(ankle, Vector3(0, -0.039, 0.042), Vector3(0.155, 0.095, 0.255), frame)
	part(ankle, Vector3(0, -0.013, 0.112), Vector3(0.148, 0.046, 0.104), armor)

	var shoulder := joint(torso, Vector3(side * 0.285, 0.37, 0))
	var elbow := joint(shoulder, Vector3(0, -0.29, 0))
	shoulders.append(shoulder)
	elbows.append(elbow)
	part(shoulder, Vector3.ZERO, Vector3(0.18, 0.15, 0.17), armor if look == Look.BLACK_PANTHER else accent)
	part(shoulder, Vector3(0, -0.145, 0), Vector3(0.125, 0.25, 0.126), armor)
	part(elbow, Vector3.ZERO, Vector3(0.113, 0.095, 0.11), frame)
	part(elbow, Vector3(0, -0.14, 0), Vector3(0.134, 0.24, 0.13), armor)
	part(elbow, Vector3(0, -0.285, 0), Vector3(0.105, 0.12, 0.11), frame)
	hands.append(joint(elbow, Vector3(0, -0.32, 0)))
	if look == Look.BLACK_PANTHER:
		for claw in range(-1, 2):
			part(elbow, Vector3(claw * 0.027, -0.349, 0.038),
				Vector3(0.012, 0.067, 0.015), accent)


func pose_walk(cycle: float, crouch := 0.0, stride := 1.0) -> void:
	var phase := cycle * TAU
	pelvis.position.y = 1.013 - cos(phase * 2.0) * 0.014 * stride - crouch
	torso.rotation.x = 0.0
	torso.rotation.y = sin(phase) * 0.09 * stride
	torso.rotation.z = sin(phase) * 0.035 * stride
	if cannon != null:
		cannon.position.z = -0.055
	for index in range(2):
		var step := fposmod(cycle + index * 0.5, 1.0)
		var foot_z := lerpf(0.24, -0.24, minf(step / STANCE, 1.0))
		var lift := 0.0
		if step > STANCE:
			var swing := (step - STANCE) / (1.0 - STANCE)
			foot_z = lerpf(-0.24, 0.24, smoothstep(0.0, 1.0, swing))
			lift = sin(swing * PI) * 0.14
		foot_z *= stride
		var down := pelvis.position.y - 0.087 - lift * stride
		var half_bend := acos(clampf(Vector2(down, foot_z).length() / (2.0 * LEG_LENGTH), 0.0, 1.0))
		hips[index].rotation.x = atan2(-foot_z, down) - half_bend
		knees[index].rotation.x = half_bend * 2.0
		ankles[index].rotation.x = -hips[index].rotation.x - knees[index].rotation.x
		shoulders[index].rotation.x = cos(step * TAU + 0.37) * 0.33 * stride
		shoulders[index].rotation.y = 0.0
		elbows[index].rotation.x = -0.23 - maxf(0.0, cos(step * TAU)) * 0.16


func pose_attack(progress: float, cycle := 0.0, stride := 1.0) -> void:
	var t := clampf(progress, 0.0, 1.0)
	var weight := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.64, 1.0, t))
	pose_walk(cycle, 0.045 * weight, stride)
	var release := smoothstep(0.26, 0.42, t)
	var reach := release * weight
	var windup := (1.0 - release) * weight
	torso.rotation.x = 0.13 * reach - 0.08 * windup
	match look:
		Look.IRON_MAN:
			aim_arm(1, weight, -0.76 - 0.87 * release, 0.06, -1.05 + 0.97 * release)
			aim_arm(0, weight, -0.30, 0.0, -0.88)
			torso.rotation.y += 0.20 * reach
		Look.VISION:
			aim_arm(0, weight, -0.50, 0.16, -0.53)
			aim_arm(1, weight, -0.50, -0.16, -0.53)
			torso.rotation.x = 0.23 * reach - 0.19 * windup
		Look.SPIDER_MAN:
			aim_arm(0, weight, -0.90 - 0.73 * release, -0.18, -1.16 + 1.06 * release)
			aim_arm(1, weight, -0.50, 0.20, -1.22)
			torso.rotation.y -= 0.27 * reach
			torso.rotation.z -= 0.15 * reach
		Look.WAR_MACHINE:
			aim_arm(0, weight, -0.62, 0.09, -0.96)
			aim_arm(1, weight, -0.41, -0.10, -0.84)
			cannon.position.z -= 0.075 * reach
			torso.rotation.x -= 0.28 * reach
		Look.BLACK_PANTHER:
			aim_arm(0, weight, -0.51, -0.17, -1.04)
			aim_arm(1, weight, 0.29 - 1.75 * release, 0.57 - 1.30 * release, -1.28 + 1.05 * release)
			torso.rotation.y += 0.48 * windup - 0.59 * reach
			torso.rotation.x += 0.25 * reach
		_:
			aim_arm(1, weight, 0.42 - 1.86 * release, -0.42 + 1.03 * release, -1.35 + 1.24 * release)
			aim_arm(0, weight, -0.55, -0.10, -1.16)
			torso.rotation.y += 0.55 * reach - 0.48 * windup


func aim_arm(index: int, weight: float, pitch: float, turn: float, bend: float) -> void:
	var shoulder := shoulders[index]
	shoulder.rotation.x = lerpf(shoulder.rotation.x, pitch, weight)
	shoulder.rotation.y = turn * weight
	elbows[index].rotation.x = lerpf(elbows[index].rotation.x, bend, weight)


func joint(parent: Node3D, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.position = at
	return pivot


func part(parent: Node3D, at: Vector3, size: Vector3, finish: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = finish
	parent.add_child(instance)
	instance.position = at
	return instance


func material(color: Color, metal: float, emit := false) -> StandardMaterial3D:
	var finish := StandardMaterial3D.new()
	finish.albedo_color = color
	finish.metallic = metal
	finish.roughness = 0.55
	finish.emission_enabled = emit
	finish.emission = color
	return finish
