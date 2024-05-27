extends Node

@onready var le_prompt: LineEdit = $UI/PanelContainer/LeftRow/Col/LePrompt
@onready var btn_generate: Button = $UI/PanelContainer/LeftRow/Col/CenterContainer/BtnGenerate
@onready var toast: PanelContainer = $UI/Toast
@onready var toast_label: Label = $UI/Toast/HBoxContainer/Label

@onready var accept_dialog: AcceptDialog = $UI/AcceptDialog

@onready var setting_dialog: Window = $UI/SettingDialog
@onready var file_dialog: FileDialog = $UI/FileDialog
@onready var le_save_path: LineEdit = $UI/SettingDialog/MarginContainer/Row/ColSaveDir/LeSavePath
@onready var le_open_ai_key: LineEdit = $UI/SettingDialog/MarginContainer/Row/ColOpenAI/LeOpenAIKey
@onready var le_tripo_key: LineEdit = $UI/SettingDialog/MarginContainer/Row/ColTripo/LeTripoKey
@onready var btn_save: Button = $UI/SettingDialog/MarginContainer/Row/HBoxContainer/BtnSave
@onready var btn_browse: Button = $UI/SettingDialog/MarginContainer/Row/ColSaveDir/BtnBrowse

@onready var sb_facelimit: SpinBox = $UI/PanelContainer/LeftRow/RightRow/Col/SbFacelimit
@onready var sb_texture_size: SpinBox = $UI/PanelContainer/LeftRow/RightRow/Col/SbTextureSize
@onready var cb_pivot_to_bottom: CheckBox = $UI/PanelContainer/LeftRow/RightRow/Col/CbPivotToBottom

@onready
var btn_batch_convert: Button = $UI/PanelContainer/LeftRow/RightRow/CenterContainer/BtnBatchConvert

@onready var texture_rect: TextureRect = $UI/TextureRect
@onready var http_request: HTTPRequest = $UI/HTTPRequest

signal process_start(msg: String)
signal process_change_status(msg: String)
signal process_finished(msg: String)

var config: ConfigFile

const CFG_SAVE_PATH = "user://config.cfg"
const CFG_SEC_GENERAL = "General"
const CFG_KEY_SAVE_DIR = "save_dir"
const CFG_KEY_OPENAI = "openai"
const CFG_KEY_TRIPO = "tripo"
const CFG_KEY_SCALE = "scale"


func _ready() -> void:
	config = ConfigFile.new()
	config.load(CFG_SAVE_PATH)

	if config.has_section_key(CFG_SEC_GENERAL, CFG_KEY_SAVE_DIR):
		le_save_path.text = config.get_value(CFG_SEC_GENERAL, CFG_KEY_SAVE_DIR)

	if config.has_section_key(CFG_SEC_GENERAL, CFG_KEY_OPENAI):
		le_open_ai_key.text = config.get_value(CFG_SEC_GENERAL, CFG_KEY_OPENAI)

	if config.has_section_key(CFG_SEC_GENERAL, CFG_KEY_TRIPO):
		le_tripo_key.text = config.get_value(CFG_SEC_GENERAL, CFG_KEY_TRIPO)

	if config.has_section_key(CFG_SEC_GENERAL, CFG_KEY_SCALE):
		get_tree().root.content_scale_factor = config.get_value(CFG_SEC_GENERAL, CFG_KEY_SCALE)

	process_start.connect(_on_process_start)
	process_change_status.connect(_on_process_change_status)
	process_finished.connect(_on_process_finished)

	btn_generate.pressed.connect(_on_btn_generate_pressed)
	btn_browse.pressed.connect(_on_btn_browse_pressed)
	btn_save.pressed.connect(_on_btn_save_pressed)

	file_dialog.dir_selected.connect(_on_file_dialog_dir_selected)

	setting_dialog.close_requested.connect(_on_settings_dialog_close_requested)

	http_request.request_completed.connect(_on_http_request_completed)

	btn_batch_convert.pressed.connect(_on_btn_batch_convert_pressed)


func _on_process_start(msg: String):
	if not toast.visible:
		toast.visible = true
		toast_label.text = msg


func _on_process_change_status(msg: String):
	toast_label.text = msg


func _on_process_finished(msg: String):
	if toast.visible:
		toast_label.text = msg
		await get_tree().create_timer(2.0).timeout
		toast.visible = false
		toast_label.text = ""


func _on_btn_generate_pressed():
	var save_dir: String = config.get_value(CFG_SEC_GENERAL, CFG_KEY_SAVE_DIR)
	var openai_key: String = config.get_value(CFG_SEC_GENERAL, CFG_KEY_OPENAI)
	var tripo_key: String = config.get_value(CFG_SEC_GENERAL, CFG_KEY_TRIPO)
	if (
		save_dir == null
		or openai_key == null
		or tripo_key == null
		or save_dir.length() == 0
		or openai_key.length() == 0
		or tripo_key.length() == 0
	):
		setting_dialog.popup_centered()
		return

	if le_prompt.text.length() == 0:
		accept_dialog.dialog_text = "Prompt cannot be empty."
		accept_dialog.popup_centered()
		return

	btn_generate.disabled = true
	var viewport = get_viewport()
	viewport.debug_draw = RenderingServer.VIEWPORT_DEBUG_DRAW_DISABLED

	openai_generate_image()


func _on_btn_browse_pressed():
	file_dialog.popup_centered()


