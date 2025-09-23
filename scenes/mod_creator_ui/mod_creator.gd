extends VBoxContainer

var current_mod := ModData.new('')
var patch_creator_window = preload("uid://bjoxoq6n622fi")

# metadata
@onready var title_type: LineEdit = %TitleType
@onready var author_type: LineEdit = %AuthorType
@onready var description_type: TextEdit = %DescriptionType
@onready var add_preview_button: Button = %AddPreviewButton
@onready var clear_preview_button: Button = %ClearPreviewButton

# mod data
@onready var add_afs_button: Button = %AddAfsButton
@onready var add_tm2_button: Button = %AddTm2Button
@onready var add_pnach_button: Button = %AddPnachButton
@onready var add_ips_button: Button = %AddIpsButton
@onready var clear_afs_button: Button = %ClearAfsButton
@onready var clear_tm2_button: Button = %ClearTm2Button
@onready var clear_pnach_button: Button = %ClearPnachButton
@onready var clear_ips_button: Button = %ClearIpsButton

@onready var save_button: Button = %SaveButton

func _ready() -> void:
	title_type.text_changed.connect(title_changed)
	author_type.text_changed.connect(author_changed)
	description_type.text_changed.connect(description_changed)
	
	add_preview_button.pressed.connect(add_preview_pressed)
	clear_preview_button.pressed.connect(on_preview_clear)
	
	add_afs_button.pressed.connect(afs_pressed)
	add_tm2_button.pressed.connect(tm2_pressed)
	add_pnach_button.pressed.connect(pnach_pressed)
	add_ips_button.pressed.connect(ips_pressed)
	
	clear_afs_button.pressed.connect(on_afs_clear)
	clear_tm2_button.pressed.connect(on_tm2_clear)
	clear_pnach_button.pressed.connect(on_pnach_clear)
	clear_ips_button.pressed.connect(on_ips_clear)
	
	save_button.pressed.connect(on_save_pressed)


func get_file_open_dialog(title : String, allow_multiple := false, filters : PackedStringArray = []) -> FileDialog:
	var file_dialog = FileDialog.new()
	
	if allow_multiple:
		file_dialog.set_file_mode(file_dialog.FILE_MODE_OPEN_FILES)
	else:
		file_dialog.set_file_mode(file_dialog.FILE_MODE_OPEN_FILE)
	
	if filters.size() > 0:
		file_dialog.filters = filters

	file_dialog.set_access(FileDialog.ACCESS_FILESYSTEM)
	file_dialog.title = title
	file_dialog.ok_button_text = "Open"
	file_dialog.use_native_dialog = true
	return file_dialog


func get_file_save_dialog(title : String, filters : PackedStringArray = []) -> FileDialog:
	var file_dialog = FileDialog.new()
	
	file_dialog.set_file_mode(file_dialog.FILE_MODE_SAVE_FILE)
	file_dialog.filters = filters
	file_dialog.set_access(FileDialog.ACCESS_FILESYSTEM)
	file_dialog.title = title
	file_dialog.ok_button_text = "Save"
	file_dialog.use_native_dialog = true
	return file_dialog


func update_buttons() -> void:
	clear_afs_button.disabled = true if current_mod.get_afs_files().size() <= 0 else false
	clear_tm2_button.disabled = true if current_mod.get_tm2_files().size() <= 0 else false
	clear_pnach_button.disabled = true if current_mod.get_pnach_files().size() <= 0 else false
	clear_ips_button.disabled = true if current_mod.get_patch_files().size() <= 0 else false
	clear_preview_button.disabled = true if current_mod.get_preview_image().get_data_size() <= 0 else false
	
	# if there's asset files present, allow mod creation
	if not clear_afs_button.disabled or not clear_tm2_button.disabled \
	or not clear_pnach_button.disabled or not clear_ips_button.disabled:
		save_button.disabled = false
	else: 
		save_button.disabled = true


func clear_current_mod() -> void:
	var null_string := ""
	
	title_type.text = null_string
	author_type.text = null_string
	description_type.text = null_string
	current_mod.set_title(null_string)
	current_mod.set_author(null_string)
	current_mod.set_description(null_string)
	current_mod.set_preview_image(Image.new())
	
	current_mod.clear_afs_files()
	current_mod.clear_tm2_files()
	current_mod.clear_pnach_files()
	current_mod.clear_patch_files()
	update_buttons()


