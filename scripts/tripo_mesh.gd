extends Node3D

class_name TripoMesh

const GROUP_TRIPO_MESH: String = "tripo_mesh"
const GLTF_NODE: String = "gltf_node"

var prompt: String
var task_id: String
var save_to_dir: String

# Bounding box
var is_selected = false
var bbox_mesh_instance = null
var bbox_material = null

# Variables to store the previous mouse position
var _previous_mouse_position = Vector2.ZERO
var _dragging = false

# Sensitivity of the rotation
var rotation_sensitivity: float = 0.01

@onready
var prefab_progress_indicator_3d: PackedScene = preload("res://prefabs/progress_indicator_3d.tscn")
var progress: ProgressIndicator3D

var _headers = []

signal model_generate_success(url: String)
signal model_generate_failed


func _init(_key: String, _prompt: String, _save_to_dir: String):
	self.prompt = _prompt
	self.save_to_dir = _save_to_dir

	_headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % [_key],
	]

	model_generate_success.connect(_on_model_generate_success)
	model_generate_failed.connect(_on_model_generate_failed)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group(GROUP_TRIPO_MESH)

	var n = get_tree().get_nodes_in_group(GROUP_TRIPO_MESH).size()
	position = _generate_spiral_grid(n, 1.2, 1.2)

	self.progress = prefab_progress_indicator_3d.instantiate()
	self.progress.name = "progress"
	add_child(self.progress)

	create_task(self.prompt)


func _exit_tree() -> void:
	remove_from_group(GROUP_TRIPO_MESH)


func _input(event):
	# If the left mouse button is pressed, start dragging
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_previous_mouse_position = event.position

		if event.pressed:
			var camera = get_viewport().get_camera_3d()
			var from = camera.project_ray_origin(event.position)
			var to = from + camera.project_ray_normal(event.position) * 1000

			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(from, to)
			query.collide_with_areas = true

			var result = space_state.intersect_ray(query)

			if result and result.collider.get_parent().name == GLTF_NODE:
				is_selected = not is_selected
				if is_selected:
					draw_bounding_box()
				else:
					bbox_mesh_instance.mesh.clear_surfaces()

	# If the mouse is being dragged, rotate the node
	if has_node(GLTF_NODE) and _dragging and event is InputEventMouseMotion:
		var delta = event.relative
		get_node(GLTF_NODE).rotate_y(delta.x * rotation_sensitivity)


func _on_model_generate_success(url: String):
	print("downloading %s" % [url])
	EasyHttp.new(self, _on_download_success, _on_download_failed).download(
		url, self._headers, self.save_to_dir
	)


func _on_model_generate_failed():
	queue_free()


func _on_download_success(_code: int, data: Dictionary):
	var gltf_doc = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	var err = gltf_doc.append_from_file(data.path, gltf_state)
	if err == OK:
		var gltf_node = gltf_doc.generate_scene(gltf_state)
		gltf_node.name = GLTF_NODE

		var aabb = get_gltf_aabb(gltf_node)
		add_collision_shape_to_gltf(gltf_node, aabb)

		# prepare bounding box
		bbox_mesh_instance = MeshInstance3D.new()
		gltf_node.add_child(bbox_mesh_instance)

		var bbox_mesh = ImmediateMesh.new()
		bbox_mesh_instance.mesh = bbox_mesh

		bbox_material = StandardMaterial3D.new()
		bbox_material.albedo_color = Color(1, 0, 0)  # Red color
		bbox_mesh_instance.material_override = bbox_material

		add_child(gltf_node)
	else:
		print("cannot load gltf scene")

	self.progress.queue_free()


func _on_download_failed(_code: int):
	queue_free()


func create_task(_prompt: String):
	var body = {
		"type": "text_to_model",
		"prompt": _prompt,
		"negative_prompt": "ugly incomplete discord blur",
	}
	EasyHttp.new(self, _on_create_success, _on_create_error).post(
		"https://api.tripo3d.ai/v2/openapi/task", self._headers, JSON.stringify(body)
	)


func _on_create_success(_code: int, data: Dictionary):
	if data.code != 0:
		print("failed to create task code %d message %s" % [data.code, data.message])
		model_generate_failed.emit()
		return

	self.task_id = data.data.task_id
	query_task(data.data.task_id)


