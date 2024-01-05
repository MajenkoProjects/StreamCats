extends Control

signal close_menu
signal connect_pressed
signal disconnect_pressed
signal avatar_imported

var currentImportPath = null

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
	$Timeouts/Name/Timeout.value = t

func set_cat_timeout(t):
	$Timeouts/Cat/Timeout.value = t

func set_attacks(a):
	$Attacks.button_pressed = a
	
func set_commands(c):
	$Commands.button_pressed = c

func set_avatars(alist):
	for c in $Avatars/S/B.get_children():
		$Avatars/S/B.remove_child(c)
		c.queue_free()
	
	for a in alist:
		var cb = CheckButton.new()
		cb.text = a
		$Avatars/S/B.add_child(cb)

func set_avatar(a):
	
	for av in $Avatars/S/B.get_children():
		av.button_pressed = a.has(av.text)

func get_avatar():
	var out = []
	for av in $Avatars/S/B.get_children():
		if av.button_pressed:
			out.append(av.text)
	return out

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
	return $Timeouts/Name/Timeout.value

func get_cat_timeout():
	return $Timeouts/Cat/Timeout.value
	
func get_attacks():
	return $Attacks.button_pressed

func get_commands():
	return $Commands.button_pressed

func _on_ok_pressed():
	close_menu.emit()


func _on_connect_pressed():
	connect_pressed.emit()


func _on_disconnect_pressed():
	disconnect_pressed.emit()


func _on_import_pressed():
	print("Import Pressed")
	var fd = FileDialog.new()
	fd.add_filter("*.Avatar")
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	fd.access = FileDialog.ACCESS_FILESYSTEM
	if (currentImportPath != null):
		fd.current_path = currentImportPath
		fd.current_dir = currentImportPath
		fd.current_file = currentImportPath
		print(currentImportPath)
	fd.file_selected.connect(_on_do_import)
	fd.files_selected.connect(_on_do_import_many)
	add_child(fd)
	fd.popup_centered_ratio()

func _on_do_import_many(paths):
	for path in paths:
		_on_do_import(path)
		
func _on_do_import(path):
	var parts = path.split("/")
	parts.remove_at(parts.size()-1)
	currentImportPath = ""
	for part in parts:
		currentImportPath += part + "/"
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
	avatar_imported.emit("user://Avatars/" + aname)
