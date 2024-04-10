extends Node

@export_group("Settings")
@export var language: String
@export var type_individual_characters: bool
@export var skip_spaces: bool
@export var pause_on_spaces: bool
@export var dynamic_word_type_time: bool
@export var dynamic_word_type_sound: bool
@export var max_sounds_per_word: int
@export var default_text_color: Color
@export var lexicon_color: Color

@export_group("References")
@export var script_reader: Node
@export var tag_manager: Node
@export var dialogue_sound: AudioStreamPlayer2D
@export var dialogue_label: RichTextLabel
@export var type_timer: Timer
@export var fade_timer: Timer

@export_group("Other")
@export var pause_punctuation: Array[String]
@export var other_punctuation: Array[String]

var skipping: bool
var letter_fade_time: float = 0.05
var word_fade_time: float = 0.2
var cooldown_between_words_factor: float = 0.1
var type_fadein_time: float = 0.01
var space_pause_factor: float = 1.5
var letter_short_puntuation_pause_factor: float = 5
var letter_long_puntuation_pause_factor: float = 10
var word_short_puntuation_pause_factor: float = 1
var word_long_puntuation_pause_factor: float = 2
var transparent_tag: String
var formatted_opening_tags: String
const formatted_closing_tags: String = "[/font_size][/color][/color]"
var current_word_hex_color: String
var current_word_alpha: float
var _continued_reading: bool

func _ready():
	formatted_opening_tags = "[font_size=40][color=#" + default_text_color.to_html() + "]"
	transparent_tag = "[color=#" + default_text_color.to_html().substr(0,6) + "00]"

func parse_dialogue(text: Dictionary):
	var _text = text[language]
	
	_text = replace_ellipsis(_text)
	# convert the text into an array of TaggedWord
	var tagged_words: Array[TaggedWord] = tag_manager.separate_words(_text)
	
	# set timer times
	fade_timer.wait_time = type_fadein_time
	if(type_individual_characters):
		type_timer.wait_time = letter_fade_time
	else:
		type_timer.wait_time = word_fade_time + (word_fade_time * cooldown_between_words_factor)
	
	# type the text
	skipping = false
	_type_text(tagged_words)
	
	# play sound
	if(type_individual_characters):
		dialogue_sound.play_talk_letters(letter_fade_time)
	elif(!dynamic_word_type_time  && !dynamic_word_type_sound):
		dialogue_sound.play_talk_words(word_fade_time)


func skip():
	skipping = true
	type_timer.wait_time = 0.001
	fade_timer.wait_time = 0.001


func _type_text(tagged_words):
	var word_index: int
	var letter_index: int
	_continued_reading = false
	_type_next_part(tagged_words, word_index, letter_index, type_individual_characters)
	


func _typing_ended(_continued_reading: bool):
	dialogue_sound.stop_talk()
	
	# disconnect _typing_ended from timer signal
	if(type_timer.is_connected("timeout",  _typing_ended)): type_timer.disconnect("timeout",  _typing_ended)
	
	if(skipping): script_reader.end_skip()
	script_reader.text_finished_typing(_continued_reading)
		