func on_save_pressed() -> void:
	var save_filters : PackedStringArray = [".zip;ZIP Archive;application/zip-compressed"]
	var save_dialog = get_file_save_dialog("Save Mod Archive", save_filters)
	save_dialog.file_selected.connect(on_file_save)
	save_dialog.popup()


func on_file_save(path : String) -> void:
	var output : Error = current_mod.write_zip_archive(path)
	if output != OK:
		OS.alert("Couldn't create mod archive. (%s)" % output, "Error")
	else:
		OS.alert("Saved mod archive to %s" % path, "Save")
		clear_current_mod()
	return


#region Metadata Functions
func title_changed(new_title: String) -> void:
	if new_title.length() <= 0:
		return
	current_mod.set_title(new_title)


func author_changed(new_author: String) -> void:
	if new_author.length() <= 0:
		return
	current_mod.set_author(new_author)


func description_changed() -> void:
	var new_description := description_type.text
	if new_description.length() <= 0:
		return
	current_mod.set_description(new_description)


func add_preview_pressed() -> void:
	var filters : PackedStringArray = ["*.png,*.jpg,*.webp;Image Files"]
	var file_dialog = get_file_open_dialog("Select Preview Image", false, filters)
	file_dialog.file_selected.connect(on_preview_selected)
	file_dialog.popup()


func on_preview_selected(path : String) -> void:
	var image := Image.load_from_file(path)
	
	if image == null:
		# TODO: can we get an error code for this
		OS.alert("Couldn't open preview image.", "Error")
		return
	
	current_mod.set_preview_image(image)
	update_buttons()


func on_preview_clear() -> void:
	var image := Image.new()
	current_mod.set_preview_image(image)
	update_buttons()
#endregion


#region Mod Data Functions
func afs_pressed() -> void:
	var filters : PackedStringArray = ["*.adx,*.bin,*.hit,*.pzz,*.sdt,*.snd,*.txb,*.txt,*.snd;AFS Assets"]
	var file_dialog = get_file_open_dialog("Select AFS Assets", true, filters)
	file_dialog.files_selected.connect(on_afs_selected)
	file_dialog.popup()


func on_afs_selected(paths: PackedStringArray) -> void:
	for path in paths:
		current_mod.add_afs_file(path)
	update_buttons()


func tm2_pressed() -> void:
	var filters : PackedStringArray = ["*.tm2;TIM2 Textures"]
	var file_dialog = get_file_open_dialog("Select TM2 textures", true, filters)
	file_dialog.files_selected.connect(on_tm2_selected)
	file_dialog.popup()


func on_tm2_selected(paths: PackedStringArray) -> void:
	for path in paths:
		current_mod.add_tm2_file(path)
	update_buttons()


func pnach_pressed() -> void:
	var filters : PackedStringArray = ["*.pnach,*.txt;PNACH Files"]
	var file_dialog = get_file_open_dialog("Select PNACH files", true, filters)
	file_dialog.files_selected.connect(on_pnach_selected)
	file_dialog.popup()


func on_pnach_selected(paths: PackedStringArray) -> void:
	for path in paths:
		current_mod.add_pnach_file(path)
	update_buttons()


func ips_pressed() -> void:
	var patch_creator_instance = patch_creator_window.instantiate()
	add_child(patch_creator_instance)
	patch_creator_instance.patch_created.connect(on_ips_created)


func on_ips_created(target_path : String, patch : PackedByteArray) -> void:
	current_mod.add_patch_data(target_path, patch)
	update_buttons()


func on_afs_clear() -> void:
	current_mod.clear_afs_files()
	update_buttons()


func on_tm2_clear() -> void:
	current_mod.clear_tm2_files()
	update_buttons()


func on_pnach_clear() -> void:
	current_mod.clear_pnach_files()
	update_buttons()


func on_ips_clear() -> void:
	current_mod.clear_patch_files()
	update_buttons()

#endregion
