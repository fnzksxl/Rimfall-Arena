extends Node2D

const Rules = preload("res://rules.gd")
const Match = preload("res://match.gd")
const Arena = preload("res://arena.gd")
const Hud = preload("res://hud.gd")
const Sounds = preload("res://sounds.gd")
const Motion = preload("res://motion.gd")
const VERSION := 16
const CAST_KEYS := [KEY_Q, KEY_E, KEY_R, KEY_F, KEY_SPACE]
const CAST_SOUNDS := [Rules.Cue.FIRE, Rules.Cue.POWER, Rules.Cue.MARK, Rules.Cue.POWER, Rules.Cue.GUARD, Rules.Cue.DASH]
enum { MENU, CONNECTING, ROOM }

var sim := Match.new()
var state: Dictionary = {}
var screen := MENU
var own_id := 1
var host := false
var practice_mode := false
var status := ""
var pending_name := ""
var connection_deadline := 0
var addresses := PackedStringArray()
var ticks := 0
var reliable_stamp := 0
var arena := Arena.new()
var hud := Hud.new()
var sound := Sounds.new()
var was_firing := false
var muted := false
var last_sound_phase := -1
var last_cooldowns: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]


func _ready() -> void:
	get_window().title = "Rimfall Arena %s" % ProjectSettings.get_setting("application/config/version")
	add_child(arena)
	hud.game = self
	add_child(hud)
	add_child(sound)
	multiplayer.connected_to_server.connect(connected)
	multiplayer.connection_failed.connect(func(): leave_game("접속 실패 · 호스트 주소와 포트를 확인하세요."))
	multiplayer.server_disconnected.connect(func(): leave_game("호스트 연결이 종료됐습니다."))
	multiplayer.peer_disconnected.connect(peer_left)
	multiplayer.peer_connected.connect(on_peer_connected)
	show_state()


func clean_name(value: String) -> String:
	var cleaned := ""
	for char in value.strip_edges().left(16):
		if char.unicode_at(0) >= 32 and char.unicode_at(0) != 127:
			cleaned += char
	return cleaned if not cleaned.is_empty() else "파일럿"


func parse_port(value: String) -> int:
	var trimmed := value.strip_edges()
	var number := trimmed.to_int() if trimmed.is_valid_int() else 0
	if number < 1024 or number > 65535:
		status = "포트는 1024~65535 사이로 입력하세요."
		return 0
	return number


func host_game(nickname: String, port_text: String, mode := Match.FREE_FOR_ALL) -> void:
	if screen != MENU:
		return
	var number := parse_port(port_text)
	if number == 0:
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(number, Rules.CAPACITY - 1, 3)
	if error != OK:
		status = "방 생성 실패 · 다른 UDP 포트를 시도하세요."
		return
	multiplayer.multiplayer_peer = peer
	addresses = local_addresses(number)
	hud.set_addresses(addresses)
	enter_host(nickname, mode)


func enter_host(nickname: String, mode: int) -> void:
	sim = Match.new()
	sim.mode = Match.TEAM_MATCH if mode == Match.TEAM_MATCH else Match.FREE_FOR_ALL
	sim.add_player(1, clean_name(nickname))
	own_id = 1
	screen = ROOM
	host = true
	status = ""
	state = sim.snapshot()


func practice(nickname: String, bot_count := 1, mode := Match.FREE_FOR_ALL) -> void:
	if screen != MENU:
		return
	practice_mode = true
	enter_host(nickname, mode)
	var count := clampi(bot_count, 1, Rules.CAPACITY - 1)
	if sim.mode == Match.TEAM_MATCH:
		count |= 1
	for index in range(1, count + 1):
		sim.add_player(-index, "스파링 봇 %d" % index if count > 1 else "스파링 봇")
	sim.start_match()
	state = sim.snapshot()


func join_game(nickname: String, address: String, port_text: String) -> void:
	if screen != MENU:
		return
	var destination := address.strip_edges()
	if destination.count(":") == 1:
		var parts := destination.split(":")
		destination = parts[0].strip_edges()
		port_text = parts[1]
	var number := parse_port(port_text)
	if number == 0:
		return
	if destination.is_empty():
		status = "참가하려면 호스트 주소를 입력하세요."
		return
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(destination, number, 3) != OK:
		status = "호스트 주소를 확인하세요."
		return
	pending_name = clean_name(nickname)
	screen = CONNECTING
	ticks = 0
	reliable_stamp = 0
	connection_deadline = Time.get_ticks_msec() + 8000
	status = "호스트에 연결 중…"
	multiplayer.multiplayer_peer = peer


func connected() -> void:
	if screen == CONNECTING:
		own_id = multiplayer.get_unique_id()
		request_join.rpc_id(1, pending_name, VERSION)


func on_peer_connected(id: int) -> void:
	if host:
		expire_unregistered_peer(id)


