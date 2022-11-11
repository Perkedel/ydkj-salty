extends Node
### "Root", for data that every page should have.
signal change_audience_count(audience_count)

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
onready var rng = RandomNumberGenerator.new()
var pass_between = {}
var players = []
var audience = []
# Store unique IDs of audience controllers for easier access.
var audience_keys = []
var cuss_regex = RegEx.new()
# 0: Render at 1280x720. Disable most shader animations.
# 1: Stretch to window size. Disable most shader animations.
# 2: Stretch to window size. Enable all shader animations.
var cfg = {
	graphics_quality = 2,
	room_size = 7,
	room_openness = 2,
	audience = true,
	subtitles = true,
	overall_volume = 15,
	music_volume = 15,
	cutscenes = true,
	hide_room_code = false,
	hide_room_code_ingame = false,
	awesomeness = true
}

var save_data = {
	history = {
		"random": {
			"last_played": 0,
			"high_score": -1,
			"best_accuracy": -1,
			"locked": false,
		},
		"demo": {
			"last_played": 0,
			"high_score": -1,
			"best_accuracy": -1,
			"locked": false,
		},
		"ep_1": {
			"last_played": 0,
			"high_score": -1,
			"best_accuracy": -1,
			"locked": false,
		},
		"ep_2": {
			"last_played": 0,
			"high_score": -1,
			"best_accuracy": -1,
			"locked": true,
		},
		"ep_3": {
			"last_played": 0,
			"high_score": -1,
			"best_accuracy": -1,
			"locked": true,
		}
	},
	achievements = {
		
	},
	misc = {
		cuss_history = []
	}
}

# Called when the node enters the scene tree for the first time.
func _ready():
	rng.randomize()
	set_currency("fmt_dollars")
	var result = cuss_regex.compile("F+U+C+K+[^A-Z]*(Y+O+U|O+F)")
	if result != OK:
		print("Could not compile cuss RegEx: error code %d" % result)
	load_settings()
	load_save_data()
	_set_visual_quality(cfg.graphics_quality)

### Helper function

# Return a 0-filled PoolByteArray of a given size.
func blank_bytes(size: int) -> PoolByteArray:
	var pba = PoolByteArray()
	pba.resize(size)
	for i in range(size):
		pba[i] = 0
	return pba

### Configuration

func save_settings():
	# Create new ConfigFile object.
	var config = ConfigFile.new()
	# Store some values.
	for k in cfg.keys():
		config.set_value("config", k, cfg[k])
	# Save it to a file (overwrite if already exists).
	config.save("user://config.cfg")

func load_settings():
	var config = ConfigFile.new()
	# Load data from a file.
	var err = config.load("user://config.cfg")
	# If the file didn't load, ignore it.
	if err != OK:
		return
	# Don't reset; Make sure every option is present,
	# by starting with a copy of the default config.
	#cfg = {}
	# Iterate over all sections.
	for k in config.get_section_keys("config"):
		# Fetch the data for each section.
		cfg[k] = config.get_value("config", k)

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

func set_save_data_item(section, key, value):
	save_data[section][key] = value

func save_save_data():
	var save = ConfigFile.new()
	for s in save_data.keys():
		for k in save_data[s].keys():
			save.set_value(s, k, save_data[s][k])
	save.save("user://save.cfg")

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
func format_currency(score = 0.0, no_plus = false, min_digits = 0):
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

func _set_visual_quality(quality):
	cfg.graphics_quality = quality
	if cfg.graphics_quality == 0:
		get_tree().set_screen_stretch(
			SceneTree.STRETCH_MODE_VIEWPORT,
			SceneTree.STRETCH_ASPECT_KEEP,
			Vector2(1280, 720),
			1
		)
		get_tree().use_font_oversampling = false
	elif cfg.graphics_quality == 1:
		get_tree().set_screen_stretch(
			SceneTree.STRETCH_MODE_2D,
			SceneTree.STRETCH_ASPECT_KEEP,
			Vector2(1280, 720),
			1
		)
		get_tree().use_font_oversampling = false
	else:
		get_tree().set_screen_stretch(
			SceneTree.STRETCH_MODE_2D,
			SceneTree.STRETCH_ASPECT_KEEP,
			Vector2(1280, 720),
			1
		)
		get_tree().use_font_oversampling = true

### Crash handling

func crash(reason):
	Ws.close_room()
	S.stop_voice()
	S.play_music("", 0)
	audience_keys = []
	
	get_tree().change_scene('res://Error.tscn')
	call_deferred(
		"_deferred_crash", reason
	)

func _deferred_crash(reason):
	get_tree().get_root().get_node('Error').set_reason(reason)
	S.play_sfx("naughty")

### Player stats

func get_lifesaver_count() -> int:
	var ans: int = 0
	for p in players:
		if p.has_lifesaver:
			ans += 1
	return ans

### Audience join (here because people might join/leave mid-game)

func listen_for_audience_join():
	if cfg.room_openness != 0 and cfg.audience:
		Ws.connect("player_joined", self, 'audience_join')
		Ws.connect('player_requested_nick', self, "give_audience_nick")

func stop_listening_for_audience_join():
	Ws.disconnect("player_joined", self, 'audience_join')
	Ws.disconnect('player_requested_nick', self, "give_audience_nick")

func audience_join(data):
	# join as audience if permitted
	if R.cfg.audience:
		# accept
		if not(data.name in audience_keys):
			var player = {
				name = ("AUDIENCE %d" % (len(audience_keys) + 1)) if data.nick == "" else data.nick,
				score = 0,
				device_name = data.name,
				player_number = cfg.room_size + len(audience),
			}
			audience.push_back(player)
			audience_keys.push_back(data.name)
			update_audience_count()
		else:
			print("rejoin")
	else:
		# reject
		Ws.kick_player(data.name)

func give_audience_nick(id):
	var i = audience_keys.find(id)
	if i != -1:
		Ws.send('message', {
			'to': id,
			'action': 'changeNick',
			'nick': audience[i].name,
			'playerIndex': 8,
			'isVip': 0
		})
		return

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
		var rng = RandomNumberGenerator.new()
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
