extends KinematicBody2D

const SPEED = 125
var is_input_blocked = false

enum {NORTH, NORTHEAST, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST, NORTHWEST}
const MAX_CARDDIR = 7
const directions_dict = {
	NORTH: 0, NORTHEAST: 45,
	EAST: 90, SOUTHEAST: 135,
	SOUTH: 180, SOUTHWEST: 225,
	WEST: 270, NORTHWEST: 315}
const cardinal_margin = 0.2

var is_lunging = false
var lunge_dir = Vector2()
const LUNGE_SPEED = 200
const LUNGE_MAX_TIME = 1
var lunge_time = 0
const LUNGE_COOLDOWN_TIME = 2
var lunge_cooldown = LUNGE_COOLDOWN_TIME

var host
const MAX_HEALTH = 3
var health = MAX_HEALTH

func _physics_process(delta):
	if not is_input_blocked:
		move(delta)

	if is_lunging and lunge_time < LUNGE_MAX_TIME:
		lunge_move(delta)
		lunge_time += delta
	else:
		if is_lunging:
			stop_lunge()
		lunge_cooldown += delta



func lunge(dir = null):
	if lunge_cooldown < LUNGE_COOLDOWN_TIME:
		return
	lunge_time = 0
	is_lunging = true
	if not dir == null:
		lunge_dir = dir
	else:
		lunge_dir = get_input_dir()
	rotate_to_dir(lunge_dir)
	is_input_blocked = true


func lunge_move(delta):
	if not lunge_dir or lunge_dir == Vector2.ZERO:
		stop_lunge()
		return
	var vel = lunge_dir * LUNGE_SPEED * delta
	var col = move_and_collide(vel)
	if col:
		print("hit something")
		stop_lunge()
		if col.collider.is_in_group("crew"):
			get_node("/root/world/possess").play()
			host = col.collider
			host.change_state(host.POSSESSED)
			get_node("col").set_disabled(true)
			set_visible(false)
			set_global_transform(host.get_global_transform())


func stop_lunge():
	print("stopped")
	is_lunging = false
	lunge_time = 0
	lunge_cooldown = 0
	get_node("col").set_disabled(false)
	set_collision_mask_bit(2, true)
	print(get_collision_mask_bit(2))
	is_input_blocked = false


func release_host():
	lunge_cooldown = LUNGE_COOLDOWN_TIME
	set_collision_mask_bit(2, false)
	var htform = host.get_global_transform()
	set_global_transform(htform)
	lunge()
	if not host.status == host.DEAD:
		host.change_state(host.STUNNED)
	host = null
	get_node("col").set_disabled(false)
	print(get_node("col").is_disabled())
	set_visible(true)


func release_host_proxy():
	release_host()


func _input(event):
	if event is InputEventKey and event.is_pressed():
		if event.scancode == KEY_SPACE and Input.is_key_pressed(KEY_SHIFT):
			if host and not is_input_blocked:
				release_host()
			elif not is_input_blocked:
				lunge()
		if event.scancode == KEY_SPACE:
			if is_input_blocked:
				return
			if is_behind_crew():
				print("Stabby time")
				if host:
					find_first_crew(host.get_node("view/front").get_overlapping_bodies()).die()
					host.is_suspicious = true
				else:
					find_first_crew(get_node("front").get_overlapping_bodies()).die()
			elif host and door_infront():
				door_infront().toggle(host.role)


func door_infront():
	var bodies = host.get_node("view/front").get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("door"):
			return body


func find_first_crew(bodies):
	for body in bodies:
		if body.is_in_group("crew"):
			return body


func is_behind_crew():
	var bodies
	if host:
		bodies = host.get_node("view/front").get_overlapping_bodies()
	else:
		bodies = get_node("front").get_overlapping_bodies()
	
	print(bodies)
	for body in bodies:
		print(body.get_name())
		if body == host:
			continue
		if body.is_in_group("crew"):
			if not body.is_dead():
				return true
	return false


func move(delta):
	var dir = get_input_dir()
	if host:
		if dir != Vector2.ZERO:
			host.rotate_to_vdir(dir)
			if not host.sprite.is_playing():
				host.sprite.play()
		else:
			host.sprite.stop()
			host.sprite.set_frame(0)
		host.move_and_slide(dir.normalized() * SPEED)
		set_global_position(host.get_global_position())
	else:
		get_node("front").look_at(get_global_position() + dir)
		move_and_slide(dir * SPEED)


func rotate_to_dir(dir):
	get_node("front").look_at(get_global_position() + dir)

func get_rotation_from_dir(dir):
	var cardinal_margin = 0.2
	var direction = 0

	if dir.y > 0 and dir.y > cardinal_margin:
		if dir.x < cardinal_margin and dir.x > -cardinal_margin:
			direction = SOUTH
		elif dir.x > cardinal_margin:
			direction = SOUTHEAST
		elif dir.x < -cardinal_margin:
			direction = SOUTHWEST

	elif dir.y < 0 and dir.y < -cardinal_margin:
		if dir.x < cardinal_margin and dir.x > -cardinal_margin:
			direction = NORTH
		elif dir.x > cardinal_margin:
			direction = NORTHEAST
		elif dir.x < -cardinal_margin:
			direction = NORTHWEST
	elif dir.x > 0:
		direction = EAST
	elif dir.x < 0:
		direction = WEST

	return direction


func get_input_dir():
	if is_input_blocked:
		return

	var dir = Vector2()
	if Input.is_key_pressed(KEY_A):
		dir.x += -1
	if Input.is_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_key_pressed(KEY_W):
		dir.y += -1
	if Input.is_key_pressed(KEY_S):
		dir.y += 1
	return dir.normalized()


func get_hit():
	health -= 1
	if health <= 0:
		print("IM DEAD")