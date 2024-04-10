extends Node

# Reads a csv file and returns an Array of PackedStringArray
# csv_array[0][1] = line 0, cell 1
func read_csv_file(file_path:String) -> Array[PackedStringArray]:
	var csv_array:Array[PackedStringArray]
	var file:FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if(file == null):
		push_error("CSVManager: File for path '" + file_path + "' is null.")
		return csv_array
	
	# add file path on first line
	var path:PackedStringArray = [file_path]
	csv_array.append(path)

	while !file.eof_reached():
		var csv_rows:PackedStringArray = file.get_csv_line(",")
		if(csv_rows.size() > 0):
			csv_array.append(csv_rows)
	file.close()
	return csv_array

# writes a PackedStringArray to disk as a csv file
func write_to_csv_file(file_path:String, csv_array:Array[PackedStringArray]):
	var file:FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	for line in csv_array:
		var string_line:String = ""
		#enclose all non-empty cells with "
		#this is the only way to do it; store_csv_line can't be used because it will escape the enclosing ", then re-enclose the cell, resulting in three "
		for n in line.size():
			# remove the headers
			if(n == 0): continue

			if(line[n].length() == 0):
				string_line += ","
			else:
				string_line += '\"' + line[n] + '\",'
		# remove the last comma
		string_line = string_line.substr(0, string_line.length()-2)

		file.store_line(string_line)
	file.close()
