extends Node
### "Root", for data that every page should have.
signal change_audience_count(audience_count)

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
export onready var rng = RandomNumberGenerator.new()
var html: bool = false
var pass_between = {}
var players = []
var audience = []
# Store unique IDs of audience controllers for easier access.
var audience_keys = []
var censor_regex = RegEx.new()
var cuss_regex = RegEx.new()

var cfg = ConfigFile.new()
# 0: Render at 1280x720. Disable most shader animations.
# 1: Stretch to window size. Disable most shader animations.
# 2: Stretch to window size. Enable all shader animations.
const DEFAULT_CFG = {
	graphics_quality = 2,
	room_size = 7,
	room_openness = 2,
	remote_start = true,
	audience = true,
	subtitles = true,
	overall_volume = 15,
	music_volume = 10,
	cutscenes = true,
	hide_room_code = false,
	hide_room_code_ingame = false,
	awesomeness = true,
}

const DEFAULT_SAVE = {
	history = { # default unlocks
		random = {
			"last_played": 0,
			"high_score": -1,
			"high_score_time": 0,
			"best_accuracy": -1,
			"best_accuracy_time": 0,
			"locked": false,
		},
		demo = {
			"last_played": 0,
			"high_score": -1,
			"high_score_time": 0,
			"best_accuracy": -1,
			"best_accuracy_time": 0,
			"locked": false,
		},
		ep_001 = {
			"last_played": 0,
			"high_score": -1,
			"high_score_time": 0,
			"best_accuracy": -1,
			"best_accuracy_time": 0,
			"locked": false,
		},
		test = {
			"last_played": 0,
			"high_score": -1,
			"high_score_time": 0,
			"best_accuracy": -1,
			"best_accuracy_time": 0,
			"locked": false,
		},
	},
	achievements = {
	},
	misc = {
		cuss_history = [],
		guests_seen = [],
	}
}
var save_data = DEFAULT_SAVE.duplicate(true)

var unlocks = {
	ep_001 = ["ep_002"],
	ep_002 = ["ep_003"],
}

# Called when the node enters the scene tree for the first time.
func _ready():
	rng.randomize()
	set_currency("fmt_dollars")
	var result = cuss_regex.compile("F+U+C+K+[^A-Z]*(Y+O+U|O+F)")
	if result != OK:
		print("Could not compile cuss RegEx: error code %d" % result)
	result = censor_regex.compile("FU(CC|CK|KK|KC)|\\b(BULL|DOG|HORSE)?SHIT(E|S|TED|TER|TY)?\\b|\\bPISS(BABY|ED|ER|ING)?|NIGG(A|ER)|\bFAG(\b|GOT|S)|QUEER")
	if result != OK:
		print("Could not compile censor RegEx: error code %d" % result)
	load_settings()
	load_save_data()
	_set_visual_quality(get_settings_value("graphics_quality"))
	pause_mode = Node.PAUSE_MODE_PROCESS
	if OS.has_feature("HTML5"):
		html = true

### Windowed/fullscreen
func _input(event):
	if event is InputEventKey and event.is_pressed():
		var code = event.get_physical_scancode()
		if code == KEY_F11:
			toggle_fullscreen()

func toggle_fullscreen():
	OS.set_window_fullscreen(!OS.window_fullscreen)

### Helper function

# Return a 0-filled PoolByteArray of a given size.
func blank_bytes(size: int) -> PoolByteArray:
	var pba = PoolByteArray()
	pba.resize(size)
	for i in range(size):
		pba[i] = 0
	return pba

# Return a randomized string for censored names.
const grawlix_chars = "£‡§ƒ¤±ℓ€÷∆√∫∑∂≠≤≥"
func grawlix(length: int) -> String:
	var out = ""
	for _i in range(length):
		out += grawlix_chars[
			rand_range(0, len(grawlix_chars) - 1)
		]
	return out

### Configuration

func save_settings():
	# Save it to a file (overwrite if already exists).
	cfg.save("user://config.cfg")

