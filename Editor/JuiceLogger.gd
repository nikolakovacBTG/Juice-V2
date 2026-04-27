## Static utility for structured debug logging across the Juice V1 system.
## Routes all log output through a standardized format with three-tier gating.
##
## All Juice debug output flows through this class. Never use raw print() for
## Juice diagnostics — always call JuiceLogger static methods instead.
##
## @experimental

class_name JuiceLogger
extends RefCounted

# ============================================================================
# WHAT: Centralized, zero-allocation debug logging for the Juice addon.
# WHY:  Uniform log format lets AI agents parse bug reports mechanically.
#       Three-tier gating (OS.is_debug_build → master switch → per-node flag)
#       ensures zero cost in release builds while keeping per-node isolation
#       available during development.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Own the master-switch setting — JuiceProjectSettings does.
#           Generate the final bug report — JuiceDebugReport assembles that
#           from the file this class writes.
# ============================================================================


# =============================================================================
# CONFIGURATION
# =============================================================================

## Project Settings key for the global debug master switch.
const MASTER_SWITCH_KEY := "juice/debug/enabled"

## Project Settings key for file logging toggle.
const LOG_TO_FILE_KEY := "juice/debug/log_to_file"

## Project Settings key for verbose per-frame console output.
## When false (default), log_delta and log_aggregation write to file only.
## When true, per-frame output also prints to the console (expect high volume).
const VERBOSE_LOG_KEY := "juice/debug/verbose"

## Path where the debug log file is written.
## Set on first write using a session timestamp — each run produces a new file.
## Format: user://juice_YYYY-MM-DDTHH.MM.SS.log
static var LOG_FILE_PATH: String = ""

## Maximum number of log lines kept in the ring buffer for bug reports.
const RING_BUFFER_MAX := 5000


# =============================================================================
# INTERNAL STATE
# =============================================================================

# Ring buffer of recent log lines for bug report export.
# Stored as a static-like pattern using a class variable.
# Since GDScript static vars are per-class (not per-instance), this works.
static var _ring_buffer: PackedStringArray = PackedStringArray()
static var _ring_index: int = 0
static var _ring_count: int = 0

# Cached FileAccess handle — opened lazily on first write, closed on flush.
static var _log_file: FileAccess = null

# Cache the master switch value to avoid ProjectSettings lookup every frame.
# Refreshed each time _should_log() is called (cheap bool read).
static var _master_switch_cache: bool = false
static var _master_switch_dirty: bool = true


# =============================================================================
# PUBLIC API — LOGGING METHODS
# =============================================================================

## Category 1: General lifecycle events (trigger, start, stop, complete).
## Use for high-level flow tracing: when things happen, in what order.
static func log_info(source: Object, domain: String, message: String, debug_flag: bool) -> void:
	if not _should_log(debug_flag):
		return
	var line := _format(source, domain, "", message)
	_emit(line)


## Category 2: Base value and From/To snapshot capture verification.
## Use when the system captures a property value that will serve as a reference.
static func log_capture(source: Object, domain: String, property: String, value: Variant, debug_flag: bool) -> void:
	if not _should_log(debug_flag):
		return
	var line := _format(source, domain, "", "Captured %s = %s" % [property, _val(value)])
	_emit(line)


## Category 3: Per-frame delta reporting (math trace).
## Use inside _apply_effect() to trace the computed offset each frame.
## Routed through _emit_delta(): always written to file + ring buffer,
## printed to console only when juice/debug/verbose is enabled.
static func log_delta(source: Object, domain: String, progress: float, delta: Variant, target_name: String, debug_flag: bool) -> void:
	if not _should_log(debug_flag):
		return
	var effect_type := _effect_type(source)
	var line := "[Juice][%s][%s] %s: progress=%.3f delta=%s" % [
		domain, effect_type, target_name, progress, _val(delta)]
	_emit_delta(line)


## Category 4: Shader/material uniform diagnostics for Appearance effects.
## Use when setting a shader parameter to trace what uniform is being targeted.
static func log_shader(source: Object, domain: String, uniform_name: String, value: Variant, material_info: String, debug_flag: bool) -> void:
	if not _should_log(debug_flag):
		return
	var effect_type := _effect_type(source)
	var line := "[Juice][%s][%s] Shader: '%s' = %s on %s" % [
		domain, effect_type, uniform_name, _val(value), material_info]
	_emit(line)


