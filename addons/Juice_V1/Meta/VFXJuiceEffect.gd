## Triggers particle effects or spawns VFX scenes on any target node.
##
## Place in any domain recipe. Two modes:
## CHILDREN — fires GPU/CPU particle nodes that are children of the target.
## EXTERNAL_SCENE — spawns a PackedScene instance near the target per trigger.

# ============================================================================
# WHAT: Side-effect trigger effect that fires particles or spawns VFX scenes.
# WHY:  Particle effects have no transform delta to aggregate — they are
#       one-shot side-effects triggered by the animation event. This effect
#       occupies a chain slot and fires particles without modifying any
#       target property through the ledger.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Compute or write any transform delta (position, rotation, scale).
#           Does not manage trail effects — use TrailJuiceEffect for that.
#
# APPROVED EXCEPTION: Unlike most effects, this class fires side-effects in
#   _on_animate_start() rather than computing deltas in _apply_effect().
#   Particle systems self-animate after being triggered — there is nothing
#   to aggregate. This mirrors TimeJuiceEffectBase's approved exception.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseVFX.svg")
class_name VFXJuiceEffect
extends JuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## How VFX are sourced.
enum SourceMode {
	CHILDREN,       ## Trigger particle nodes that are children of the target.
	EXTERNAL_SCENE  ## Instantiate a PackedScene near the target each trigger.
}

## Which instance to remove when max_living_instances is reached.
enum CullStrategy {
	OLDEST,          ## Remove the first spawned (FIFO) — simple and predictable.
	MOST_PROGRESSED, ## Remove the one that has run longest — minimal disruption.
	FARTHEST_CAMERA  ## Remove the one farthest from the active camera — best visual quality.
}


# =============================================================================
# CONFIGURATION
# =============================================================================

## Offset from target center when spawning. For 2D targets only X and Y are used.
var spawn_offset: Vector3 = Vector3.ZERO

## If true, spawned VFX inherits the target's rotation. EXTERNAL_SCENE only.
var inherit_rotation: bool = true

## If true, spawned VFX is placed in world space (survives if target is freed).
## If false, placed as a sibling of the target. EXTERNAL_SCENE only.
var spawn_in_world_space: bool = true

## If true, any previous instances from this effect are killed before spawning.
## Default false — particles die naturally and can overlap.
var kill_previous_on_trigger: bool = false

## Multiplier on all particle amounts. 1.0 = authored value. 2.0 = double density.
var intensity_multiplier: float = 1.0

## Maximum simultaneous instances. 0 = unlimited. When exceeded, the cull
## strategy determines which instance is removed. EXTERNAL_SCENE only.
var max_living_instances: int = 0:
	set(value):
		max_living_instances = value
		notify_property_list_changed()

## Source mode — children particles or spawned scene.
var vfx_source: int = SourceMode.CHILDREN:
	set(value):
		vfx_source = value
		notify_property_list_changed()

## The VFX scene to instantiate per trigger. Only active in EXTERNAL_SCENE mode.
var vfx_scene: PackedScene

## Fallback lifetime (seconds) to auto-free spawned VFX with no "finished" signal.
var auto_free_delay: float = 2.0