func load_settings():
	# Load data from a file.
	var err = cfg.load("user://config.cfg")
	# If the file didn't load, ignore it.
	if err != OK:
		return


func get_settings_value(key: String):
	return cfg.get_value("config", key, DEFAULT_CFG[key])


func set_settings_value(key: String, value):
	return cfg.set_value("config", key, value)


### save data
func load_save_data():
	var save = ConfigFile.new()
	var err = save.load("user://save.cfg")
	# If the file didn't load, ignore t.
	if err != OK:
		return
	# If the option isn't present in the file, don't reset it.
	for s in save.get_sections():
		for k in save.get_section_keys(s):
			save_data[s][k] = save.get_value(s, k)

func get_save_data_item(section, key, default_value = null):
	return save_data[section][key] if (
		section in save_data.keys() and\
		key in save_data[section].keys()
	) else default_value


func set_save_data_item(section, key, value):
	save_data[section][key] = value


func delete_save_data():
	save_data = DEFAULT_SAVE.duplicate()
	save_save_data()


func save_save_data():
	var save = ConfigFile.new()
	for s in save_data.keys():
		for k in save_data[s].keys():
			save.set_value(s, k, save_data[s][k])
	save.save("user://save.cfg")


const DEFAULT_HS = {
	"last_played": 0,
	"high_score": -1,
	"high_score_time": 0,
	"best_accuracy": -1,
	"best_accuracy_time": 0,
	"locked": true,
}
func init_high_score(ep_id: String):
	save_data.history[ep_id] = DEFAULT_HS.duplicate(true);


func get_high_score(ep_id: String):
	if not (ep_id in save_data.history.keys()):
		init_high_score(ep_id)
	else:
		for k in DEFAULT_HS.keys():
			if not (k in save_data.history[ep_id]):
				save_data.history[ep_id][k] = DEFAULT_HS[k]
	return save_data.history[ep_id]


func submit_high_score(score: int, accuracy: float):
	if not (pass_between.episode_data.filename in save_data.history.keys()):
		init_high_score(pass_between.episode_data.filename)
	var edited_high_score: bool = false
	var now = OS.get_unix_time()
	save_data.history[pass_between.episode_data.filename].last_played = now
	# check if high score is better
	if save_data.history[pass_between.episode_data.filename].high_score_time == 0\
	or score > save_data.history[pass_between.episode_data.filename].high_score:
		edited_high_score = true
		save_data.history[pass_between.episode_data.filename].high_score = score
		save_data.history[pass_between.episode_data.filename].high_score_time = now
	# check if accuarcy is better
	if !is_nan(accuracy) and (
		save_data.history[pass_between.episode_data.filename].best_accuracy_time == 0\
		or accuracy > save_data.history[pass_between.episode_data.filename].best_accuracy
	):
		edited_high_score = true
		save_data.history[pass_between.episode_data.filename].best_accuracy = accuracy
		save_data.history[pass_between.episode_data.filename].best_accuracy_time = now
	# check if new episode is unlocked
	if pass_between.episode_data.filename in unlocks.keys():
		for unlock in unlocks[pass_between.episode_data.filename]:
			if save_data.history[unlock].locked:
				edited_high_score = true
				save_data.history[unlock].locked = false
	if edited_high_score:
		save_save_data()

### currency formatting
var currency_data = {
  "name": "dollars"
, "multiplier": 1
, "decimalDigits": 0
, "decimalSymbol": "."
, "separatorDigits": [3]
, "separatorSymbol": ","
, "nega":   ["-$", ""]
, "zero":   ["±$", ""]
, "posi":   ["+$", ""]
, "noSign": [ "$", ""]
}

func set_currency(curr_name="fmt_dollars"):
	var fmt_file = File.new()
	var result = fmt_file.open("res://strings/%s.json" % curr_name, File.READ)
	if result == OK:
		result = JSON.parse(fmt_file.get_as_text())
		if result.error == OK:
			currency_data = result.result
		else:
			breakpoint
	fmt_file.close()

