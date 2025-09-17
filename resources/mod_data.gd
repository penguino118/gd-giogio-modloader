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


func set_preview_image(zip_reader : ZIPReader, path : String) -> void:
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
			var metajson : PackedByteArray = zip_reader.read_file(path) 
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
			set_preview_image(zip_reader, path)
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
	
	
func get_author() -> String:
	return self.author
	
	
func get_description() -> String:
	return self.description


func get_preview_image() -> Image:
	return preview_image


func get_source_filename() -> String:
	return source_filename


func get_if_active() -> bool:
	return active


func set_if_active(value : bool) -> void:
	active = value


func get_patch_files() -> Array[Dictionary]:
	return patch_files


func get_afs_files() -> Array[Dictionary]:
	return afs_files


func get_tm2_files() -> Array[Dictionary]:
	return tm2_files


func get_pnach_files() -> PackedStringArray:
	return pnach_files
