extends RefCounted

const Match = preload("res://match.gd")
const Rules = preload("res://rules.gd")
const COOLDOWN_TICKS := 20.0
const MOTION_PAYLOAD_BUDGET := 1320
const EFFECT_BYTES := 21


static func put_position(buffer: StreamPeerBuffer, value: Vector2) -> void:
	buffer.put_float(value.x)
	buffer.put_float(value.y)


static func get_position(buffer: StreamPeerBuffer) -> Vector2:
	return Vector2(buffer.get_float(), buffer.get_float())


static func encode(game: RefCounted, viewer := 0) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_float(game.left)
	buffer.put_float(game.elapsed)
	buffer.put_float(game.half_side)
	if game.phase != Match.FIGHT:
		return buffer.data_array
	buffer.put_u8(game.players.size())
	for id: int in game.players:
		var player: Dictionary = game.players[id]
		var concealed: bool = viewer != 0 and id != viewer and player.cloak > 0.0 and \
			not Match.same_team(game.players.get(viewer, {}), player)
		buffer.put_u32(id)
		put_position(buffer, Vector2.ZERO if concealed else player.p)
		buffer.put_16(0 if concealed else roundi(player.aim.angle() * 8000.0))
		var walk: Vector2 = Vector2.ZERO if concealed else player.walk
		buffer.put_16(roundi(walk.x))
		buffer.put_16(roundi(walk.y))
		var fire_id: int = player.fire_id if not concealed and game.elapsed - player.fire_at < 0.6 else 0
		buffer.put_u32(fire_id)
		if fire_id != 0:
			buffer.put_float(player.fire_at)
			buffer.put_16(roundi(player.fire_aim.angle() * 8000.0))
		buffer.put_u16(roundi(player.hp * 100.0))
		buffer.put_u8(roundi(player.impact))
		buffer.put_u8(int(player.alive))
		buffer.put_u8(player.kills)
		buffer.put_u8(roundi(player.guard * 100.0))
		buffer.put_u8(roundi(player.reflect * 100.0))
		buffer.put_u8(roundi(player.charge * 100.0))
		buffer.put_u8(roundi(player.flash * 100.0))
		buffer.put_u8(roundi(player.gear_time * 100.0))
		buffer.put_u8(int(player.gear_used) | (int(player.shield_used) << 1))
		var anchor := 0 if concealed else roundi(player.anchor_left * 100.0)
		var windup := roundi(player.windup * 100.0)
		buffer.put_u8(anchor)
		if anchor > 0:
			put_position(buffer, player.anchor_pos)
		buffer.put_u8(windup)
		if windup > 0:
			buffer.put_16(roundi(player.windup_aim.angle() * 8000.0))
		buffer.put_u8(roundi(player.step_left * 100.0))
		buffer.put_u8(roundi(player.surge_wait * 100.0))
		buffer.put_u8(roundi(player.surge_left * 100.0))
		buffer.put_u8(ceili(player.cloak * 100.0))
		buffer.put_u8(roundi(player.root * 100.0))
		buffer.put_u8(roundi(player.jam * 100.0))
		buffer.put_u8(player.mirror_mask)
		if player.mirror_mask != 0:
			buffer.put_16(roundi(player.mirror_axis.angle() * 8000.0))
		buffer.put_32(player.link_target)
		for cooldown: float in player.cooldowns:
			buffer.put_u8(ceili(cooldown * COOLDOWN_TICKS))
	buffer.put_u8(game.shots.size())
	for shot: Dictionary in game.shots:
		buffer.put_u32(shot.id)
		put_position(buffer, shot.p)
		buffer.put_16(roundi(shot.v.angle() * 8000.0))
		buffer.put_u8(shot.slot)
		buffer.put_u8(shot.style)
		buffer.put_u8(shot.size)
	buffer.put_u8(game.strikes.size())
	for strike: Dictionary in game.strikes:
		put_position(buffer, strike.p)
		buffer.put_u8(ceili(strike.left * 100.0))
		buffer.put_u8(strike.size)
		buffer.put_u8(roundi(strike.duration * 100.0))
		var flags: int = strike.slot | (0x80 if strike.pull else 0) | (0x40 if strike.get("scatter", false) else 0) | \
			(0x20 if strike.has("repeats") else 0)
		buffer.put_u8(flags)
		if flags & 0x60:
			buffer.put_16(roundi(strike.angle * 8000.0))
		if flags & 0x20:
			buffer.put_u8(strike.repeats)
	var effect_count := clampi(floori((MOTION_PAYLOAD_BUDGET - buffer.get_size() - 1) / float(EFFECT_BYTES)), 0, game.effects.size())
	buffer.put_u8(effect_count)
	for index in range(game.effects.size() - effect_count, game.effects.size()):
		var effect: Dictionary = game.effects[index]
		put_position(buffer, effect.p)
		buffer.put_u32(effect.color.to_rgba32())
		buffer.put_u8(effect.size)
		buffer.put_u8(ceili(effect.left * 100.0))
		buffer.put_u8(roundi(effect.duration * 100.0))
		buffer.put_u8(effect.damage)
		buffer.put_8(effect.cue)
		buffer.put_u32(effect.audio_id)
	return buffer.data_array


