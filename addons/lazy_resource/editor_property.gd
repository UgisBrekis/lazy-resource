@tool
extends EditorProperty

# Load the new widget script
const LazyPropertyWidget = preload("picker.gd")

var widget: LazyPropertyWidget

func _init(_accepted_type: String, _target_class_name: String):
	# Create the new container widget
	widget = LazyPropertyWidget.new(_accepted_type)
	add_child(widget)
	
	# Make sure it fills the inspector width
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Listen to the signal
	widget.resource_changed.connect(_on_resource_changed)

func _update_property():
	var current_val = get_edited_object()[get_edited_property()]
	# Pass the value to the widget's update logic
	widget.update_value(current_val)

func _on_resource_changed(resource: Resource):
	if resource == null:
		emit_changed(get_edited_property(), null)
		return

	if resource is LazyResource:
		emit_changed(get_edited_property(), resource)
		return

	var new_lazy = LazyResource.new()
	new_lazy.set_target(resource)
	new_lazy.resource_local_to_scene = true 
	emit_changed(get_edited_property(), new_lazy)
