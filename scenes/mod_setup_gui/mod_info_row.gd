extends HBoxContainer

signal unselected
signal selected

@onready var active_checkbox = %"Active Checkbox"
@onready var tags_panel = %"Tags Panel"
@onready var afs_rect = %AFSRect
@onready var tex_rect = %TextureRect
@onready var pnach_rect = %PnachRect
@onready var patch_rect = %PatchRect
@onready var title_label = %"Title Label"
@onready var checkbox_focus_overlay = $"Panel/Active Checkbox/FocusOverlay"
@onready var tags_focus_overlay = $"Tags Panel/FocusOverlay"
@onready var title_focus_overlay = $"Title Label/FocusOverlay"


func _ready() -> void:
	highlight_all_cells(false)
	active_checkbox.pressed.connect(emit_cell_selected)
	# focus connections: if one "cell" is focused, all of the surrounding ones must be too
	# mouse entered
	active_checkbox.mouse_entered.connect(on_cell_mouse_entered)
	tags_panel.mouse_entered.connect(on_cell_mouse_entered)
	title_label.mouse_entered.connect(on_cell_mouse_entered)
	# mouse exited
	active_checkbox.mouse_exited.connect(on_cell_mouse_exited)
	tags_panel.mouse_exited.connect(on_cell_mouse_exited)
	title_label.mouse_exited.connect(on_cell_mouse_exited)
	# focus exited
	active_checkbox.focus_exited.connect(on_cell_mouse_exited)
	tags_panel.focus_exited.connect(on_cell_mouse_exited)
	title_label.focus_exited.connect(on_cell_mouse_exited)
	# focus entered
	active_checkbox.focus_entered.connect(emit_cell_selected)
	tags_panel.focus_entered.connect(emit_cell_selected)
	title_label.focus_entered.connect(emit_cell_selected)
	# focus exited
	active_checkbox.focus_exited.connect(emit_cell_unselected)
	tags_panel.focus_exited.connect(emit_cell_unselected)
	title_label.focus_exited.connect(emit_cell_unselected)


func is_selected() -> bool:
	return active_checkbox.has_focus() or tags_panel.has_focus() or title_label.has_focus() 


func highlight_all_cells(on : bool) -> void:
	if on:
		checkbox_focus_overlay.show()
		tags_focus_overlay.show()
		title_focus_overlay.show()
	else:
		checkbox_focus_overlay.hide()
		tags_focus_overlay.hide()
		title_focus_overlay.hide()


func on_cell_mouse_entered() -> void:
	highlight_all_cells(true)


func on_cell_mouse_exited() -> void:
	if not is_selected(): highlight_all_cells(false)


func emit_cell_selected() -> void:
	var active = active_checkbox.button_pressed
	selected.emit(active, self)


func emit_cell_unselected() -> void:
	unselected.emit()


func set_title(new_title : String) -> void:
	title_label.text = new_title


func set_tags(flag_array : Array[bool]) -> void:
	var tag_array = [afs_rect, tex_rect, pnach_rect, patch_rect]
	
	if tag_array.size() != flag_array.size():
		OS.alert("Info row tag size and mod tag size mismatch", "Error")
		return
	
	for i in tag_array.size():
		if flag_array[i] == false:
			tag_array[i].modulate = Color(0.4, 0.4, 0.4)
			tag_array[i].tooltip_text = "" 


func set_title_tooltip(string : String) -> void:
	title_label.tooltip_text = string


func get_source_filename() -> String:
	return title_label.tooltip_text


func set_if_active(value : bool) -> void:
	active_checkbox.button_pressed = value
