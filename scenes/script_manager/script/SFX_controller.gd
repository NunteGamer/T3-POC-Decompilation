extends Node

@export var sfx_list: Node
@export var sfx_players: Array[AudioStreamPlayer2D]
var _sfx_players_record: Array[int]

func _play_sfx(stream: AudioStream, vol: float, pitch: float):
	var player: AudioStreamPlayer2D = _get_available_sfx_player()
	player.stream = stream
	player.volume_db = vol
	player.pitch_scale = pitch
	player.play()


func _get_available_sfx_player() -> AudioStreamPlayer2D:
	for i in sfx_players.size():
		if(!sfx_players[i].playing):
			_record_player(i)
			return sfx_players[i]
	
	# all players playing
	return sfx_players[_sfx_players_record[0]]


func _record_player(index: int):
	if(_sfx_players_record.has(index)):
		_sfx_players_record.erase(index)
	_sfx_players_record.append(index)
	if(_sfx_players_record.size() > sfx_players.size()):
		_sfx_players_record.remove_at(0)


func play_chara_move():
	var pitch: float = randf_range(0.8, 1.2)
	_play_sfx(sfx_list.chara_move, -5, pitch)

func play_chara_highlight():
	var pitch: float = randf_range(0.8, 1.2)
	_play_sfx(sfx_list.chara_highlight, 0, pitch)
