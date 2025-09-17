extends Node

signal mod_apply_start
signal mod_apply_end

const MOD_FOLDER_NAME = "mods"
const BACKUPS_FOLDER_NAME = "backups"
const AFS_FOLDER_NAME = "afs"
const TM2_FOLDER_NAME = "tm2"

const HOOK_PNACH_PATH = "res://resources/hook_mod/SLPM-65140_8F82785A.modloader.pnach"
const HOOK_BINARY_PATH = "res://resources/hook_mod/modloader.bin"

const MOD_ELF_FILENAME = "gg-modloader.elf"
const ELF_FILENAME = "SLPM_651.40"
const RETAIL_CRC = 0x8F82785A

var file_handler = FileHandler.new()
var mod_list : Array[ModData] = []
# config variables
var config_path : String = "user://gd-giogio-modloader.cfg"
var game_path : String = ""
var pcsx2_cheats_path : String = ""
var pcsx2_arguments : PackedStringArray = []
var mod_list_order : Array = [] # order for the mods in the mod list
var mod_list_active : Array = [] # active flags for each mod in the mod list


func _ready() -> void:
	DisplayServer.window_set_min_size(Vector2i(292, 570))
	load_config()


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_config()
		get_tree().quit()


func check_and_add_pnach_header(pnach: String, mod_title: String, index: int) -> String:
	if pnach.length() == 0: return pnach
	
	var pnach_lines = pnach.split('\n')
	var has_title = false
	
	for line in pnach_lines:
		# first few lines might be titles, might be patches, might be comments
		# we need to add a title if it doesn't exist by the start of the patch
		# incase there's randomly a title in the middle of the patch, this
		# should break before that, and only add a title to the unlabelled start
		# it shouldn't add a title if it already exists at the start of the patch
		# FIXME: this probably breaks if patch lines are commented using /* these */
		if line.begins_with("//") or line.begins_with("/*") or line.begins_with("*/")\
			or line.begins_with("gsinterlacemode") or line.begins_with("gsaspectratio"): continue 
		if line.begins_with("author") or line.begins_with("description") or line.begins_with("patch="):
			has_title = false
			break
		if line.begins_with("[") and line.ends_with("]"):
			has_title = true
			break
	
	if has_title: return pnach
	
	var placeholder_title = "[Modloader\\Unlabeled Patches\\%s (%s)]" % [mod_title, index]
	pnach_lines.insert(0, placeholder_title)
	return '\n'.join(pnach_lines)
	
	# alt take that adds modloader header to existing pnachs
	#var pnach_lines = pnach.split('\n')
	#var first_line = pnach_lines[0]
	#if first_line.begins_with("[") and first_line.ends_with("]"): 
		#if first_line.begins_with("[Modloader\\Mods\\"): 
			#return pnach
		#else: # append modloader header to title
			#first_line.insert(1, "[Modloader\\Mods\\")
			#pnach_lines.set(0, first_line)
			#return pnach_lines.join('\n')
	#else: # create placeholder title
		#var new_title = "[Modloader\\Mods\\Unlabeled Pnach (%s)]\n" % mod_title
		#pnach_lines.insert(0, new_title)
		#return pnach_lines.join('\n')


func get_pnach_filename() -> String:
	var elf_basename = ELF_FILENAME
	elf_basename = elf_basename.replace('.', '')
	elf_basename = elf_basename.replace('-', '_')
	return "%s_%8X.modloader.pnach" % [elf_basename, RETAIL_CRC]


func insert_hook_pnach(pnach_lines: PackedStringArray) -> void:
	var hook_lines = FileAccess.get_file_as_string(HOOK_PNACH_PATH)
	if hook_lines == "":
		OS.alert("Can't write hook lines to the game pnach! (%s)" % FileAccess.get_open_error(), "Error")
		return
	pnach_lines.insert(0, hook_lines)


