extends Node

const RATE := 22050
const STANDBY = preload("res://assets/audio/standby.ogg")
const COMBAT = preload("res://assets/audio/combat.ogg")
const SILENT_DB := -80.0

var cues: Array[AudioStreamWAV] = []
var voice: AudioStreamPlayer
var bed: AudioStreamPlayer
var rhythm: AudioStreamPlayer
var fade: Tween
var muted := false
var last_effect := 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for cue in [[680.0, 190.0, 0.13, 0.16], [200.0, 62.0, 0.24, 0.32], [180.0, 640.0, 0.23, 0.48],
		[365.0, 560.0, 0.23, 0.04], [805.0, 430.0, 0.19, 0.18], [165.0, 62.0, 0.16, 0.48],
		[520.0, 805.0, 0.29, 0.02], [330.0, 655.0, 0.42, 0.03], [1650.0, 620.0, 0.15, 0.62],
		[1250.0, 470.0, 0.23, 0.09], [220.0, 45.0, 0.37, 0.34], [280.0, 57.0, 0.27, 0.48]]:
		cues.append(synthesize(cue[0], cue[1], cue[2], cue[3]))
	voice = AudioStreamPlayer.new()
	var polyphonic := AudioStreamPolyphonic.new()
	polyphonic.polyphony = 16
	voice.stream = polyphonic
	add_child(voice)
	voice.play()
	bed = loop_player(STANDBY, -17.0)
	rhythm = loop_player(COMBAT, SILENT_DB)
	bed.play()
	rhythm.play()


func loop_player(stream: AudioStreamOggVorbis, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	stream.loop = true
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player


func set_mix(combat: bool, silent: bool) -> void:
	if not bed:
		return
	if fade:
		fade.kill()
	if silent:
		voice.stop()
		bed.volume_db = SILENT_DB
		rhythm.volume_db = SILENT_DB
		muted = true
		return
	if muted:
		voice.play()
	muted = false
	fade = create_tween().set_parallel(true)
	fade.tween_property(bed, "volume_db", -15.0 if combat else -17.0, 0.50)
	fade.tween_property(rhythm, "volume_db", -13.0 if combat else SILENT_DB, 0.50)


func play_cue(index: int, offset_db := 0.0) -> void:
	if voice and not muted:
		var playback := voice.get_stream_playback() as AudioStreamPlaybackPolyphonic
		if playback:
			playback.play_stream(cues[index], 0.0, -9.0 + offset_db)


func play_effects(effects: Array, listener: Vector2) -> void:
	for effect: Dictionary in effects:
		if effect.cue < 0 or effect.audio_id <= last_effect:
			continue
		last_effect = effect.audio_id
		var distance := listener.distance_to(effect.p)
		if distance < 780.0:
			play_cue(effect.cue, linear_to_db(1.0 - distance / 860.0))


func synthesize(first: float, last: float, duration: float, noise_amount: float) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = int(first * 17.0 + last)
	var phase := 0.0
	var previous := 0.0
	for index in range(count):
		var fraction := float(index) / count
		phase += TAU * lerpf(first, last, 1.0 - pow(1.0 - fraction, 2.2)) / RATE
		var volume := minf(1.0, fraction * 45.0) * pow(1.0 - fraction, 2.1)
		var white := noise.randf_range(-1.0, 1.0)
		var transient := (white - previous * 0.67) * exp(-fraction * 4.7)
		previous = white
		var tone := sin(phase) * 0.56 + sin(phase * 1.48) * 0.16 + sin(phase * 2.03) * 0.11
		var sample := clampf(tone + transient * noise_amount, -1.0, 1.0)
		samples.encode_s16(index * 2, int(sample * volume * 23400))
	var cue := AudioStreamWAV.new()
	cue.format = AudioStreamWAV.FORMAT_16_BITS
	cue.mix_rate = RATE
	cue.data = samples
	return cue
