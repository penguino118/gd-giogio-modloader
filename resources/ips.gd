class_name IPSParser

const UINT16_MAX: int = (1 << 16) - 1
const MAGIC: String = 'PATCH' # "PATCH"
const EOF: int = 0x454F46 # "EOF"

# partially based off of:
# https://github.com/marcrobledo/RomPatcher.js/blob/master/rom-patcher-js/modules/RomPatcher.format.ips.js

func decode_u16_be(packed_array: PackedByteArray, offset: int) -> int: 
	var short_le := packed_array.slice(offset,offset+0x2)
	offset += 0x2
	short_le.reverse() # reverse endianness
	return short_le.decode_u16(0)


func decode_u24_be(packed_array: PackedByteArray, offset: int) -> int:
	var byte1 = packed_array.decode_u8(offset)
	var byte2 = packed_array.decode_u8(offset + 1)
	var byte3 = packed_array.decode_u8(offset + 2)
	return (byte1 << 16) | (byte2 << 8) | byte3


func test_magic(packed_array: PackedByteArray) -> bool:
	var slice =  packed_array.slice(0, 5)
	slice = slice.get_string_from_utf8()
	return slice == MAGIC


func encode_u16_be(packed_array: PackedByteArray, value: int, offset: int) -> PackedByteArray: 
	if packed_array.size() < offset + 2:
		packed_array.resize(offset + 2)
	
	var short_le: PackedByteArray = [0,0]
	short_le.encode_u16(0, value)
	short_le.reverse() # reverse endianness
	packed_array.encode_u16(offset, short_le.decode_u16(0))
	return packed_array


func encode_u24_be(packed_array: PackedByteArray, value: int, offset: int) -> void:
	if packed_array.size() < offset + 3:
		packed_array.resize(offset + 3)

	var byte1 = (value >> 16) & 0xFF
	var byte2 = (value >> 8) & 0xFF
	var byte3 = value & 0xFF

	packed_array.encode_u8(offset, byte1)
	packed_array.encode_u8(offset + 1, byte2)
	packed_array.encode_u8(offset + 2, byte3)


func encode_magic(packed_array: PackedByteArray) -> void:
	var encoded_magic = MAGIC.to_utf8_buffer().hex_encode()
	packed_array.append_array(encoded_magic)


func encode_record(patch_data: PackedByteArray, record: Dictionary) -> void:
	encode_u24_be(patch_data, record["offset"], patch_data.size())
	if record["type"] == "simple":
		encode_u16_be(patch_data, record["length"], patch_data.size())
		for byte in record["data"]:
			patch_data.append(byte)
	elif record["type"] == "rle":
		encode_u16_be(patch_data, 0, patch_data.size()) # RLE marker
		encode_u16_be(patch_data, record["length"], patch_data.size())
		patch_data.append(record["byte"])


func append_record(diff_records: Array, offset: int, diff_sequence: Array, is_rle: bool, byte: int):
	if is_rle and diff_sequence.size() > 2:
		diff_records.append({"type": "rle", "offset": offset, "length": diff_sequence.size(), "byte": byte})
	else:
		diff_records.append({"type": "simple", "offset": offset, "data": diff_sequence, "length": diff_sequence.size()})


func collect_diff_records(source_bytes: PackedByteArray, target_bytes: PackedByteArray) -> Array:
	var offset := 0
	var records := [{}]
	var previous_record = records[0]
	while offset < target_bytes.size():
		var source = source_bytes.decode_u8(offset)
		var target = target_bytes.decode_u8(offset)
		
		if source == target:
			offset += 0x1
		else:
			var start_offset = offset
			var diff_sequence = []
			var rle_mode = true
			var first_byte = target
			
			while offset < target_bytes.size() and diff_sequence.size() < UINT16_MAX:
				source = source_bytes.decode_u8(offset)
				target = target_bytes.decode_u8(offset)
				if source == target: break
				diff_sequence.append(target)
				if diff_sequence.size() > 1 and target != diff_sequence[0]:
					rle_mode = false
				offset += 1
			
			# check if we can merge with the previous record
			if not previous_record.is_empty() and previous_record["type"] == "simple":
				var end_of_previous = previous_record["offset"] + previous_record["length"]
				var distance = start_offset - end_of_previous
				if distance < 6 and (previous_record["length"] + distance + diff_sequence.size()) < UINT16_MAX:
					if rle_mode and diff_sequence.size() > 6:
						# separate a potential RLE record
						offset = start_offset
						previous_record = {"type": "invalid"}
					else:
						# merge with previous record
						for i in range(distance):
							var byte = target_bytes.decode_u8(end_of_previous + i)
							previous_record["data"].append(byte)
						previous_record["data"] += diff_sequence
						previous_record["length"] = previous_record["data"].size()
				else:
					append_record(records, start_offset, diff_sequence, rle_mode, first_byte)
					previous_record = records[-1]
			else:
				append_record(records, start_offset, diff_sequence, rle_mode, first_byte)
				previous_record = records[-1]
	return records


