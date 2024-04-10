extends Node

@export var _print_debug: bool
@export var script_manager: Node
enum Lang{EN, ES}

# Receives an Array of PackedStringArray from a csv read by CSVManager
# and turns it into an Array of ScriptLine
# ScriptLine is a custom class with id, type, code and dialogue
func parse_csv_array_as_script(csv_array:Array) -> Array[ScriptLine]:
	# ID, code, name, en, es, etc
	
	var script_lines: Array[ScriptLine]

	var line_number: int = 0
	for line in csv_array:
		line_number += 1
		
		# skip first line (an added file path)
		if(line.size() < 2):
			continue
		# skip headers line
		if(line[0].to_lower() == "id" && line[1].to_lower() == "code"):
			continue
		
		var csv_cell: Vector2
		csv_cell = Vector2(line_number - 1, 0) # -1 beacuse there's an extra line added at the start with the file path
		
		# parse line
		# id
		var new_script_line:ScriptLine = ScriptLine.new()
		new_script_line.id = line[0]
		
		# code
		if(line[1].length() > 0):
			# ignore comments (text lines preceded by #)
			if(line[1].substr(0,1) == "#"): continue
			
			# check if it's a copy instruction and if there is, copy the required lines
			var keywords: PackedStringArray = line[1].split(":")
			if(keywords[0] == "copy"):
				# get the indexes of the instruction lines with the "from" id
				var from_line_indexes: Array[int] = _get_id_line_indexes(script_lines, keywords[1])
				# check that it was found
				if(from_line_indexes.size() == 0):
					push_error("ERROR: CSV_PARSER: Attempted to copy from ID: '" + keywords[1] +"' but didn't found it.")
					continue
				
				# if it includes "from" and "to"
				if(keywords.size() > 2):
					# from the first line containing the "from" ID
					var from_line_index: int = from_line_indexes[0]
					
					var to_line_indexes: Array[int] = _get_id_line_indexes(script_lines, keywords[2])
					# check that it was found
					if(from_line_indexes.size() == 0):
						push_error("ERROR: CSV_PARSER: Attempted to copy to ID: '" + keywords[2] +"' but didn't found it.")
						continue
					
					# to the last line containing the "to" ID
					var to_line_index: int = to_line_indexes[to_line_indexes.size() - 1]
					
					var i: int = from_line_index
					# copy all the lines from from_line_index to to_line_index
					while(i <= to_line_index):
						script_lines.append(script_lines[i])
						i += 1
					
				# includes only "from", so just copy instructions from that one line
				else:
					for i in from_line_indexes:
						script_lines.append(script_lines[i])
			
			# if it's a addcript line
			elif(keywords[0] == "copyscript"):
				var external_script_lines: Array[ScriptLine]
				external_script_lines = script_manager.get_script_lines(keywords[1])
				# if there is a from_id and to_id
				if(keywords.size() > 2):
					var from_line_indexes: Array[int]
					from_line_indexes = _get_id_line_indexes(external_script_lines, keywords[2])
					if(from_line_indexes.size() == 0):
						push_error("ERROR: CSV_PARSER: Attempted to copy from script: '" + keywords[1] + "' ID (from): '" + keywords[2] +"' but didn't found it.")
					else:
						var to_line_indexes: Array[int]
						to_line_indexes = _get_id_line_indexes(external_script_lines, keywords[3])
						if(from_line_indexes.size() == 0):
							push_error("ERROR: CSV_PARSER: Attempted to copy from script: '" + keywords[1] + "' ID (to): '" + keywords[3] +"' but didn't found it.")
						else:
							var from_line_index: int = from_line_indexes[0]
							var to_line_index: int = to_line_indexes[to_line_indexes.size() - 1]
							
							var i: int = from_line_index
							# copy all the lines from from_line_index to to_line_index
							while(i <= to_line_index):
								script_lines.append(script_lines[i])
								i += 1
							
				# no from_id and to_id; copy the whole script
				else:
					for script_line in external_script_lines:
						script_lines.append(script_line)
			
			else:
				# if it's a normal code line, proceed normally
				csv_cell.y = 2
				new_script_line.csv_cell = csv_cell
				
				new_script_line.type = ScriptLine.Type.CODE
				new_script_line.code = line[1].to_lower()
				# if no id, generate one
				if(new_script_line.id == ""):
					new_script_line.id = "auto_id" + str(csv_cell)
				script_lines.append(new_script_line)
				new_script_line = ScriptLine.new()
				new_script_line.id = line[0]
		# name
		if(line[2].length() > 0):
			csv_cell.y = 3
			new_script_line.csv_cell = csv_cell
			
			new_script_line.type = ScriptLine.Type.NAME
			new_script_line.code = line[2].to_lower()
			# if no id, generate one
			if(new_script_line.id == ""):
				new_script_line.id = "auto_id" + str(csv_cell)
			script_lines.append(new_script_line)
			new_script_line = ScriptLine.new()
			new_script_line.id = line[0]
		# en text
		if(line[3].length() > 0):
			# ignore comments (text lines preceded by #)
			if(line[3].substr(0,1) == "#"): continue
			
			csv_cell.y = 4
			new_script_line.csv_cell = csv_cell
			
			new_script_line.type = ScriptLine.Type.DIALOGUE
			var i:int = 0
			for key in Lang.keys():
				new_script_line.dialogue[key.to_lower()] = line[3 + i]
				if (line[3 + i].length() == 0):
					if(_print_debug): push_warning("Translation " + key + " missing in " + csv_array[0][0] + ": " + line[3])
				i += 1
			# if no id, generate one
			if(new_script_line.id == ""):
				new_script_line.id = "auto_id" + str(csv_cell)
			script_lines.append(new_script_line)
			new_script_line = ScriptLine.new()
			new_script_line.id = line[0]
	
	return script_lines


