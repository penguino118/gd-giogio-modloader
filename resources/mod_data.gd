extends Resource
class_name ModData

var source_filename : String = "N/A"
var active : bool = false

var title : String = "N/A"
var author : String = "N/A"
var description : String = "N/A"
var preview_image : Image = Image.new()

var patch_files : Array[Dictionary] = [] # members: [patch_target, patch_data]
var pnach_files : PackedStringArray = [] # members: string
var afs_files  : Array[Dictionary] = [] # members: [filename, bytes]
var tm2_files  : Array[Dictionary] = [] # members: [filename, bytes]


func escape_bbcode(bbcode_text) -> String:
	return bbcode_text.replace("[", "[lb]")


func set_metadata_from_json(parsed_json : Variant) -> void:
	if parsed_json.has("Metadata"):
		var meta_section = parsed_json["Metadata"]
		if meta_section.has("Title"): title = meta_section["Title"]
		if meta_section.has("Author"): author = meta_section["Author"]
		if meta_section.has("Description"): description = meta_section["Description"]


func set_ips_entries_from_json(parsed_json : Variant, zip_reader : ZIPReader) -> void:
	if parsed_json.has("IPS Entries"):
		var ips_section = parsed_json["IPS Entries"]
		for entry in ips_section:
			if entry.has("Patch") and entry.has("Target"):
				var patch_path = entry["Patch"]
				var patch_target = entry["Target"]
				var patch_data : PackedByteArray = zip_reader.read_file(patch_path) 
				
				if patch_data.size() < 0:
					printerr("MODDATA: File for patch entry couldn't be read (%s)" % patch_path)
					continue
				
				patch_files.append({
					"patch_target" : patch_target,
					"patch_data" : patch_data
				})


func set_preview_image_from_archive(zip_reader : ZIPReader, path : String) -> void:
	var preview_file : PackedByteArray = zip_reader.read_file(path)
	if preview_file.size() > 0:
		match(path.get_extension()):
			# TODO: is there any reason not to add in all formats that godot can load?
			"png" : preview_image.load_png_from_buffer(preview_file)
			"jpg" : preview_image.load_jpg_from_buffer(preview_file)
			"webp": preview_image.load_webp_from_buffer(preview_file)
			_: printerr("MODDATA: Unknown format for preview image: ", path.get_extension())
	else:
		print("MODDATA: Mod is missing a preview image.")
		return


func fill_data_from_filelist(zip_reader : ZIPReader, file_list : PackedStringArray) -> void:
	for path in file_list:
		# set metadata and ips patches if present
		var metadata : PackedByteArray = zip_reader.read_file(path) 
		
		if path.get_file() == "meta.json": 
			var json_string
			var parsed_json
			
			if metadata.size() > 0:
				json_string = metadata.get_string_from_utf8()
				parsed_json = JSON.parse_string(json_string) 
			else:
				printerr("MODDATA: Metadata file is empty.")
				continue
			
			if parsed_json is not Dictionary: # parse is unsuccesful
				printerr("Metadata could not be parsed.")
				continue
			
			set_metadata_from_json(parsed_json)
			set_ips_entries_from_json(parsed_json, zip_reader)
			continue
		
		# set preview image if any
		if path.get_file().get_basename() == "preview": 
			set_preview_image_from_archive(zip_reader, path)
			continue
		
		# set up mod assets
		var root_folder = path.split("/")[0] # FIXME: kinda ugly
		var file_data : PackedByteArray = zip_reader.read_file(path) 
		if file_data.size() < 0:
			printerr("MODDATA: File within mod couldn't be read: ", path)
			continue
			
		match(root_folder):
			"afs":
				afs_files.append({
					"filename" : path.get_file(),
					"bytes" : file_data
				})
			"ips":
				continue # this is set up earlier
				#var fname = path.get_file()
				#var bytes = file_data
				#patch_files.append({
					#"filename" : path.get_file(),
					#"bytes" : file_data
				#})
			"pnach":
				var string = file_data.get_string_from_utf8()
				pnach_files.append(string)
			"textures":
				tm2_files.append({
					"filename" : path.get_file(),
					"bytes" : file_data
				})
			_:
				printerr("MODDATA: Unknown root folder type: ", root_folder)
				continue


func _init(filepath : String) -> void:
	if filepath.length() == 0:
		print("MODDATA: Created with empty path")
		return
	
	print("MODDATA: Reading mod: ", filepath)
	
	var path_parts = filepath.split("/")
	source_filename = path_parts[path_parts.size()-1]
	
	var zip_reader = ZIPReader.new()
	var err = zip_reader.open(filepath)
	if err != OK:
		OS.alert("MODDATA: Failed to open zip file: %s (%s)" % [filepath, err], "Error")
		return
	
	var file_list : PackedStringArray = zip_reader.get_files()

	# remove directory listings, leave file paths only
	for i in range(file_list.size()-1, -1, -1):
		if file_list[i].ends_with("/"):
			file_list.remove_at(i)
	
	fill_data_from_filelist(zip_reader, file_list)
	print("MODDATA: Done.")

