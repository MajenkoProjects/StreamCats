extends Control

signal close_menu
signal connect_pressed
signal disconnect_pressed

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func set_username(u):
	$Username/IRCUsername.text = u

func set_password(p):
	$Password/IRCPassword.text = p

func set_hostname(h):
	$Hostname/IRCHostname.text = h

func set_channel(c):
	$Channel/IRCChannel.text = c

func set_port(p):
	$Port/IRCPort.get_line_edit().text = str(p)

func set_autoconnect(a):
	$IRCAutoConnect.button_pressed = a

func set_name_timeout(t):
	$Name/Timeout.get_line_edit().text = str(t)

func set_cat_timeout(t):
	$Cat/Timeout.get_line_edit().text = str(t)

func set_attacks(a):
	$Attacks.button_pressed = a

func get_username():
	return $Username/IRCUsername.text

func get_password():
	return $Password/IRCPassword.text

func get_hostname():
	return $Hostname/IRCHostname.text

func get_channel():
	return $Channel/IRCChannel.text

func get_port():
	return int($Port/IRCPort.get_line_edit().text)

func get_autoconnect():
	return $IRCAutoConnect.button_pressed

func get_name_timeout():
	return int($Name/Timeout.get_line_edit().text)

func get_cat_timeout():
	return int($Cat/Timeout.get_line_edit().text)

func get_attacks():
	return $Attacks.button_pressed

func _on_ok_pressed():
	close_menu.emit()


func _on_connect_pressed():
	connect_pressed.emit()


func _on_disconnect_pressed():
	disconnect_pressed.emit()
