## VFXJuiceComp.gd
## ============================================================================
## WHAT: Unified juice component for triggering particle VFX effects.
##       Supports two modes: using particle children OR spawning external scenes.
## WHY: Provides a single, marketable component for all VFX juice needs with
##       proper lifecycle management, intensity control, and performance limits.
## SYSTEM: Juicing System (addons/juice/VFX/)
## DOES NOT: Create particle systems - they must be authored as children or scenes.
##           Does NOT handle trails - use TrailJuiceComp for that.
## ============================================================================
##
## USAGE (Children Mode - Default):
## 1. Add VFXJuiceComp as parent of your particle effects
## 2. Add GPUParticles3D/2D or CPUParticles3D/2D as children
## 3. Configure trigger and one_shot setting
## 4. animate_in() triggers particles, animate_out() stops them (continuous mode)
##
## USAGE (External Scene Mode):
## 1. Add VFXJuiceComp to any node
## 2. Set vfx_source to EXTERNAL_SCENE
## 3. Assign a PackedScene containing your VFX
## 4. Each animate_in() spawns a new independent VFX instance
##
## LIFECYCLE MANAGEMENT:
## - max_living_instances limits simultaneous VFX (0 = unlimited)
## - cull_strategy determines which VFX to remove when limit reached
## - Default: particles die naturally, NOT killed by new spawns
## ============================================================================

@tool
@icon("res://addons/Juice_V1/Icons/JuiceBaseVFX.svg")
class_name VFXJuiceComp
extends JuiceCompBase

# =============================================================================
# ENUMS
# =============================================================================

## How VFX are sourced
enum SourceMode {
	CHILDREN,        ## Use particle nodes that are children of this component
	EXTERNAL_SCENE   ## Instantiate a PackedScene containing VFX
}

## Strategy for culling VFX when max_living_instances is reached
enum CullStrategy {
	OLDEST,          ## Remove the first spawned (FIFO) - simple, predictable
	MOST_PROGRESSED, ## Remove the one closest to natural death - minimal disruption
	FARTHEST_CAMERA  ## Remove the one farthest from active camera - best visual quality
}

# =============================================================================
# VFX CONFIGURATION
# =============================================================================

@export_group("Effect")

## Offset from target position when spawning (3D). For 2D, only X and Y are used.
@export var spawn_offset: Vector3 = Vector3.ZERO

## If true, spawned VFX inherits the target's rotation
@export var inherit_rotation: bool = true

## If true, spawn in world space (VFX survives if target is freed)
## If false, spawn as child of target (moves with target)
## Only applies to EXTERNAL_SCENE mode
@export var spawn_in_world_space: bool = true

## If true, kill all previous VFX from this component when triggering a new one.
## Default is FALSE - particles die naturally and can overlap.
@export var kill_previous_on_trigger: bool = false

## Multiplier for particle amount. 1.0 = use configured amount.
## 2.0 = double particles, 0.5 = half, etc.
@export var intensity_multiplier: float = 1.0

## Maximum simultaneous VFX instances from this component.
## 0 = unlimited. When limit is reached, oldest VFX is culled based on cull_strategy.
@export var max_living_instances: int = 0:
	set(value):
		max_living_instances = value
		notify_property_list_changed()

## How to source the VFX: from children or an external scene
@export var vfx_source: SourceMode = SourceMode.CHILDREN:
	set(value):
		vfx_source = value
		notify_property_list_changed()

## The VFX scene to instantiate (only shown when vfx_source = EXTERNAL_SCENE)
var vfx_scene: PackedScene

## Fallback time to free spawned VFX if it has no "finished" signal.
## Only applies to EXTERNAL_SCENE mode.
var auto_free_delay: float = 2.0

