extends Node3D

const LEG_LENGTH := 0.49
const STANCE := 0.60
const CHEST_WIDTH := [0.56, 0.64, 0.59, 0.51, 0.47, 0.73, 0.54]
const SHOULDER_SPREAD := [0.32, 0.36, 0.34, 0.32, 0.285, 0.42, 0.34]
const SHOULDER_WIDTH := [0.22, 0.32, 0.24, 0.18, 0.17, 0.33, 0.24]
const SHELL_OUTLINE := [
	Vector2(0.34, 0.50), Vector2(-0.34, 0.50), Vector2(-0.50, 0.34), Vector2(-0.50, -0.34),
	Vector2(-0.34, -0.50), Vector2(0.34, -0.50), Vector2(0.50, -0.34), Vector2(0.50, 0.34),
]
const SHELL_HEIGHTS := [-0.50, -0.32, 0.29, 0.50]
const SHELL_WIDTHS := [0.80, 1.0, 1.0, 0.71]

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

static var shell_mesh: ArrayMesh

var armor := material(Color("#607383"), 0.36)
var frame := material(Color("#202937"), 0.24)
var accent := material(Color("#63d8ba"), 0.32)
var visor := material(Color("#f5696d"), 0.0, true)


func _ready() -> void:
	match look:
		Look.ULTRON:
			armor = material(Color("#a7b9c6"), 0.53)
			accent = material(Color("#a54b54"), 0.34)
		Look.IRON_MAN:
			armor = material(Color("#bc414c"), 0.38)
			frame = material(Color("#402834"), 0.27)
			accent = material(Color("#dcb168"), 0.43)
			visor = material(Color("#95e5ff"), 0.0, true)
		Look.VISION:
			armor = material(Color("#59a68e"), 0.36)
			frame = material(Color("#21383b"), 0.26)
			accent = material(Color("#c7b77d"), 0.39)
			visor = material(Color("#d5ffe2"), 0.0, true)
		Look.SPIDER_MAN:
			armor = material(Color("#c34350"), 0.26)
			frame = material(Color("#27364d"), 0.24)
			accent = material(Color("#527cc0"), 0.39)
			visor = material(Color("#eef6ff"), 0.0, true)
		Look.WAR_MACHINE:
			armor = material(Color("#798594"), 0.52)
			frame = material(Color("#212832"), 0.36)
			accent = material(Color("#b78358"), 0.39)
			visor = material(Color("#ffad67"), 0.0, true)
		Look.BLACK_PANTHER:
			armor = material(Color("#4c4969"), 0.40)
			frame = material(Color("#232335"), 0.23)
			accent = material(Color("#a29ac5"), 0.48)
			visor = material(Color("#cda8ff"), 0.0, true)
	pelvis = joint(self, Vector3(0, 1.03, 0))
	shell(pelvis, Vector3.ZERO, Vector3(0.39, 0.19, 0.28), frame)
	shell(pelvis, Vector3(0, -0.037, 0.10), Vector3(0.24, 0.14, 0.14), armor)
	torso = joint(pelvis, Vector3(0, 0.13, 0))
	var chest_width: float = CHEST_WIDTH[look]
	shell(torso, Vector3(0, 0.14, -0.027), Vector3(chest_width * 0.62, 0.29, 0.27), frame)
	shell(torso, Vector3(0, 0.34, 0.02), Vector3(chest_width, 0.33, 0.39), armor)
	shell(torso, Vector3(0, 0.47, -0.014), Vector3(chest_width * 0.57, 0.13, 0.29), frame)
	head = joint(torso, Vector3(0, 0.631, 0.025))
	build_helmet()
	build_body_armor(chest_width)
	for side: float in [-1.0, 1.0]:
		build_limbs(side)
	pose_walk(0.0)


func build_helmet() -> void:
	var helmet_width := 0.32 if look == Look.WAR_MACHINE else 0.27
	shell(head, Vector3.ZERO, Vector3(helmet_width, 0.28, 0.30), armor)
	shell(head, Vector3(0, -0.058, 0.137), Vector3(helmet_width * 0.74, 0.12, 0.079), frame)
	shell(head, Vector3(0, 0.038, 0.139), Vector3(helmet_width * 0.92, 0.083, 0.064), frame)
	shell(head, Vector3(0, 0.123, -0.024), Vector3(helmet_width * 0.333, 0.046, 0.19), accent)
	for side: float in [-1.0, 1.0]:
		var lens := shell(head, Vector3(side * helmet_width * 0.208, 0.04, 0.17),
			Vector3(helmet_width * 0.39, 0.042 if look == Look.SPIDER_MAN else 0.030, 0.022), visor)
		lens.rotation.z = side * (0.12 if look == Look.WAR_MACHINE else 0.26)
		var cheek := shell(head, Vector3(side * helmet_width * 0.43, -0.039, 0.073),
			Vector3(0.058, 0.13, 0.17), accent)
		cheek.rotation.z = -side * 0.20
		if look in [Look.VISION, Look.BLACK_PANTHER]:
			var antenna := shell(head, Vector3(side * 0.088, 0.138, -0.078),
				Vector3(0.042, 0.105, 0.096), frame if look == Look.BLACK_PANTHER else accent)
			antenna.rotation.z = -side * 0.28


