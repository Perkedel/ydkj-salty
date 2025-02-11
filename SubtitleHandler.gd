extends Control

onready var timer = $Timer
onready var vbox = $Viewport
onready var sbox = $Viewport/SubBox
onready var tbox = $Viewport/SubBox/SubText
onready var sview = $SubView
var queue = []
var last_duration: int = 0

func _ready():
#	clear_contents()
	S.sub_node = self
	### Testing
	#queue_subtitles("Welcome to Salty Trivia with Candy Barre,[#3000#]and I woke up like this.[#5500#]Disheveled.")
	### End testing
	_on_size_changed()
	get_viewport().connect("size_changed", self, "_on_size_changed")

func clear_contents():
#	print("SUB CLEAR_CONTENTS")
	timer.stop()
	queue.clear()
	tbox.bbcode_text = ""

# Queues timed subtitles.
func queue_subtitles(contents = ""):
#	print("SUB QUEUE_SUBTITLES ", contents)
	if !R.get_settings_value("subtitles"): return
	queue = Loader.parse_time_markers(contents)
	show_queued()

const base_resolution: Vector2 = Vector2(1280.0, 720.0) # resolution of full viewport
var scale: float = 1.0
func _on_size_changed():
	var resolution = get_viewport_rect().size
	if resolution.x / resolution.y > base_resolution.x / base_resolution.y:
		# too wide
		scale = resolution.y / base_resolution.y
	else:
		# too narrow
		scale = resolution.x / base_resolution.x
	print("Subtitle scale is ", scale)
	vbox.size = Vector2(900, 96) * scale
	rect_scale = Vector2.ONE * scale
	sbox.rect_scale = Vector2.ONE * scale
	sview.material.set_shader_param(
		"line_thickness", 4.0 * scale
	)

# Shows subtitles from the queue. Clears the subtitle if the queue is empty.
func show_queued():
#	print("SUB SHOW_QUEUED ", queue)
	if len(queue) == 0:
		clear_contents()
		return
	var next = queue.pop_front()
	show_subtitle(next.text, next.time)

# Time of 0 clears the contents.
# Negative time disables the timer,
# displaying the subtitle until interrupted by a different subtitle.
func show_subtitle(contents = "", time = 0):
#	print("SUB SHOW_SUBTITLE ", contents, " ", time)
	if !R.get_settings_value("subtitles"): return
	if time == 0:
		clear_contents()
	else:
		last_duration = time
		tbox.clear()
		tbox.append_bbcode("[center]" + contents.strip_edges() + "[/center]")
		if time >= 0:
			var duration: float = (time / 1000.0) - S.get_voice_time()
#			print("SUBTITLE Duration:", duration)
			if duration > 0.0:
				timer.start(duration)

# Only clear the subtitles if current length is -1
func signal_end_subtitle():
	if last_duration == -1:
		tbox.clear()
		last_duration = 0

func _on_Timer_timeout():
#	print("SUB TIMER_TIMEOUT")
	show_queued()