## Strategy for culling VFX when max_living_instances is exceeded (hidden when unlimited)
var cull_strategy: int = CullStrategy.OLDEST

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	if max_living_instances > 0:
		props.append({
			"name": "cull_strategy",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Oldest,Most Progressed,Farthest Camera",
		})
	if vfx_source == SourceMode.EXTERNAL_SCENE:
		props.append({
			"name": "vfx_scene",
			"type": TYPE_OBJECT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "PackedScene",
		})
		props.append({
			"name": "auto_free_delay",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	return props


func _set(prop: StringName, value: Variant) -> bool:
	match prop:
		&"vfx_scene":
			vfx_scene = value
			return true
		&"cull_strategy":
			cull_strategy = value
			return true
		&"auto_free_delay":
			auto_free_delay = value
			return true
	return false


func _get(prop: StringName) -> Variant:
	match prop:
		&"vfx_scene":
			return vfx_scene
		&"cull_strategy":
			return cull_strategy
		&"auto_free_delay":
			return auto_free_delay
	return null

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Cached particle children (for CHILDREN mode)
var _particle_children: Array[Node] = []

## Original particle amounts (for intensity restoration)
var _original_amounts: Dictionary = {}

## Tracked spawned instances with metadata (for EXTERNAL_SCENE mode)
## Each entry: { "instance": Node, "spawn_time": float }
var _spawned_instances: Array[Dictionary] = []

## Flag indicating if particles are currently active (for continuous mode)
var _particles_active: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()
	
	# Discover children if in CHILDREN mode
	if vfx_source == SourceMode.CHILDREN:
		_discover_particle_children()
	elif vfx_source == SourceMode.EXTERNAL_SCENE and vfx_scene == null:
		if debug_enabled:
			push_warning("[%s] vfx_source is EXTERNAL_SCENE but no vfx_scene assigned" % name)
	
	if debug_enabled:
		if vfx_source == SourceMode.CHILDREN:
			print("[%s] Ready (CHILDREN mode) - found %d particles" % [name, _particle_children.size()])
		else:
			print("[%s] Ready (EXTERNAL_SCENE mode) - scene: %s" % [name, vfx_scene.resource_path if vfx_scene else "none"])


func _exit_tree() -> void:
	# Clean up any remaining spawned instances
	for entry in _spawned_instances:
		var instance = entry.get("instance")
		if is_instance_valid(instance):
			instance.queue_free()
	_spawned_instances.clear()

# =============================================================================
# PARTICLE DISCOVERY (CHILDREN MODE)
# =============================================================================

## Discover all particle system children using type-safe checks
func _discover_particle_children() -> void:
	_particle_children.clear()
	_original_amounts.clear()
	
	for child in get_children():
		if _is_particle_node(child):
			_particle_children.append(child)
			_original_amounts[child] = _get_particle_amount(child)
			
			if debug_enabled:
				print("[%s] Discovered particle: %s (%s)" % [name, child.name, child.get_class()])


## Check if a node is any type of particle system
func _is_particle_node(node: Node) -> bool:
	return (node is GPUParticles2D or node is GPUParticles3D or
			node is CPUParticles2D or node is CPUParticles3D)

# =============================================================================
# PARTICLE HELPERS (work with any particle type)
# =============================================================================

func _get_particle_amount(particle: Node) -> int:
	if particle is GPUParticles2D:
		return (particle as GPUParticles2D).amount
	elif particle is GPUParticles3D:
		return (particle as GPUParticles3D).amount
	elif particle is CPUParticles2D:
		return (particle as CPUParticles2D).amount
	elif particle is CPUParticles3D:
		return (particle as CPUParticles3D).amount
	return 0


func _set_particle_amount(particle: Node, amount: int) -> void:
	if particle is GPUParticles2D:
		(particle as GPUParticles2D).amount = amount
	elif particle is GPUParticles3D:
		(particle as GPUParticles3D).amount = amount
	elif particle is CPUParticles2D:
		(particle as CPUParticles2D).amount = amount
	elif particle is CPUParticles3D:
		(particle as CPUParticles3D).amount = amount


func _is_particle_emitting(particle: Node) -> bool:
	if particle is GPUParticles2D:
		return (particle as GPUParticles2D).emitting
	elif particle is GPUParticles3D:
		return (particle as GPUParticles3D).emitting
	elif particle is CPUParticles2D:
		return (particle as CPUParticles2D).emitting
	elif particle is CPUParticles3D:
		return (particle as CPUParticles3D).emitting
	return false


func _set_particle_emitting(particle: Node, emitting: bool) -> void:
	if particle is GPUParticles2D:
		(particle as GPUParticles2D).emitting = emitting
	elif particle is GPUParticles3D:
		(particle as GPUParticles3D).emitting = emitting
	elif particle is CPUParticles2D:
		(particle as CPUParticles2D).emitting = emitting
	elif particle is CPUParticles3D:
		(particle as CPUParticles3D).emitting = emitting


func _restart_particle(particle: Node) -> void:
	if particle is GPUParticles2D:
		(particle as GPUParticles2D).restart()
	elif particle is GPUParticles3D:
		(particle as GPUParticles3D).restart()
	elif particle is CPUParticles2D:
		(particle as CPUParticles2D).restart()
	elif particle is CPUParticles3D:
		(particle as CPUParticles3D).restart()


func _get_particle_lifetime(particle: Node) -> float:
	if particle is GPUParticles2D:
		return (particle as GPUParticles2D).lifetime
	elif particle is GPUParticles3D:
		return (particle as GPUParticles3D).lifetime
	elif particle is CPUParticles2D:
		return (particle as CPUParticles2D).lifetime
	elif particle is CPUParticles3D:
		return (particle as CPUParticles3D).lifetime
	return 1.0


func _is_particle_one_shot(particle: Node) -> bool:
	if particle is GPUParticles2D:
		return (particle as GPUParticles2D).one_shot
	elif particle is GPUParticles3D:
		return (particle as GPUParticles3D).one_shot
	elif particle is CPUParticles2D:
		return (particle as CPUParticles2D).one_shot
	elif particle is CPUParticles3D:
		return (particle as CPUParticles3D).one_shot
	return false

# =============================================================================
# JUICE IMPLEMENTATION
# =============================================================================

func _on_animate_start() -> void:
	# Handle based on source mode
	if vfx_source == SourceMode.CHILDREN:
		_trigger_children_particles()
	else:
		_spawn_external_vfx()


func _apply_effect(_progress: float) -> void:
	# Particles handle their own animation via process_material
	# Nothing to interpolate here
	pass


func _on_animate_out_complete() -> void:
	# For continuous mode: stop particles when animate_out completes
	if vfx_source == SourceMode.CHILDREN:
		_stop_children_particles()
	
	# Restore original amounts if modified
	if intensity_multiplier != 1.0:
		for particle in _particle_children:
			if is_instance_valid(particle) and _original_amounts.has(particle):
				_set_particle_amount(particle, _original_amounts[particle])
	
	_particles_active = false

# =============================================================================
# CHILDREN MODE IMPLEMENTATION
# =============================================================================

func _trigger_children_particles() -> void:
	if _particle_children.is_empty():
		if debug_enabled:
			push_warning("[%s] No particle children to trigger" % name)
		return
	
	# Handle kill_previous_on_trigger
	if kill_previous_on_trigger:
		for particle in _particle_children:
			if is_instance_valid(particle) and _is_particle_emitting(particle):
				_restart_particle(particle)
				if debug_enabled:
					print("[%s] Restarted particle: %s (kill_previous_on_trigger)" % [name, particle.name])
	
	# Position particles at target node center (fixes Node2D children of Control parents)
	# Node2D particles don't inherit position from Control ancestors, so we set it manually
	# For Controls, we use center (global_position + size/2) not top-left corner
	if _target_node is Control:
		var target_ctrl := _target_node as Control
		var target_pos: Vector2 = target_ctrl.global_position + (target_ctrl.size / 2.0)
		for particle in _particle_children:
			if particle is Node2D:
				(particle as Node2D).global_position = target_pos
	elif _target_node is Node2D:
		var target_pos: Vector2 = (_target_node as Node2D).global_position
		for particle in _particle_children:
			if particle is Node2D:
				(particle as Node2D).global_position = target_pos
	
	# Apply intensity and start particles
	for particle in _particle_children:
		if not is_instance_valid(particle):
			continue
		
		# Skip if already emitting and we don't want to restart
		if not kill_previous_on_trigger and _is_particle_emitting(particle):
			if debug_enabled:
				print("[%s] Skipping %s (already emitting, kill_previous=false)" % [name, particle.name])
			continue
		
		# Apply intensity multiplier
		if intensity_multiplier != 1.0:
			var original := _original_amounts.get(particle, 1) as int
			var scaled := int(original * intensity_multiplier)
			_set_particle_amount(particle, maxi(1, scaled))
		
		# Start the particle
		_set_particle_emitting(particle, true)
		
		if debug_enabled:
			var pos_str: String = str((particle as Node2D).global_position) if particle is Node2D else "N/A"
			print("[%s] Triggered particle: %s at %s" % [name, particle.name, pos_str])
	
	_particles_active = true


func _stop_children_particles() -> void:
	for particle in _particle_children:
		if is_instance_valid(particle):
			_set_particle_emitting(particle, false)
	
	if debug_enabled:
		print("[%s] Stopped all children particles" % name)

# =============================================================================
# EXTERNAL SCENE MODE IMPLEMENTATION
# =============================================================================

func _spawn_external_vfx() -> void:
	if vfx_scene == null:
		if debug_enabled:
			push_warning("[%s] Cannot spawn - no vfx_scene assigned" % name)
		return
	
	if _target_node == null:
		if debug_enabled:
			push_warning("[%s] Cannot spawn - no target node" % name)
		return
	
	# Handle kill_previous_on_trigger
	if kill_previous_on_trigger:
		_kill_all_spawned_instances()
	
	# Check max_living_instances limit and cull if needed
	if max_living_instances > 0:
		while _spawned_instances.size() >= max_living_instances:
			_cull_one_instance()
	
	# Instantiate the VFX scene
	var instance := vfx_scene.instantiate()
	if instance == null:
		if debug_enabled:
			push_error("[%s] Failed to instantiate vfx_scene" % name)
		return
	
	# Determine spawn parent
	var spawn_parent: Node
	if spawn_in_world_space:
		spawn_parent = _target_node.get_tree().current_scene
	else:
		spawn_parent = _target_node.get_parent()
	
	if spawn_parent == null:
		spawn_parent = _target_node.get_tree().current_scene
	
	# Add to scene tree FIRST (global_position requires being in tree)
	spawn_parent.add_child(instance)
	
	# Position the instance AFTER adding to tree
	_position_instance(instance)
	
	# Track with metadata
	var entry := {
		"instance": instance,
		"spawn_time": Time.get_ticks_msec() / 1000.0
	}
	_spawned_instances.append(entry)
	
	# Apply intensity to all particles in the instance
	if intensity_multiplier != 1.0:
		_apply_intensity_to_instance(instance)
	
	# Start all particles
	_start_particles_in_instance(instance)
	
	# Setup auto-free
	_setup_instance_auto_free(instance)
	
	if debug_enabled:
		print("[%s] Spawned VFX instance #%d at %s" % [name, _spawned_instances.size(), _get_position_debug()])

# =============================================================================
# LIFECYCLE MANAGEMENT (CULLING)
# =============================================================================

func _cull_one_instance() -> void:
	if _spawned_instances.is_empty():
		return
	
	var index_to_cull: int = 0
	
	match cull_strategy:
		CullStrategy.OLDEST:
			# First in array is oldest (FIFO)
			index_to_cull = 0
		
		CullStrategy.MOST_PROGRESSED:
			# Find the one with earliest spawn_time (same as oldest for same-lifetime VFX)
			var earliest_time: float = INF
			for i in range(_spawned_instances.size()):
				var spawn_time: float = _spawned_instances[i].get("spawn_time", 0.0)
				if spawn_time < earliest_time:
					earliest_time = spawn_time
					index_to_cull = i
		
		CullStrategy.FARTHEST_CAMERA:
			# Find the one farthest from active camera
			var camera := _get_active_camera()
			if camera == null:
				# Fallback to OLDEST if no camera
				index_to_cull = 0
			else:
				var max_distance: float = -1.0
				var camera_pos: Vector3 = camera.global_position if camera is Camera3D else Vector3.ZERO
				
				for i in range(_spawned_instances.size()):
					var inst = _spawned_instances[i].get("instance")
					if not is_instance_valid(inst):
						continue
					
					var inst_pos: Vector3
					if inst is Node3D:
						inst_pos = (inst as Node3D).global_position
					elif inst is Node2D:
						var pos_2d := (inst as Node2D).global_position
						inst_pos = Vector3(pos_2d.x, pos_2d.y, 0)
					else:
						continue
					
					var distance := camera_pos.distance_to(inst_pos)
					if distance > max_distance:
						max_distance = distance
						index_to_cull = i
	
	# Cull the selected instance
	var entry := _spawned_instances[index_to_cull]
	var cull_instance = entry.get("instance")
	if is_instance_valid(cull_instance):
		cull_instance.queue_free()
		if debug_enabled:
			print("[%s] Culled instance (strategy: %s)" % [name, CullStrategy.keys()[cull_strategy]])
	
	_spawned_instances.remove_at(index_to_cull)


func _kill_all_spawned_instances() -> void:
	for entry in _spawned_instances:
		var instance = entry.get("instance")
		if is_instance_valid(instance):
			instance.queue_free()
	_spawned_instances.clear()
	
	if debug_enabled:
		print("[%s] Killed all spawned instances (kill_previous_on_trigger)" % name)


func _get_active_camera() -> Node:
	# Try to get 3D camera first
	var viewport := get_viewport()
	if viewport:
		var camera_3d := viewport.get_camera_3d()
		if camera_3d:
			return camera_3d
	
	# For 2D, there's no direct equivalent - return null
	return null

# =============================================================================
# INSTANCE HELPERS (EXTERNAL SCENE MODE)
# =============================================================================

func _position_instance(instance: Node) -> void:
	var is_target_3d := _target_node is Node3D
	var is_target_2d := _target_node is Node2D or _target_node is Control
	
	if is_target_3d and instance is Node3D:
		var target_3d := _target_node as Node3D
		var instance_3d := instance as Node3D
		instance_3d.global_position = target_3d.global_position + spawn_offset
		if inherit_rotation:
			instance_3d.global_rotation = target_3d.global_rotation
			
	elif is_target_2d and instance is Node2D:
		var offset_2d := Vector2(spawn_offset.x, spawn_offset.y)
		if _target_node is Node2D:
			var target_2d := _target_node as Node2D
			var instance_2d := instance as Node2D
			instance_2d.global_position = target_2d.global_position + offset_2d
			if inherit_rotation:
				instance_2d.global_rotation = target_2d.global_rotation
		elif _target_node is Control:
			# Use center of Control (global_position + size/2), not top-left corner
			var target_ctrl := _target_node as Control
			var instance_2d := instance as Node2D
			var center_pos := target_ctrl.global_position + (target_ctrl.size / 2.0)
			instance_2d.global_position = center_pos + offset_2d


func _apply_intensity_to_instance(instance: Node) -> void:
	var particles := _find_all_particles_in_subtree(instance)
	for particle in particles:
		var current := _get_particle_amount(particle)
		var scaled := int(current * intensity_multiplier)
		_set_particle_amount(particle, maxi(1, scaled))


func _find_all_particles_in_subtree(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	_find_particles_recursive(root, result)
	return result


func _find_particles_recursive(node: Node, result: Array[Node]) -> void:
	if _is_particle_node(node):
		result.append(node)
	for child in node.get_children():
		_find_particles_recursive(child, result)


func _start_particles_in_instance(instance: Node) -> void:
	var particles := _find_all_particles_in_subtree(instance)
	for particle in particles:
		_restart_particle(particle)
		_set_particle_emitting(particle, true)


func _setup_instance_auto_free(instance: Node) -> void:
	# Try "finished" signal first
	if instance.has_signal("finished"):
		instance.connect("finished", func(): _on_instance_finished(instance))
		if debug_enabled:
			print("[%s] Connected to 'finished' signal for auto-free" % name)
	else:
		# Timer fallback
		get_tree().create_timer(auto_free_delay).timeout.connect(
			func(): _on_instance_finished(instance)
		)
		if debug_enabled:
			print("[%s] Using timer fallback (%.1fs) for auto-free" % [name, auto_free_delay])


func _on_instance_finished(instance: Node) -> void:
	if is_instance_valid(instance):
		# Remove from tracking
		for i in range(_spawned_instances.size() - 1, -1, -1):
			if _spawned_instances[i].get("instance") == instance:
				_spawned_instances.remove_at(i)
				break
		
		instance.queue_free()
		if debug_enabled:
			print("[%s] Auto-freed VFX instance" % name)


func _get_position_debug() -> String:
	if _target_node is Node3D:
		return str((_target_node as Node3D).global_position + spawn_offset)
	elif _target_node is Node2D:
		return str((_target_node as Node2D).global_position + Vector2(spawn_offset.x, spawn_offset.y))
	elif _target_node is Control:
		return str((_target_node as Control).global_position + Vector2(spawn_offset.x, spawn_offset.y))
	return "(unknown)"
