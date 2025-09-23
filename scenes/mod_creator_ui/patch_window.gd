extends Window

signal patch_created

var ips_parser = IPSParser.new()

@onready var original_file_picker: VBoxContainer = %OriginalFilePicker
@onready var modified_file_picker: VBoxContainer = %ModifiedFilePicker
@onready var create_patch_button: Button = %CreatePatchButton

var original_path := ""
var modified_path := ""

func _ready() -> void:
	close_requested.connect(on_close)
	original_file_picker.file_selected.connect(on_original_picked)
	modified_file_picker.file_selected.connect(on_modified_picked)
	create_patch_button.pressed.connect(on_create_patch_pressed)


func on_close() -> void:
	queue_free()


func update_create_button() -> void:
	if original_path.length() > 0 and modified_path.length() > 0:
		create_patch_button.disabled = false
	else:
		create_patch_button.disabled = true


func on_original_picked(target_name : String, selected_file : String) -> void:
	if not selected_file.contains(Global.game_path):
		OS.alert("You should only be patching files within the game directory!", "Error")
		original_path = "" 
	else:
		original_path = selected_file
	update_create_button()


func on_modified_picked(target_name : String, selected_file : String) -> void:
	modified_path = selected_file
	update_create_button()


func on_create_patch_pressed() -> void:
	var patch_output : PackedByteArray = ips_parser.create_patch(original_path, modified_path)
	var target_path := original_path.trim_prefix(Global.game_path)
	
	if patch_output.size() <= 0:
		OS.alert("Failed to create IPS Patch, check the log.", "Error")
		return
	
	patch_created.emit(target_path, patch_output)
	close_requested.emit()
