extends Camera3D

var zoom_speed: float = 0.2
var pan_speed: float = 0.01

var is_panning: bool = false
var last_mouse_position: Vector2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if is_panning:
			var delta = event.relative * position.z * 0.2
			translate(Vector3(-delta.x * pan_speed, delta.y * pan_speed, 0))
	elif event is InputEventMouseButton:
		if event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_UP:
			if position.z > 2.0:
				translate(Vector3(0, 0, -zoom_speed))
		elif event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
			translate(Vector3(0, 0, zoom_speed))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				is_panning = true
				last_mouse_position = event.position
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				is_panning = false
