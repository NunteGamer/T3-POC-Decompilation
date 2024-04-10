class_name SquareStats

var wins_x: int = 0
var wins_o: int = 0
var ties: int = 0
var min_moves_to_win_x: int = 99
var min_moves_to_win_o: int = 99
var min_moves_to_tie: int = 99
var max_moves_to_win_x: int = 0
var max_moves_to_win_o: int = 0
var max_moves_to_tie: int = 0
var potential_forks_x: int = 0
var potential_forks_o: int = 0
var forced_forks_x: int = 0
var forced_forks_o: int = 0


func print_simple_win_stats():
	print("wins_x: " + str(wins_x))
	print("wins_o: " + str(wins_o))
	print("ties: " + str(ties))


func print_win_stats():
	print("wins_x: " + str(wins_x))
	print("min_moves_to_win_x: " + str(min_moves_to_win_x))
	print("max_moves_to_win_x: " + str(max_moves_to_win_x))
	print("wins_o: " + str(wins_o))
	print("min_moves_to_win_o: " + str(min_moves_to_win_o))
	print("max_moves_to_win_o: " + str(max_moves_to_win_o))
	print("ties: " + str(ties))
	print("min_moves_to_tie: " + str(min_moves_to_tie))
	print("max_moves_to_tie: " + str(max_moves_to_tie))
	

func print_fork_stats():
	print("potential_forks_x: " + str(potential_forks_x))
	print("potential_forks_o: " + str(potential_forks_o))
	print("forced_forks_x: " + str(forced_forks_x))
	print("forced_forks_o: " + str(forced_forks_o))
