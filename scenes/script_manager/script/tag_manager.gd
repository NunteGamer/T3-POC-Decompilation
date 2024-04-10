extends Node

@export var dialogue_parser: Node
@export var flag_list: Node

##### separate words #####

func separate_words(text: String) -> Array[TaggedWord]:
	# separate each word as a TaggedWord, including all the tags that wrap it
	var tagged_words: Array[TaggedWord]
	var word_index: int
	var opening_tags: Array[String]
	var closing_tags: Array[String]
	var start_index: int
	
	# go through the text one character at a time
	var i: int = 0
	while(i < text.length()):
		# if a tag starts, see if it's opening or closing
		if(text[i] == "[" || text[i] == "<" || text[i] == ">"):
			start_index = i
			# closing bbc tag
			if(text[i + 1] == "/"):
				# get where it ends
				while(text.length() > i && text[i] != "]"):
					i += 1
				# since a tag closed, remove it from the active opening/closing tags
				var tag: String = text.substr(start_index, i - start_index + 1)
				opening_tags = remove_tag(opening_tags, tag)
				closing_tags = remove_tag(closing_tags, tag)
				
			# opening bbc tag
			elif(text[i] == "["):
				# get where it ends
				while(text.length() > i && text[i] != "]"):
					i += 1
				# get the tag to later add it to the opening_tags
				var tag: String = text.substr(start_index, i - start_index + 1)
				
				# if it's a color tag, make the alpha 0
				if(tag.contains("color")):
					var tag_until_alpha = tag.substr(0, tag.length() - 3)
					tag = tag_until_alpha + "00]"
				
				# add it as an active opening tag and generate its closing tag
				opening_tags.append(tag)
				closing_tags.insert(0, genearte_closing_tag(tag))
				
			# pause tag
			elif(text.length() > i + 2 && (text.substr(i, 3) == "<p=")):
				start_index = i
				# get where the tag ends
				var ending_index: int = i
				while(text.length() > ending_index && text[ending_index] != ">"):
					ending_index += 1
				# get the complete tag
				var tagged_word_s: String = text.substr(start_index, ending_index - start_index + 1)
				# remove the <p= > to get the number
				var pause_number_s: String = tagged_word_s.substr(3, tagged_word_s.length() - 4)
				var pause_number: int = int(pause_number_s)
				# add a pause word for each dot
				# the word is empty, with just an opening tag "<.>"
				for n in pause_number:
					var word: String = "<pause>"
					var tagged_word: TaggedWord = TaggedWord.new()
					tagged_word.index = word_index
					word_index += 1
					tagged_word.word = word
					tagged_word.function = true
					tagged_words.append(tagged_word)
				
				# continue after the tag
				i = ending_index
			
			# flag tag
			elif(text.length() > i + 2 && (text.substr(i, 3) == "<f=")):
				start_index = i
				# get where the tag ends
				var ending_index: int = i
				while(text.length() > ending_index && text[ending_index] != ">"):
					ending_index += 1
				# get the complete tag
				var tagged_word_s: String = text.substr(start_index, ending_index - start_index + 1)
				# remove the <f= > to get the number
				var flag_name: String = tagged_word_s.substr(3, tagged_word_s.length() - 4)
				var flag_value = flag_list.get_current_flag_value(flag_name)
				# add the value as a word
				var tagged_word: TaggedWord = TaggedWord.new()
				tagged_word.index = word_index
				word_index += 1
				tagged_word.word = str(flag_value)
				tagged_words.append(tagged_word)
				
				# continue after the tag
				i = ending_index
			
			# <continue>
			elif(text.length() > i + 9 && (text.substr(i, 10) == "<continue>")):
				start_index = i
				# get where the tag ends
				var ending_index: int = i
				while(text.length() > ending_index && text[ending_index] != ">"):
					ending_index += 1
				
				# add function as tagged word
				var word: String = "<continue>"
				var tagged_word: TaggedWord = TaggedWord.new()
				tagged_word.index = word_index
				word_index += 1
				tagged_word.word = word
				tagged_word.function = true
				tagged_words.append(tagged_word)
				
				# continue after the tag
				i = ending_index
			
			# opening lexicon tag
			elif(text[i] == "<"):
				start_index = i
				# add lexicon style tags
				var tag: String = "[color=#" + dialogue_parser.lexicon_color.to_html().substr(0, 6) + "00]"
				# add it as an active opening tag and generate its closing tag
				opening_tags.append(tag)
				closing_tags.insert(0, genearte_closing_tag(tag))
				
				# get where the lexicon ends
				var ending_index: int = i
				while(text.length() > ending_index && text[ending_index] != ">"):
					ending_index += 1
				# get the complete tagged lexicon word
				var tagged_word: String = text.substr(start_index, ending_index - start_index + 1)
				# remove the tag to get the keyword
				var keyword: String = tagged_word.substr(1, tagged_word.length() - 2)
				# create the tag
				tag = "[url=" + keyword + "]"
				# add it as an active opening tag and generate its closing tag
				opening_tags.append(tag)
				closing_tags.insert(0, genearte_closing_tag(tag))
				
			# closing lexicon tag (>)
			else:
				# since a tag closed, remove it from the active opening/closing tags
				var tag: String = "[/url]"
				opening_tags = remove_tag(opening_tags, tag)
				closing_tags = remove_tag(closing_tags, tag)
				
				# also close the lexicon style tags
				tag = "[/color]"
				opening_tags = remove_tag(opening_tags, tag)
				closing_tags = remove_tag(closing_tags, tag)
			
		# if its a word
		else:
			start_index = i
			# get where it ends
			var word_ended: bool
			var regress: bool # text[i] is part of the next word, so it should go back one index
			while(!word_ended):
				# if no more, text, it ends
				if(text.length() <= i):
					word_ended = true
				# if opening bbc tag or lexicon tag, it ends
				elif(text[i] == "[" || text[i] == "<" ||  text[i] == ">" ):
					word_ended = true
					regress = true
				# if space, in ends, unless it's on the first index (before the word starts)
				elif(text[i] == " " && start_index != i):
					word_ended = true
					regress = true
				else:
					# if it's a punctuation sign, it ends
					for _sign in dialogue_parser.pause_punctuation:
						if(text[i] == _sign):
							word_ended = true
							regress = true
							break
					if(!word_ended):
						for _sign in dialogue_parser.other_punctuation:
							if(text[i] == _sign):
								word_ended = true
								regress = true
								break
					# if none of the avobe, it continues
					if(!word_ended):
						i += 1
				
			# text[i] is part of the next word, so it should go back one index
			# if i is not greater than start_index, the word is a single punctuation, so don't regress
			if(i > start_index && regress):
				i -= 1
			
			# check if it's just spaces,
			# if it is, it must be because its after a word tags
			# eg: [b]hello[/b]*[b]there[/b]
			# so add it to the previous word
			var all_spaces: bool = true
			for n in range(start_index, i + 1):
				if(text[n] != " "):
					all_spaces = false
					break
			
			if(all_spaces):
				tagged_words[tagged_words.size() - 1].word += text.substr(start_index, i - start_index + 1)
			else:
			# save it
				var word: String = text.substr(start_index, i - start_index + 1)
				# create a TaggedWord and add it to the list
				var tagged_word: TaggedWord = TaggedWord.new()
				tagged_word.index = word_index
				word_index += 1
				tagged_word.opening_tags = opening_tags.duplicate()
				tagged_word.word = word
				tagged_word.closing_tags = closing_tags.duplicate()
				tagged_words.append(tagged_word)
		# advance to the next character
		i += 1
	
	return tagged_words


