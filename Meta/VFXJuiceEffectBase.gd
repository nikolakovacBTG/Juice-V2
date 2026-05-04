## Shared base for all domain VFX effects (VFXControlJuiceEffect, VFX2DJuiceEffect, VFX3DJuiceEffect).
##
## Two modes: TRIGGER_EXISTING fires particle children on a list of target nodes.
## INSTANTIATE_NEW spawns PackedScene instances at a list of locations.

# =============================================================================
# WHAT: Side-effect trigger effect — fires particles or spawns VFX scenes.
# WHY:  Particle effects have no transform delta to aggregate — they are one-shot
#       side-effects triggered by the animation event. This class holds all shared
#       configuration, inspector layout, particle helpers, and spawn orchestration.
#       Domain subclasses (VFXControl, VFX2D, VFX3D) implement only the position
#       math that requires type-safe access to domain-specific node properties.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Compute or write any transform delta through the ledger.
# DOES NOT: Handle trail effects — use TrailJuiceEffect for that.
#
# APPROVED EXCEPTION: Side-effects live in _on_animate_start(), not _apply_effect().
#   Particle systems self-animate after being triggered — there is nothing to
#   aggregate. This mirrors the TimeJuiceEffectBase approved exception pattern.
# =============================================================================

@tool
class_name VFXJuiceEffectBase
extends JuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## How VFX are sourced.
enum VFXMode {
	TRIGGER_EXISTING, ## Fire particle nodes that are already children of listed target nodes.
	INSTANTIATE_NEW   ## Instantiate PackedScene(s) at listed spawn location nodes.
}

## Which living instance to remove when max_living_instances is reached.
enum CullStrategy {
	OLDEST,          ## Remove the first spawned (FIFO) — simple and predictable.
	MOST_PROGRESSED, ## Remove the one that has run longest.
	FARTHEST_CAMERA  ## Remove the one farthest from the active camera.
}


# =============================================================================
# CONFIGURATION
# =============================================================================

## Selects the VFX behaviour mode. Changes which settings are visible below.
var vfx_mode: int = VFXMode.TRIGGER_EXISTING:
	set(value):
		vfx_mode = value
		notify_property_list_changed()

## If true, stops any previous emitting particles (TRIGGER_EXISTING) or kills spawned
## instances (INSTANTIATE_NEW) before the new trigger fires. Prevents overlap buildup.
var kill_previous_on_trigger: bool = false

# --- TRIGGER_EXISTING configuration ---

## Nodes whose GPU/CPU particle children will be fired on trigger.
## Drag nodes directly from the Scene tree dock. Leave empty to fire on the
## juice's own animated node. Add multiple to fire on several nodes at once.
var trigger_targets: Array[NodePath] = []

# --- INSTANTIATE_NEW configuration ---

## Scenes to instantiate on each trigger. Drag .tscn files directly from
## the FileSystem dock. Each scene is spawned at every spawn location.
## Add multiple scenes to mix different VFX types per trigger.
var spawn_scenes: Array[PackedScene] = []

## Nodes at whose positions the scenes will be spawned as children of the target.
## Drag nodes directly from the Scene tree dock. Leave empty to spawn at
## the juice's own animated node. Add multiple to spawn at several points.
var spawn_locations: Array[NodePath] = []

## Multiplier applied to all particle amounts inside every spawned scene.
## 1.0 = authored density. 2.0 = double density. Does not affect TRIGGER_EXISTING mode.
var intensity_multiplier: float = 1.0

## Seconds before a spawned instance is auto-freed when it has no "finished" signal.
## Match this to the longest particle lifetime in your VFX scenes.
var auto_free_delay: float = 2.0

## World-space offset applied to every spawn location.
## 2D/Control: X and Y in pixels (1 unit = 1 px at default zoom). Z ignored.
## 3D: all three axes in metres (1 unit = 1 m in Godot 3D world space).
var spawn_offset: Vector3 = Vector3.ZERO

## If true, spawned instances inherit the spawn location node's world-space rotation.
var inherit_rotation: bool = false