func expire_unregistered_peer(id: int) -> void:
	var peer := multiplayer.multiplayer_peer
	await get_tree().create_timer(8.0).timeout
	if host and peer == multiplayer.multiplayer_peer and id in multiplayer.get_peers() and not sim.players.has(id):
		peer.disconnect_peer(id)


@rpc("any_peer", "call_remote", "reliable", 0)
func request_join(nickname: String, version: int) -> void:
	if not host or practice_mode:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sim.players.has(sender):
		return
	if version != VERSION:
		reject_join.rpc_id(sender, "게임 버전이 다릅니다. 같은 실행 파일을 사용하세요.")
		return
	if sim.phase != Match.LOBBY:
		reject_join.rpc_id(sender, "대전이 진행 중입니다. 호스트가 대기실로 돌아오면 참가할 수 있습니다.")
		return
	sim.add_player(sender, clean_name(nickname))
	broadcast_state(true)


@rpc("authority", "call_remote", "reliable", 0)
func reject_join(message: String) -> void:
	leave_game.call_deferred(message)


func peer_left(id: int) -> void:
	if host and sim.players.has(id):
		sim.remove_player(id)
		broadcast_state(true)


func leave_game(message := "") -> void:
	var peer := multiplayer.multiplayer_peer
	screen = MENU
	host = false
	practice_mode = false
	own_id = 1
	addresses.clear()
	hud.set_addresses(addresses)
	state = {}
	sim = Match.new()
	if peer is ENetMultiplayerPeer:
		peer.close()
		multiplayer.multiplayer_peer = null
	status = message
	last_sound_phase = -1
	sound.last_effect = 0
	last_cooldowns.fill(0.0)


func local_addresses(number: int) -> PackedStringArray:
	var candidates := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			candidates.append("%s:%d" % [address, number])
	candidates.append("127.0.0.1:%d" % number)
	return candidates


func copy_address(index: int) -> void:
	if index < 0 or index >= addresses.size():
		return
	DisplayServer.clipboard_set(addresses[index])
	status = "호스트 주소와 포트를 복사했습니다."


func toggle_audio() -> void:
	muted = not muted
	sound.set_mix(state.get("phase") == Match.FIGHT, muted)


func primary_action() -> void:
	var phase: int = state.get("phase", Match.LOBBY)
	if phase == Match.SHOP:
		if host:
			sim.toggle_ready(own_id)
			broadcast_state(true)
		else:
			request_shop.rpc_id(1, state.epoch, -1, 0)
	elif host:
		if phase == Match.LOBBY:
			sim.start_match()
		elif phase == Match.RESULTS:
			sim.return_to_lobby()
			status = ""
		broadcast_state(true)


func switch_team() -> void:
	if screen != ROOM or state.get("phase") != Match.LOBBY or state.get("mode") != Match.TEAM_MATCH:
		return
	if host:
		sim.switch_team(own_id)
		broadcast_state(true)
	else:
		request_team_switch.rpc_id(1, state.epoch)


@rpc("any_peer", "call_remote", "reliable", 0)
func request_team_switch(epoch: int) -> void:
	if host and epoch == sim.epoch and sim.phase == Match.LOBBY and sim.mode == Match.TEAM_MATCH:
		sim.switch_team(multiplayer.get_remote_sender_id())
		broadcast_state(true)


func buy_slot(slot: int, choice := 0) -> void:
	if state.get("phase") != Match.SHOP:
		return
	if host:
		sim.buy(own_id, slot, choice)
		broadcast_state(true)
	else:
		request_shop.rpc_id(1, state.epoch, slot, choice)


func sell_gear(choice: int) -> void:
	if state.get("phase") != Match.SHOP:
		return
	if host:
		sim.sell_gear(own_id, choice)
		broadcast_state(true)
	else:
		request_shop.rpc_id(1, state.epoch, -2, choice)