static func apply(data: PackedByteArray, state: Dictionary) -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	state.left = buffer.get_float()
	state.elapsed = buffer.get_float()
	state.half_side = buffer.get_float()
	if state.phase != Match.FIGHT:
		return
	for index in range(buffer.get_u8()):
		var id := buffer.get_u32()
		var player: Dictionary = state.players.get(id, {})
		player.p = get_position(buffer)
		player.aim = Vector2.from_angle(buffer.get_16() / 8000.0)
		player.walk = Vector2(buffer.get_16(), buffer.get_16())
		player.fire_id = buffer.get_u32()
		if player.fire_id != 0:
			player.fire_at = buffer.get_float()
			player.fire_aim = Vector2.from_angle(buffer.get_16() / 8000.0)
		else:
			player.fire_at = -99.0
			player.fire_aim = Vector2.RIGHT
		player.hp = buffer.get_u16() / 100.0
		player.impact = float(buffer.get_u8())
		player.alive = bool(buffer.get_u8())
		player.kills = buffer.get_u8()
		player.guard = buffer.get_u8() / 100.0
		player.reflect = buffer.get_u8() / 100.0
		player.charge = buffer.get_u8() / 100.0
		player.flash = buffer.get_u8() / 100.0
		player.gear_time = buffer.get_u8() / 100.0
		var gear_flags := buffer.get_u8()
		player.gear_used = bool(gear_flags & 1)
		player.shield_used = bool(gear_flags & 2)
		player.anchor_left = buffer.get_u8() / 100.0
		if player.anchor_left > 0.0:
			player.anchor_pos = get_position(buffer)
		player.windup = buffer.get_u8() / 100.0
		if player.windup > 0.0:
			player.windup_aim = Vector2.from_angle(buffer.get_16() / 8000.0)
		player.step_left = buffer.get_u8() / 100.0
		player.surge_wait = buffer.get_u8() / 100.0
		player.surge_left = buffer.get_u8() / 100.0
		player.cloak = buffer.get_u8() / 100.0
		player.root = buffer.get_u8() / 100.0
		player.jam = buffer.get_u8() / 100.0
		player.mirror_mask = buffer.get_u8()
		if player.mirror_mask != 0:
			player.mirror_axis = Vector2.from_angle(buffer.get_16() / 8000.0)
		player.link_target = buffer.get_32()
		var cooldowns: Array[float] = []
		for slot in range(Rules.ACTIVE_SLOTS):
			cooldowns.append(buffer.get_u8() / COOLDOWN_TICKS)
		player.cooldowns = cooldowns
	state.shots.clear()
	for index in range(buffer.get_u8()):
		state.shots.append({"id": buffer.get_u32(), "p": get_position(buffer),
			"v": Vector2.from_angle(buffer.get_16() / 8000.0), "slot": buffer.get_u8(),
			"style": buffer.get_u8(), "size": float(buffer.get_u8())})
	state.strikes.clear()
	for index in range(buffer.get_u8()):
		var strike := {"p": get_position(buffer), "left": buffer.get_u8() / 100.0,
			"size": float(buffer.get_u8()), "duration": buffer.get_u8() / 100.0}
		var flags := buffer.get_u8()
		strike.slot = flags & 0x1f
		strike.pull = bool(flags & 0x80)
		strike.scatter = bool(flags & 0x40)
		if flags & 0x60:
			strike.angle = buffer.get_16() / 8000.0
		if flags & 0x20:
			strike.repeats = buffer.get_u8()
		state.strikes.append(strike)
	state.effects.clear()
	for index in range(buffer.get_u8()):
		state.effects.append({"p": get_position(buffer), "color": Color.hex(buffer.get_u32()),
			"size": float(buffer.get_u8()), "left": buffer.get_u8() / 100.0,
			"duration": buffer.get_u8() / 100.0, "damage": buffer.get_u8(),
			"cue": buffer.get_8(), "audio_id": buffer.get_u32()})
