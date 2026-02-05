@tool
extends Button

signal resource_changed(res: Resource)

var accepted_type: String = "Resource"

func _init(_accepted_type: String):
	accepted_type = _accepted_type
	
	# Visual Setup
	custom_minimum_size.y = 28
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_text = true
	
	# Connect click to the Native Quick Open
	pressed.connect(_on_pressed)

# --- VISUALS ---

func update_value(lazy_resource: LazyResource):
	# 1. EMPTY STATE
	if not lazy_resource or lazy_resource.get_uid() == -1:
		text = "Assign " + accepted_type
		icon = get_theme_icon("Add", "EditorIcons")
		tooltip_text = "Click to Quick Open (Fuzzy Search)"
		modulate = Color(1, 1, 1, 0.6)
		return

	# 2. FILLED STATE
	var uid = lazy_resource.get_uid()
	if ResourceUID.has_id(uid):
		var path = ResourceUID.get_id_path(uid)
		text = path.get_file() 
		icon = _get_icon_for_path(path)
		tooltip_text = path
		modulate = Color.WHITE
	else:
		# 3. BROKEN STATE
		text = "Missing UID: " + str(uid)
		icon = get_theme_icon("FileBroken", "EditorIcons")
		modulate = Color(1, 0.5, 0.5)

# --- EVENTS ---

func _on_pressed():
	# Prepare the type filter
	var types: Array[StringName] = []
	if accepted_type != "Resource":
		types.append(accepted_type)
		
	# Triggers the NATIVE "Quick Open" dialog (fuzzy searcher)
	# The callback must accept a single String argument (the selected path)
	EditorInterface.popup_quick_open(_on_quick_open_selected, types)

func _on_quick_open_selected(path: String):
	if path.is_empty(): return
	
	var res = load(path)
	resource_changed.emit(res)

# Handle Right-Click to Clear
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			resource_changed.emit(null)
			accept_event()

# --- DRAG & DROP ---

func _can_drop_data(_at_position, data):
	if data.has("type") and data.type == "files":
		return true 
	return false

func _drop_data(_at_position, data):
	var path = data.files[0]
	var res = load(path)
	
	if res.is_class(accepted_type) or accepted_type == "Resource":
		resource_changed.emit(res)
	else:
		print("LazyResource: Wrong type! Expected " + accepted_type)

# --- ICON HELPER ---

func _get_icon_for_path(path: String) -> Texture2D:
	# Try to get the specific icon for the file type
	var ext = path.get_extension().to_lower()
	var theme = EditorInterface.get_editor_theme()
	
	if ext == "tscn" or ext == "scn":
		return theme.get_icon("PackedScene", "EditorIcons")
	elif ext in ["png", "jpg", "svg", "webp"]:
		return theme.get_icon("Texture2D", "EditorIcons")
	elif ext in ["wav", "ogg", "mp3"]:
		return theme.get_icon("AudioStream", "EditorIcons")
	elif ext == "tres" or ext == "res":
		return theme.get_icon("Resource", "EditorIcons")
	elif ext == "gd":
		return theme.get_icon("Script", "EditorIcons")
		
	return theme.get_icon("Object", "EditorIcons")
