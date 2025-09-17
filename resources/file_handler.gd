class_name FileHandler

var IPS_Parser = IPSParser.new()

var backup_entries = []
# structure:
#	"file_path"    : path to the file that was modified
#	"mod_filename" : filename of the mod that patched this file
#	"backup_path"  : path to the backup created


#region Backup related code
func set_backup_entries(list: Array) -> void:
	backup_entries = list


func get_backup_entries() -> Array:
	return backup_entries


func restore_from_backup(entry: Dictionary) -> void:
	var file_directory = DirAccess.open(entry["file_path"].get_base_dir())
	if not file_directory:
		printerr("Couldn't access backup file directory. (%s)" % DirAccess.get_open_error())
		return
	
	var copy = file_directory.copy(entry["backup_path"], entry["file_path"])
	if copy != OK:
		printerr("Backup file (%s) couldn't be restored. (%s)" % \
		[entry["backup_path"].get_file(), str(copy)])
		return
	
	backup_entries.erase(entry)
	
	var error = OS.move_to_trash(entry["backup_path"])
	if error != OK:
		printerr("Can't remove backup file (%s) from %s (%s)" % \
		[entry["backup_path"].get_file(), entry["backup_path"].get_base_dir(), str(error)])
	else:
		print("Removed %s from %s" % \
		[entry["backup_path"].get_file(), entry["backup_path"].get_base_dir()])
	
	print("Restored backup file. (%s)" % entry["backup_path"].get_file())


func check_and_restore_backups() -> void:
	for entry in backup_entries:
		var mod_origin = null
		for mod in Global.mod_list:
			var mod_filename = mod.get_source_filename()
			if mod_filename == entry["mod_filename"]:
				mod_origin = mod
				break
		
		if mod_origin == null or not mod_origin.get_if_active():
			# the mod is missing or disabled, so restore the file it patched
			restore_from_backup(entry)


func backup_file(source_file: String, patch: PackedByteArray, mod_filename: String) -> bool:
	if source_file == "": 
		printerr("Source path is empty, skipping patching.")
		return false
	
	var backup_path = Global.get_backup_folder()
	if backup_path == "": 
		printerr("Backup folder couldn't be retrieved, skipping patching.")
		return false
	
	var backup_file_path = backup_path.path_join(source_file.get_file())
	var file_directory = DirAccess.open(source_file.get_base_dir())
	if not file_directory:
		printerr("Couldn't access source file directory. (%s)" % DirAccess.get_open_error())
		return false
	
	var copy = file_directory.copy(source_file, backup_file_path)
	if copy != OK:
		printerr("File couldn't be copied for backup. (%s)" % str(copy))
		return false

	backup_entries.append({
	"file_path" : source_file,
	"mod_filename" : mod_filename,
	"backup_path" : backup_file_path,
	})
	return true
#endregion


func patch_file(source_file_path, patch_data, mod_filename) -> void:
	if source_file_path == "": 
		printerr("Source path is empty, skipping patching.")
		return
	
	var patched_file = IPS_Parser.get_patched_file(patch_data, source_file_path)
	var file = FileAccess.open(source_file_path, FileAccess.WRITE)
	if file == null:
		printerr("Source file (%s) couldn't be opened for patching. (%s)" % \
		[source_file_path.get_file(), str(FileAccess.get_open_error())])
		return
	file.store_buffer(patched_file)
	file.close()


func add_or_overwrite_entries(master_list: Array[Dictionary], new_entries:  Array[Dictionary], mod_filename := "") -> void:
	# FIXME: this kinda sucks
	for new_entry in new_entries:
		var new_entry_filename := ""
		var match_found = false
		
		if mod_filename != "": 
			new_entry["mod_filename"] = mod_filename # this is here mainly just for IPS patch entries
		
		
		if new_entry.has("filename"):
			new_entry_filename = new_entry["filename"]
		elif new_entry.has("patch_path"):
			new_entry_filename = new_entry["patch_path"]
		
		for i in range(master_list.size()):
			var master_entry = master_list[i]
			var master_entry_filename = master_entry["filename"]
			if master_entry_filename == new_entry_filename:
				master_list.set(i, new_entry)
		
		if not match_found:
			master_list.append(new_entry)


func replace_tm2_files(tm2_files: Array[Dictionary]) -> void:
	var tm2_folder = Global.get_tm2_folder()
	var dir_access = DirAccess.open(tm2_folder)
	if not dir_access:
		printerr("Couldn't access the global textures folder. (%s)" % DirAccess.get_open_error())
		return
	
	# clear files inside (excluding the work directory)
	# get_files() doesnt include folders so this works
	var dir_files = dir_access.get_files()
	for file in dir_files:
		if file.get_extension() != "tm2": continue
		var global_path = tm2_folder.path_join(file)
		var error = OS.move_to_trash(global_path)
		if error != OK:
			printerr("Can't remove %s from %s (%s)" % [file, tm2_folder, str(error)])
		else:
			print("Removed %s from %s" % [file, tm2_folder])
	
	for tm2 in tm2_files:
		var name = tm2["filename"]
		var bytes = tm2["bytes"]
		if name.get_extension() != "tm2": continue
		var file = FileAccess.open(tm2_folder.path_join(name), FileAccess.WRITE)
		if not file:
			printerr("Couldn't create %s (%s)" % [name, FileAccess.get_open_error()])
		else:
			print("Created %s on %s" % [name, tm2_folder])
			file.store_buffer(bytes)


