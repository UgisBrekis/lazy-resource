@tool
extends EditorProperty

# CHANGE: Load the Button instead of the Picker
const LazyQuickButton = preload("lazy_picker.gd")

var quick_button: LazyQuickButton

func _init(_accepted_type: String, _target_class_name: String):
	# Instantiate our new custom button
	quick_button = LazyQuickButton.new(_accepted_type)
	add_child(quick_button)
	
	# Allow it to expand to full width
	quick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Listen to changes
	quick_button.resource_changed.connect(_on_resource_changed)

func _update_property():
	var current_val = get_edited_object()[get_edited_property()]
	# Pass the LazyResource object to the button to render
	quick_button.update_value(current_val)

func _on_resource_changed(resource: Resource):
	if resource == null:
		emit_changed(get_edited_property(), null)
		return

	# ... (Same logic as before to wrap it in LazyResource) ...
	if resource is LazyResource:
		emit_changed(get_edited_property(), resource)
		return

	var new_lazy
	# (Subclass instantiation logic...)
	# For brevity, assuming the previous script_path logic is here:
	new_lazy = LazyResource.new() 
	new_lazy.set_target(resource)
	new_lazy.resource_local_to_scene = true 
	
	emit_changed(get_edited_property(), new_lazy)