# generate a closing tag for a given opening tag
func genearte_closing_tag(tag: String) -> String:
	var tag_parts: PackedStringArray = tag.split("[")
	tag_parts = tag_parts[1].split("]")
	tag_parts = tag_parts[0].split("=")
	return "[/" + tag_parts[0] + "]"


# for a given closing tag, remove its matching opening or closing tag from a list,
# starting from the last added tag
func remove_tag(tags: Array[String], tag: String) -> Array[String]:
	var keyword: String = tag.split("/")[1]
	keyword = keyword.split("]")[0]
	
	for i in range(tags.size() - 1, -1, -1):
		if(tags[i].contains(keyword)):
			tags.remove_at(i)
			return tags
	return tags


func tagged_word_to_string(taged_word: TaggedWord) -> String:
	var string_word: String
	for tag in taged_word.opening_tags:
		if(tag == "<.>"): return ""
		string_word += tag
	string_word += taged_word.word
	for tag in taged_word.closing_tags:
		string_word += tag
	return string_word


# turn a float 0-1 to a 2 digit hex (0-255)
func alpha_to_hex(alpha: float):
	# convert the float value to an integer in the range [0, 255]
	var decimal_value: int = int(alpha * 255)
	
	var hex_characters: String = "0123456789ABCDEF"
	var hex_value: String = ""
	
	if (decimal_value < 16):
		hex_value = str(decimal_value)
	else:
		while decimal_value > 0:
			var remainder = decimal_value % 16
			var hex_digit = hex_characters[remainder]
			hex_value = hex_digit + hex_value
			decimal_value = decimal_value / 16
	
	# pad the hex value if needed
	if(hex_value.length() < 2): hex_value = "0" + hex_value
	
	return hex_value
