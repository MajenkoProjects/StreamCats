extends Sprite2D

var direction = 0
var speed = 40
var nametimer = 0
var lift = 0
var lstep = 0

signal avatar_died
signal fight_timeout
signal fight_lost

var hitpoints:int = 10
var fighting = null
var challenge = null;
var fightlocation = null;
var fightdistance = null;

var miscData = {}
var username = ""

var alive = false

enum {
	MODE_SIT,
	MODE_RUN_LEFT,
	MODE_RUN_RIGHT,
	MODE_ENTER_SLEEP,
	MODE_SLEEP,
	MODE_WAKE,
	MODE_JUMP_LEFT,
	MODE_JUMP_RIGHT,
	MODE_FIGHT_START,
	MODE_FIGHT_RUN,
	MODE_LOSE,
	MODE_WIN
}

var mode = MODE_SIT
var jpos = 0

func _ready():
	randomize()
	
	var vps = get_viewport_rect().size
	
	position.x = (randi() % (int(vps.x) - 64)) + 32
	position.y = int(vps.y) - 16
	$Name.visible = 1
	$NameTimer.start()
	$SuicideTimer.start()
	$Neko.play("Sit")

func _process(delta):
	if (!alive):
		return
		
	var vps = get_viewport_rect().size
	position.x += direction * delta * speed
	if (lift < 0):
		lift = 0
	position.y = int(vps.y) - 16 - int(lift)
		
	var r = randi() % 100
	
	match mode:
		MODE_RUN_LEFT:
			position.x -= delta * speed
			if (lift > 0):
				lift -= delta * speed
			if (position.x < 20):
				mode = MODE_RUN_RIGHT
				$Neko.play("Run Right")
			elif (r == 0):
				mode = MODE_RUN_RIGHT
				$Neko.play("Run Right")
			elif (r == 1):
				mode = MODE_SIT
				$Neko.play("Sit")
		MODE_RUN_RIGHT:
			position.x += delta * speed
			if (lift > 0):
				lift -= delta * speed
			if (position.x > int(vps.x) - 20):
				mode = MODE_RUN_LEFT
				$Neko.play("Run Left")
			elif (r == 0):
				mode = MODE_RUN_LEFT
				$Neko.play("Run Left")
			elif (r == 1):
				mode = MODE_SIT
				$Neko.play("Sit")
		MODE_SIT:
			if (r == 0):
				mode = MODE_RUN_LEFT
				$Neko.play("Run Left")
			if (r == 1):
				mode = MODE_RUN_RIGHT
				$Neko.play("Run Right")
		MODE_WAKE:
			pass
		MODE_ENTER_SLEEP:
			pass
		MODE_SLEEP:
			pass
		MODE_JUMP_LEFT:
			jpos += delta
			position.x -= delta * speed * 2
			var l = int(sin(jpos*4) * 32)
			if (l < 0): 
				l = 0
			lift = l
		MODE_JUMP_RIGHT:
			jpos += delta
			position.x += delta * speed * 2
			var l = int(sin(jpos*4) * 32)
			if (l < 0): 
				l = 0
			lift = l
		MODE_FIGHT_START:
			if (position.x > fightlocation):
				position.x -= delta * speed;
				lift = (float(fightdistance - (position.x - fightlocation)) / float(fightdistance)) * 48.0
				if (position.x <= fightlocation):
					position.x = fightlocation
					$Neko.play("Fight Left")
					hitpoints = 10
					$HP.value = hitpoints
					$HP.show()
					$AttackTimer.start()
					mode = MODE_FIGHT_RUN
			else:
				position.x += delta * speed;
				lift = (float(fightdistance - (fightlocation - position.x)) / float(fightdistance)) * 48.0
				if (position.x >= fightlocation):
					position.x = fightlocation
					hitpoints = 10
					$HP.value = hitpoints
					$HP.show()
					$Neko.play("Fight Right")
					$AttackTimer.start()
					mode = MODE_FIGHT_RUN
		MODE_FIGHT_RUN:
			pass

func _on_name_timer_timeout():
	$Name.visible = 0

func setName(avatarName):
	username = avatarName
	if (!miscData.has("display-name")):
		$Name.text = avatarName
		miscData["display-name"] = avatarName

func _on_suicide_timer_timeout():
	avatar_died.emit(self)
	set_alive(false)

func is_alive():
	return alive

func set_alive(a):
	alive = a
	visible = a
	
func prod(nt:int, ct:int):
	$Name.visible = 1
	$NameTimer.start(nt)
	$SuicideTimer.start(ct)
	set_alive(true)

func setColour(colour):
	$Neko.modulate = colour


func _on_neko_animation_finished():
	match mode:
		MODE_ENTER_SLEEP:
			mode = MODE_SLEEP
			$Neko.play("Sleep")
		MODE_WAKE:
			mode = MODE_SIT
			$Neko.play("Sit")
		MODE_JUMP_LEFT:
			mode = MODE_RUN_LEFT
			$Neko.play("Run Left")
		MODE_JUMP_RIGHT:
			mode = MODE_RUN_RIGHT
			$Neko.play("Run Right")
		MODE_WIN:
			mode = MODE_SIT
			$Neko.play("Sit")
		MODE_LOSE:
			mode = MODE_SIT
			$Neko.play("Sit")
			

func sleep():
	mode = MODE_ENTER_SLEEP
	$Neko.play("Enter Sleep")
	
func wake():
	mode = MODE_WAKE
	$Neko.play("Wake")
	
func jump():
	jpos = 0
	match mode:
		MODE_RUN_LEFT:
			mode = MODE_JUMP_LEFT
			$Neko.play("Jump Left")
		MODE_RUN_RIGHT:
			mode = MODE_JUMP_RIGHT
			$Neko.play("Jump Right")
		_:
			if (randi() % 2 == 1):
				mode = MODE_JUMP_LEFT
				$Neko.play("Jump Left")
			else:
				mode = MODE_JUMP_RIGHT
				$Neko.play("Jump Right")

func start_challenge(user):
	challenge = user
	$FightTimer.start(30)
	
func get_challenge():
	return challenge

func _on_fight_timer_timeout():
	var c = String(challenge)
	fight_timeout.emit(self, c)
	challenge = null
	
func getName():
	return username

func startFight(user, loc):
	challenge = null
	fighting = user
	fightlocation = loc
	mode = MODE_FIGHT_START
	if (position.x > loc):
		fightdistance = position.x - loc
		print (position.x - loc)
		print(lstep)
		$Neko.play("Run Left")
	else:
		fightdistance = loc - position.x
		print(loc - position.x)
		print(lstep)
		$Neko.play("Run Right")
		
	$FightTimer.stop()
	$SuicideTimer.stop()
	
func getLocation():
	return position.x

	
	


func _on_attack_timer_timeout():
	var roll:int = randi() % 20
	fighting.claw(self, roll)

func claw(from, amount):
	var def:int = randi() % 20
	if (amount > def):
		hitpoints -= 1
		$HP.value = hitpoints
		if (hitpoints == 0):
			fight_lost.emit(self, from)

func lose_fight():
	$AttackTimer.stop()
	mode = MODE_LOSE
	$Neko.play("Lose")
	$HP.hide()
	
func win_fight():
	$AttackTimer.stop()
	mode = MODE_WIN
	$Neko.play("Win")
	$HP.hide()

func setData(d):
	miscData = d
	if miscData.has("display-name"):
		$Name.text = miscData["display-name"]

func set_sprite_frames(f):
	$Neko.set_sprite_frames(f)
