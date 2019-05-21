import board
import lib.pycom

my_board = board.Board(lib.pycom.get_components())
my_board.run()