@tool
class_name LazyResource extends Resource

# We only save the integer UID to disk. This is the "Zero Weight" magic.
@export_storage var _uid: int = -1

# These functions create a "Virtual Property" in the Inspector.
# It allows you to see what is assigned, but Godot never saves the actual resource.
func _get_property_list() -> Array:
	return [{
		"name": "editor_preview",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY # Read-only!
	}]


func _get(property: StringName):
	if property == "editor_preview" and _uid != -1:
		if ResourceUID.has_id(_uid):
			return load(ResourceUID.get_id_path(_uid))
	return null


# Override this in a subclass (e.g. LazyScene) to restrict the allowed type.
static func get_lazy_type() -> String:
	return "Resource"


# Called by the Editor Plugin when you drop a resource.
func set_target(resource: Resource) -> void:
	if resource:
		var path := resource.resource_path
		
		if not path.is_empty():
			_uid = ResourceLoader.get_resource_uid(path)
		else:
			push_warning("LazyResource: Resource has no path. Cannot lazy load.")
			_uid = -1
	else:
		_uid = -1
	
	emit_changed()


## Load the resource immediately on the main thread and return it. Will freeze game for large assets.
func load_resource() -> Resource:
	if _uid != -1 and ResourceUID.has_id(_uid):
		return load(ResourceUID.get_id_path(_uid))
	
	return null


## Load the resource in background without blocking the main thread and return when ready.
## Usage: var scene = await my_lazy.load_resource_async()
func load_resource_async() -> Resource:
	if _uid == -1 or not ResourceUID.has_id(_uid):
		push_error("LazyResource: No valid UID assigned.")
		return null

	var path = ResourceUID.get_id_path(_uid)

	# If already cached, return immediately
	if ResourceLoader.has_cached(path):
		return load(path)

	# Start loading if not already in progress
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)
	
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await Engine.get_main_loop().process_frame
	
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(path)
	
	return null


## Starts loading but doesn't wait. Good for pre-warming caches.
func request_load() -> void:
	if _uid != -1 and ResourceUID.has_id(_uid):
		var path = ResourceUID.get_id_path(_uid)
		if not ResourceLoader.has_cached(path):
			ResourceLoader.load_threaded_request(path)


## Returns 0.0 to 1.0. Useful for loading bars.
func get_load_progress() -> float:
	if _uid == -1:
		return 0.0
	
	var path := ResourceUID.get_id_path(_uid)
	var progress : Array[float] = []
	ResourceLoader.load_threaded_get_status(path, progress)
	
	if progress.size() > 0:
		return progress[0]
	
	return 0.0

## Helper to get the raw UID (for validation tools)
func get_uid() -> int:
	return _uid
