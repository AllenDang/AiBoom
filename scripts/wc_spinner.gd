extends TextureProgressBar


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(self, "radial_initial_angle", 360.0, 1.5).as_relative()
