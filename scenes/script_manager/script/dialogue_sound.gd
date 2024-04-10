extends AudioStreamPlayer2D

@export var dialogue_sound_1: AudioStream

var playing_talk: bool
var remaining_letters: int
var sounds_per_word: int = 5

var await_timer: SceneTreeTimer

func stop_talk():
	playing_talk = false
	if(await_timer != null):
		await_timer.set_time_left(0)


# play one sound per 2 letters
func play_talk_letters(cooldown: float):
	# if already talking, don't double the sounds
	if(playing_talk): return
	
	playing_talk = true
	self.stream = dialogue_sound_1
	_do_play_talk_letters(cooldown * 2)


func _do_play_talk_letters(cooldown: float):
	self.pitch_scale = randf_range(0.9, 1.1)
	self.play()
	if(playing_talk):
		await_timer = get_tree().create_timer(cooldown)
		await await_timer.timeout
		if(!playing_talk): return
		_do_play_talk_letters(cooldown)


# play sounds_per_word per word
func play_talk_words(word_duration: float):
	# if already talking, don't double the sounds
	if(playing_talk): return
	
	playing_talk = true
	self.stream = dialogue_sound_1
	var counter_to_silence: int = sounds_per_word
	var word_talk_cooldown: float
	word_talk_cooldown = word_duration/sounds_per_word
	_do_play_talk_words(word_duration, word_talk_cooldown, counter_to_silence)


func _do_play_talk_words(word_duration: float, word_talk_cooldown: float, counter_to_silence: int):
	if(counter_to_silence <= 0):
		playing_talk = false
		return
	self.pitch_scale = randf_range(0.9, 1.1)
	self.play()
	counter_to_silence -= 1
	await get_tree().create_timer(word_talk_cooldown).timeout
	_do_play_talk_words(word_duration, word_talk_cooldown, counter_to_silence)


# play one sound per 2 letters, spacing them according to word_duration
func play_talk_dynamic_word(letters: int, word_duration: float):
	# if already talking, don't double the sounds
	if(playing_talk): return
	
	playing_talk = true
	self.stream = dialogue_sound_1
	var cooldown: float = (word_duration * 0.8)/letters
	cooldown *= 2
	_do_play_talk_dynamic_word(letters, cooldown)


func _do_play_talk_dynamic_word(_remaining_letters: int, cooldown: float):
	self.pitch_scale = randf_range(0.9, 1.1)
	self.play()
	_remaining_letters -= 1
	if(_remaining_letters > 0):
		await get_tree().create_timer(cooldown).timeout
		_do_play_talk_dynamic_word(_remaining_letters, cooldown)
	else:
		playing_talk = false