@rpc("any_peer", "call_remote", "reliable", 0)
func request_shop(epoch: int, slot: int, choice: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not host or epoch != sim.epoch or sim.phase != Match.SHOP or not sim.players.has(sender):
		return
	if slot == -1:
		sim.toggle_ready(sender)
	elif slot == -2:
		sim.sell_gear(sender, choice)
	else:
		sim.buy(sender, slot, choice)
	broadcast_state(true)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func request_move(epoch: int, direction: Vector2, target: Vector2) -> void:
	if host and epoch == sim.epoch:
		sim.steer(multiplayer.get_remote_sender_id(), direction, target)


@rpc("any_peer", "call_remote", "reliable", 2)
func request_cast(epoch: int, slot: int, target: Vector2) -> void:
	if host and epoch == sim.epoch:
		sim.cast(multiplayer.get_remote_sender_id(), slot, target)


@rpc("authority", "call_remote", "reliable", 0)
func sync_room(data: Dictionary, stamp: int) -> void:
	receive_state(data, stamp)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func sync_motion(data: PackedByteArray, stamp: int, epoch: int) -> void:
	if screen == ROOM and state.epoch == epoch and stamp > ticks:
		Motion.apply(data, state)
		ticks = stamp


func receive_state(data: Dictionary, stamp: int) -> void:
	if screen == MENU or not data.players.has(own_id) or stamp <= reliable_stamp:
		return
	reliable_stamp = stamp
	ticks = maxi(ticks, stamp)
	state = data
	screen = ROOM
	status = ""


func broadcast_state(reliable: bool) -> void:
	state = sim.snapshot()
	if practice_mode or multiplayer.get_peers().is_empty():
		return
	ticks += 1
	if not reliable:
		var has_cloak: bool = sim.players.values().any(func(player: Dictionary): return player.cloak > 0.0)
		var shared := PackedByteArray() if has_cloak else Motion.encode(sim)
		for id: int in multiplayer.get_peers():
			if sim.players.has(id):
				var data := Motion.encode(sim, id) if has_cloak else shared
				sync_motion.rpc_id(id, data, ticks, sim.epoch)
		return
	for id: int in multiplayer.get_peers():
		if sim.players.has(id):
			sync_room.rpc_id(id, sim.snapshot(id), ticks)


func _physics_process(delta: float) -> void:
	if screen == CONNECTING and Time.get_ticks_msec() >= connection_deadline:
		leave_game("연결 시간 초과 · 주소, UDP 포트, 방화벽을 확인하세요.")
	if screen != ROOM:
		return
	var frame := Engine.get_physics_frames()
	if state.get("phase") == Match.FIGHT:
		var direction := Vector2.ZERO
		if DisplayServer.window_is_focused():
			direction = Vector2(
				int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
				int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W)))
		var target := arena.world_target()
		if host:
			sim.steer(own_id, direction, target)
		elif frame % 2 == 0:
			request_move.rpc_id(1, state.epoch, direction, target)
		var local: Dictionary = state.players.get(own_id, {})
		var firing := was_firing and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and DisplayServer.window_is_focused()
		var mouse := get_local_mouse_position()
		if firing and Arena.COMBAT_VIEW.has_point(mouse) and not local.is_empty() and local.cooldowns[0] <= 0.0:
			try_cast(0)
		if not firing:
			was_firing = false
	else:
		was_firing = false
	if host:
		var epoch := sim.epoch
		var feed_revision := sim.feed_revision
		sim.advance(delta)
		if sim.epoch != epoch or sim.feed_revision != feed_revision:
			broadcast_state(true)
		elif frame % 3 == 0 and sim.phase in [Match.SHOP, Match.COUNTDOWN, Match.FIGHT]:
			broadcast_state(false)
		else:
			state = sim.snapshot()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE:
		hud.close_picker()
	if screen == ROOM and state.get("phase") == Match.FIGHT:
		var slot := CAST_KEYS.find(event.physical_keycode)
		if slot >= 0:
			try_cast(slot + 1)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if screen != ROOM or state.get("phase") != Match.FIGHT:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Arena.COMBAT_VIEW.has_point(event.position):
			was_firing = true
			try_cast(0)


func try_cast(slot: int) -> void:
	var local: Dictionary = state.players.get(own_id, {})
	if not Match.can_cast(local, slot):
		return
	if host:
		sim.cast(own_id, slot, arena.world_target())
	else:
		request_cast.rpc_id(1, state.epoch, slot, arena.world_target())


func _process(_delta: float) -> void:
	show_state()
	var phase: int = state.get("phase", Match.LOBBY)
	var player: Dictionary = state.get("players", {}).get(own_id, {})
	if phase != last_sound_phase:
		sound.set_mix(phase == Match.FIGHT, muted)
		if phase == Match.FIGHT:
			sound.play_cue(Rules.Cue.START)
		elif phase == Match.RESULTS:
			sound.play_cue(Rules.Cue.RESULT)
		last_sound_phase = phase
		last_cooldowns.fill(0.0)
	var listener: Vector2 = arena.camera_focus if phase == Match.FIGHT else player.get("p", Vector2.ZERO)
	sound.play_effects(state.get("effects", []), listener)
	if phase == Match.FIGHT and not player.is_empty():
		for slot in range(Rules.ACTIVE_SLOTS):
			var cd: float = player.cooldowns[slot]
			if cd > last_cooldowns[slot] + 0.18:
				sound.play_cue(CAST_SOUNDS[slot])
			last_cooldowns[slot] = cd


func show_state() -> void:
	arena.menu = screen < ROOM
	arena.state = state
	arena.own_id = own_id
	hud.update_view(state, screen, own_id, status, host, muted, practice_mode)
