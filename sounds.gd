extends Node

const RATE := 22050

var cues: Array[AudioStreamWAV] = []
var voice: AudioStreamPlayer


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for cue in [[540.0, 180.0, 0.105], [210.0, 65.0, 0.25], [180.0, 600.0, 0.19],
		[370.0, 540.0, 0.23], [860.0, 340.0, 0.22], [155.0, 72.0, 0.13],
		[520.0, 790.0, 0.29], [330.0, 650.0, 0.37]]:
		cues.append(synthesize(cue[0], cue[1], cue[2]))
	voice = AudioStreamPlayer.new()
	voice.max_polyphony = 4
	voice.volume_db = -9
	add_child(voice)


func play_cue(index: int) -> void:
	if voice:
		voice.stream = cues[index]
		voice.play()


func synthesize(first: float, last: float, duration: float) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var phase := 0.0
	for index in range(count):
		var fraction := float(index) / count
		phase += TAU * lerpf(first, last, fraction) / RATE
		var volume := minf(1.0, fraction * 33.0) * pow(1.0 - fraction, 2.1)
		var sample := (sin(phase) * 0.65 + sin(phase * 1.5) * 0.17 + sin(phase * 2.03) * 0.10)
		samples.encode_s16(index * 2, int(sample * volume * 23400))
	var cue := AudioStreamWAV.new()
	cue.format = AudioStreamWAV.FORMAT_16_BITS
	cue.mix_rate = RATE
	cue.data = samples
	return cue
