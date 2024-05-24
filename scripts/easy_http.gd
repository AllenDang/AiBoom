extends HTTPRequest

class_name EasyHttp

signal on_success(result: int, body: Dictionary)
signal on_error(result: int)

var _on_success: Callable
var _on_error: Callable


func _init(parent: Node, cb_on_success: Callable, cb_on_error: Callable) -> void:
	_on_success = cb_on_success
	_on_error = cb_on_error

	parent.add_child(self)


func _enter_tree() -> void:
	on_success.connect(_on_success)
	on_error.connect(_on_error)


func _exit_tree() -> void:
	on_success.disconnect(_on_success)
	on_error.disconnect(_on_error)


func post(
	url: String,
	headers: PackedStringArray,
	body: String,
):
	request_completed.connect(_on_http_request_completed)
	request(url, headers, HTTPClient.METHOD_POST, body)


func http_get(url: String, headers: PackedStringArray):
	request_completed.connect(_on_http_request_completed)
	request(url, headers, HTTPClient.METHOD_GET)


func download(url: String, headers: PackedStringArray, to_dir: String):
	var file_name = _extract_file_name_from_url(url)
	if file_name.length() == 0:
		print("failed to extract file name from url")
		on_error.emit(-1)
		return

	download_file = "%s/%s" % [to_dir, file_name]
	print("download to %s" % [download_file])
	request_completed.connect(_on_http_download_completed)
	request(url, headers)


func _extract_file_name_from_url(url: String) -> String:
	var query_index = url.find("?")
	if query_index != -1:
		url = url.substr(0, query_index)
	var slash_index = url.rfind("/")
	if slash_index != -1:
		return url.substr(slash_index + 1)
	return ""


func _on_http_download_completed(
	result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray
):
	if result == HTTPRequest.RESULT_SUCCESS:
		on_success.emit(result, {"path": download_file})
	else:
		on_error.emit(result)

	queue_free()


func _on_http_request_completed(
	result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray
):
	if result == HTTPRequest.RESULT_SUCCESS:
		if body:
			var data = JSON.parse_string(body.get_string_from_utf8())
			on_success.emit(result, data)
		else:
			on_error.emit(result)
	else:
		on_error.emit(result)

	queue_free()