func verify_hook_binary_exists() -> void:
	if game_path == "":
		OS.alert("Can't get or create modloader hook binary (Game path is null)", "Error")
		return
	
	var hook_path = game_path.path_join(HOOK_BINARY_PATH.get_file())
	if FileAccess.file_exists(hook_path):
		return
	
	var file = FileAccess.open(hook_path, FileAccess.WRITE)
	if file == null:
		OS.alert("Can't create modloader hook binary (%s)" % FileAccess.get_open_error(), "Error")
		return
	
	var hook_buffer = FileAccess.get_file_as_bytes(HOOK_BINARY_PATH)
	if hook_buffer.size() <= 0:
		OS.alert("Can't retrieve modloader hook binary (%s)" % FileAccess.get_open_error(), "Error")
		return
	
	file.store_buffer(hook_buffer)


func sort_modlist_from_config() -> void: 
	# sort children according to mod order
	if mod_list_order.size() == 0: return
	mod_list.sort_custom(
	func(a, b):
		var index_a = Global.mod_list_order.find(a.get_source_filename())
		var index_b = Global.mod_list_order.find(b.get_source_filename())
		if index_a == -1: index_a = mod_list.size() # place names not in the array at the end
		if index_b == -1: index_b = mod_list.size()
		return index_a < index_b)


func toggle_mods_from_config() -> void:
	for entry in mod_list_active:
		var entry_filename = entry["filename"]
		var is_active = entry["active"]
		
		var index = mod_list.find_custom(
			func(mod : ModData):
				return mod.get_source_filename() == entry_filename)
		
		if index <= -1: continue
		mod_list[index].set_if_active(is_active)


func get_backup_folder() -> String:
	if game_path == "":
		printerr("Game path is null.")
		return ""

	# try to open the game folder
	var dir = DirAccess.open(game_path)
	if dir == null:
		printerr("Couldn't access the game path.")
		return ""

	var backup_path = game_path.path_join(BACKUPS_FOLDER_NAME)
	if dir.dir_exists(BACKUPS_FOLDER_NAME):
		return backup_path

	# if "mods" doesn't exist, check if the game folder is correct by getting the game exec
	if not FileAccess.file_exists(Global.get_elf_path()):
		printerr("Executable not found. Check if the game path is correct.")
		return ""

	# try to create the mods folder
	var error = dir.make_dir(BACKUPS_FOLDER_NAME)
	if error == OK:
		print("Created the backups folder.")
		return backup_path

	printerr("Couldn't create the backups folder.")
	return ""


func get_mod_folder() -> String:
	if game_path == "":
		printerr("Game path is null.")
		return ""

	# try to open the game folder
	var dir = DirAccess.open(game_path)
	if dir == null:
		printerr("Couldn't access the game path.")
		return ""

	var mods_path = game_path.path_join(MOD_FOLDER_NAME)
	if dir.dir_exists(MOD_FOLDER_NAME):
		return mods_path

	# if "mods" doesn't exist, check if the game folder is correct by getting the game exec
	if not FileAccess.file_exists(Global.get_elf_path()):
		printerr("Executable not found. Check if the game path is correct.")
		return ""

	# try to create the mods folder
	var error = dir.make_dir(MOD_FOLDER_NAME)
	if error == OK:
		print("Created the mods folder.")
		return mods_path

	printerr("Couldn't create the mods folder.")
	return ""


func get_tm2_folder() -> String:
	if game_path == "":
		printerr("Game path is null.")
		return ""

	# try to open the game folder
	var dir = DirAccess.open(game_path)
	if dir == null:
		printerr("Couldn't access the game path.")
		return ""

	var tm2_path = game_path.path_join(TM2_FOLDER_NAME)
	if dir.dir_exists(TM2_FOLDER_NAME):
		return tm2_path

	# try to create the mods folder
	var error = dir.make_dir(TM2_FOLDER_NAME)
	if error == OK:
		print("Created the global textures folder.")
		return tm2_path

	printerr("Couldn't create the global textures folder.")
	return ""


func get_afs_folder() -> String:
	if game_path == "":
		printerr("Game path is null.")
		return ""

	# try to open the game folder
	var dir = DirAccess.open(game_path)
	if dir == null:
		printerr("Couldn't access the game path.")
		return ""

	var afs_path = game_path.path_join(AFS_FOLDER_NAME)
	if dir.dir_exists(AFS_FOLDER_NAME):
		return afs_path

	# try to create the mods folder
	var error = dir.make_dir(AFS_FOLDER_NAME)
	if error == OK:
		print("Created the afs assets folder.")
		return afs_path

	printerr("Couldn't create the afs assets folder.")
	return ""


