extends Node2D

var Avatar = preload("res://Avatar.tscn")
var DataClass = preload("res://Data.gd")

var save_path = "user://streamcats.tres"

var irc = StreamPeerTCP.new()
var peerStatus = StreamPeerTCP.STATUS_NONE
var loginState = 0
var dataQueueString = ""

var Database: Data

var Avatars = {}
var AvatarConfigs = {}

enum {
	NET_IDLE,
	NET_DISCONNECTED,
	NET_CONNECTING,
	NET_CONNECTED
}

var netmode = NET_IDLE

func _ready():
	#Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	load_avatars("res://Avatars")
	
	if !FileAccess.file_exists("user://Avatars/Neko/Avatar.ini"):
		import_avatar("res://Neko.Avatar")
	
	
	load_avatars("user://Avatars")
	
	if ResourceLoader.exists(save_path):
		Database = load(save_path)
	else:
		Database = Data.new()


	$Popup/Menu.close_menu.connect(_on_close_menu)
	$Popup/Menu.connect_pressed.connect(_on_connect_pressed)
	$Popup/Menu.disconnect_pressed.connect(_on_disconnect_pressed)
	$Popup/Menu.avatar_imported.connect(_on_avatar_imported)

func _process(_delta):
	match netmode:
		NET_IDLE:
			if Database.AutoConnect:
				var err = irc.connect_to_host(Database.Server, Database.Port)
				if (err == OK):
					irc.set_no_delay(true)
					netmode = NET_CONNECTING
					loginState = 0
					$IRCTimer.start()
				else:
					print("Error connecting to " + Database.Server + ":" + str(Database.Port))
					netmode = NET_IDLE

	irc.poll()
	var state = irc.get_status()
	
	if state != peerStatus:
		peerStatus = state

	if (state == StreamPeerTCP.STATUS_CONNECTED):
		var avail = irc.get_available_bytes()
		if (avail > 0):		
			var darr = irc.get_partial_data(avail)
			var bytes:PackedByteArray = darr[1]
			dataQueueString += bytes.get_string_from_ascii()

	if (dataQueueString.length() > 0):
		var rpos = dataQueueString.find("\n")
		if (rpos >= 0):
			var left = dataQueueString.substr(0, rpos).strip_edges()
			var right = dataQueueString.substr(rpos+1)
			dataQueueString = right
			
			process_message(left)
		

func _on_avatar_died(_av):
	pass
	
func _on_irc_timer_timeout():
	var state = irc.get_status()
	if (state == StreamPeerTCP.STATUS_CONNECTED):		
		match loginState:
			0:
				netsend("PASS " + Database.Password)
				loginState += 1
			1:
				netsend("NICK " + Database.Username)
				loginState += 1
			2:
				netsend("JOIN " + Database.Channel)
				loginState += 1
			3:
				netsend("CAP REQ :twitch.tv/membership twitch.tv/commands twitch.tv/tags")
				loginState += 1
			4:
				netmode = NET_CONNECTED
				$IRCTimer.stop()

func _on_save_timer_timeout():
	ResourceSaver.save(Database, save_path)

func _input(event):
	if (event is InputEventKey):
		if (event.pressed and event.keycode == KEY_ESCAPE):
			var avs = Avatars.keys()
			avs.sort()
			$Popup/Menu.set_avatars(avs)
			$Popup/Menu.set_username(Database.Username)
			$Popup/Menu.set_password(Database.Password)
			$Popup/Menu.set_hostname(Database.Server)
			$Popup/Menu.set_port(Database.Port)
			$Popup/Menu.set_channel(Database.Channel)
			$Popup/Menu.set_autoconnect(Database.AutoConnect)
			$Popup/Menu.set_name_timeout(Database.NameTimeout)
			$Popup/Menu.set_cat_timeout(Database.CatTimeout)
			$Popup/Menu.set_attacks(Database.AttacksEnabled)
			$Popup/Menu.set_commands(Database.CommandsEnabled)
			$Popup/Menu.set_avatar(Database.SelectedAvatars)
			$Popup.show()

func _on_close_menu():
	Database.Username = $Popup/Menu.get_username()
	Database.Password = $Popup/Menu.get_password()
	Database.Channel = $Popup/Menu.get_channel()
	Database.Server = $Popup/Menu.get_hostname()
	Database.Port = $Popup/Menu.get_port()
	Database.AutoConnect = $Popup/Menu.get_autoconnect()
	Database.NameTimeout = $Popup/Menu.get_name_timeout()
	Database.CatTimeout = $Popup/Menu.get_cat_timeout()
	Database.AttacksEnabled = $Popup/Menu.get_attacks()
	Database.CommandsEnabled = $Popup/Menu.get_commands()
	Database.SelectedAvatars = $Popup/Menu.get_avatar()
	
	for a in Database.Avatars.keys():
		if !Database.SelectedAvatars.has(Database.WhichAvatar[a]):
			Database.WhichAvatar[a] = Database.SelectedAvatars[randi() % Database.SelectedAvatars.size()]
			Database.Avatars[a].set_sprite_frames(Avatars[Database.WhichAvatar[a]])
			
	$Popup.hide()
	ResourceSaver.save(Database, save_path)