func create_patch(source_path: String, target_path: String) -> PackedByteArray:
	var patch_output: PackedByteArray = []
	var source_bytes: PackedByteArray = FileAccess.get_file_as_bytes(source_path)
	var target_bytes: PackedByteArray = FileAccess.get_file_as_bytes(target_path)
	
	if target_bytes.size() == 0 || source_bytes.size() == 0:
		printerr("IPS: Target file or Source file failed to open. (%s)" % \
		[target_path.get_file(), source_path.get_file()])
		return []
	
	if target_bytes.size() < source_bytes.size():
		printerr("IPS: Target file (%s) is smaller than the source file (%s), patch will be truncated." % \
		[target_path.get_file(), source_path.get_file()])

	print("IPS: Creating patch (%s -> %s)" % [source_path, target_path])
	var diff_records := collect_diff_records(source_bytes, target_bytes)
	
	encode_magic(patch_output)
	patch_output.resize(5)
	for record in diff_records:
		if not record.is_empty(): encode_record(patch_output, record)
	encode_u24_be(patch_output, EOF, patch_output.size()) 
	print("IPS: Patch created.")
	return patch_output


func apply_patch(patch: PackedByteArray, source: PackedByteArray) -> void:
	var offset = 0x5
	while offset <= patch.size():
		var record_bytes : PackedByteArray = []
		var record_address = decode_u24_be(patch, offset)
		
		if record_address == EOF:
			# TODO: technically this should be a >=, but i'll change it only if issues arise
			break 
		
		var record_size = decode_u16_be(patch, offset + 0x3)
		if record_size == 0: # means the record is RLE encoded
			if offset == 0x62ab:
				while (1):
					break
			
			record_size = decode_u16_be(patch, offset + 0x5)
			var rle_byte = patch.decode_u8(offset + 0x7)
			record_bytes.resize(record_size)
			record_bytes.fill(rle_byte)
			offset += 0x8
			#print("IPS: RLE ENCODE (%s) x (%s) at %08X to %08X" % [rle_byte, record_size, offset, record_address])
		else:
			record_bytes = patch.slice(0x5 + offset, 0x5 + offset + record_size)
			offset += 0x5 + record_size
		#print("IPS: pAddres=%08X; pSize=%s; (offset=%04X)" % [record_address, record_size, offset])
		for i in range(record_size):
			source.set(record_address+i, record_bytes[i])
	print("IPS: Patching done.")


func get_patched_file(patch: PackedByteArray, source_path: String) -> PackedByteArray:
	var source_bytes: PackedByteArray = FileAccess.get_file_as_bytes(source_path)
	
	if source_bytes.size() <= 0:
		printerr("IPS: Source file (%s) returned empty. (%s)" % \
		[source_path.get_file(), str(FileAccess.get_open_error())])
		return []
	
	if source_bytes.size() >= EOF:
		printerr("IPS: Source file (%s) is larger than the maximum supported filesize. The file might not be fully patched." % \
		source_path.get_file())

	if not test_magic(patch):
		printerr("IPS: Patch is lacking the magic value, skipping.")
		return []
	
	print("IPS: Patching %s" % source_path.get_file())
	apply_patch(patch, source_bytes)
	return source_bytes


func get_patched_bytes(patch: PackedByteArray, source_bytes: PackedByteArray) -> PackedByteArray:
	if source_bytes.size() <= 0:
		printerr("IPS: Source bytes are empty, skipping.")
		return []
	
	if source_bytes.size() >= EOF:
		printerr("IPS: Source bytes are larger than the maximum supported filesize. The output might not be fully patched.")
	
	if test_magic(patch):
		printerr("IPS: Patch is lacking the magic value, skipping.")
		return []
	
	print("IPS: Patching PackedByteArray")
	var output = source_bytes.duplicate()
	apply_patch(patch, output)
	return output
