@tool
extends HBoxContainer

signal resource_changed(res: Resource)

var accepted_type: String = "Resource"
var main_btn: Button
var quick_load_btn: Button
var current_path: String = ""

func _init(_accepted_type: String):
	accepted_type = _accepted_type
	
	# 1. Setup Container
	add_theme_constant_override("separation", 0) # Merge buttons visually
	
	# 2. Main Button (Status & Navigation)
	main_btn = Button.new()
	main_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	main_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	main_btn.clip_text = true
	main_btn.custom_minimum_size.y = 28
	main_btn.pressed.connect(_on_main_btn_pressed)
	# Enable Right-click to clear on the main button
	main_btn.gui_input.connect(_on_main_btn_gui_input)
	add_child(main_btn)
	
	# 3. Quick Load Button (The "Assign" trigger)
	quick_load_btn = Button.new()
	quick_load_btn.custom_minimum_size.x = 28 # Square button
	quick_load_btn.flat = false
	quick_load_btn.pressed.connect(_open_quick_load)
	add_child(quick_load_btn)

func _ready():
		# This gives it the "Nested Resource" look you see in standard Godot inspectors
	var style = get_theme_stylebox("bg", "EditorProperty")
	main_btn.add_theme_stylebox_override("normal", style)
	main_btn.add_theme_stylebox_override("hover", style)
	main_btn.add_theme_stylebox_override("pressed", style)
	
	var style_normal = get_theme_stylebox("normal", "EditorInspectorFlatButton")
	var style_hover = get_theme_stylebox("hover", "EditorInspectorFlatButton")
	var style_pressed = get_theme_stylebox("pressed", "EditorInspectorFlatButton")
	
	quick_load_btn.add_theme_stylebox_override("normal", style_normal)
	quick_load_btn.add_theme_stylebox_override("hover", style_hover)
	quick_load_btn.add_theme_stylebox_override("pressed", style_pressed)
	
	# Set the icon for the quick load button once ready (needs theme)
	quick_load_btn.icon = get_theme_icon("LoadQuick", "EditorIcons")
	quick_load_btn.tooltip_text = "Quick Load Resource"


# --- VISUAL STATE MACHINE ---

func update_value(lazy_resource: LazyResource):
	# STATE 1: EMPTY
	if not lazy_resource or lazy_resource.get_uid() == -1:
		_set_state_empty()
		return

	var uid = lazy_resource.get_uid()
	
	if ResourceUID.has_id(uid):
		# STATE 2: ASSIGNED (VALID)
		var path = ResourceUID.get_id_path(uid)
		_set_state_assigned(path)
	else:
		# STATE 3: INVALID (BROKEN UID)
		_set_state_invalid(uid)

# --- STATES ---

func _set_state_empty():
	current_path = ""
	
	# Main Button acts as "Invite to Assign"
	main_btn.text = "Assign " + accepted_type
	main_btn.icon = get_theme_icon("NodeWarning", "EditorIcons")
	main_btn.modulate = Color.WHITE
	main_btn.tooltip_text = "No resource assigned. Click to Quick Load."
	
	# 3. TEXT COLOR: Use the standard Editor Warning color (Yellowish)
	var warn_color = get_theme_color("warning_color", "Editor")
	main_btn.add_theme_color_override("font_color", warn_color)
	main_btn.add_theme_color_override("font_hover_color", warn_color)
	main_btn.add_theme_color_override("font_focus_color", warn_color)
	
	# In empty state, the "Search" button is redundant if the main button does the same,
	# but we keep it for layout consistency or hide it. 
	# User Request: "Empty state - display a button... that invites to assign"
	# We'll hide the small button so the main one takes full width.
	quick_load_btn.visible = false

func _set_state_assigned(path: String):
	current_path = path
	
	# 1. Main Button: Navigation (Click to show in FileSystem)
	main_btn.text = path.get_file()
	main_btn.icon = _get_icon_for_path(path)
	main_btn.modulate = Color.WHITE
	main_btn.tooltip_text = path + "\nClick to highlight in FileSystem."
	
	# 2. APPLY THE STYLEBOX
	main_btn.remove_theme_color_override("font_color")
	main_btn.remove_theme_color_override("font_hover_color")
	main_btn.remove_theme_color_override("font_focus_color")
	
	# 3. Show Quick Load Button
	quick_load_btn.visible = true