func _type_next_part(tagged_words: Array[TaggedWord], word_index: int, letter_index: int, _type_individual_characters: bool):
	var formatted_text: String
	var original_wait_time: float = type_timer.wait_time
	var stop_sound: bool
	var is_short_punctuation: bool
	var is_long_punctuation: bool
	
	# add initial tags
	formatted_text = formatted_opening_tags
	
	# add already typed words
	for i in word_index:
		if(!tagged_words[i].function): # ignore functions
			formatted_text += tag_manager.tagged_word_to_string(tagged_words[i])
	
	# manage current word
	var current_tagged_word: TaggedWord = tagged_words[word_index]
	var current_word: String = current_tagged_word.word
	# manage functions
	if(current_tagged_word.function):
		# pause tag
		if(current_word == "<pause>"):
			if(_type_individual_characters):
				type_timer.wait_time = letter_fade_time * letter_long_puntuation_pause_factor
			else:
				type_timer.wait_time = word_fade_time * word_long_puntuation_pause_factor
			stop_sound = true
		# continue tag
		elif(current_word == "<continue>"):
			_continued_reading = true
			script_reader.continue_read_next_line(skipping)
			
	# normal words
	else:
		# already typed letters
		# recover alpha of typed color tag, so already showed letters show in their proper color
		current_tagged_word = _recover_alpha_of_color_tag(current_tagged_word)
		# get the opening and closing tags
		var opening_tags: String
		for tag in current_tagged_word.opening_tags:
			opening_tags += tag
		var closing_tags: String
		for tag in current_tagged_word.closing_tags:
			closing_tags += tag
		
		# get new word or letter
		var new_letter: String
		if(!_type_individual_characters):
			# add new word
			formatted_text += opening_tags + "<fadein>" + tagged_words[word_index].word + "<fadein>" + closing_tags
			new_letter = current_tagged_word.word[0] # to later check if it's punctuation
		else:
			# get already typed letters
			var already_typed_letters: String
			already_typed_letters = current_word.substr(0,letter_index)
			# add already typed letters with enclosing tags
			formatted_text += opening_tags + already_typed_letters + closing_tags
			
			# new letter
			# remove alpha of typed color tag, so yet to  be typed letters remain invisible
			current_tagged_word = _remove_alpha_of_color_tag(current_tagged_word)
			# get tags again so color is updated
			opening_tags = ""
			for tag in current_tagged_word.opening_tags:
				opening_tags += tag
			
			# get new letter
			new_letter = current_tagged_word.word[letter_index]
			
			# manage skip spaces and pause_on_spaces
			if(skip_spaces):
				# if new letter is a space, skip it and get the next non-space one
				var contiguous_spaces: int
				while(new_letter == " "):
					contiguous_spaces += 1
					if(current_tagged_word.word.length() > letter_index + contiguous_spaces):
						new_letter = current_tagged_word.word[letter_index + contiguous_spaces]
					else:
						break
				if(contiguous_spaces > 0):
					new_letter = current_tagged_word.word.substr(letter_index, contiguous_spaces + 1)
					letter_index += contiguous_spaces
				
				# check if following letters are spaces, and if so, add them
				var advanced_letter_index: int = letter_index + 1
				contiguous_spaces = 0
				while(current_tagged_word.word.length() > advanced_letter_index):
					if(current_tagged_word.word[advanced_letter_index] == " "):
						contiguous_spaces += 1
						advanced_letter_index += 1
					else:
						break
				if(contiguous_spaces > 0):
					new_letter = current_tagged_word.word.substr(letter_index, contiguous_spaces + 1)
					letter_index += contiguous_spaces
			elif(pause_on_spaces && new_letter == " "):
				type_timer.wait_time = letter_fade_time * space_pause_factor
				
			# add new letter with fadein tags
			formatted_text += opening_tags + "<fadein>" + new_letter + "<fadein>" + closing_tags
		
		# longer pause in punctuation
		if(!current_tagged_word.function):
			if(new_letter == "," || new_letter == ";"):
				is_short_punctuation = true
				var new_wait_time: float
				if(_type_individual_characters):
					new_wait_time = letter_fade_time * letter_short_puntuation_pause_factor
				else:
					new_wait_time = word_fade_time * word_short_puntuation_pause_factor
				type_timer.wait_time = new_wait_time
			elif(new_letter == "." || new_letter == "!" || new_letter == "?"):
				is_long_punctuation = true
				var new_wait_time: float
				if(_type_individual_characters):
					new_wait_time = letter_fade_time * letter_long_puntuation_pause_factor
				else:
					new_wait_time = word_fade_time * word_long_puntuation_pause_factor
				type_timer.wait_time = new_wait_time
		
		# don't resume sound if space or punctuation
		if(!_type_individual_characters && new_letter == " "):
			# if it's a whole world, it might start with a space. In that case, it's not a pause
			pass
		else:
			stop_sound = _should_stop_sound(new_letter)
		
		# add transparent tag
		formatted_text += transparent_tag
		
		if(_type_individual_characters):
			# add the rest of the word
			var remaining_letters: String
			remaining_letters = current_word.substr(letter_index + 1, current_word.length() - letter_index + 1)
			formatted_text += opening_tags + remaining_letters + closing_tags
		
	# add the rest of the words
	for i in range(word_index + 1, tagged_words.size()):
		if(!tagged_words[i].function): # ignore functions
			formatted_text += tag_manager.tagged_word_to_string(tagged_words[i])
	
	# add closing of initial tags + transparent
	formatted_text += formatted_closing_tags
	
	# call type fadein
	if(!current_tagged_word.function):
		current_word_alpha = 0
		if(_type_individual_characters):
			_fadein_type(formatted_text, _get_color_from_tags(current_tagged_word), letter_fade_time)
		else:
			var _fade_time: float = word_fade_time
			# if it's punctuation, the fade time is shorter
			if(is_short_punctuation):
				_fade_time = word_fade_time * word_short_puntuation_pause_factor
			elif(is_long_punctuation):
				_fade_time = word_fade_time * word_long_puntuation_pause_factor
			_fadein_type(formatted_text, _get_color_from_tags(current_tagged_word), _fade_time)
	
	# recover alpha of typed color tag
	current_tagged_word = _recover_alpha_of_color_tag(current_tagged_word)
	
	# advance letter/word
	var current_word_ended: bool
	if(_type_individual_characters):
		# advance letter index
		letter_index += 1
		#advance word index if no more letters or function
		if(letter_index >= current_word.length() || current_tagged_word.function):
			word_index += 1
			current_word_ended = true
			letter_index = 0
	else:
		word_index += 1
		current_word_ended = true
		
		
	
	# if there is text left, invoke this function again
	if(word_index < tagged_words.size()):
		#must disconnect the previous one so the arguments being sent are updated
		if(type_timer.is_connected("timeout",  _type_next_part)): type_timer.disconnect("timeout",  _type_next_part)
		if(skipping):
			_type_next_part(tagged_words, word_index, letter_index, _type_individual_characters)
		else:
			type_timer.connect("timeout",  Callable(_type_next_part).bind(tagged_words, word_index, letter_index, _type_individual_characters))
			type_timer.start()
	else:
		# if no more words, reduce the wait time so it doesn't needlessly wait after the full stop
		type_timer.wait_time = letter_fade_time
		
		if(type_timer.is_connected("timeout",  _type_next_part)): type_timer.disconnect("timeout",  _type_next_part)
		if(type_timer.is_connected("timeout",  Callable(_typing_ended).bind(_continued_reading))): type_timer.disconnect("timeout",  _typing_ended)
		type_timer.connect("timeout",  Callable(_typing_ended).bind(_continued_reading))
		type_timer.start()
	
	# in case it has been changed during this function for a particular character
	type_timer.wait_time = original_wait_time
	
	
	# check if the next letter should stop the sound, and if so do it now
	# otherwise the sound might play before stop talk is called
	if(_type_individual_characters && !current_word_ended && !current_tagged_word.function):
		var next_letter: String
		next_letter = current_tagged_word.word[letter_index]
		if(!stop_sound && word_index < tagged_words.size() && tagged_words[word_index].word.length() > 0):
			next_letter = tagged_words[word_index].word[letter_index]
	
	# stop or resume talk sounds
	if(stop_sound || skipping):
		dialogue_sound.stop_talk()
	else:
		if(_type_individual_characters):
			dialogue_sound.play_talk_letters(letter_fade_time)
		else:
			dialogue_sound.play_talk_words(word_fade_time)