## Category 5: Aggregation write summary from domain nodes.
## Use in _post_tick_write() to trace the final value written to the target.
## Routed through _emit_delta(): always written to file + ring buffer,
## printed to console only when juice/debug/verbose is enabled.
static func log_aggregation(domain: String, target_name: String, channel: String, base: Variant, total_delta: Variant, final_value: Variant, debug_flag: bool) -> void:
	if not _should_log(debug_flag):
		return
	var line := "[Juice][%s] %s: Write %s: base=%s + delta=%s → final=%s" % [
		domain, target_name, channel, _val(base), _val(total_delta), _val(final_value)]
	_emit_delta(line)


## Category 6: Domain mismatch warning — always logs in debug builds.
## No per-node debug_flag needed; this is a configuration error that must be visible.
static func warn_domain_mismatch(effect_class: String, expected_domain: String, actual_class: String) -> void:
	if not OS.is_debug_build():
		return
	var line := "[Juice][WARNING] Domain mismatch: %s expects %s target, got %s" % [
		effect_class, expected_domain, actual_class]
	push_warning(line)
	_ring_push(line)
	_file_write(line)


## General warning — for non-category-specific issues.
## Use for missing nodes, broken paths, invalid configurations.
static func warn(source: Object, domain: String, message: String, debug_flag: bool) -> void:
	if not _should_log(debug_flag):
		return
	var line := _format(source, domain, "", message)
	push_warning(line)
	_ring_push(line)
	_file_write(line)


# =============================================================================
# PUBLIC API — RING BUFFER ACCESS
# =============================================================================

## Returns all buffered log lines (oldest first). Used by JuiceDebugReport.
static func get_recent_logs() -> PackedStringArray:
	if _ring_count == 0:
		return PackedStringArray()
	var result := PackedStringArray()
	var start := 0
	if _ring_count >= RING_BUFFER_MAX:
		start = _ring_index  # Wrap-around: oldest is at current write position
	for i in range(_ring_count):
		var idx := (start + i) % RING_BUFFER_MAX
		if idx < _ring_buffer.size():
			result.append(_ring_buffer[idx])
	return result


## Clears the ring buffer. Call after exporting a bug report.
static func clear_ring_buffer() -> void:
	_ring_buffer.clear()
	_ring_index = 0
	_ring_count = 0


## Flush and close the log file handle. Call on plugin exit or report export.
static func flush_log_file() -> void:
	if _log_file != null:
		_log_file.flush()
		_log_file = null


# =============================================================================
# CORE LOGIC — GATING
# =============================================================================

# Three-tier gate check. Returns true if this log call should proceed.
# Tier 1: OS.is_debug_build() — zero cost in export builds.
# Tier 2: Master switch in Project Settings — one-click enable-all.
# Tier 3: Per-node debug_enabled flag — individual isolation.
# Logic: OS.is_debug_build() AND (master_switch OR debug_flag)
static func _should_log(debug_flag: bool) -> bool:
	if not OS.is_debug_build():
		return false
	# Refresh master switch cache (cheap ProjectSettings bool read)
	_master_switch_cache = ProjectSettings.get_setting(MASTER_SWITCH_KEY, false)
	return _master_switch_cache or debug_flag


# =============================================================================
# HELPERS — FORMATTING
# =============================================================================

# Builds the standard log line: [Juice][Domain][EffectType] SourceName: message
static func _format(source: Object, domain: String, effect_type: String, message: String) -> String:
	var src_name := _source_name(source)
	if effect_type.is_empty():
		return "[Juice][%s] %s: %s" % [domain, src_name, message]
	return "[Juice][%s][%s] %s: %s" % [domain, effect_type, src_name, message]


# Extracts a human-readable name from the source object.
static func _source_name(source: Object) -> String:
	if source == null:
		return "null"
	if source is Node:
		return source.name
	if source is Resource:
		var script: Script = source.get_script()
		if script != null:
			var global_name: String = script.get_global_name()
			if not global_name.is_empty():
				return global_name
		var res_name: String = source.resource_name
		if not res_name.is_empty():
			return res_name
	return source.get_class()


