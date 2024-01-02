extends Node2D

var Avatar = preload("res://Avatar.tscn")
var DataClass = preload("res://Data.gd")

var save_path = "user://streamcats.tres"

var irc = StreamPeerTCP.new()
var peerStatus = StreamPeerTCP.STATUS_NONE
var loginState = 0
var dataQueueString = ""

var Database: Data


enum {
	NET_IDLE,
	NET_DISCONNECTED,
	NET_CONNECTING,
	NET_CONNECTED
}

var netmode = NET_IDLE

func _ready():
	#Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	if ResourceLoader.exists(save_path):
		Database = load(save_path)
	else:
		Database = Data.new()

	$Popup/Menu.close_menu.connect(_on_close_menu)
	$Popup/Menu.connect_pressed.connect(_on_connect_pressed)
	$Popup/Menu.disconnect_pressed.connect(_on_disconnect_pressed)


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

func _on_avatar_died(av):
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
			$Popup/Menu.set_username(Database.Username)
			$Popup/Menu.set_password(Database.Password)
			$Popup/Menu.set_hostname(Database.Server)
			$Popup/Menu.set_port(Database.Port)
			$Popup/Menu.set_channel(Database.Channel)
			$Popup/Menu.set_autoconnect(Database.AutoConnect)
			$Popup/Menu.set_name_timeout(Database.NameTimeout)
			$Popup/Menu.set_cat_timeout(Database.CatTimeout)
			$Popup/Menu.set_attacks(Database.AttacksEnabled)
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
		
		a.avatar_died.connect(_on_avatar_died)
		a.fight_timeout.connect(_on_fight_timeout)
		a.fight_lost.connect(_on_fight_lost)

		if Database.Colours.has(username):
			a.setColour(Database.Colours[username])
		else:
			Database.Colours[username] = Color(randf(), randf() / 2, randf())
			a.setColour(Database.Colours[username])							

		Database.Avatars[username] = a
		add_child(a)
		return a

func run_command(avatar, command):
	var argv = command.split(" ")
	match argv[0]:
		"!color":
			var c = Color(argv[1].strip_edges())
			Database.Colours[avatar.getName()] = c
			avatar.setColour(Database.Colours[avatar.getName()])
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
				print("Starting attack with " + target)
				if (Database.Present.has(target)):
					print("Found that user")
					avatar.start_challenge(target)
					netsend("PRIVMSG " + Database.Channel + " :" + avatar.getName() + " has challenged @" + target + " to a cat fight. " + target + " must !accept within 30 seconds.")
				else:
					print("No such user")
		"!accept":
			if (Database.AttacksEnabled):
				var foundavatar = null
				for av in Database.Avatars:
					if (Database.Avatars[av].get_challenge() == avatar.getName()):
						print("Found challenge with " + av)
						foundavatar = av
				if (foundavatar == null):
					print("Cannot find attack")								
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

func _on_timer_timeout():
	$Label.text = str(Database.Avatars.size()) + " avatars"
