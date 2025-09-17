extends VBoxContainer

signal directory_selected

@onready var path_label : Label = %PathLabel
@onready var path_line_edit : LineEdit = %PathLineEdit
@onready var browse_button : Button = %BrowseButton
@export var target_name : String = "Folder"
var selected_directory : String = "":
	set(value):
		selected_directory = value
		path_line_edit.text = selected_directory
		directory_selected.emit(target_name, selected_directory)


func _ready() -> void:
	set_ui_text()
	browse_button.pressed.connect(on_browse_pressed)


func set_ui_text() -> void:
	path_label.text = target_name
	path_line_edit.placeholder_text = str("Path to ", target_name)


func on_browse_pressed() -> void:
	var file_dialog = FileDialog.new()
	# init
	file_dialog.set_file_mode(file_dialog.FILE_MODE_OPEN_DIR)
	file_dialog.set_access(FileDialog.ACCESS_FILESYSTEM)
	file_dialog.title = str("Select ", target_name, " Folder")
	file_dialog.ok_button_text = "Open"
	file_dialog.use_native_dialog = true
	# set signals
	file_dialog.dir_selected.connect(on_folder_selected)
	# pop-up
	file_dialog.popup()


func on_folder_selected(dir : String) -> void:
	print(target_name, " -> Selected folder: ", dir)
	var access = DirAccess.open(dir)
	if access:
		selected_directory = dir
	else:
		OS.alert("An error occurred when trying to access the path: " % DirAccess.get_open_error(), "Error")
		return