#var title : String = "N/A"
#var author : String = "N/A"
#var description : String = "N/A"
#var preview_image : Image = Image.new()
#
#var patch_files : Array[Dictionary] = [] # members: [patch_target, patch_data]
#var pnach_files : PackedStringArray = [] # members: string
#var afs_files  : Array[Dictionary] = [] # members: [filename, bytes]
#var tm2_files  : Array[Dictionary] = [] # members: [filename, bytes]
func write_zip_archive(path : String) -> Error:
	var metadata : Dictionary = {
		"Metadata" = {
			"Title": get_title_clean(),
			"Author": get_author_clean(),
			"Description": get_description_clean()
		},
		"IPS Entries" = []
	}
	
	var writer = ZIPPacker.new()
	var err = writer.open(path)
	if err != OK:
		return err
	
	for afs in afs_files:
		var write_path = "afs".path_join(afs.filename)
		
		writer.start_file(write_path)
		writer.write_file(afs.bytes)
		writer.close_file()
	
	for tm2 in tm2_files:
		var write_path = "textures".path_join(tm2.filename)
		
		writer.start_file(write_path)
		writer.write_file(tm2.bytes)
		writer.close_file()
	
	for i in range(pnach_files.size()):
		var pnach_bytes = pnach_files[i].to_utf8_buffer()
		var write_path = "pnach".path_join("pnach_%d.pnach" % i)
		
		writer.start_file(write_path)
		writer.write_file(pnach_bytes)
		writer.close_file()
	
	for ips in patch_files:
		var filename = "%s.ips" % ips.patch_target
		var write_path = "ips".path_join(filename)
		
		writer.start_file(write_path)
		writer.write_file(ips.patch_data)
		writer.close_file()
		
		metadata["IPS Entries"].append({
			"Patch": write_path,
			"Target" : ips.patch_target
		})
	
	if preview_image.get_data_size() > 0:
		var preview_bytes := preview_image.save_png_to_buffer()
		writer.start_file("preview.png")
		writer.write_file(preview_bytes)
		writer.close_file()
	
	var json_metadata = JSON.stringify(metadata, '\t')
	writer.start_file("meta.json")
	writer.write_file(json_metadata.to_utf8_buffer())
	writer.close_file()
	
	writer.close()
	return OK


func get_tags() -> Array[bool]:
	return [
		afs_files.size() > 0,
		tm2_files.size() > 0,
		pnach_files.size() > 0,
		patch_files.size() > 0
	]


func get_title_clean() -> String:
	return escape_bbcode(self.title)


func get_author_clean() -> String:
	return escape_bbcode(self.author)


func get_description_clean() -> String:
	return escape_bbcode(self.description)


func get_title() -> String:
	return self.title


func set_title(string : String) -> void:
	self.title = string


func get_author() -> String:
	return self.author


func set_author(string : String) -> void:
	self.author = string


func get_description() -> String:
	return self.description


func set_description(string : String) -> void:
	self.description = string


func get_preview_image() -> Image:
	return preview_image


func set_preview_image(image : Image) -> void:
	self.preview_image = image


func get_source_filename() -> String:
	return source_filename


func get_if_active() -> bool:
	return active


func set_if_active(value : bool) -> void:
	active = value


func get_patch_files() -> Array[Dictionary]:
	return patch_files


func add_patch_data(patch_target : String, patch_data : PackedByteArray) -> void:
	patch_files.append({
		"patch_target" : patch_target,
		"patch_data" : patch_data
	})


func clear_patch_files() -> void:
	patch_files.clear()


func get_afs_files() -> Array[Dictionary]:
	return afs_files


func add_afs_file(path : String) -> void:
	if not FileAccess.file_exists(path):
		OS.alert("Can't add AFS asset because it doesn't exist (%s)" % path, "Error")
		return
	
	var buffer = FileAccess.get_file_as_bytes(path)
	if buffer.size() == 0:
		OS.alert("Can't add AFS asset (%s) because it failed to open (%s)" % \
		[path, FileAccess.get_open_error()], "Error")
		return
	
	afs_files.append({
		"filename" : path.get_file(),
		"bytes" : buffer
	})


func clear_afs_files() -> void:
	afs_files.clear()


func get_tm2_files() -> Array[Dictionary]:
	return tm2_files


func add_tm2_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		OS.alert("Can't add TM2 file because it doesn't exist (%s)" % path, "Error")
		return
	
	var buffer = FileAccess.get_file_as_bytes(path)
	if buffer.size() == 0:
		OS.alert("Can't add TM2 file (%s) because it failed to open (%s)" % \
		[path, FileAccess.get_open_error()], "Error")
		return
	
	tm2_files.append({
		"filename" : path.get_file(),
		"bytes" : buffer
	})


func clear_tm2_files() -> void:
	tm2_files.clear()


func get_pnach_files() -> PackedStringArray:
	return pnach_files


func add_pnach_file(path: String) -> void:
	var file_string = FileAccess.get_file_as_string(path)
	
	if file_string == "":
		OS.alert("Can't read file (%s) as string (%s)" %\
		[path, FileAccess.get_open_error()], "Error")
		return
	
	pnach_files.append(file_string)


func clear_pnach_files() -> void:
	pnach_files.clear()