## Which instance to cull when the living limit is exceeded.
var cull_strategy: int = CullStrategy.OLDEST


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _init() -> void:
	_subclass_owns_effect_group = true


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	props.append({"name": "VFX Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})

	props.append({"name": "vfx_source", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Children,External Scene",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "spawn_offset", "type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "inherit_rotation", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "kill_previous_on_trigger", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "intensity_multiplier", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,4.0,0.1,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "max_living_instances", "type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0,100,1,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})

	if max_living_instances > 0:
		props.append({"name": "cull_strategy", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Oldest,Most Progressed,Farthest Camera",
			"usage": PROPERTY_USAGE_DEFAULT})

	if vfx_source == SourceMode.EXTERNAL_SCENE:
		props.append({"name": "spawn_in_world_space", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "vfx_scene", "type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "PackedScene",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "auto_free_delay", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,30.0,0.1",
			"usage": PROPERTY_USAGE_DEFAULT})

	props.append_array(_get_effect_base_properties())
	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"vfx_source":               vfx_source = value;               return true
		&"spawn_offset":             spawn_offset = value;             return true
		&"inherit_rotation":         inherit_rotation = value;         return true
		&"spawn_in_world_space":     spawn_in_world_space = value;     return true
		&"kill_previous_on_trigger": kill_previous_on_trigger = value; return true
		&"intensity_multiplier":     intensity_multiplier = value;     return true
		&"max_living_instances":     max_living_instances = value;     return true
		&"cull_strategy":            cull_strategy = value;            return true
		&"vfx_scene":                vfx_scene = value;                return true
		&"auto_free_delay":          auto_free_delay = value;          return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"vfx_source":               return vfx_source
		&"spawn_offset":             return spawn_offset
		&"inherit_rotation":         return inherit_rotation
		&"spawn_in_world_space":     return spawn_in_world_space
		&"kill_previous_on_trigger": return kill_previous_on_trigger
		&"intensity_multiplier":     return intensity_multiplier
		&"max_living_instances":     return max_living_instances
		&"cull_strategy":            return cull_strategy
		&"vfx_scene":                return vfx_scene
		&"auto_free_delay":          return auto_free_delay
	return super._get(property)


# =============================================================================
# INTERNAL STATE
# =============================================================================

# Particle children discovered at _on_animate_start (CHILDREN mode).
# Cleared after stop so stale freed-node references don't accumulate.
var _particle_children: Array[Node] = []

# Authored particle amounts keyed by node, captured before intensity scaling.
# Restored on stop so the scene is left in its authored state.
var _original_amounts: Dictionary = {}

# Tracked spawned instances with metadata (EXTERNAL_SCENE mode).
# Each entry: { "instance": Node, "spawn_time": float }
var _spawned_instances: Array[Dictionary] = []


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Fire the side-effect when the chain slot triggers.
## CHILDREN: discovers and emits particle children on the target.
## EXTERNAL_SCENE: instantiates vfx_scene near the target.
func _on_animate_start(target: Node) -> void:
	if target == null:
		return
	match vfx_source:
		SourceMode.CHILDREN:
			_discover_particle_children(target)
			_trigger_children_particles(target)
		SourceMode.EXTERNAL_SCENE:
			_spawn_external_vfx(target)
	JuiceLogger.log_info(self, _get_domain_tag(),
			"VFX triggered (mode=%s) on '%s'" % [
			SourceMode.keys()[vfx_source], target.name], debug_enabled)


## No delta output — particles self-animate. Approved side-effect exception.
func _apply_effect(_progress: float, _target: Node) -> void:
	pass


## Stop continuous-mode particles and restore particle amounts on animate_out.
func _on_animate_out_complete(target: Node) -> void:
	if vfx_source == SourceMode.CHILDREN:
		_stop_children_particles()
		_restore_particle_amounts()
	JuiceLogger.log_info(self, _get_domain_tag(),
			"animate_out complete on '%s'" % (target.name if target else "null"),
			debug_enabled)


## Stop particles and clear tracked instances on explicit stop.
func _restore_to_natural(_target: Node) -> void:
	if vfx_source == SourceMode.CHILDREN:
		_stop_children_particles()
		_restore_particle_amounts()
	elif vfx_source == SourceMode.EXTERNAL_SCENE:
		_kill_all_spawned_instances()


# =============================================================================
# CHILDREN MODE
# =============================================================================

# Walk the target's children and cache all GPU/CPU particle nodes.
# Runs at animate_start so it handles dynamically added children correctly.
func _discover_particle_children(target: Node) -> void:
	_particle_children.clear()
	_original_amounts.clear()
	for child in target.get_children():
		if _is_particle_node(child):
			_particle_children.append(child)
			_original_amounts[child] = _get_particle_amount(child)
	JuiceLogger.log_info(self, _get_domain_tag(),
			"discovered %d particle children on '%s'" % [
			_particle_children.size(), target.name], debug_enabled)


# Fire all discovered particle children on the target.
# Positions Node2D particles at the target center for Control parents, since
# Node2D children of Controls do not inherit layout position automatically.
func _trigger_children_particles(target: Node) -> void:
	if _particle_children.is_empty():
		JuiceLogger.warn(self, _get_domain_tag(),
				"no particle children on '%s'" % target.name, debug_enabled)
		return

	if kill_previous_on_trigger:
		for particle in _particle_children:
			if is_instance_valid(particle) and _is_particle_emitting(particle):
				_restart_particle(particle)

	if target is Control:
		var ctrl := target as Control
		var center: Vector2 = ctrl.global_position + ctrl.size / 2.0
		for particle in _particle_children:
			if particle is Node2D:
				(particle as Node2D).global_position = center
	elif target is Node2D:
		var pos: Vector2 = (target as Node2D).global_position
		for particle in _particle_children:
			if particle is Node2D:
				(particle as Node2D).global_position = pos

	for particle in _particle_children:
		if not is_instance_valid(particle):
			continue
		if not kill_previous_on_trigger and _is_particle_emitting(particle):
			continue
		if intensity_multiplier != 1.0:
			var orig := _original_amounts.get(particle, 1) as int
			_set_particle_amount(particle, maxi(1, int(orig * intensity_multiplier)))
		_set_particle_emitting(particle, true)


# Disable emitting on all discovered particle children.
func _stop_children_particles() -> void:
	for particle in _particle_children:
		if is_instance_valid(particle):
			_set_particle_emitting(particle, false)


# Restore particle amounts to their authored values after intensity scaling.
func _restore_particle_amounts() -> void:
	if intensity_multiplier == 1.0:
		return
	for particle in _particle_children:
		if is_instance_valid(particle) and _original_amounts.has(particle):
			_set_particle_amount(particle, _original_amounts[particle])


# =============================================================================
# EXTERNAL SCENE MODE
# =============================================================================

# Instantiate vfx_scene near the target, applying intensity and auto-free.
# Culls old instances first if max_living_instances is exceeded.
func _spawn_external_vfx(target: Node) -> void:
	if vfx_scene == null:
		JuiceLogger.warn(self, _get_domain_tag(), "vfx_scene is null", debug_enabled)
		return
	if not is_instance_valid(_host_node):
		JuiceLogger.warn(self, _get_domain_tag(), "no host node — cannot access tree", debug_enabled)
		return

	if kill_previous_on_trigger:
		_kill_all_spawned_instances()

	if max_living_instances > 0:
		while _spawned_instances.size() >= max_living_instances:
			_cull_one_instance()

	var instance := vfx_scene.instantiate()
	if instance == null:
		JuiceLogger.warn(self, _get_domain_tag(), "vfx_scene.instantiate() returned null", debug_enabled)
		return

	var spawn_parent: Node = (
		_host_node.get_tree().current_scene if spawn_in_world_space
		else target.get_parent())
	if spawn_parent == null:
		spawn_parent = _host_node.get_tree().current_scene

	spawn_parent.add_child(instance)
	_position_instance(instance, target)

	if intensity_multiplier != 1.0:
		for p in _find_all_particles_in_subtree(instance):
			_set_particle_amount(p, maxi(1, int(_get_particle_amount(p) * intensity_multiplier)))

	for p in _find_all_particles_in_subtree(instance):
		_restart_particle(p)
		_set_particle_emitting(p, true)

	_setup_instance_auto_free(instance)
	_spawned_instances.append({
		"instance": instance,
		"spawn_time": Time.get_ticks_msec() / 1000.0
	})
	JuiceLogger.log_info(self, _get_domain_tag(),
			"spawned VFX instance #%d" % _spawned_instances.size(), debug_enabled)


# Remove one instance selected by cull_strategy to make room for a new one.
func _cull_one_instance() -> void:
	if _spawned_instances.is_empty():
		return
	var idx := 0
	match cull_strategy:
		CullStrategy.MOST_PROGRESSED:
			var earliest := INF
			for i in _spawned_instances.size():
				var t: float = _spawned_instances[i].get("spawn_time", 0.0)
				if t < earliest:
					earliest = t
					idx = i
		CullStrategy.FARTHEST_CAMERA:
			var cam := _get_active_camera()
			if cam != null:
				var max_d := -1.0
				var cam_pos: Vector3 = cam.global_position if cam is Camera3D else Vector3.ZERO
				for i in _spawned_instances.size():
					var inst = _spawned_instances[i].get("instance")
					if not is_instance_valid(inst):
						continue
					var ipos: Vector3
					if inst is Node3D:
						ipos = (inst as Node3D).global_position
					elif inst is Node2D:
						var p2 := (inst as Node2D).global_position
						ipos = Vector3(p2.x, p2.y, 0.0)
					else:
						continue
					var d := cam_pos.distance_to(ipos)
					if d > max_d:
						max_d = d
						idx = i
	var inst = _spawned_instances[idx].get("instance")
	if is_instance_valid(inst):
		inst.queue_free()
	_spawned_instances.remove_at(idx)


# Free every tracked spawned instance immediately.
func _kill_all_spawned_instances() -> void:
	for entry in _spawned_instances:
		var inst = entry.get("instance")
		if is_instance_valid(inst):
			inst.queue_free()
	_spawned_instances.clear()


# Position a spawned instance at target center + spawn_offset.
func _position_instance(instance: Node, target: Node) -> void:
	var off2: Vector2 = Vector2(spawn_offset.x, spawn_offset.y)
	if target is Node3D and instance is Node3D:
		var i3 := instance as Node3D
		i3.global_position = (target as Node3D).global_position + spawn_offset
		if inherit_rotation:
			i3.global_rotation = (target as Node3D).global_rotation
	elif instance is Node2D:
		var i2 := instance as Node2D
		if target is Node2D:
			i2.global_position = (target as Node2D).global_position + off2
			if inherit_rotation:
				i2.global_rotation = (target as Node2D).global_rotation
		elif target is Control:
			var ctrl := target as Control
			i2.global_position = ctrl.global_position + ctrl.size / 2.0 + off2
			if inherit_rotation:
				i2.global_rotation = ctrl.global_transform.get_rotation()


# Hook "finished" signal if available; fall back to a timed callback for auto-free.
func _setup_instance_auto_free(instance: Node) -> void:
	if instance.has_signal("finished"):
		instance.finished.connect(func(): _on_instance_finished(instance))
	elif is_instance_valid(_host_node):
		_host_node.get_tree().create_timer(auto_free_delay).timeout.connect(
			func(): _on_instance_finished(instance))


# Remove a completed or timed-out instance from tracking and free it.
func _on_instance_finished(instance: Node) -> void:
	if not is_instance_valid(instance):
		return
	for i in range(_spawned_instances.size() - 1, -1, -1):
		if _spawned_instances[i].get("instance") == instance:
			_spawned_instances.remove_at(i)
			break
	instance.queue_free()


# Return the viewport's active camera node, or null if unavailable.
func _get_active_camera() -> Node:
	if not is_instance_valid(_host_node):
		return null
	var vp := _host_node.get_viewport()
	return vp.get_camera_3d() if vp else null


# =============================================================================
# PARTICLE HELPERS (type-agnostic: GPU/CPU × 2D/3D)
# =============================================================================

func _find_all_particles_in_subtree(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	_find_particles_recursive(root, result)
	return result


func _find_particles_recursive(node: Node, result: Array[Node]) -> void:
	if _is_particle_node(node):
		result.append(node)
	for child in node.get_children():
		_find_particles_recursive(child, result)


func _is_particle_node(node: Node) -> bool:
	return (node is GPUParticles2D or node is GPUParticles3D
		or node is CPUParticles2D or node is CPUParticles3D)


func _get_particle_amount(particle: Node) -> int:
	if particle is GPUParticles2D: return (particle as GPUParticles2D).amount
	if particle is GPUParticles3D: return (particle as GPUParticles3D).amount
	if particle is CPUParticles2D: return (particle as CPUParticles2D).amount
	if particle is CPUParticles3D: return (particle as CPUParticles3D).amount
	return 0


func _set_particle_amount(particle: Node, amount: int) -> void:
	if particle is GPUParticles2D: (particle as GPUParticles2D).amount = amount
	elif particle is GPUParticles3D: (particle as GPUParticles3D).amount = amount
	elif particle is CPUParticles2D: (particle as CPUParticles2D).amount = amount
	elif particle is CPUParticles3D: (particle as CPUParticles3D).amount = amount


func _is_particle_emitting(particle: Node) -> bool:
	if particle is GPUParticles2D: return (particle as GPUParticles2D).emitting
	if particle is GPUParticles3D: return (particle as GPUParticles3D).emitting
	if particle is CPUParticles2D: return (particle as CPUParticles2D).emitting
	if particle is CPUParticles3D: return (particle as CPUParticles3D).emitting
	return false


func _set_particle_emitting(particle: Node, emitting: bool) -> void:
	if particle is GPUParticles2D: (particle as GPUParticles2D).emitting = emitting
	elif particle is GPUParticles3D: (particle as GPUParticles3D).emitting = emitting
	elif particle is CPUParticles2D: (particle as CPUParticles2D).emitting = emitting
	elif particle is CPUParticles3D: (particle as CPUParticles3D).emitting = emitting


func _restart_particle(particle: Node) -> void:
	if particle is GPUParticles2D: (particle as GPUParticles2D).restart()
	elif particle is GPUParticles3D: (particle as GPUParticles3D).restart()
	elif particle is CPUParticles2D: (particle as CPUParticles2D).restart()
	elif particle is CPUParticles3D: (particle as CPUParticles3D).restart()


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

## Warn if EXTERNAL_SCENE mode is selected but no scene is assigned.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if vfx_source == SourceMode.EXTERNAL_SCENE and vfx_scene == null:
		warnings.append("vfx_source is External Scene but no vfx_scene is assigned.")
	return warnings
