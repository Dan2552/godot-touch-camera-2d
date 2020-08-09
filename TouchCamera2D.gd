class_name TouchCamera2D, "res://touch_camera_icon.svg"

extends Camera2D

# The minimum camera zoom
export var min_zoom: float = 0.5

# The maximum camera zoom
export var max_zoom: float = 2

# Represents the amount of pixels traveled before the zoom action begins
export var zoom_sensitivity: int = 10

# How much the zoom will be incremented/decremented when the action happens
export var zoom_increment: float = 0.05

# If true the camera can be moved while zooming
# Relevant only for pinch to zoom actions
export var move_while_zooming: bool = true

# If true, allows the mouse wheel to change the zoom, and click and drag
# to pan the camera (without the need of emulating touch from mouse)
export var handle_mouse_events: bool = true

# How much the mouse wheel will incremented/decremented the zoom
export var mouse_zoom_increment: float = 0.1

# The last distance between two touches.
# The last_pinch_distance will be compared to the current pinch distance to
# determine if the zoom needs to be incremented or decremented
var last_pinch_distance: float = 0

# Dictionary that holds the events in case of multitouch
# The InputEventScreen Touch/Drag only represents the last touch, even in case
# of multi touches. So, to hold the information off all touches you have
# to store previous events for latter use
var events = {}

# Viewport size
var vp_size := Vector2.ZERO


# Connects the viewport signal
func _ready() -> void:
	# This call initializes the vp_size reference
	_on_viewport_size_changed()

	# If the signal connection is not OK
	if get_viewport().connect("size_changed",
			self,"_on_viewport_size_changed") != OK:
		# Sets vp_size
		vp_size = get_viewport().size


# Captures the unhandled inputs to verify the action to be executed by
# the camera
func _unhandled_input(event: InputEvent) -> void:
	# If event is a touch
	if event is InputEventScreenTouch:
		# And it's pressed
		if event.is_pressed():
			# Stores the event in the dictionary
			events[event.index] = event

		# If it's not pressed
		else:
			# Erases this event from the dictionary
			events.erase(event.index)

	# If it's set to handle the mouse events, it's a Left button
	# and it's pressed
	elif handle_mouse_events and event is InputEventMouseButton:
		if event.get_button_index() == BUTTON_LEFT:
			if event.is_pressed():
				# Stores the event in the dictionary
				events[0] = event

			# If it's not pressed
			else:
				# Erases this event from the dictionary
				events.erase(0)

		# If move while zooming is set true it means that the event stored
		# have to stay in the dictionary to allow the camera to move
		# Otherwise it can be erased
		elif not move_while_zooming:
			# Checks if the key exists
			if events.has(0):
				# Erases this event from the dictionary
				events.erase(0)

	# If it's a motion
	if ( (event is InputEventScreenDrag)
			or (handle_mouse_events and event is InputEventMouseMotion) ):
		# If it's a ScreenDrag
		if event is InputEventScreenDrag:
			var last_pos: Vector2 = events[event.index].position

			# If the distance between this touch index and the stored
			# is greater than the zoom sensitivity
			if last_pos.distance_to(event.position) > zoom_sensitivity:
				# Update the event stored in the dictionary
				events[event.index] = event

		# If the dictionary have only one event stored, it means that
		# the user is moving the camera
		if events.size() == 1:
			set_position(position - event.relative * zoom)

		# If there are more than one finger on screen
		if events.size() == 2 and events.has_all([0, 1]):
			# Stores the touches position
			var p1: Vector2 = events[0].position
			var p2: Vector2 = events[1].position

			# If move while zooming is set true
			if move_while_zooming:
				# Sets the position of the camera considering the average
				# position of the touches
				set_position(position - event.relative / 2 * zoom)

			# Calculates the distance between them
			var pinch_distance: float = p1.distance_to(p2)
			# If the absolute difference between the last and the
			# current pinch distance is greater than the zoom sensitivity
			if abs(pinch_distance - last_pinch_distance) > zoom_sensitivity:
				var new_zoom: float

				# If the pinch distance is lower than the last pinch distance
				# it means that a zoom-out action is happening
				if pinch_distance < last_pinch_distance:
					new_zoom = (zoom.x + zoom_increment)

				# Otherwise a zoom-in
				else:
					new_zoom = (zoom.x - zoom_increment)

				# Updates the camera's zoom
				set_zoom(new_zoom * Vector2.ONE)

				# Stores the current pinch_distance as the last for
				# future verification
				last_pinch_distance = pinch_distance

	# If the mouse events is set to be handled
	elif handle_mouse_events:
		if event is InputEventMouseButton and event.is_pressed():
			var zoom_diff := Vector2(mouse_zoom_increment, mouse_zoom_increment)
			# Wheel up = zoom-in
			if event.get_button_index() == BUTTON_WHEEL_UP:
				set_zoom(zoom - zoom_diff)

			# Wheel down = zoom-out
			if event.get_button_index() == BUTTON_WHEEL_DOWN:
				set_zoom(zoom + zoom_diff)


# Updates the reference vp_size properly when the viewport change size
func _on_viewport_size_changed() -> void:
	print(get_viewport().get_size_override())
	# If the stretch mode is set to disabled or viewport, the size override will
	# always be (0, 0). And if that's the case, the vp_size will be the
	# viewport size
	if get_viewport().get_size_override() == Vector2.ZERO:
		vp_size = get_viewport().size

	# Otherwise, vp_size will be the size_override
	else:
		vp_size = get_viewport().get_size_override()


# Sets the camera's zoom making sure it stays between the minimum and maximum
func set_zoom(new_zoom: Vector2) -> void:
	new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
	zoom = Vector2.ONE * new_zoom.x


# Sets the camera's position making sure it stays between the scroll limits
func set_position(new_position: Vector2) -> void:
	var offset: Vector2
	var left: float
	var right: float
	var top: float
	var bottom: float

	# If the camera's anchor is set to center, to make sure the camera's
	# position stays inside the scroll limits, the position can't be less than
	# the left/top (bottom/right as well) limit plus half the viewport
	# times the zoom
	if anchor_mode == ANCHOR_MODE_DRAG_CENTER:
		offset = vp_size / 2
		left = limit_left + offset.x * zoom.x
		top = limit_top + offset.y * zoom.y

	# If the anchor is set to top left, the left/top limits are not influenced
	# by the offset. Consequently the offset for bottom/right limits are the
	# entire viewport times the zoom
	elif anchor_mode == ANCHOR_MODE_FIXED_TOP_LEFT:
		offset = vp_size
		left = limit_left
		top = limit_top

	# Apply the offset to the bottom/right limits
	right = limit_right - offset.x * zoom.x
	bottom = limit_bottom - offset.y * zoom.y

	# Makes sure that the camera's position stays between the scroll limits
	position.x = clamp(new_position.x, left, right)
	position.y = clamp(new_position.y, top, bottom)