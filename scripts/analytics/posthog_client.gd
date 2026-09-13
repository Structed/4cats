class_name PostHogClient
extends Node

signal accepted(event_ids: Array[String])
signal diagnostic(message: String)

const ENDPOINT := "https://eu.i.posthog.com/batch/"
const BATCH_SIZE := 20
const FLUSH_MS := 60000
const MAX_BACKOFF_MS := 300000

var project_token: String = ""
var _request: HTTPRequest
var _in_flight: Array[String] = []
var _next_attempt_ms: int = 0
var _failures: int = 0
var _permanent_failure: bool = false
var _generation: int = 0
var _completion: Callable
var _now: Callable = Time.get_ticks_msec


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func tick(queue: Array, now_ms: int, force: bool = false) -> void:
	if project_token.is_empty() or _permanent_failure or not _in_flight.is_empty() \
			or queue.is_empty() or now_ms < _next_attempt_ms and not force:
		return
	# A forced flush does not bypass a failed request's backoff.
	if _failures > 0 and now_ms < _next_attempt_ms:
		return
	var batch: Array[Dictionary] = []
	for index in mini(BATCH_SIZE, queue.size()):
		var entry: Dictionary = queue[index]
		var payload: Dictionary = entry["payload"]
		batch.append(payload)
		var properties: Dictionary = payload["properties"]
		_in_flight.append(String(properties["event_id"]))
	var error := _submit(JSON.stringify({"api_key": project_token, "batch": batch}), _generation)
	if error != OK:
		_complete(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), _generation)


func _submit(body: String, generation: int) -> Error:
	if _request == null:
		_request = HTTPRequest.new()
		_request.timeout = 10.0
		_request.max_redirects = 0
		add_child(_request)
	if _completion.is_valid() and _request.request_completed.is_connected(_completion):
		_request.request_completed.disconnect(_completion)
	_completion = _complete.bind(generation)
	_request.request_completed.connect(_completion, CONNECT_ONE_SHOT)
	return _request.request(ENDPOINT, PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST, body)


func _complete(result: int, code: int, _headers: PackedStringArray,
		_body: PackedByteArray, generation: int) -> void:
	if generation != _generation or _in_flight.is_empty():
		return
	var ids := _in_flight.duplicate()
	_in_flight.clear()
	var now_ms: int = _now.call()
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		_failures = 0
		_next_attempt_ms = now_ms + FLUSH_MS
		accepted.emit(ids)
	elif result != HTTPRequest.RESULT_SUCCESS or code in [408, 429] or code >= 500:
		_failures += 1
		var delay := mini(MAX_BACKOFF_MS, 5000 * (1 << mini(_failures - 1, 6)))
		_next_attempt_ms = now_ms + delay
		if _failures == 1:
			diagnostic.emit("Nutzungsanalyse: Versand fehlgeschlagen; erneuter Versuch folgt.")
	else:
		_permanent_failure = true
		diagnostic.emit("Nutzungsanalyse: Server lehnt die Konfiguration oder Ereignisse ab (HTTP %d)." % code)


func cancel() -> void:
	_generation += 1
	if _request != null:
		_request.cancel_request()
		if _completion.is_valid() and _request.request_completed.is_connected(_completion):
			_request.request_completed.disconnect(_completion)
	_in_flight.clear()
	_failures = 0
	_permanent_failure = false
	_next_attempt_ms = 0
