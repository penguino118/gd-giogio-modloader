extends Control

signal request_mod_list
signal mod_selected

@onready var refresh_button: Button = $"HBoxContainer/Button Container/RefreshButton"
@onready var top_button: Button = $"HBoxContainer/Button Container/TopButton"
@onready var up_button: Button = $"HBoxContainer/Button Container/UpButton"
@onready var add_button: Button = $"HBoxContainer/Button Container/AddButton"
@onready var remove_button: Button = $"HBoxContainer/Button Container/RemoveButton"
@onready var down_button: Button = $"HBoxContainer/Button Container/DownButton"
@onready var bottom_button: Button = $"HBoxContainer/Button Container/BottomButton"

@onready var mod_info_row = preload("uid://bpi2h7oeo5g22")
@onready var row_container = %"Row Container"
@onready var mod_entry_rows = %"Mod Entry Rows"
@onready var list_header = %Header


func _ready() -> void:
	refresh_button.pressed.connect(on_refresh_pressed)
	top_button.pressed.connect(on_top_pressed)
	up_button.pressed.connect(on_up_pressed)
	add_button.pressed.connect(on_add_pressed)
	remove_button.pressed.connect(on_remove_pressed)
	down_button.pressed.connect(on_down_pressed)
	bottom_button.pressed.connect(on_bottom_pressed)


func set_list() -> void:
	# clear rows
	for child in mod_entry_rows.get_children():
		child.queue_free()

	# load mod data
	if Global.mod_list.size() > 0:
		var mod_count = Global.mod_list.size()
		
		for i in range(mod_count):
			var mod = Global.mod_list[i]
			var info_row = mod_info_row.instantiate()
			mod_entry_rows.add_child(info_row)
			info_row.set_title(mod.get_title())
			info_row.set_tags(mod.get_tags())
			info_row.set_title_tooltip(mod.get_source_filename())
			info_row.set_if_active(mod.get_if_active())
			info_row.selected.connect(on_mod_selected)
			info_row.unselected.connect(on_mod_unselected)
	else:
		printerr("Global.mod_list has no entries.")


func get_selected_row_index() -> int:
	for child in mod_entry_rows.get_children():
		if child.is_selected(): return child.get_index()
	return -1


func enable_move_buttons(on : bool):
	if on:
		top_button.disabled = false
		up_button.disabled = false
		down_button.disabled = false
		bottom_button.disabled = false
	else:
		top_button.disabled = true
		up_button.disabled = true
		down_button.disabled = true
		bottom_button.disabled = true


func on_mod_selected(active : bool, row_node : Object) -> void:
	var row_index = row_node.get_index()
	mod_selected.emit(active, row_index)
	enable_move_buttons(true)
	Global.update_mod_list_cvars()


func on_mod_unselected() -> void:
	# check if anything else on the list is selected
	# if not, disable move buttons
	# TODO: this could be optimized somehow maybe
	for child in mod_entry_rows.get_children():
		if child.is_selected(): return
	enable_move_buttons(false)


func on_refresh_pressed() -> void:
	request_mod_list.emit()


func move_mod_in_list(from_index : int, to_index : int) -> void:
	if from_index <= -1 or to_index <= -1: return
	if from_index == to_index: return
	var row_node = mod_entry_rows.get_child(from_index)
	# modify mod list
	if to_index == 0: # move to top
		var selected_mod = Global.mod_list.pop_at(from_index)
		Global.mod_list.push_front(selected_mod)
	elif to_index == Global.mod_list.size()-1: # move to bottom
		var selected_mod = Global.mod_list.pop_at(from_index)
		Global.mod_list.push_back(selected_mod)
	else:
		var selected_mod = Global.mod_list.pop_at(from_index)
		Global.mod_list.insert(to_index, selected_mod)
	# modify view
	mod_entry_rows.move_child(row_node, to_index)
	Global.update_mod_list_cvars()


func on_top_pressed() -> void:
	var selected_index = get_selected_row_index()
	move_mod_in_list(selected_index, 0)


func on_up_pressed() -> void:
	var selected_index = get_selected_row_index()
	move_mod_in_list(selected_index, max(selected_index-1, 0))


func on_down_pressed() -> void:
	var selected_index = get_selected_row_index()
	var mod_count = mod_entry_rows.get_children().size()-1
	move_mod_in_list(selected_index, min(selected_index+1, mod_count))


func on_bottom_pressed() -> void:
	var selected_index = get_selected_row_index()
	var mod_count = mod_entry_rows.get_children().size()-1
	move_mod_in_list(selected_index, mod_count)


func on_add_pressed() -> void:
	var file_dialog = FileDialog.new()
	# init
	file_dialog.set_file_mode(file_dialog.FILE_MODE_OPEN_FILES)
	file_dialog.set_access(FileDialog.ACCESS_FILESYSTEM)
	file_dialog.title = "Select mod files (.zip)"
	file_dialog.ok_button_text = "Open"
	file_dialog.filters = ["*.zip"]
	file_dialog.use_native_dialog = true
	# set signals
	file_dialog.file_selected.connect(on_add_mod_file_selected)
	file_dialog.files_selected.connect(on_add_mod_files_selected)
	# pop-up
	file_dialog.popup()


func on_add_mod_file_selected(path : String) -> void:
	print("Adding to list: ", path)
	var filename = path.get_file()
	var output_path = Global.get_mod_folder().path_join(filename)
	var dir = DirAccess.open(Global.get_mod_folder())
	if dir:
		dir.copy(path, output_path)
		on_refresh_pressed()
	else:
		OS.alert("An error occurred when trying to access the path: " % DirAccess.get_open_error(), "Error")
		return


func on_add_mod_files_selected(paths : PackedStringArray) -> void:
	print("Adding to list: ", paths)
	for path in paths:
		on_add_mod_file_selected(path)


func on_remove_pressed() -> void:
	var selected_index = get_selected_row_index()
	var filename = Global.mod_list[selected_index].get_source_filename()
	var title = Global.mod_list[selected_index].get_title_clean()
	var path = Global.get_mod_folder().path_join(filename)
	
	var error = OS.move_to_trash(path)
	if error != OK:
		printerr("Can't remove %s from the mod list (%s)" % [filename, str(error)])
		return
	else:
		print("Removed %s (%s)" % [title, filename])

	var row_node = mod_entry_rows.get_child(selected_index)
	mod_entry_rows.remove_child(row_node)
	Global.mod_list.pop_at(selected_index)
	Global.update_mod_list_cvars()
	pass
