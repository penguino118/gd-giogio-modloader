extends VBoxContainer

signal file_selected

@onready var path_label : Label = %PathLabel
@onready var path_line_edit : LineEdit = %PathLineEdit
@onready var browse_button : Button = %BrowseButton
@export var target_name : String = "File"
var selected_file : String = "":
	set(value):
		selected_file = value
		path_line_edit.text = selected_file
		file_selected.emit(target_name, selected_file)


func _ready() -> void:
	set_ui_text()
	browse_button.pressed.connect(on_browse_pressed)


func set_ui_text() -> void:
	path_label.text = target_name
	path_line_edit.placeholder_text = str("Path to ", target_name)


func on_browse_pressed() -> void:
	var file_dialog = FileDialog.new()
	# init
	file_dialog.set_file_mode(file_dialog.FILE_MODE_OPEN_FILE)
	file_dialog.set_access(FileDialog.ACCESS_FILESYSTEM)
	file_dialog.title = str("Select ", target_name, " File")
	file_dialog.ok_button_text = "Open"
	file_dialog.use_native_dialog = true
	# set signals
	file_dialog.file_selected.connect(on_file_selected)
	# pop-up
	file_dialog.popup()


func on_file_selected(path : String) -> void:
	print(target_name, " -> Selected File: ", path)
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		selected_file = path
		file.close()
	else:
		OS.alert(str("An error occurred when trying to access the file: ", path), "Error")
		return
