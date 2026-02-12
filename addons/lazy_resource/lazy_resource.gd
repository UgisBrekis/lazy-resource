@tool
class_name LazyResource extends Resource

## A lightweight wrapper for resources that prevents automatic loading.

## Emitted when the background loading actually begins.
signal started_loading()
## Emitted when the resource is fully loaded and ready to use.
signal loaded(resource: Resource)

## Target resource UID
@export var _uid: int = -1


## Override this in a subclass (e.g. LazyScene) to restrict the allowed type.
static func get_lazy_type() -> String:
	return "Resource"


## Load the resource immediately on the main thread and return it.
## [br]
## Will freeze game for large resources.
func load_resource() -> Resource:
	if _uid == -1 or not ResourceUID.has_id(_uid):
		return null
		
	var path := ResourceUID.get_id_path(_uid)
	var res := load(path)
	
	if res:
		loaded.emit(res)
	
	return res


## Start loading the resource in background (Fire and Forget).
## [br]
## This will emit 'started_loading' if a new load is triggered.
## [codeblock]
## extends Node2D
##
## @export var my_resource: LazyResource
##
## func _on_trigger() -> void:
##	my_resource.started_loading.connect(func():
##		while my_resource.get_load_progress() < 1.0:
##			var progress := my_resource.get_load_progress()
##			await get_tree().process_frame
##		
##		var packed_scene := my_resource.load_resource() as PackedScene
##		var node := packed_scene.instantiate() as Node
##		add_child(node)
##		)
##	
##	my_resource.request_load()
## [/codeblock]
func request_load() -> void:
	if _uid == -1 or not ResourceUID.has_id(_uid):
		return
	
	var path := ResourceUID.get_id_path(_uid)
	
	# If already cached, do nothing (it's already ready)
	if ResourceLoader.has_cached(path):
		return
	
	# Check current status
	var status := ResourceLoader.load_threaded_get_status(path)
	
	# Only start if not already loading or failed
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		var err := ResourceLoader.load_threaded_request(path)
		if err == OK:
			started_loading.emit()
		else:
			push_error("LazyResource: Failed to start background load for " + path)


## Returns 0.0 to 1.0. Useful for loading bars.
func get_load_progress() -> float:
	if _uid == -1: return 0.0
	
	var path := ResourceUID.get_id_path(_uid)
	
	# If fully loaded, return 1.0
	if ResourceLoader.has_cached(path):
		return 1.0
		
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(path, progress)
	
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		return 1.0
		
	if progress.size() > 0:
		return progress[0]
	
	return 0.0


## Load the resource in background without blocking the main thread.
## [codeblock]
## func _on_trigger() -> void:
##	var packed_scene := await my_resource.load_resource_threaded() as PackedScene
##	var node := packed_scene.instantiate() as Node
##	add_child(node)
## [/codeblock]
func load_resource_threaded() -> Resource:
	if _uid == -1 or not ResourceUID.has_id(_uid):
		push_error("LazyResource: No valid UID assigned.")
		return null

	var path := ResourceUID.get_id_path(_uid)

	# CACHED HIT: Return immediately
	if ResourceLoader.has_cached(path):
		var res := load(path)
		loaded.emit(res) # Always emit 'loaded' when requested!
		return res

	# START LOAD: If not already running
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)
		started_loading.emit()
	
	# AWAIT: Loop until done
	while true:
		status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await Engine.get_main_loop().process_frame
		else:
			break
	
	# FINISH: Retrieve and Emit
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var res := ResourceLoader.load_threaded_get(path)
		loaded.emit(res)
		return res
	
	# Handle Failure
	push_error("LazyResource: Threaded load failed for path: " + path)
	return null
	
	
#region Plugin API
## Intended to be used by the plugin, so don't touch.
func get_uid() -> int:
	return _uid


## Intended to be used by the plugin, so don't touch.
func set_uid(uid: int) -> void:
	_uid = uid
	emit_changed()
#endregion
	
	