func _should_stop_sound(letter: String):
	# return true if space or punctuation
	if(letter == " "):
		return true
	for punctuation in pause_punctuation:
		if(letter == punctuation):
			return true
	for punctuation in other_punctuation:
		if(letter == punctuation):
			return true
	return false


func _fadein_type(formatted_text: String, color: String, type_time: float):
	# if a color was received, use that. otherwise use default
	if(color.length() != 6):
		color = default_text_color.to_html().substr(0,6)
	
	# replace fadeins with proper tags
	var formatted_text_array: PackedStringArray = formatted_text.split("<fadein>")
	var new_formatted_text = formatted_text_array[0] + "[color=#" + color + tag_manager.alpha_to_hex(current_word_alpha) +  "]" + formatted_text_array[1] + "[/color]" + formatted_text_array[2]
	
	# show text
	dialogue_label.text = new_formatted_text
	
	# increment alpha for next call
	var increment: float
	# if type_timer is lower than fade_timer, don't fade in
	if(fade_timer.wait_time > type_time):
		increment = 1
	else:
		# calculate fade in speed according to type time
		increment = 1 / (type_time/ fade_timer.wait_time)
	
	# if still not full alpha, invoke this function again
	if(current_word_alpha < 1):
		current_word_alpha += increment
		current_word_alpha = clampf(current_word_alpha, 0, 1)
		if(fade_timer.is_connected("timeout",  _fadein_type)): fade_timer.disconnect("timeout",  _fadein_type)
		fade_timer.connect("timeout",  Callable(_fadein_type).bind(formatted_text, color, type_time))
		fade_timer.start()


# if the word is tagged with a color, get its hex value without the alpha
func _get_color_from_tags(tagged_word: TaggedWord) -> String:
	var color: String
	for tag in tagged_word.opening_tags:
		if(tag.find("color") != -1):
			color = tag.split("#")[1]
			color = color.substr(0,6)
	return color


# get the alpha value of color tags and change it to max (ff)
func _recover_alpha_of_color_tag(tagged_word: TaggedWord) -> TaggedWord:
	var i: int
	while(i < tagged_word.opening_tags.size()):
		var tag: String = tagged_word.opening_tags[i]
		if(tag.find("color") != -1):
			var color_until_alpha = tag.substr(0, tag.length()-3)
			tag = color_until_alpha + "ff]"
			tagged_word.opening_tags[i] = tag
		i += 1
	
	return tagged_word


# get the alpha value of color tags and change it to 0
func _remove_alpha_of_color_tag(tagged_word: TaggedWord) -> TaggedWord:
	var i: int
	while(i < tagged_word.opening_tags.size()):
		var tag: String = tagged_word.opening_tags[i]
		if(tag.find("color") != -1):
			var color_until_alpha = tag.substr(0, tag.length()-3)
			tag = color_until_alpha + "00]"
			tagged_word.opening_tags[i] = tag
		i += 1
	
	return tagged_word


func clear_dialogue_label():
	# only clear if dialogue is not being typed (if it is, this is being called because the <continue> tag making other lines being read
	if(!script_reader.is_text_typing()):
		dialogue_label.text = ""


# replace ellipsis
func replace_ellipsis(text: String) -> String:
	text = text.replace("…", "...")
	return text