# Extracts the effect type name from a source object (for delta/shader logs).
static func _effect_type(source: Object) -> String:
	if source == null:
		return "?"
	var script: Script = source.get_script()
	if script != null:
		var global_name: String = script.get_global_name()
		if not global_name.is_empty():
			# Strip domain prefix/suffix for readability
			# e.g. "TransformControlJuiceEffect" → "Transform"
			var cleaned := global_name
			for suffix in ["ControlJuiceEffect", "2DJuiceEffect", "3DJuiceEffect",
							"ControlJuiceUtility", "2DJuiceUtility", "3DJuiceUtility",
							"JuiceEffectBase", "JuiceEffect", "JuiceUtility"]:
				if cleaned.ends_with(suffix):
					cleaned = cleaned.left(cleaned.length() - suffix.length())
					break
			if not cleaned.is_empty():
				return cleaned
			return global_name
	return source.get_class()


# Converts a value to a compact string for log output.
static func _val(value: Variant) -> String:
	if value is Vector2:
		return "(%.2f, %.2f)" % [value.x, value.y]
	if value is Vector3:
		return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]
	if value is Color:
		return "(%.2f, %.2f, %.2f, %.2f)" % [value.r, value.g, value.b, value.a]
	if value is float:
		return "%.3f" % value
	if value is Dictionary:
		var parts := PackedStringArray()
		for key in value:
			parts.append("%s=%s" % [key, _val(value[key])])
		return "{%s}" % ", ".join(parts)
	return str(value)


# =============================================================================
# HELPERS — OUTPUT
# =============================================================================

# Emit a lifecycle log line to console, ring buffer, and file.
# Use for log_info, log_capture, warn — events that fire at most once per
# animation and are always safe to show on the console.
static func _emit(line: String) -> void:
	print(line)
	_ring_push(line)
	_file_write(line)


# Emit a per-frame log line to ring buffer and file, console only if verbose.
# Use for log_delta and log_aggregation — 60fps output that overflows the
# Godot console panel on any non-trivial scene.
# Verbose mode is opt-in via juice/debug/verbose in Project Settings.
static func _emit_delta(line: String) -> void:
	_ring_push(line)
	_file_write(line)
	if ProjectSettings.get_setting(VERBOSE_LOG_KEY, false):
		print(line)


# Push a line into the ring buffer.
static func _ring_push(line: String) -> void:
	if _ring_buffer.size() < RING_BUFFER_MAX:
		_ring_buffer.append(line)
	else:
		_ring_buffer[_ring_index] = line
	_ring_index = (_ring_index + 1) % RING_BUFFER_MAX
	_ring_count = mini(_ring_count + 1, RING_BUFFER_MAX)


# Write a line to the log file if file logging is enabled.
static func _file_write(line: String) -> void:
	if not ProjectSettings.get_setting(LOG_TO_FILE_KEY, false):
		return
	if _log_file == null:
		_log_file = FileAccess.open(_build_session_log_path(), FileAccess.WRITE)
		if _log_file == null:
			# Can't open file — disable silently to avoid error spam
			return
		# Write header on new file
		_log_file.store_line("=== JUICE DEBUG LOG ===")
		_log_file.store_line("Timestamp: %s" % Time.get_datetime_string_from_system())
		_log_file.store_line("Godot: %s" % Engine.get_version_info().string)
		_log_file.store_line("===")
		_log_file.store_line("")
	_log_file.store_line(line)


# Builds the session log path on first call and caches it in LOG_FILE_PATH.
# Uses the same timestamp format as Godot's own engine logs (colons replaced
# by dots for Windows filename compatibility).
static func _build_session_log_path() -> String:
	if not LOG_FILE_PATH.is_empty():
		return LOG_FILE_PATH
	var dt := Time.get_datetime_string_from_system()
	# Replace colons with dots: 2026-04-27T17:22:53 → 2026-04-27T17.22.53
	dt = dt.replace(":", ".")
	LOG_FILE_PATH = "user://juice_%s.log" % dt
	return LOG_FILE_PATH