func parse_csv_array_as_chara_names(csv_array:Array) -> Array[ScriptLine]:
	# code, en, es, etc
	
	var script_lines: Array[ScriptLine]

	var line_number: int = 0
	for line in csv_array:
		line_number += 1
		
		# skip first line (an added file path)
		if(line.size() < 2):
			continue
		# skip headers line
		if(line[0].to_lower() == "code" && line[1].to_lower() == "en"):
			continue
		
		var csv_cell: Vector2
		csv_cell = Vector2(line_number, 0)
		
		# parse line
		var new_script_line:ScriptLine = ScriptLine.new()
		
		# code
		if(line[0].length() > 0):
			new_script_line.csv_cell = csv_cell
			
			# add code name
			new_script_line.type = ScriptLine.Type.CODE
			new_script_line.code = line[1].to_lower()
			
			# en text
			if(line[1].length() > 0):
				# ignore comments (text lines preceded by #)
				if(line[1].substr(0,1) == "#"): continue
				var i:int = 0
				for key in Lang.keys():
					new_script_line.dialogue[key.to_lower()] = line[1 + i]
					if (line[1 + i].length() == 0):
						if(_print_debug): push_warning("Translation " + key + " missing in " + csv_array[0][0] + ": " + line[3])
					i += 1
				# if no id, generate one
				if(new_script_line.id == ""):
					new_script_line.id = "auto_id" + str(csv_cell)
				script_lines.append(new_script_line)
	
	return script_lines

func _get_id_line_indexes(script_lines: Array[ScriptLine], id: String) -> Array[int]:
	# since csv lines are separated into instruction lines, there can be multiple lines with the same ID
	var line_indexes: Array[int]
	var id_found: bool
	var i: int
	while(i < script_lines.size()):
		if(script_lines[i].id == id):
			id_found = true
			line_indexes.append(i)
		# if id has been found and the next line does not have that id, there shouldn't be any more lines with it
		elif(id_found):
			break
		i += 1
	
	return line_indexes
