class_name PlaytimeTracker
extends RefCounted

const IDLE_MS := 120000
const SESSION_IDLE_MS := 1800000
const CHECKPOINT_MS := 60000

var session_id: String = ""
var _last_sample: int = -1
var _last_activity: int = -1
var _eligible: bool = false
var _scene: String = ""
var _pending_ms: int = 0
var _pending_end_utc: int = 0
var _suspended_at_utc: int = -1
var _suspend_inactivity_ms: int = 0
var _session_expired: bool = false


func reset() -> void:
	session_id = ""
	_last_sample = -1
	_last_activity = -1
	_pending_ms = 0
	_pending_end_utc = 0
	_eligible = false
	_scene = ""
	_suspended_at_utc = -1
	_session_expired = false


func update(now_ms: int, utc_ms: int, eligible: bool, activity: bool,
		context: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if _last_sample >= 0 and _eligible and not session_id.is_empty():
		var end := mini(now_ms, _last_activity + IDLE_MS)
		var elapsed := maxi(0, end - _last_sample)
		while elapsed > 0:
			var step := mini(elapsed, CHECKPOINT_MS - _pending_ms)
			_pending_ms += step
			elapsed -= step
			_pending_end_utc = utc_ms - maxi(0, now_ms - end) - elapsed
			if _pending_ms == CHECKPOINT_MS:
				events.append(_segment())
	if not eligible or context != _scene or activity and (
			_session_expired or not session_id.is_empty() and now_ms - _last_activity >= SESSION_IDLE_MS):
		if _pending_ms > 0:
			events.append(_segment())
	if activity:
		if session_id.is_empty() or _session_expired \
				or now_ms - _last_activity >= SESSION_IDLE_MS:
			session_id = AnalyticsEvents.uuid()
			events.append({
				"event": "play_session_started", "properties": {},
				"game_session_id": session_id, "utc_ms": utc_ms,
			})
		_last_activity = now_ms
		_session_expired = false
	_last_sample = now_ms
	_scene = context
	_eligible = eligible
	return events


func checkpoint(now_ms: int, utc_ms: int) -> Array[Dictionary]:
	var events := update(now_ms, utc_ms, _eligible, false, _scene)
	if _pending_ms > 0:
		events.append(_segment())
	return events


func suspend(now_ms: int, utc_ms: int) -> Array[Dictionary]:
	var events := update(now_ms, utc_ms, false, false, _scene)
	_suspended_at_utc = utc_ms
	_suspend_inactivity_ms = maxi(0, now_ms - _last_activity)
	return events


func resume(now_ms: int, utc_ms: int) -> void:
	# Suspend clocks differ by platform. Never reconstruct gameplay from wall time.
	if _suspended_at_utc >= 0 and not session_id.is_empty():
		var inactivity := maxi(now_ms - _last_activity,
			_suspend_inactivity_ms + maxi(0, utc_ms - _suspended_at_utc))
		_last_activity = now_ms - inactivity
		_session_expired = inactivity >= SESSION_IDLE_MS
	_last_sample = now_ms
	_eligible = false
	_suspended_at_utc = -1


func _segment() -> Dictionary:
	var event := {
		"event": "playtime",
		"properties": {"duration_seconds": _pending_ms / 1000.0, "scene": _scene},
		"game_session_id": session_id, "utc_ms": _pending_end_utc,
	}
	_pending_ms = 0
	return event