func build_body_armor(width: float) -> void:
	shell(torso, Vector3(0, 0.35, -0.211), Vector3(width * 0.58, 0.33, 0.175), frame)
	shell(torso, Vector3(0, 0.32, 0.205), Vector3(0.13, 0.162, 0.065), frame)
	match look:
		Look.ULTRON, Look.WAR_MACHINE:
			for row in range(2):
				part(torso, Vector3(0, 0.318 + row * 0.041, 0.243), Vector3(0.088, 0.018, 0.020), visor)
		Look.VISION, Look.BLACK_PANTHER:
			shell(torso, Vector3(0, 0.335, 0.238), Vector3(0.045, 0.14, 0.023), visor)
		_:
			shell(torso, Vector3(0, 0.34, 0.238), Vector3(0.084, 0.083, 0.023), visor).rotation.z = PI * 0.25
	for side: float in [-1.0, 1.0]:
		var chest := shell(torso, Vector3(side * width * 0.249, 0.365, 0.173),
			Vector3(width * 0.39, 0.17, 0.111), accent if look in [Look.IRON_MAN, Look.VISION] else armor)
		chest.rotation.z = -side * 0.21
		shell(torso, Vector3(side * width * 0.205, 0.18, 0.137), Vector3(0.065, 0.045, 0.045), accent)
		shell(torso, Vector3(side * width * 0.155, 0.39, -0.296), Vector3(0.06, 0.15, 0.029), accent)
		shell(torso, Vector3(side * width * 0.155, 0.425, -0.315), Vector3(0.022, 0.075, 0.013), visor)
		match look:
			Look.IRON_MAN:
				var pod := shell(torso, Vector3(side * 0.215, 0.43, -0.232),
					Vector3(0.14, 0.39, 0.23), accent)
				pod.rotation.z = -side * 0.23
				shell(pod, Vector3(0, -0.43, 0), Vector3(0.75, 0.23, 0.67), frame)
			Look.VISION:
				var fin := shell(torso, Vector3(side * 0.25, 0.483, -0.215),
					Vector3(0.095, 0.54, 0.22), accent)
				fin.rotation = Vector3(-0.42, 0, -side * 0.80)
			Look.SPIDER_MAN:
				var spar := shell(torso, Vector3(side * 0.245, 0.478, -0.193),
					Vector3(0.12, 0.34, 0.16), accent)
				spar.rotation = Vector3(-0.62, 0, -side * 0.55)
				var tip := shell(torso, Vector3(side * 0.366, 0.578, -0.30),
					Vector3(0.072, 0.26, 0.16), accent)
				tip.rotation.z = -side * 1.04
			Look.BLACK_PANTHER:
				var fin := shell(torso, Vector3(side * 0.29, 0.49, -0.115),
					Vector3(0.075, 0.32, 0.24), frame)
				fin.rotation = Vector3(-0.58, 0, -side * 0.52)
				part(torso, Vector3(side * 0.298, 0.52, -0.228),
					Vector3(0.036, 0.047, 0.045), visor)
	if look == Look.WAR_MACHINE:
		cannon = joint(torso, Vector3(0.394, 0.635, -0.055))
		shell(cannon, Vector3(0, -0.071, -0.04), Vector3(0.20, 0.23, 0.32), frame)
		shell(cannon, Vector3(0, 0.020, 0.03), Vector3(0.22, 0.18, 0.38), armor)
		shell(cannon, Vector3(0, 0.025, 0.215), Vector3(0.154, 0.135, 0.32), frame)
		shell(cannon, Vector3(0, 0.025, 0.394), Vector3(0.14, 0.122, 0.092), accent)
		for side: float in [-1.0, 1.0]:
			part(cannon, Vector3(side * 0.038, 0.029, 0.443), Vector3(0.024, 0.049, 0.008), visor)
		cannon_tip = joint(cannon, Vector3(0, 0.027, 0.451))


func _process(delta: float) -> void:
	if autoplay:
		time = fposmod(time + delta, 2.30 if preview_attack else 1.04)
		if preview_attack and time >= 1.04:
			pose_attack((time - 1.04) / 1.26)
		else:
			pose_walk(time / 1.04)


