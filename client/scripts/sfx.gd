class_name Sfx
extends Node
## Generated sound: city hum (traffic), rain, birds by day, crickets at night, and short UI/event cues.
## No audio files. One AudioStreamGenerator, filled every frame.

const MIX := 22050.0
const CUES := {
	"place": [[660.0, 0.0, 0.05]],
	"bulldoze": [[180.0, 0.0, 0.08]],
	"good": [[660.0, 0.0, 0.1], [880.0, 0.1, 0.15]],
	"chime": [[784.0, 0.0, 0.12], [988.0, 0.12, 0.12], [1319.0, 0.24, 0.25]],
	"bad": [[330.0, 0.0, 0.15], [247.0, 0.15, 0.25]],
	"petition": [[523.0, 0.0, 0.08], [659.0, 0.1, 0.08]],
	"alarm": [[880.0, 0.0, 0.2], [660.0, 0.25, 0.2], [880.0, 0.5, 0.2], [660.0, 0.75, 0.2]],
}

var m: Node2D
var vol := 0.0  # starts at the minimum; raise it from the menu
var muted := false
var amb := 1.0  # ambience (traffic hum, rain, birds) level, 0 to 1
var cues := 1.0  # event and interface cue level, 0 to 1
var pb: AudioStreamGeneratorPlayback
var brown := 0.0
var lp := 0.0
var out := 0.0
var t := 0.0
var tones: Array = []  # [freq, start, dur, amp, phase]


const PREFS := "user://settings.cfg"


## The volume and mute choice survive a restart (it still starts quiet the first time).
func save_prefs() -> void:
	var f := ConfigFile.new()
	f.load(PREFS)
	f.set_value("sound", "vol", vol)
	f.set_value("sound", "muted", muted)
	f.set_value("sound", "amb", amb)
	f.set_value("sound", "cues", cues)
	f.save(PREFS)


func _ready() -> void:
	var f := ConfigFile.new()
	if f.load(PREFS) == OK:
		vol = clampf(float(f.get_value("sound", "vol", vol)), 0.0, 1.0)
		muted = bool(f.get_value("sound", "muted", muted))
		amb = clampf(float(f.get_value("sound", "amb", amb)), 0.0, 1.0)
		cues = clampf(float(f.get_value("sound", "cues", cues)), 0.0, 1.0)
	var p := AudioStreamPlayer.new()
	var g := AudioStreamGenerator.new()
	g.mix_rate = MIX
	g.buffer_length = 0.2
	p.stream = g
	add_child(p)
	p.play()
	pb = p.get_stream_playback()


func cue(name_: String) -> void:
	for n in CUES.get(name_, []):
		tones.append([n[0] * 0.5, t + n[1], n[2] * 2.5, 0.05 * cues, 0.0])


func _process(dt: float) -> void:
	var n := pb.get_frames_available()
	if n <= 0:
		return
	var c: City = m.city
	var day := c.clock >= 6.0 and c.clock < 20.0
	var w: String = m.sig.weather_at(c.world_pos())
	var hum := amb * clampf(c.congestion - 0.3, 0.0, 1.0) * 0.04 * (1.0 if m.speed > 0.0 else 0.3)
	var rain := amb * (0.025 if w == "rain" else (0.05 if w == "storm" else 0.0))
	var crick := 0.0 if (not day and c.season != 3) else 0.0
	if m.started and day and c.season != 3 and randf() < dt * 0.12:
		var f := randf_range(880.0, 1320.0)  # low and soft: high chirps sounded screechy
		for k in randi_range(2, 4):
			tones.append([f * randf_range(0.9, 1.1), t + k * 0.14, 0.16, 0.006 * amb, 0.0])
	if not m.started:
		hum = 0.0
		rain = 0.0
	var buf := PackedVector2Array()
	buf.resize(n)
	var step := 1.0 / MIX
	var g := 0.0 if muted else vol
	for i in n:
		var wn := randf() * 2.0 - 1.0
		brown = clampf(brown * 0.995 + wn * 0.03, -1.0, 1.0)
		lp += (wn - lp) * 0.08
		var s := brown * hum + lp * rain * 2.0
		if crick > 0.0 and fmod(t, 0.7) < 0.06:
			s += sin(t * TAU * 4300.0) * crick
		for tn in tones:
			var age: float = t - float(tn[0 + 1])
			if age >= 0.0 and age < float(tn[2]):
				var u: float = age / float(tn[2])
				var env := smoothstep(0.0, 0.03, age) * (1.0 - u) * (1.0 - u)  # soft attack, smooth fade
				var ph := age * TAU * float(tn[0])
				s += (sin(ph) + 0.25 * sin(ph * 2.0)) * float(tn[3]) * env
		out += (s - out) * 0.35  # gentle low-pass takes the edge off
		buf[i] = Vector2(out, out) * g
		t += step
	pb.push_buffer(buf)
	var keep: Array = []
	for tn in tones:
		if t - float(tn[1]) < float(tn[2]):
			keep.append(tn)
	tones = keep