func _on_connect_pressed():
	if (netmode == NET_IDLE):
		var err = irc.connect_to_host(Database.Server, Database.Port)
		if (err == OK):
			netmode = NET_CONNECTING
			loginState = 0
			$IRCTimer.start()
		else:
			print("Error connecting to " + Database.Server + ":" + str(Database.Port))
			netmode = NET_IDLE

func _on_disconnect_pressed():
	if (netmode == NET_CONNECTED):
		irc.disconnect_from_host()
		netmode = NET_IDLE

func _on_fight_timeout(avatar, target):
	netsend("PRIVMSG " + Database.Channel + " :The fight between " + avatar.getName() + " and " + target + " timed out")

func netsend(msg):
	#print(">>> " + msg)
	msg += "\r\n"
	irc.put_data(msg.to_ascii_buffer())

func _on_fight_lost(loser, victor):
	loser.lose_fight()
	victor.win_fight()
	loser.prod(Database.NameTimeout, Database.CatTimeout)
	victor.prod(Database.NameTimeout, Database.CatTimeout)
	netsend("PRIVMSG " + Database.Channel + " :@" + victor.getName() + " beat @" + loser.getName() + " in a fair and open fight!")

func get_avatar(username:String, data):
	if (!Database.Present.has(username)):
		Database.Present.append(username)
	if (Database.Avatars.has(username)):
		var a = Database.Avatars[username]
		a.setData(data)
		return a
	else:
		var a = Avatar.instantiate()
		a.setName(username)
		a.setData(data)

		var avname = Database.SelectedAvatars[randi() % Database.SelectedAvatars.size()]
		if (Database.WhichAvatar.has(username)):
			avname = Database.WhichAvatar[username]
			if (!Database.SelectedAvatars.has(avname)):
				avname = Database.SelectedAvatars[randi() % Database.SelectedAvatars.size()]
		Database.WhichAvatar[username] = avname
		
		a.avatar_died.connect(_on_avatar_died)
		a.fight_timeout.connect(_on_fight_timeout)
		a.fight_lost.connect(_on_fight_lost)
		a.set_sprite_frames(Avatars[avname])

		Database.Avatars[username] = a
		add_child(a)
		return a

func run_command(avatar, command):
	if ! Database.CommandsEnabled:
		return
	var argv = command.split(" ")
	argv[0] = argv[0].to_lower()
	match argv[0].to_lower():

		"!avatars":
			var alist = ""
			for a in Database.SelectedAvatars:
				if (!alist == ""):
					alist += ", "
				alist += "\""
				alist += a
				alist += "\""
			netsend("PRIVMSG " + Database.Channel + " :Available avatars: " + alist)
		"!avatar":
			if (argv.size() > 1):
				if ! Database.SelectedAvatars.has(argv[1]):
					netsend("PRIVMSG " + Database.Channel + " :Sorry, @" + avatar.getName() + ", that avatar is unknown.")
					return
				Database.WhichAvatar[avatar.getName()] = argv[1]
				avatar.set_sprite_frames(Avatars[argv[1]])
			else:
				privmsg("@" + avatar.getName() + " Please tell me which avatar to select. Use !avatars to list them.")
		"!sleep":
			avatar.sleep()
		"!wake":
			avatar.wake()
		"!jump":
			avatar.jump()
		"!attack":
			if (Database.AttacksEnabled):
				var target = argv[1].to_lower()
				if (target[0] == "@"):
					target = target.substr(1)
				if (target == "random"):
					target = Database.Present[randi() % Database.Present.size()]
				if (Database.Present.has(target)):
					avatar.start_challenge(target)
					netsend("PRIVMSG " + Database.Channel + " :" + avatar.getName() + " has challenged @" + target + " to a cat fight. " + target + " must !accept within 30 seconds.")
				else:
					netsend("PRIVMSG " + Database.Channel + " :@" + avatar.getName() + " - Sorry, that user is not known")
		"!accept":
			if (Database.AttacksEnabled):
				var foundavatar = null
				for av in Database.Avatars:
					if (Database.Avatars[av].get_challenge() == avatar.getName()):
						foundavatar = av
				if (foundavatar == null):
					netsend("PRIVMSG " + Database.Channel + " :@" + avatar.getName() + " - Sorry, you have not been challenged")
				else:
					var them = Database.Avatars[foundavatar]
								
					var x1 = avatar.getLocation()
					var x2 = them.getLocation()
					var midpoint = 0
					if (x1 > x2):
						midpoint = x2 + ((x1 - x2) / 2)
						avatar.startFight(them, midpoint + 16)
						them.startFight(avatar, midpoint - 16)
					else:
						midpoint = x1 + ((x2 - x1) / 2)
						avatar.startFight(them, midpoint - 16)
						them.startFight(avatar, midpoint + 16)