func build_limbs(side: float) -> void:
	var hip := joint(pelvis, Vector3(side * 0.133, 0, 0))
	var knee := joint(hip, Vector3(0, -LEG_LENGTH, 0))
	var ankle := joint(knee, Vector3(0, -LEG_LENGTH, 0))
	hips.append(hip)
	knees.append(knee)
	ankles.append(ankle)
	var shin_width := 0.204 if look == Look.WAR_MACHINE else 0.171
	shell(hip, Vector3(0.011 * side, -0.192, 0.018), Vector3(0.185, 0.39, 0.20), armor)
	shell(hip, Vector3(side * 0.063, -0.095, -0.004), Vector3(0.10, 0.19, 0.17), frame)
	shell(knee, Vector3(0, 0, 0.021), Vector3(0.169, 0.14, 0.186), frame)
	shell(knee, Vector3(0, -0.176, 0.043), Vector3(shin_width, 0.35, 0.198), armor)
	shell(knee, Vector3(0, -0.397, -0.015), Vector3(0.099, 0.194, 0.107), frame)
	shell(knee, Vector3(0, -0.195, 0.140), Vector3(shin_width * 0.47, 0.183, 0.043), accent)
	part(knee, Vector3(0, -0.124, 0.163), Vector3(0.04, 0.032, 0.012), visor)
	shell(ankle, Vector3(0, -0.042, 0.057), Vector3(shin_width * 1.05, 0.12, 0.287), frame)
	shell(ankle, Vector3(0, -0.010, 0.115), Vector3(shin_width * 0.94, 0.080, 0.155), armor)

	var shoulder := joint(torso, Vector3(side * SHOULDER_SPREAD[look], 0.368, 0.006))
	shoulder.rotation.z = side * 0.115
	var elbow := joint(shoulder, Vector3(0, -0.29, 0))
	shoulders.append(shoulder)
	elbows.append(elbow)
	var shoulder_width: float = SHOULDER_WIDTH[look]
	var pad := shell(shoulder, Vector3(side * 0.033, 0.032, 0.002),
		Vector3(shoulder_width, 0.225 if look in [Look.ULTRON, Look.WAR_MACHINE] else 0.185, 0.257), armor)
	pad.rotation.z = side * (0.33 if look == Look.ULTRON else 0.15)
	var inlay := shell(shoulder, Vector3(side * shoulder_width * 0.44, 0.041, 0.012),
		Vector3(0.084, 0.125, 0.201), accent)
	inlay.rotation.z = side * 0.21
	part(shoulder, Vector3(side * shoulder_width * 0.48, 0.107, 0.023), Vector3(0.038, 0.031, 0.098), visor)
	shell(shoulder, Vector3(0, -0.145, 0), Vector3(0.146, 0.256, 0.158), armor)
	shell(elbow, Vector3.ZERO, Vector3(0.124, 0.115, 0.128), frame)
	var forearm := 0.137 if look == Look.SPIDER_MAN else (0.195 if look == Look.WAR_MACHINE else 0.167)
	shell(elbow, Vector3(side * 0.010, -0.125, 0.040), Vector3(forearm, 0.239, 0.205), armor)
	shell(elbow, Vector3(side * 0.058, -0.103, 0.090), Vector3(0.088, 0.176, 0.116), accent)
	shell(elbow, Vector3(0, -0.284, 0.011), Vector3(0.121, 0.128, 0.13), frame)
	hands.append(joint(elbow, Vector3(0, -0.32, 0)))
	if look == Look.BLACK_PANTHER:
		for claw in range(-1, 2):
			shell(elbow, Vector3(claw * 0.036, -0.362, 0.072),
				Vector3(0.021, 0.112 - absf(claw) * 0.018, 0.029), accent)


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


func shell(parent: Node3D, at: Vector3, dimensions: Vector3, finish: StandardMaterial3D) -> MeshInstance3D:
	if shell_mesh == null:
		shell_mesh = make_shell_mesh()
	var instance := MeshInstance3D.new()
	instance.mesh = shell_mesh
	instance.scale = dimensions
	instance.material_override = finish
	parent.add_child(instance)
	instance.position = at
	return instance


static func make_shell_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(SHELL_HEIGHTS.size() - 1):
		for index in range(SHELL_OUTLINE.size()):
			var next := (index + 1) % SHELL_OUTLINE.size()
			var a := shell_vertex(index, row)
			var b := shell_vertex(next, row)
			var c := shell_vertex(next, row + 1)
			var d := shell_vertex(index, row + 1)
			shell_face(surface, a, b, c)
			shell_face(surface, a, c, d)
	var top := SHELL_HEIGHTS.size() - 1
	for index in range(SHELL_OUTLINE.size()):
		var next := (index + 1) % SHELL_OUTLINE.size()
		shell_face(surface, Vector3(0, SHELL_HEIGHTS[top], 0), shell_vertex(index, top), shell_vertex(next, top))
		shell_face(surface, Vector3(0, SHELL_HEIGHTS[0], 0), shell_vertex(next, 0), shell_vertex(index, 0))
	surface.index()
	return surface.commit()


static func shell_vertex(index: int, row: int) -> Vector3:
	var outline: Vector2 = SHELL_OUTLINE[index] * SHELL_WIDTHS[row]
	return Vector3(outline.x, SHELL_HEIGHTS[row], outline.y)


static func shell_face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for point in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(point)


func material(color: Color, metal: float, emit := false) -> StandardMaterial3D:
	var finish := StandardMaterial3D.new()
	finish.albedo_color = color
	finish.metallic = metal
	finish.roughness = 0.43
	finish.emission_enabled = emit
	finish.emission = color
	return finish