func _on_create_error(_code: int):
	model_generate_failed.emit()


func query_task(taskID: String):
	EasyHttp.new(self, _on_query_success, _on_query_error).http_get(
		"https://api.tripo3d.ai/v2/openapi/task/%s" % [taskID], self._headers
	)


func _on_query_success(_code: int, data: Dictionary):
	if data.code != 0:
		print("failed to query task")
		model_generate_failed.emit()
		return

	match data.data.status:
		"queued":
			print("queued")
			await get_tree().create_timer(1.0).timeout
			query_task(data.data.task_id)
		"running":
			print("running...%d" % [data.data.progress])
			self.progress.progress = data.data.progress
			await get_tree().create_timer(1.0).timeout
			query_task(data.data.task_id)
		"success":
			model_generate_success.emit(data.data.output.model)
		"failed", "cancelled", "unknown":
			model_generate_failed.emit()


func _on_query_error(_code: int):
	model_generate_failed.emit()


func _generate_spiral_grid(n: int, step_x: float, step_y: float) -> Vector3:
	if n < 1:
		return Vector3(0, 0, 0)

	# Directions: right, down, left, up
	var directions = [
		Vector3(step_x, 0, 0), Vector3(0, -step_y, 0), Vector3(-step_x, 0, 0), Vector3(0, step_y, 0)
	]

	var pos = Vector3(0, 0, 0)
	var current_dir = 0
	var steps_in_current_dir = 1
	var step_count = 0
	var change_dir_count = 0

	for i in range(2, n + 1):
		pos += directions[current_dir]
		step_count += 1

		if step_count == steps_in_current_dir:
			step_count = 0
			current_dir = (current_dir + 1) % 4
			change_dir_count += 1

			if change_dir_count == 2:
				steps_in_current_dir += 1
				change_dir_count = 0

	return pos


# Function to get the AABB of a GLTFNode
func get_gltf_aabb(gltf_node: Node3D) -> AABB:
	var combined_aabb = AABB()
	var first_aabb = true

	var stack = [gltf_node]

	while stack.size() > 0:
		var current_node = stack.pop_back()

		for child in current_node.get_children():
			if child is MeshInstance3D:
				var mesh_instance = child as MeshInstance3D
				var mesh_aabb = mesh_instance.get_aabb()

				if first_aabb:
					combined_aabb = mesh_aabb
					first_aabb = false
				else:
					combined_aabb = combined_aabb.merge(mesh_aabb)
			stack.push_back(child)

	return combined_aabb


# Function to add a collision shape to a GLTFNode using its AABB
func add_collision_shape_to_gltf(gltf_node: Node3D, aabb: AABB):
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()

	box_shape.extents = aabb.size * 0.5
	collision_shape.shape = box_shape

	var static_body = StaticBody3D.new()
	static_body.add_child(collision_shape)
	gltf_node.add_child(static_body)


func draw_bounding_box():
	if not has_node(GLTF_NODE):
		return

	var aabb = get_gltf_aabb(get_node(GLTF_NODE))

	var bbox_mesh = bbox_mesh_instance.mesh
	bbox_mesh.clear_surfaces()

	bbox_mesh.surface_begin(Mesh.PRIMITIVE_LINES, bbox_material)

	var vertices = [
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z + aabb.size.z),
		Vector3(
			aabb.position.x + aabb.size.x,
			aabb.position.y + aabb.size.y,
			aabb.position.z + aabb.size.z
		),
		Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z)
	]

	# Draw lines between the vertices to form the bounding box
	var edges = [
		[0, 1],
		[1, 2],
		[2, 3],
		[3, 0],  # Bottom face
		[4, 5],
		[5, 6],
		[6, 7],
		[7, 4],  # Top face
		[0, 4],
		[1, 5],
		[2, 6],
		[3, 7]  # Vertical lines
	]

	for edge in edges:
		bbox_mesh.surface_add_vertex(vertices[edge[0]])
		bbox_mesh.surface_add_vertex(vertices[edge[1]])

	bbox_mesh.surface_end()
