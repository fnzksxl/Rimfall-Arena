extends SubViewport

const Robot = preload("res://assets/robot/robot.gd")
const Rules = preload("res://rules.gd")
const MODEL_SIZE := 60.0
const ATTACK_TIME := 0.44
const MUZZLE_TIME := 0.16
const LOOKS := [Robot.Look.ULTRON, Robot.Look.IRON_MAN, Robot.Look.VISION, Robot.Look.SPIDER_MAN,
	Robot.Look.WAR_MACHINE, Robot.Look.BLACK_PANTHER]
const FLASH_COLORS := [Color("#ff6258"), Color("#8deaff"), Color("#ffe476"), Color("#edf5ff"),
	Color("#ffaf64"), Color("#c695ff")]

var robot := Robot.new()
var camera := Camera3D.new()
var fire_id := 0
var fire_clock := -99.0
var variant := 0


func _ready() -> void:
	size = Vector2i(128, 128)
	own_world_3d = true
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	camera.position = Vector3(0.0, 5.46, 2.80)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.48
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#bdcfdf")
	environment.ambient_light_energy = 0.81
	camera.environment = environment
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.92, 0.0))
	camera.current = true
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-49, -32, 0)
	key.light_color = Color("#fff1df")
	key.light_energy = 1.40
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-23, 147, 0)
	rim.light_color = Color("#96d6ff")
	rim.light_energy = 0.75
	add_child(rim)
	robot.look = LOOKS[variant]
	robot.autoplay = false
	add_child(robot)


func update_pose(player: Dictionary, facing: Vector2, step: float, now: float, elapsed: float) -> void:
	var latest: int = player.get("fire_id", 0)
	if latest != fire_id:
		fire_clock = now - maxf(0.0, elapsed - player.get("fire_at", -99.0))
		fire_id = latest
	var age := now - fire_clock
	var walk: Vector2 = player.walk
	var stride := clampf(walk.length() / Rules.WALK_SPEED, 0.0, 1.0)
	if player.windup > 0.0:
		var slot: int = player.windup_slot
		var duration := Rules.cast_delay(slot, player.choices[slot])
		facing = player.windup_aim
		robot.pose_attack(lerpf(0.0, 0.42, clampf(1.0 - player.windup / duration, 0.0, 1.0)), step / TAU, 0.0)
	elif player.charge > 0.0:
		robot.pose_walk(step / TAU, 0.40, 0.60)
		robot.torso.rotation.x = 0.37
	elif age < ATTACK_TIME:
		facing = player.fire_aim
		robot.pose_attack(lerpf(0.42, 1.0, age / ATTACK_TIME), step / TAU, stride)
	else:
		robot.pose_walk(step / TAU, 0.0, stride)
	robot.rotation.y = atan2(facing.x, facing.y)


func muzzle_offset() -> Vector2:
	var origin := robot.hands[1].global_position
	match robot.look:
		Robot.Look.VISION:
			origin = robot.head.global_position + robot.head.global_basis.z * 0.15
		Robot.Look.SPIDER_MAN:
			origin = robot.hands[0].global_position
		Robot.Look.WAR_MACHINE:
			origin = robot.cannon_tip.global_position
	return (camera.unproject_position(origin) - Vector2(size) * 0.5) * (MODEL_SIZE / size.x)