## If true, also spawn instances at the additional world-space positions below.
var use_custom_positions: bool = false:
	set(value):
		use_custom_positions = value
		notify_property_list_changed()

## Additional world-space spawn positions (appended on top of spawn_locations).
## 2D/Control: Vector2 — pixels (1 unit = 1 px at default Godot 2D zoom).
## 3D: Vector3 — metres (1 unit = 1 m in Godot 3D world space).
## Type is enforced per-domain: Vector2 for 2D/Control, Vector3 for 3D.
var custom_positions: Array = []

## Maximum simultaneous living instances. 0 = unlimited.
## When exceeded, cull_strategy determines which instance is removed.
var max_living_instances: int = 0:
	set(value):
		max_living_instances = value
		notify_property_list_changed()

## Which instance to remove when the living limit is exceeded.
var cull_strategy: int = CullStrategy.OLDEST


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _init() -> void:
	_subclass_owns_effect_group = true


## Build the full VFX inspector property list. Called by domain subclass _get_property_list().
## Named _build_vfx_property_list (not _get_property_list) so Godot does NOT auto-call it
## on the base class — calling super._get_property_list() from a subclass causes
## every group and property to appear twice.
func _build_vfx_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	props.append({"name": "VFX Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})

	props.append({"name": "vfx_mode", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Trigger Existing,Instantiate New",
		"usage": PROPERTY_USAGE_DEFAULT})

	props.append({"name": "kill_previous_on_trigger", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})

	if vfx_mode == VFXMode.TRIGGER_EXISTING:
		props.append({"name": "Trigger Sources", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""})
		props.append({
			"name": "trigger_targets",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_ARRAY_TYPE,
			"hint_string": "%d:" % TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT
		})

	elif vfx_mode == VFXMode.INSTANTIATE_NEW:
		props.append({"name": "Spawn Scenes", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""})
		props.append({
			"name": "spawn_scenes",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_ARRAY_TYPE,
			"hint_string": "%d/%d:%s" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "PackedScene"],
			"usage": PROPERTY_USAGE_DEFAULT
		})

		props.append({"name": "Spawn Locations", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""})
		props.append({
			"name": "spawn_locations",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_ARRAY_TYPE,
			"hint_string": "%d:" % TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT
		})
		props.append({"name": "spawn_offset", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "inherit_rotation", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})

		props.append({"name": "Spawn Settings", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""})
		props.append({"name": "intensity_multiplier", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,4.0,0.1,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "auto_free_delay", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,30.0,0.1",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "use_custom_positions", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})
		# Domain subclass appends typed custom_positions array here when enabled.

		props.append({"name": "Limits", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""})
		props.append({"name": "max_living_instances", "type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0,100,1,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})
		if max_living_instances > 0:
			props.append({"name": "cull_strategy", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Oldest,Most Progressed,Farthest Camera",
				"usage": PROPERTY_USAGE_DEFAULT})

	props.append_array(_get_effect_base_properties())
	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"vfx_mode":               vfx_mode = value;               return true
		&"kill_previous_on_trigger": kill_previous_on_trigger = value; return true
		&"trigger_targets":        trigger_targets = value;         return true
		&"spawn_scenes":           spawn_scenes = value;            return true
		&"spawn_locations":        spawn_locations = value;         return true
		&"intensity_multiplier":   intensity_multiplier = value;    return true
		&"auto_free_delay":        auto_free_delay = value;         return true
		&"spawn_offset":           spawn_offset = value;            return true
		&"inherit_rotation":       inherit_rotation = value;        return true
		&"use_custom_positions":   use_custom_positions = value;    return true
		&"custom_positions":       custom_positions = value;        return true
		&"max_living_instances":   max_living_instances = value;    return true
		&"cull_strategy":          cull_strategy = value;           return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"vfx_mode":               return vfx_mode
		&"kill_previous_on_trigger": return kill_previous_on_trigger
		&"trigger_targets":        return trigger_targets
		&"spawn_scenes":           return spawn_scenes
		&"spawn_locations":        return spawn_locations
		&"intensity_multiplier":   return intensity_multiplier
		&"auto_free_delay":        return auto_free_delay
		&"spawn_offset":           return spawn_offset
		&"inherit_rotation":       return inherit_rotation
		&"use_custom_positions":   return use_custom_positions
		&"custom_positions":       return custom_positions
		&"max_living_instances":   return max_living_instances
		&"cull_strategy":          return cull_strategy
	return super._get(property)


# =============================================================================
# INTERNAL STATE
# =============================================================================

# Particle children discovered per trigger-source node at animate_start.
# Keyed by source node: { Node → Array[Node] }. Cleared on stop.
var _particle_children: Dictionary = {}

# Authored particle amounts before intensity scaling, keyed by particle node.
# Restored on stop so the scene is left in its authored state.
var _original_amounts: Dictionary = {}

# Tracked spawned instances with metadata (INSTANTIATE_NEW mode).
# Each entry: { "instance": Node, "spawn_time": float }
var _spawned_instances: Array[Dictionary] = []


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Dispatch to the correct mode handler when the chain slot triggers.
func _on_animate_start(target: Node) -> void:
	if target == null:
		return
	match vfx_mode:
		VFXMode.TRIGGER_EXISTING:
			_trigger_existing(target)
		VFXMode.INSTANTIATE_NEW:
			_instantiate_new(target)
	JuiceLogger.log_info(self, _get_domain_tag(),
			"VFX triggered (mode=%s) on '%s'" % [
			VFXMode.keys()[vfx_mode], target.name], debug_enabled)


## No delta output — particles self-animate. Approved side-effect exception.
func _apply_effect(_progress: float, _target: Node) -> void:
	pass


## Stop continuous-mode particles on animate_out complete.
func _on_animate_out_complete(target: Node) -> void:
	if vfx_mode == VFXMode.TRIGGER_EXISTING:
		_stop_all_particle_children()
		_restore_particle_amounts()
	JuiceLogger.log_info(self, _get_domain_tag(),
			"animate_out complete on '%s'" % (target.name if target else "null"),
			debug_enabled)


## Stop particles and kill spawned instances on explicit stop().
func _restore_to_natural(_target: Node) -> void:
	if vfx_mode == VFXMode.TRIGGER_EXISTING:
		_stop_all_particle_children()
		_restore_particle_amounts()
	elif vfx_mode == VFXMode.INSTANTIATE_NEW:
		_kill_all_spawned_instances()
	_particle_children.clear()
	_original_amounts.clear()


# =============================================================================
# TRIGGER_EXISTING MODE
# =============================================================================

# Resolve all trigger_targets, discover particle children on each, then fire them.
# An empty NodePath in trigger_targets means the juice's own animated target.
func _trigger_existing(target: Node) -> void:
	_particle_children.clear()
	_original_amounts.clear()

	# If no entries configured, default to firing on the animated target itself.
	var resolved_sources: Array[Node] = []
	if trigger_targets.is_empty():
		resolved_sources.append(target)
	else:
		for path: NodePath in trigger_targets:
			var source_node: Node
			if path == NodePath():
				source_node = target
			elif not is_instance_valid(_host_node):
				JuiceLogger.warn(self, _get_domain_tag(),
						"_host_node not set — cannot resolve trigger path '%s', skipping" % path, debug_enabled)
				continue
			else:
				source_node = _host_node.get_node_or_null(path)
			if not is_instance_valid(source_node):
				JuiceLogger.warn(self, _get_domain_tag(),
						"trigger_target path '%s' could not be resolved" % path, debug_enabled)
				continue
			resolved_sources.append(source_node)

	for source_node in resolved_sources:
		var particles := _discover_particle_children(source_node)
		if particles.is_empty():
			JuiceLogger.warn(self, _get_domain_tag(),
					"no particle children on '%s'" % source_node.name, debug_enabled)
			continue

		_particle_children[source_node] = particles
		_reposition_particles_to_node(particles, source_node)

		if kill_previous_on_trigger:
			for p in particles:
				if is_instance_valid(p) and _is_particle_emitting(p):
					_restart_particle(p)

		for p in particles:
			if not is_instance_valid(p):
				continue
			if not kill_previous_on_trigger and _is_particle_emitting(p):
				continue
			var original := _get_particle_amount(p)
			_original_amounts[p] = original
			_set_particle_emitting(p, true)

	JuiceLogger.log_info(self, _get_domain_tag(),
			"triggered particles on %d source nodes" % _particle_children.size(),
			debug_enabled)

func _stop_all_particle_children() -> void:
	for node in _particle_children:
		for p in _particle_children[node]:
			if is_instance_valid(p):
				_set_particle_emitting(p, false)


# Restore all particle amounts to their authored values.
func _restore_particle_amounts() -> void:
	for p in _original_amounts:
		if is_instance_valid(p):
			_set_particle_amount(p, _original_amounts[p])


# Walk a node's direct children and return all GPU/CPU particle nodes found.
func _discover_particle_children(source: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in source.get_children():
		if _is_particle_node(child):
			result.append(child)
	return result


# Intensity applied per particle in TRIGGER_EXISTING mode.
# Kept for backward compat — returns 1.0 since intensity now applies only in INSTANTIATE_NEW.
func intensity_multiplier_for_trigger() -> float:
	return 1.0


# =============================================================================
# INSTANTIATE_NEW MODE
# =============================================================================

# Spawn each scene at each node-path location and optionally at each custom position.
# An empty NodePath in spawn_locations means the juice's own animated target.
func _instantiate_new(target: Node) -> void:
	if spawn_scenes.is_empty():
		JuiceLogger.warn(self, _get_domain_tag(), "spawn_scenes is empty", debug_enabled)
		return

	if kill_previous_on_trigger:
		_kill_all_spawned_instances()

	# Resolve spawn locations; empty array defaults to the animated target itself.
	var ref_nodes: Array[Node] = []
	if spawn_locations.is_empty():
		ref_nodes.append(target)
	else:
		for path: NodePath in spawn_locations:
			var ref_node: Node
			if path == NodePath():
				ref_node = target
			elif not is_instance_valid(_host_node):
				JuiceLogger.warn(self, _get_domain_tag(),
						"_host_node not set — cannot resolve spawn path '%s', skipping" % path, debug_enabled)
				continue
			else:
				ref_node = _host_node.get_node_or_null(path)
			if not is_instance_valid(ref_node):
				JuiceLogger.warn(self, _get_domain_tag(),
						"spawn_location path '%s' could not be resolved" % path, debug_enabled)
				continue
			ref_nodes.append(ref_node)

	for ref_node in ref_nodes:
		_spawn_all_scenes_at_node(ref_node)

	if use_custom_positions:
		for pos in custom_positions:
			_spawn_all_scenes_at_custom_position(target, pos)


# Spawn every configured scene at a resolved reference node position.
func _spawn_all_scenes_at_node(ref_node: Node) -> void:
	for scene: PackedScene in spawn_scenes:
		if scene == null:
			continue
		_spawn_one_scene(scene, ref_node)


# Spawn every configured scene at a domain-typed custom position.
func _spawn_all_scenes_at_custom_position(target: Node, pos: Variant) -> void:
	for scene: PackedScene in spawn_scenes:
		if scene == null:
			continue
		_spawn_one_scene_at_custom_pos(scene, target, pos)


# Instantiate one scene at a reference node's position and add it to the tree.
func _spawn_one_scene(scene: PackedScene, ref_node: Node) -> void:
	if max_living_instances > 0:
		while _spawned_instances.size() >= max_living_instances:
			_cull_one_instance()

	var instance := scene.instantiate()
	if instance == null:
		return

	ref_node.add_child(instance)
	_place_instance(instance, ref_node, spawn_offset, inherit_rotation)
	_apply_scene_intensity(instance, intensity_multiplier)
	_fire_particles_in_subtree(instance)
	_setup_auto_free(instance, auto_free_delay)

	_spawned_instances.append({
		"instance": instance,
		"spawn_time": Time.get_ticks_msec() / 1000.0
	})
	JuiceLogger.log_info(self, _get_domain_tag(),
			"spawned instance #%d" % _spawned_instances.size(), debug_enabled)


# Instantiate one scene at a domain-typed custom position.
func _spawn_one_scene_at_custom_pos(scene: PackedScene, target: Node, pos: Variant) -> void:
	if max_living_instances > 0:
		while _spawned_instances.size() >= max_living_instances:
			_cull_one_instance()

	var instance := scene.instantiate()
	if instance == null:
		return

	target.add_child(instance)
	_place_instance_at_custom_pos(instance, pos)
	_apply_scene_intensity(instance, intensity_multiplier)
	_fire_particles_in_subtree(instance)
	_setup_auto_free(instance, auto_free_delay)

	_spawned_instances.append({
		"instance": instance,
		"spawn_time": Time.get_ticks_msec() / 1000.0
	})


# Apply intensity multiplier to all particles inside a spawned instance subtree.
func _apply_scene_intensity(instance: Node, multiplier: float) -> void:
	if multiplier == 1.0:
		return
	for p in _find_all_particles_in_subtree(instance):
		_set_particle_amount(p, maxi(1, int(_get_particle_amount(p) * multiplier)))


# Restart and enable emitting on all particles in a newly spawned instance.
func _fire_particles_in_subtree(instance: Node) -> void:
	for p in _find_all_particles_in_subtree(instance):
		_restart_particle(p)
		_set_particle_emitting(p, true)


# Hook the "finished" signal if available; fall back to a timer on the instance's tree.
# Using instance.get_tree() avoids depending on _host_node being valid.
func _setup_auto_free(instance: Node, delay: float) -> void:
	if instance.has_signal("finished"):
		instance.finished.connect(func(): _on_instance_finished(instance))
	else:
		instance.get_tree().create_timer(delay).timeout.connect(
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


# Kill all tracked spawned instances immediately (used by kill_previous_on_trigger and stop).
func _kill_all_spawned_instances() -> void:
	for entry in _spawned_instances:
		var inst = entry.get("instance")
		if is_instance_valid(inst):
			inst.queue_free()
	_spawned_instances.clear()


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


# Return the viewport's active camera, or null if unavailable.
func _get_active_camera() -> Node:
	if not is_instance_valid(_host_node):
		return null
	var vp := _host_node.get_viewport()
	return vp.get_camera_3d() if vp else null


# =============================================================================
# VIRTUAL METHODS — domain subclasses MUST override these
# =============================================================================

## Position a spawned instance relative to a resolved reference node.
## Called for each (scene_entry × location_entry) combination.
## Subclasses have type-safe access to their domain's node properties here.
func _place_instance(_instance: Node, _ref_node: Node,
		_offset: Vector3, _inherit_rot: bool) -> void:
	push_error("VFXJuiceEffectBase: _place_instance() not implemented by domain subclass.")


## Place a spawned instance at a domain-typed custom position.
## pos is Vector2 for 2D/Control subclasses, Vector3 for 3D subclasses.
func _place_instance_at_custom_pos(_instance: Node, _pos: Variant) -> void:
	push_error("VFXJuiceEffectBase: _place_instance_at_custom_pos() not implemented by domain subclass.")


## Reposition particle children relative to the source node's domain-specific center.
## Called before firing in TRIGGER_EXISTING mode to correct Node2D layout offsets.
func _reposition_particles_to_node(_particles: Array[Node], _source_node: Node) -> void:
	pass  # 3D and default: no repositioning needed. 2D/Control override.


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

## Warn when minimum configuration is missing for the selected mode.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	match vfx_mode:
		VFXMode.TRIGGER_EXISTING:
			if trigger_targets.is_empty():
				warnings.append("No trigger sources configured. Add at least one entry.")
		VFXMode.INSTANTIATE_NEW:
			if spawn_scenes.is_empty():
				warnings.append("No spawn scenes configured. Drag a .tscn into Spawn Scenes.")
			else:
				for i in spawn_scenes.size():
					if spawn_scenes[i] == null:
						warnings.append("Spawn Scenes[%d] is null — drag a .tscn to fill it." % i)
			if spawn_locations.is_empty() and not use_custom_positions:
				warnings.append("No spawn locations and no custom positions. VFX will not spawn.")
	return warnings
