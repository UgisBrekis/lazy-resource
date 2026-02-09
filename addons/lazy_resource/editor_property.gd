@tool
extends EditorProperty

var _container: HBoxContainer
var _main_btn: Button
var _quick_load_btn: Button

var _accepted_type: String = "Resource"
var _icon_cache : Dictionary[String, Texture2D]
var _current_path: String = ""


func _init(accepted_type: String, icon_cache : Dictionary[String, Texture2D]):
	_accepted_type = accepted_type
	_icon_cache = icon_cache
	
	# 1. SETUP CONTAINER
	_container = HBoxContainer.new()
	_container.add_theme_constant_override("separation", 0)
	_container.size_flags_horizontal = SIZE_EXPAND_FILL # Fill available space
	add_child(_container)
	
	# 2. SETUP MAIN BUTTON
	_main_btn = Button.new()
	_main_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	_main_btn.clip_text = true
	_main_btn.custom_minimum_size.y = 28
	
	_main_btn.pressed.connect(_on_main_btn_pressed)
	_container.add_child(_main_btn)
	
	# 3. SETUP QUICK LOAD BUTTON
	_quick_load_btn = Button.new()
	_quick_load_btn.custom_minimum_size.x = 28
	_quick_load_btn.flat = false
	_quick_load_btn.pressed.connect(_open_quick_load)
	_container.add_child(_quick_load_btn)


func _ready():
	var style_bg := get_theme_stylebox("bg", "EditorProperty")
	_main_btn.add_theme_stylebox_override("normal", style_bg)
	_main_btn.add_theme_stylebox_override("hover", style_bg)
	_main_btn.add_theme_stylebox_override("pressed", style_bg)
	
	# Quick Button: Use standard flat inspector button styles
	var style_normal := get_theme_stylebox("normal", "EditorInspectorFlatButton")
	var style_hover := get_theme_stylebox("hover", "EditorInspectorFlatButton")
	var style_pressed := get_theme_stylebox("pressed", "EditorInspectorFlatButton")
	
	_quick_load_btn.add_theme_stylebox_override("normal", style_normal)
	_quick_load_btn.add_theme_stylebox_override("hover", style_hover)
	_quick_load_btn.add_theme_stylebox_override("pressed", style_pressed)
	
	_quick_load_btn.icon = get_theme_icon("LoadQuick", "EditorIcons")
	_quick_load_btn.tooltip_text = "Quick Load Resource"


func _update_property() -> void:
	var lazy_resource := get_edited_object()[get_edited_property()] as LazyResource
	
	if not lazy_resource or lazy_resource.get_uid() == -1:
		_set_state_empty()
		return

	var uid := lazy_resource.get_uid()
	
	if ResourceUID.has_id(uid):
		var path := ResourceUID.get_id_path(uid)
		_set_state_assigned(path)
	else:
		_set_state_invalid(uid)


#region Visual states
func _set_state_empty() -> void:
	_current_path = ""
	
	_main_btn.text = "Assign " + _accepted_type
	_main_btn.icon = get_theme_icon("StatusWarning", "EditorIcons")
	_main_btn.tooltip_text = "No resource assigned. Click to Quick Load."
	
	var warn_color := get_theme_color("warning_color", "Editor")
	_main_btn.add_theme_color_override("font_color", warn_color)
	_main_btn.add_theme_color_override("font_hover_color", warn_color)
	_main_btn.add_theme_color_override("font_focus_color", warn_color)
	
	_quick_load_btn.visible = false

func _set_state_assigned(path: String) -> void:
	_current_path = path
	
	_main_btn.text = path.get_file()
	_main_btn.icon = _get_icon_for_path(path)
	_main_btn.tooltip_text = path + "\nClick to highlight in FileSystem."
	
	_main_btn.remove_theme_color_override("font_color")
	_main_btn.remove_theme_color_override("font_hover_color")
	_main_btn.remove_theme_color_override("font_focus_color")
	
	_quick_load_btn.visible = true


func _set_state_invalid(uid: int) -> void:
	_current_path = ""
	
	_main_btn.text = "Broken UID: " + str(uid)
	_main_btn.icon = get_theme_icon("FileBroken", "EditorIcons")
	_main_btn.tooltip_text = "The referenced resource is missing! Click to re-assign."
	
	var err_color := get_theme_color("error_color", "Editor")
	_main_btn.add_theme_color_override("font_color", err_color)
	_main_btn.add_theme_color_override("font_hover_color", err_color)
	_main_btn.add_theme_color_override("font_focus_color", err_color)
	
	_quick_load_btn.visible = false
#endregion


func _on_main_btn_pressed() -> void:
	if not _current_path.is_empty():
		EditorInterface.select_file(_current_path)
		return
	
	_open_quick_load()


func _open_quick_load() -> void:
	var types: Array[StringName] = []
	if _accepted_type != "Resource":
		types.append(_accepted_type)
	
	EditorInterface.popup_quick_open(_on_quick_open_selected, types)


func _on_quick_open_selected(path: String) -> void:
	if path.is_empty():
		return
	
	var resource := load(path) as Resource
	_apply_resource(resource)


func _apply_resource(resource: Resource) -> void:
	if not resource:
		emit_changed(get_edited_property(), null)
		return
	
	if resource is LazyResource:
		emit_changed(get_edited_property(), resource)
		return
	
	var lazy_resource := LazyResource.new()
	lazy_resource.set_target(resource)
	lazy_resource.resource_local_to_scene = true 
	emit_changed(get_edited_property(), lazy_resource)



#region Drag and drop
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data.has("type") and data.type == "files":
		return true 
	return false


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var path := data.files[0] as String
	var res = load(path)
	if res.is_class(_accepted_type) or _accepted_type == "Resource":
		_apply_resource(res)
#endregion


#region Icon
func _get_icon_for_path(path: String) -> Texture2D:
	var type := EditorInterface.get_resource_filesystem().get_file_type(path)
	if type.is_empty():
		return get_theme_icon("Object", "EditorIcons")
	
	if _icon_cache.has(type):
		return _icon_cache[type]
	
	var icon := _resolve_icon(type)
	_icon_cache[type] = icon
	
	return icon


func _resolve_icon(type_name: String) -> Texture2D:
	var theme := EditorInterface.get_editor_theme()
	
	if theme.has_icon(type_name, "EditorIcons"):
		return theme.get_icon(type_name, "EditorIcons")
	
	var global_classes := ProjectSettings.get_global_class_list()
	for class_data in global_classes:
		if class_data["class"] == type_name:
			var icon_path := class_data["icon"] as String
			if not icon_path.is_empty() and FileAccess.file_exists(icon_path):
				return load(icon_path)
			
			# Inheritance Recursion
			return _resolve_icon(class_data["base"])
	
	return theme.get_icon("Object", "EditorIcons")
#endregion