# Helper function to convert the score into a currency-signed and comma'd string.
func format_currency(score = 0.0, no_plus = false, min_digits = 0) -> String:
	score *= currency_data.multiplier
	var numText = str(int(floor(abs(score))))
	var digits = len(numText)
	var numText_ = ""
	var i = 0
	while true:
		if currency_data.separatorDigits[i] < len(numText):
			numText_ = currency_data.separatorSymbol + numText.right(
				len(numText) - currency_data.separatorDigits[i]
			) + numText_
			numText = numText.left(len(numText) - currency_data.separatorDigits[i])
			i = (i + 1) % len(currency_data.separatorDigits)
		else:
			break
	numText = numText + numText_
	var decimal_digits = max(currency_data.decimalDigits, min_digits - digits)
	if decimal_digits > 0:
		numText += currency_data.decimalSymbol + ("%0*.*f" % [
			decimal_digits + 2,
			decimal_digits,
			abs(score) - floor(abs(score))
		]).right(2) # get part after the "0."
	var sign_arr = currency_data.nega
	if score >= 0.0:
		if no_plus:
			sign_arr = currency_data.noSign
		elif score > 0.0:
			sign_arr = currency_data.posi
		else:
			sign_arr = currency_data.zero
	return sign_arr[0] + numText + sign_arr[1]

## date formatting
func format_date(unix_timestamp: int) -> String:
	# year, month, day, weekday, hour, minute, second
	var dict = Time.get_datetime_dict_from_unix_time(unix_timestamp)
	return "%04d-%02d-%02d %02d:%02d" % [
		dict.year, dict.month, dict.day,
		dict.hour, dict.minute
	]

func _set_visual_quality(quality: int = -1):
	if quality != -1:
		set_settings_value("graphics_quality", quality)
	else:
		quality = get_settings_value("graphics_quality")
	if quality == 0:
		get_tree().set_screen_stretch(
			SceneTree.STRETCH_MODE_VIEWPORT,
			SceneTree.STRETCH_ASPECT_KEEP,
			Vector2(1280, 720),
			1
		)
		get_tree().use_font_oversampling = false
	elif quality == 1:
		get_tree().set_screen_stretch(
			SceneTree.STRETCH_MODE_DISABLED,
			SceneTree.STRETCH_ASPECT_KEEP,
			Vector2(1280, 720),
			1
		)
		get_tree().use_font_oversampling = false
	else:
		get_tree().set_screen_stretch(
			SceneTree.STRETCH_MODE_DISABLED,
			SceneTree.STRETCH_ASPECT_KEEP,
			Vector2(1280, 720),
			1
		)
		get_tree().use_font_oversampling = true

### Crash handling

func crash(reason):
#	Ws.close_room()
	S.stop_voice()
	S.play_music("", 0)
	audience_keys = []
	
# warning-ignore:return_value_discarded
	get_tree().change_scene('res://essential/FatalError.tscn')
	call_deferred(
		"_deferred_crash", reason
	)

func _deferred_crash(reason):
# warning-ignore:unsafe_method_access
	get_tree().get_root().get_node('Error').set_reason(reason)
	S.play_sfx("naughty")

### Player stats

func get_lifesaver_count() -> int:
	var ans: int = 0
	for p in players:
		if p.has_lifesaver:
			ans += 1
	return ans

### Look up player slot from controller index (C.gd)
# Store controller indices previously asked for.
var slot_dict: Dictionary

func slot2player(slot) -> int:
	if slot_dict.has(slot):
		return slot_dict[slot]
	else:
		for i in len(players):
			if players[i].device_index == slot:
				slot_dict[slot] = i
				return i
		for i in len(audience):
			if audience[i].device_index == slot:
				slot_dict[slot] = i + get_settings_value("room_size") + 1
				return slot_dict[slot]
		slot_dict[slot] = -1
		return -1

func uuid_reset():
	slot_dict.clear()

