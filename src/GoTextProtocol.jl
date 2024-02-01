module GoTextProtocol

export gtp_repl

const default_name = "GoTextProtocol.jl"
const default_version = v"0.1.0"

const WHITE = -1
const EMPTY = 0
const BLACK = 1

const PASS = (0, 0)
const RESIGN = Val(:resign)

const MIN_BOARD_SIZE = 7
const MAX_BOARD_SIZE = 19

# Code that handles the board and stones (including captures, etc)
include("board.jl") 

# Code that handles the Go Text Protocol
include("protocol.jl") 

end