func _on_file_dialog_dir_selected(dir: String):
	le_save_path.text = dir


func _on_btn_save_pressed():
	config.set_value(CFG_SEC_GENERAL, CFG_KEY_OPENAI, le_open_ai_key.text)
	config.set_value(CFG_SEC_GENERAL, CFG_KEY_TRIPO, le_tripo_key.text)
	config.set_value(CFG_SEC_GENERAL, CFG_KEY_SAVE_DIR, le_save_path.text)

	config.save(CFG_SAVE_PATH)
	setting_dialog.hide()


func _on_settings_dialog_close_requested():
	setting_dialog.hide()


func _on_btn_batch_convert_pressed():
	var tripo_meshes = get_tree().get_nodes_in_group("tripo_mesh")
	for tripo_mesh in tripo_meshes:
		tripo_mesh.convert(
			sb_facelimit.value, sb_texture_size.value, cb_pivot_to_bottom.button_pressed
		)


func trim_prefix(input_string: String) -> String:
	# Use a regular expression to match and remove the prefix
	var regex = RegEx.new()
	var pattern = r"^\d+\.\s*"
	var result = regex.compile(pattern)

	if result == OK:
		var match = regex.search(input_string)
		if match:
			return input_string.substr(match.get_end(0), input_string.length() - match.get_end(0))

	return input_string


func openai_generate_image():
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % [config.get_value(CFG_SEC_GENERAL, CFG_KEY_OPENAI)],
	]
	var body = {
		"model": "dall-e-3",
		"prompt": le_prompt.text,
		"n": 1,
		"size": "1024x1024",
		"quality": "hd",
	}
	EasyHttp.new(self, _on_dalle_completed, _on_dalle_error).post(
		"https://api.openai.com/v1/images/generations", headers, JSON.stringify(body)
	)

	process_start.emit("Generating image according to your prompt...")


func _on_dalle_completed(_response_code: int, data: Dictionary):
	if data == null or data.data == null or data.data.size() == 0:
		process_finished.emit("Failed to generate image...")
		return

	btn_generate.disabled = false

	var url = data.data[0].url
	openai_describe_image(url)

	# show image
	http_request.request(url)


func _on_dalle_error(_response_code: int):
	process_finished.emit("Failed to generate image")
	btn_generate.disabled = false


func _on_http_request_completed(
	_result: int, _resposne_code: int, _headers: PackedStringArray, body: PackedByteArray
):
	var image = Image.new()
	image.load_png_from_buffer(body)
	texture_rect.texture = ImageTexture.create_from_image(image)


func openai_describe_image(url: String):
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % [config.get_value(CFG_SEC_GENERAL, CFG_KEY_OPENAI)],
	]
	var body = {
		"model": "gpt-4o",
		"messages":
		[
			{
				"role": "system",
				"content":
				"""Your task is to identify all objects in the image I provide, then give a description for each object.
				The description should include the type, shape, style, surface material, and color (or pattern) of the object.
				The description should be as concise as possible, as it will be used to generate corresponding 3D models.
				Each object's description should be on a separate line.
				Generate description for one object at a time, do not descript lots of objects in one line."""
			},
			{
				"role": "user",
				"content":
				[
					{"type": "text", "text": "Describe it"},
					{"type": "image_url", "image_url": {"url": url}}
				]
			}
		],
	}
	EasyHttp.new(self, _on_gpt_completed, _on_gpt_error).post(
		"https://api.openai.com/v1/chat/completions", headers, JSON.stringify(body)
	)

	process_change_status.emit("Image is created, identifying all objects...")


func _on_gpt_completed(_response_code: int, data: Dictionary):
	var result_str: String = data.choices[0].message.content
	var lines = result_str.split("\n")

	process_finished.emit("Found %d objects, generating 3d models..." % [lines.size()])

	btn_generate.disabled = false

	var save_dir = config.get_value(CFG_SEC_GENERAL, CFG_KEY_SAVE_DIR)
	for line in lines:
		var tripo_mesh = TripoMesh.new(
			config.get_value(CFG_SEC_GENERAL, CFG_KEY_TRIPO), trim_prefix(line), save_dir
		)
		add_child(tripo_mesh)


func _on_gpt_error(_response_code: int):
	process_finished.emit("Failed to identify objects in the image")
	btn_generate.disabled = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_wireframe"):
		var viewport = get_viewport()
		if viewport.debug_draw != RenderingServer.VIEWPORT_DEBUG_DRAW_WIREFRAME:
			viewport.debug_draw = RenderingServer.VIEWPORT_DEBUG_DRAW_WIREFRAME
		else:
			viewport.debug_draw = RenderingServer.VIEWPORT_DEBUG_DRAW_DISABLED

	if event.is_action_pressed("ui_zoom_out"):
		get_tree().root.content_scale_factor += 0.2
		config.set_value(CFG_SEC_GENERAL, CFG_KEY_SCALE, get_tree().root.content_scale_factor)
		config.save(CFG_SAVE_PATH)

	if event.is_action_pressed("ui_zoom_in"):
		get_tree().root.content_scale_factor -= 0.2
		config.set_value(CFG_SEC_GENERAL, CFG_KEY_SCALE, get_tree().root.content_scale_factor)
		config.save(CFG_SAVE_PATH)

	if event.is_action_pressed("settings"):
		setting_dialog.popup_centered()
