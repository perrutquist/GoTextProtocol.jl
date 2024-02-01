#!/usr/bin/env -S julia --quiet --startup-file=no --threads=auto

# Example of how to use GoTextProtocol.jl to implement a go engine.

# The below lines will cause julia to look for a Project.toml file in the directory
# where this script is found, and make sure that all dependencies are met.
using Pkg
Pkg.activate(@__DIR__) 
Pkg.instantiate()

using GoTextProtocol: gtp_repl, possible_moves, PASS, other_color, play_move!

# Evaluate the board, from the point of view of `color`, assuming that the other color is to play.
function score(board, color)
    # Let the score be minus the number of opponent stones, which will make the engine
    # prefer the move that captures the most stones.
    # (Taking territory into account is left as an excersise for the reader.)
    return -count(==(other_color(color)), board.board)
end

# To implement a Go engine, all we need a function that takes a board state and a color, 
# (plus some additional info) and returns the move that it decides to make.
function genmove(board, color, info)
    # Get a list of legal moves that are not filling own eyes
    moves = possible_moves(board, color)

    bestmove = PASS
    bestscore = score(board, color) # score that we'd get if we passed

    for m in moves
        b = deepcopy(board)
        play_move!(b, m, color)
        s = score(b, color)
        s += 0.1*randn() # Add a random number to introduce some variation.
        if s > bestscore
            bestmove = m
            bestscore = s
        end
    end
    return bestmove
end

# Run the GTP REPL on stdin/stdout, until it receives the "quit" command.
# Normally this will be used by a Go client, but it is also possible to run this from 
# the terminal, and simply type in GTP commands (for testing).
# The name and version given here will be communicated to the client if it asks for them.
gtp_repl(genmove, name="My Awesome Go Engine", version=v"0.1.0")
