extends MeshInstance3D

class_name ProgressIndicator3D

@onready
var texture_progress_bar: TextureProgressBar = $SubViewport/CenterContainer/TextureProgressBar
@onready var label: Label = $SubViewport/CenterContainer/Label

var progress: int = 0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if progress >= 0:
		texture_progress_bar.value = progress
		label.text = "%d%%" % [progress]
	else:
		texture_progress_bar.value = 0
		label.text = "Remeshing"