func get_elf_path() -> String:
	if game_path == "": return ""
	return game_path.path_join(ELF_FILENAME)


func get_modded_elf_path() -> String:
	if game_path == "": return ""
	return game_path.path_join(MOD_ELF_FILENAME)

func verify_modloader_elf_exists() -> void:
	if game_path == "":
		OS.alert("Can't get or create modloader ELF (Game path is null)", "Error")
		return
	
	var original_elf_path = Global.game_path.path_join(Global.ELF_FILENAME)
	var mod_elf_path = game_path.path_join(MOD_ELF_FILENAME)
	if FileAccess.file_exists(mod_elf_path):
		return
	
	var game_directory = DirAccess.open(game_path)
	if not game_directory:
		printerr("Couldn't access game directory for ELF creation. (%s)" % DirAccess.get_open_error())
		return
	
	var copy = game_directory.copy(original_elf_path, mod_elf_path)
	if copy != OK:
		printerr("Couldn't create modloader ELF. (%s)" % str(copy))
	
	print("Modloader ELF created. (%s)" % MOD_ELF_FILENAME)


func get_file_crc(path : String) -> int:
	# FIXME: slow
	var output = 0
	var file = FileAccess.open(path, FileAccess.READ)
	if file != null:
		while not file.eof_reached():
			output ^= file.get_32()
	else:
		OS.alert("Couldn't calculate CRC for the following file: %s" % path)
	file.close()
	print("%s CRC returned %08X" % [path.get_file(), output])
	return output


func init_mod_list() -> void:
	print("Retrieving mod list...")
	mod_list.clear()
	var mod_folder_path = get_mod_folder()
	if mod_folder_path == "": return
	var dir = DirAccess.open(mod_folder_path)
	if dir:
		for file in dir.get_files():
			# TODO: this only retrieves files, folder based mods would require dir scanning
			if file.ends_with(".zip"):
				var filepath = mod_folder_path.path_join(file)
				var mod_data = ModData.new(filepath)
				mod_list.append(mod_data)
	else:
		OS.alert("An error occurred when trying to access the path: %s " % str(DirAccess.get_open_error()), "Error")
	sort_modlist_from_config()
	toggle_mods_from_config()


func update_mod_list_cvars() -> void:
	mod_list_order.clear()
	mod_list_active.clear()
	for mod in mod_list:
		mod_list_order.append(mod.get_source_filename())
		mod_list_active.append({
			"filename" : mod.get_source_filename(),
			"active" : mod.get_if_active()
		})


func save_config() -> void:
	print("Saving current configuration...")
	var config = ConfigFile.new()
	
	config.set_value("General", "pcsx2_cheats_path", pcsx2_cheats_path)
	config.set_value("General", "pcsx2_arguments", pcsx2_arguments)
	config.set_value("General", "game_path", game_path)
	config.set_value("ModList", "order", mod_list_order)
	config.set_value("ModList", "active", mod_list_active)
	config.set_value("ModList", "patched_files", file_handler.get_backup_entries())
	
	var err = config.save(config_path)
	if err != OK:
		OS.alert("Couldn't save modloader settings! (%s)" % str(err), "Error")
		return


func load_config() -> void:
	print("Loading configuration...")
	var config = ConfigFile.new()
	var err = config.load(config_path)

	if err != OK:
		OS.alert("Couldn't load modloader settings! (%s)" % str(err), "Error")
		return

	pcsx2_cheats_path = config.get_value("General", "pcsx2_cheats_path", "")
	pcsx2_arguments = config.get_value("General", "pcsx2_arguments", [])
	game_path = config.get_value("General", "game_path", "")
	mod_list_order = config.get_value("ModList", "order", [])
	mod_list_active = config.get_value("ModList", "active", [])
	file_handler.set_backup_entries(config.get_value("ModList", "patched_files", []))
