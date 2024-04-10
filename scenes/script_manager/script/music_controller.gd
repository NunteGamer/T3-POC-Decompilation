extends Node

@export var _print_debug: bool
@export var music_list: Node
@export var music_player1: AudioStreamPlayer2D
@export var music_player2: AudioStreamPlayer2D

const _fade_duration: float = 2

var _tween: Tween
var _tween_fadeout: Tween
var _tween_fadein: Tween

var _player_is_fadingout: Array[bool]

var _null_signal: Signal

func parse_music(keywords: PackedStringArray):
	match keywords[0]:
		"fadeout":
			_manage_fadeout()
			return
		"stop":
			_manage_stop()
			return
		"pause":
			_manage_pause()
			return
		"resume":
			_manage_resume()
			return
	
	# music name is included
	var music: AudioResource = music_list.get_music(keywords[0])
	if(music == null):
		if(_print_debug): print("ERROR: MusicController: No music '" + keywords[0] + "' on music list.")
		return
	
	var transition: String = "cut"
	if(keywords.size() > 1):
		transition = keywords[1]
	
	match transition:
		"cut":
			_manage_cut_transition(music)
		"fade":
			_manage_fade_transition(music)
		"fadein":
			_manage_fadein_transition(music)


func _manage_cut_transition(music: AudioResource):
	_fade_active_player(0.1)
	_play_music(music)


func _manage_fade_transition(music: AudioResource):
	var on_music_finished_fading: Signal = _fade_active_player(_fade_duration)
	on_music_finished_fading.connect(Callable(_play_music).bind(music))


func _manage_fadein_transition(music: AudioResource):
	var on_music_finished_fading: Signal = _fade_active_player(_fade_duration)
	on_music_finished_fading.connect(Callable(_fadein).bind(music))


func _fadein(music: AudioResource):
	var free_player: AudioStreamPlayer2D = _get_music_player(true)[0]
	free_player.stream = music.file
	free_player.volume_db = -80
	free_player.play()
	
	if(_tween_fadein == null || !_tween_fadein.is_running()):
		_tween_fadein = create_tween()
	else:
		_tween_fadein.set_parallel(true)
	_tween_fadein.tween_property(free_player, "volume_db", music.volume, _fade_duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	if(_print_debug): print("MusicController: Fading in music '" + music.name + "'")

func _play_music(music: AudioResource):
	var free_player: AudioStreamPlayer2D = _get_music_player(true)[0]
	print("free_player: " + free_player.name) #todelete
	free_player.stream = music.file
	free_player.volume_db = music.volume
	free_player.play()
	
	if(_print_debug): print("MusicController: Playing music '" + music.name + "'")


func _manage_fadeout():
	var active_players: Array[AudioStreamPlayer2D] = _get_music_player(false)
	
	for active_player in active_players:
		if(_tween_fadeout != null && _tween_fadeout.is_running):
			_tween_fadeout.set_parallel(true)
		else:
			_tween_fadeout = create_tween()
		_tween_fadeout.tween_property(active_player, "volume_db", -80, _fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _manage_stop():
	var active_players: Array[AudioStreamPlayer2D] = _get_music_player(false)
	
	for active_player in active_players:
		active_player.stop()


func _manage_pause():
	var active_players: Array[AudioStreamPlayer2D] = _get_music_player(false)
	
	for active_player in active_players:
		active_player.stream_paused = true


func _manage_resume():
	if(music_player1.stream_paused == true):
		music_player1.stream_paused = false
	if(music_player2.stream_paused == true):
		music_player2.stream_paused = false


func _fade_active_player(duration: float) -> Signal:
	var active_players: Array[AudioStreamPlayer2D] = _get_music_player(false)
	
	for active_player in active_players:
		print(active_player.name) #todelete
		if(_tween != null && _tween.is_running()):
			_tween.set_parallel(true)
		else:
			_tween = create_tween()
		_tween.tween_property(active_player, "volume_db", -80, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.connect("finished", Callable(_stop_player).bind(active_player))
	if(_tween == null):
		emit_null_signal.call_deferred()
		return _null_signal
	return _tween.finished


func _stop_player(player: AudioStreamPlayer2D):
	player.stop()


func _get_music_player(free: bool) -> Array[AudioStreamPlayer2D]:
	var players: Array[AudioStreamPlayer2D]
	if(!free):
		if(music_player1.playing):
			players.append(music_player1)
		if(music_player2.playing):
			players.append(music_player2)
	elif(free):
		if(!music_player1.playing):
			players.append(music_player1)
		if(!music_player2.playing):
			players.append(music_player2)
		if(players.size() == 0):
			players.append(music_player1)
			if(_print_debug): print("MusicController: No free players. Overwriting music_player_1")
		
	return players


func emit_null_signal():
	_null_signal.emit()