func process_message(message):
	var re = RegEx.new()
	var res
	#print("<<< " + message)
	re.compile("^PING")
	if (re.search(message)):
		netsend("PONG :StreamCats")	
		return

	re.compile("^:([^!]+)!.+\\s+PRIVMSG\\s[^\\s]+\\s:(.*)$")
	res = re.search(message)
	if (res):
		var dict = {}
		var username = res.get_string(1)
		var mess = res.get_string(2)
		dict["display-name"] = username
		dict["subscriber"] = 0
		var avatar = get_avatar(username, dict)
		avatar.prod(Database.NameTimeout, Database.CatTimeout)
		if mess.begins_with("!"):
			run_command(avatar, mess)
		return

	re.compile("^@([^\\s]+)\\s+:([^!]+)!.+\\s+PRIVMSG\\s[^\\s]+\\s:(.*)$")
	res = re.search(message)
	if (res):
		var dict = {}
		var parts = res.get_string(1).split(";")
		for part in parts:
			var kv = part.split("=")
			dict[kv[0]] = kv[1]
		var username = res.get_string(2)
		var mess = res.get_string(3)
		var avatar = get_avatar(username, dict)
		avatar.prod(Database.NameTimeout, Database.CatTimeout)
		if mess.begins_with("!"):
			run_command(avatar, mess)
		return

	re.compile("^:([^!]+)!.+ JOIN (.*)$")
	res = re.search(message)
	if (res):
		var username = res.get_string(1)
		if (!Database.Present.has(username)):
			Database.Present.append(username)
		return

	re.compile("^:([^!]+)!.+ PART (.*)$")
	res = re.search(message)
	if (res):
		var username = res.get_string(1)
		if (Database.Present.has(username)):
			Database.Present.erase(username)
		return

func load_avatar(path):
	var conf = ConfigFile.new()
	

	if (conf.load(path + "/" + "Avatar.ini") != OK):
		print("Error loading config file")



	var anim = SpriteFrames.new()
	
	var aname = conf.get_value("general", "name")
	load_animation(path, anim, conf, "Enter Sleep", false)
	load_animation(path, anim, conf, "Fight Left", true)
	load_animation(path, anim, conf, "Fight Right", true)
	load_animation(path, anim, conf, "Jump Left", false)
	load_animation(path, anim, conf, "Jump Right", false)
	load_animation(path, anim, conf, "Lose", false)
	load_animation(path, anim, conf, "Run Left", true)
	load_animation(path, anim, conf, "Run Right", true)
	load_animation(path, anim, conf, "Sit", false)
	load_animation(path, anim, conf, "Sleep", true)
	load_animation(path, anim, conf, "Wake", false)
	load_animation(path, anim, conf, "Win", false)
	
	Avatars[aname] = anim
	AvatarConfigs[aname] = conf

func load_animation(path, anim, conf, aname, loop):
	var sec = aname.replace(" ", "").to_lower()
	anim.add_animation(aname)
	anim.set_animation_speed(aname, conf.get_value(sec, "speed"))
	anim.set_animation_loop(aname, loop)
	var frames:Array = conf.get_value(sec, "frames")
	for frame in frames:
		anim.add_frame(aname, ImageTexture.create_from_image(Image.load_from_file(path + "/" + frame)))

func load_avatars(root):
	var dir = DirAccess.open(root)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if FileAccess.file_exists(root + "/" + file_name + "/Avatar.ini"):
					load_avatar(root + "/" + file_name )
			file_name = dir.get_next()
					
func dir_contents(path):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				print("Found directory: " + file_name)
			else:
				print("Found file: " + file_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")

func _on_avatar_imported(path):
	load_avatar(path)
	var avs = Avatars.keys()
	avs.sort()
	$Popup/Menu.set_avatars(avs)
	$Popup/Menu.set_avatar(Database.SelectedAvatars)

func import_avatar(path):
	
	var zip = ZIPReader.new()
	var err = zip.open(path)
	if (err != OK):
		return
	if (!zip.file_exists("Avatar.ini")):
		return
	var info = zip.read_file("Avatar.ini")
	var conf = ConfigFile.new()
	conf.parse(info.get_string_from_ascii())
	if (!conf.has_section_key("general", "name")):
		return
	var aname = conf.get_value("general", "name")
	DirAccess.make_dir_recursive_absolute("user://Avatars/" + aname)
	for f in zip.get_files():
		var infile = zip.read_file(f)
		var outname = "user://Avatars/" + aname + "/" + f
		var outfile = FileAccess.open(outname, FileAccess.WRITE)
		outfile.store_buffer(infile)
		outfile.close()



func privmsg(msg):
	netsend("PRIVMSG " + Database.Channel + " :" + msg)
