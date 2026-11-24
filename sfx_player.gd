extends Node

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var phase = 0.0
var sfx_type = "none"
var sfx_timer = 0.0
var sample_rate = 22050.0
var muted = false

func _ready():
	player = AudioStreamPlayer.new()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = sample_rate
	gen.buffer_length = 0.1
	player.stream = gen
	add_child(player)
	player.play()
	playback = player.get_stream_playback()

func _unhandled_input(e):
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_M:
		muted = !muted

func play_sound(kind):
	if muted: return
	sfx_type = kind
	sfx_timer = 0.18 if kind == "boom" else (0.10 if kind == "cash" else 0.06)

func _process(_delta):
	if playback == null: return
	var frames = playback.get_frames_available()
	for i in range(frames):
		var sample = 0.0
		if not muted and sfx_timer > 0.0:
			sfx_timer -= 1.0 / sample_rate
			if sfx_type == "shoot":
				sample = randf_range(-0.18, 0.18) * (sfx_timer / 0.06)
			elif sfx_type == "boom":
				sample = randf_range(-0.28, 0.28) * sin(phase * 140.0)
			elif sfx_type == "cash":
				sample = 0.15 * sin(phase * 920.0 * TAU)
		phase += 1.0 / sample_rate
		playback.push_frame(Vector2(sample, sample))
