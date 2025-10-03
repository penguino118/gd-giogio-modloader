extends VBoxContainer

@onready var game_dir_picker : VBoxContainer = %GameDirPicker
@onready var game_dir_status_view : RichTextLabel = %GameDirStatusView
@onready var pcsx2_cheats_picker : VBoxContainer = %PCSX2CheatsPicker
@onready var apply_settings_button: Button = $FooterPanel/ApplySettingsButton


func _ready() -> void:
	game_dir_picker.directory_selected.connect(on_settings_changed)
	pcsx2_cheats_picker.directory_selected.connect(on_settings_changed)
	apply_settings_button.pressed.connect(on_save_settings)
	try_set_from_settings()


func try_set_from_settings() -> void:
	game_dir_picker.selected_directory = Global.game_path
	pcsx2_cheats_picker.selected_directory = Global.pcsx2_cheats_path
	var elf_exists = FileAccess.file_exists(Global.get_elf_path())
	update_status_view(elf_exists)


func update_status_view(elf_exists : bool) -> void:
	game_dir_status_view.text = ""
	var string_color = ""
	
	if elf_exists:
		var crc = Global.get_file_crc(Global.get_elf_path())
		string_color = "#50c5b7" # green
		game_dir_status_view.append_text("[color=%s][outline_size=4]\
		Game executable found: %s [/outline_size][/color]\n" % \
		[string_color, Global.get_elf_path().get_file()])
		
		if crc != Global.RETAIL_CRC:
			string_color = "#eff760" # yellow; retail crc mismatch
		
		game_dir_status_view.append_text("[color=%s][outline_size=4]\
		Executable CRC: %8X [/outline_size][/color]" % [string_color, crc])
	else:
		string_color = "#f76b60" # red
		game_dir_status_view.append_text(\
		"[color=%s][outline_size=4]\
		Game executable not found.\
		[/outline_size][/color]" % string_color)


func on_settings_changed(target : String, value : String) -> void:
	var original := Global.game_path if target == "Game Directory" else Global.pcsx2_cheats_path
	if value != original and value.length() <= 0:
		printerr("\"%s\" shouldn't be empty..." % target)
		return
	
	match(target):
		"Game Directory":
			Global.game_path = value
			var elf_exists = FileAccess.file_exists(Global.get_elf_path())
			update_status_view(elf_exists)
			Global.verify_modloader_elf_exists()
		"PCSX2 Cheats":
			Global.pcsx2_cheats_path = value
		_:
			printerr("Unknown settings change: %s <- %s" % [target, value])


func on_save_settings() -> void:
	Global.save_config()