func replace_afs_files(afs_files: Array[Dictionary]) -> void:
	var afs_folder = Global.get_afs_folder()
	var dir_access = DirAccess.open(afs_folder)
	if not dir_access:
		printerr("Couldn't access the afs assets folder. (%s)" % DirAccess.get_open_error())
		return
	
	# clear files inside (excluding the work directory)
	# get_files() doesnt include folders so this works
	var dir_files = dir_access.get_files()
	for file in dir_files:
		var global_path = afs_folder.path_join(file)
		var error = OS.move_to_trash(global_path)
		if error != OK:
			printerr("Can't remove %s from %s (%s)" % [file, afs_folder, str(error)])
		else:
			print("Removed %s from %s" % [file, afs_folder])
	
	for afs_file in afs_files:
		var name = afs_file["filename"]
		var bytes = afs_file["bytes"]
		var file = FileAccess.open(afs_folder.path_join(name), FileAccess.WRITE)
		if not file:
			printerr("Couldn't create %s (%s)" % [name, FileAccess.get_open_error()])
		else:
			file.store_buffer(bytes)
			print("Wrote %s to %s" % [name, afs_folder])


func create_pnach(pnach_array: PackedStringArray) -> void:
	var pcsx2_cheats_dir = Global.pcsx2_cheats_path
	var pnach_filename = Global.get_pnach_filename()
	if pcsx2_cheats_dir == "":
		OS.alert("The PCSX2 Cheats directory was not set, PNACH patches won't be copied over.", "Error!")
		return

	var file = FileAccess.open(pcsx2_cheats_dir.path_join(pnach_filename), FileAccess.WRITE)
	if not file:
		OS.alert("The PNACH file (%s) couldn't be accessed (%s), PNACH patches won't be copied over." %\
		[pnach_filename, FileAccess.get_open_error()], "Error!")
		return
	
	for line in pnach_array:
		file.store_line(line)
		file.store_line("\n")
	
	print("Wrote PNACH to %s" % pnach_filename)


func patch_all_files(patch_files: Array[Dictionary]) -> void:
	# TODO: change behavior for exec patches
	for patch_entry in patch_files:
		var mod_filename = patch_entry["mod_filename"]
		var patch_data = patch_entry["patch_data"]
		var patch_target = patch_entry["patch_target"]
		var source_file_path = Global.game_path.path_join(patch_target)
		var backup_exists := false
		
		if not FileAccess.file_exists(source_file_path):
			printerr("File to be patched doesn't exist: %s" % source_file_path)
			continue
			
		# warn user if it's patching over an already patched file
		for backup_entry in backup_entries:
			if backup_entry["file_path"] == source_file_path:
				print("One or more mods are patching the same file (%s)." % source_file_path.get_file())
				backup_exists = true
				break
		
		if not backup_exists:
			var backup_success = backup_file(source_file_path, patch_data, mod_filename)
			if not backup_success:
				continue
		patch_file(source_file_path, patch_data, mod_filename)


func apply_mods() -> void:
	var mod_list = Global.mod_list
	var patch_files : Array[Dictionary] = []
	var pnach_files : PackedStringArray = []
	var afs_files  : Array[Dictionary] = []
	var tm2_files  : Array[Dictionary] = []
	
	check_and_restore_backups()
	for mod in mod_list:
		if not mod.get_if_active(): continue
		var mod_filename = mod.get_source_filename()
		var mod_patch_files = mod.get_patch_files()
		var mod_pnach_files = mod.get_pnach_files()
		var mod_afs_files = mod.get_afs_files()
		var mod_tm2_files = mod.get_tm2_files()
		
		# add titles to pnach files if unlabelled
		for i in range(mod_pnach_files.size()):
			var pnach = mod_pnach_files[i]
			var pnach_clean = Global.check_and_add_pnach_header(pnach, mod.get_title_clean(), i)
			mod_pnach_files.set(i, pnach_clean)
		
		pnach_files.append_array(mod_pnach_files)
		add_or_overwrite_entries(patch_files, mod_patch_files, mod_filename)
		add_or_overwrite_entries(afs_files, mod_afs_files)
		add_or_overwrite_entries(tm2_files, mod_tm2_files)
	
	Global.insert_hook_pnach(pnach_files)
	Global.verify_hook_binary()
	
	patch_all_files(patch_files)
	create_pnach(pnach_files)
	replace_tm2_files(tm2_files)
	replace_afs_files(afs_files)