### Audience join (here because people might join/leave mid-game)
# [TODO] Not implemented for Firebase

func listen_for_audience_join():
	pass
	if get_settings_value("room_openness") != 0 and get_settings_value("audience"):
#		Ws.connect("player_joined", self, 'audience_join')
# warning-ignore:return_value_discarded
		Fb.connect("player_joined", self, 'audience_join')
#		Ws.connect('player_requested_nick', self, "give_audience_nick")

func stop_listening_for_audience_join():
	pass
#	Ws.disconnect("player_joined", self, 'audience_join')
	Fb.disconnect("player_joined", self, 'audience_join')
#	Ws.disconnect('player_requested_nick', self, "give_audience_nick")

func audience_join(data):
	# join as audience if permitted
	if get_settings_value("audience"):
		# accept
		if not(data.name in audience_keys):
			var device_number = C.add_controller(C.DEVICES.REMOTE, data.name)
			var player = {
				name = ("AUDIENCE %d" % (len(audience_keys) + 1)) if data.nick == "" else data.nick,
				score = 0,
				device_name = data.name,
				device_index = device_number,
				player_number = get_settings_value("room_size") + 1 + len(audience),
			}
			Fb.add_remote_audience(player.device_name, player.name, len(audience))
			audience.push_back(player)
			audience_keys.push_back(data.name)
			update_audience_count()
		else:
			print("rejoin")
	else:
		# reject
#		Ws.kick_player(data.name)
		Fb.reject_remote_player(data.name)

func update_audience_count():
	emit_signal("change_audience_count", len(audience_keys))

### Room code generation
## Generate 4 ASCII uppercase letters, then try again if it gets censored
## lots of them are based on pokemon nickname censors
## ref: https://bulbapedia.bulbagarden.net/wiki/List_of_censored_words_in_Generation_V
## If a search for swear words led you here, I'm sorry.
const bad_room_codes = ["ARSE","ARSH","BICH","BITC","BITE","BSTD","BTCH","CAZI","CAZO","CAZZ","CHNK","CLIT","COCC","COCK","COCU","COKC","COKK","CONO","COON","CUCK","CULE","CULO","CUUL","CUMM","CUMS","CUNT","CUUM","DAMN","DICC","DICK","DICS","DICX","DIKC","DIKK","DIKS","DIKX","DIXX","DKHD","DYKE","FAAG","FAGG","FAGS","FFAG","FICA","FICK","FIGA","FOTZ","FCUK","FUCC","FUCK","FUCT","FUCX","FUKC","FUKK","FUKT","FUKX","FUXX","GIMP","GYPS","HEIL","HOES","HOMO","HORE","HTLR","JODA","JODE","JAPS","JEWS","JIPS","JIZZ","KACK","KIKE","KUNT","MERD","MRCA","MRCN","MRDE","NAZI","NCUL","NEGR","NGGR","NGRR","NGRS","NIGG","NIGR","NUTE","NUTT","PAKI","PCHA","PEDE","PEDO","PHUC","PHUK","PINE","PISS","PLLA","PNIS","POOP","PORN","POYA","PUTA","PUTE","PUTN","PUTO","RAEP","RAPE","SECS","SECX","SEKS","SEKX","SEXX","SHAT","SHIT","SHIZ","SHYT","SIMP","SLAG","SPAS","SPAZ","SPRM","TARD","TITS","TROA","TROI","TWAT","VAGG","VIOL","WANK","WHOR"];
const bad_room_substr = ["ASS","CUM","FAG","KKK"];
func generate_room_code():
	var buf: PoolByteArray = [0, 0, 0, 0]
	var code: String = ""
	while true:
		rng.randomize()
		for i in range(4):
			buf[i] = rng.randi_range(65, 90)
		code = buf.get_string_from_ascii()
		# validate
		if code in bad_room_codes: continue;
		var substr_passing: bool = true
		for substr in bad_room_substr:
			if code.find(substr) != -1:
				substr_passing = false; break
		if !substr_passing: continue
		return code