func _set_state_invalid(uid: int):
	current_path = ""
	
	# Main Button acts as "Fix Me"
	main_btn.text = "Broken UID: " + str(uid)
	main_btn.icon = get_theme_icon("FileBroken", "EditorIcons")
	main_btn.modulate = Color.WHITE
	main_btn.tooltip_text = "The referenced resource is missing! Click to re-assign."
	
	# 3. TEXT COLOR: Use the standard Editor Error color (Reddish)
	var err_color = get_theme_color("error_color", "Editor")
	main_btn.add_theme_color_override("font_color", err_color)
	main_btn.add_theme_color_override("font_hover_color", err_color)
	main_btn.add_theme_color_override("font_focus_color", err_color)
	
	# Hide quick load, clicking the red error should trigger fix immediately
	quick_load_btn.visible = false

# --- ACTIONS ---

func _on_main_btn_pressed():
	if current_path != "":
		# Assigned State: Highlight in FileSystem
		EditorInterface.select_file(current_path)
	else:
		# Empty/Invalid State: Open Quick Load
		_open_quick_load()

func _open_quick_load():
	var types: Array[StringName] = []
	if accepted_type != "Resource":
		types.append(accepted_type)
	EditorInterface.popup_quick_open(_on_quick_open_selected, types)

func _on_quick_open_selected(path: String):
	if path.is_empty(): return
	var res = load(path)
	resource_changed.emit(res)

func _on_main_btn_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			resource_changed.emit(null) # Clear
			accept_event()

# --- DRAG & DROP (On the whole container) ---

func _can_drop_data(_at_position, data):
	if data.has("type") and data.type == "files":
		return true 
	return false

func _drop_data(_at_position, data):
	var path = data.files[0]
	var res = load(path)
	if res.is_class(accepted_type) or accepted_type == "Resource":
		resource_changed.emit(res)

func _get_icon_for_path(path: String) -> Texture2D:
	# 1. Ask the EditorFileSystem what this file actually is.
	# This returns strings like "PackedScene", "Resource", "GDScript", 
	# or your custom class name "MyInventoryItem".
	var type = EditorInterface.get_resource_filesystem().get_file_type(path)
	
	# Safety: If the file is new and not scanned yet, fallback to a generic object
	if type.is_empty():
		return get_theme_icon("Object", "EditorIcons")

	var theme = EditorInterface.get_editor_theme()

	# 2. Strategy A: Is it a built-in type with an icon? (e.g. PackedScene)
	if theme.has_icon(type, "EditorIcons"):
		return theme.get_icon(type, "EditorIcons")

	# 3. Strategy B: Is it a Custom Script Class? (class_name MyData)
	# We iterate the global class list to find custom icons defined in scripts.
	var global_classes = ProjectSettings.get_global_class_list()
	for class_data in global_classes:
		if class_data["class"] == type:
			# We found the class! Does it have a custom icon path?
			var icon_path = class_data["icon"]
			if not icon_path.is_empty() and FileAccess.file_exists(icon_path):
				return load(icon_path)
			
			# If no custom icon, try to use the base class's icon
			# (e.g. MyData extends Resource -> Use Resource icon)
			var base_type = class_data["base"]
			if theme.has_icon(base_type, "EditorIcons"):
				return theme.get_icon(base_type, "EditorIcons")
	
	# 4. Strategy C: Inheritance Walk (For internal types like CompressedTexture2D)
	# If "StreamTexture2D" doesn't have an icon, maybe "Texture2D" does.
	while not type.is_empty():
		if theme.has_icon(type, "EditorIcons"):
			return theme.get_icon(type, "EditorIcons")
		
		# Walk up the C++ inheritance tree
		type = ClassDB.get_parent_class(type)

	# 5. Final Fallback
	return theme.get_icon("Object", "EditorIcons")
