# Go board logic adapted from https://gist.github.com/GunnarFarneback/3373404
# which is dervied from http://www.lysator.liu.se/~gunnar/gtp/brown-1.0.tar.gz 
# by Gunnar Farnebäck (MIT license)

# Function to find the opposite color.
other_color(color::Int) = WHITE + BLACK - color

# Offsets for the four directly adjacent neighbors. Used for looping.
const deltai = (-1, 1, 0, 0)
const deltaj = (0, 0, -1, 1)
neighbor(i::Int, j::Int, k::Int) = (i + deltai[k], j + deltaj[k])

struct Board
    size::Int

    # Board represented by a 1D array. The first board_size*board_size
    # elements are used. Vertices are indexed row by row, starting with 0
    # in the upper left corner.
    board::Matrix{Int}

    # Stones are linked together in a circular list for each string.
    next_stone::Matrix{Int}

    # Point which would be an illegal ko recapture.
    ko::Ref{Tuple{Int, Int}}
end

function Board(n::Int)
    Board(n, zeros(Int, n, n), zeros(Int, n, n), Ref((0,0)))
end

Base.getindex(board::Board, pos::Int) = board.board[pos]
Base.getindex(board::Board, i::Int, j::Int) = board.board[i, j]

# Functions to convert between 1D and 2D coordinates. The 2D coordinate
# (i, j) points to row i and column j, starting with (1,1) in the
# upper left corner.
POS(board::Board, i::Int, j::Int) = (j - 1) * board.size + i
IJ(board::Board, pos::Int) = (1 + mod((pos - 1), board.size), 1 + fld(pos - 1, board.size))

function new_board(::Board, size::Int)
    Board(size)
end

function clear!(board::Board)
    board.board .= EMPTY
    return board # clear! must return a board to the engine
end

function on_board(board::Board, i::Int, j::Int)
    1 ≤ i ≤ board.size && 1 ≤ j ≤ board.size
end

function legal_move(board::Board, (i, j)::Tuple{Int,Int}, color::Int)
    other = other_color(color)

    # Pass is always legal.
    if (i, j) == PASS
        return true
    end

    # Already occupied.
    if board[i, j] != EMPTY
        return false
    end

    # Illegal ko recapture. It is not illegal to fill the ko so we must
    # check the color of at least one neighbor.
    if (i, j) == board.ko[] && ((on_board(board, i - 1, j) && board[i-1, j] == other) || (on_board(board, i + 1, j) && board[i+1, j] == other))
        return false
    end

    true
end

# Does the string at (i, j) have any more liberty than the one at (libi, libj)?
function has_additional_liberty(board::Board, i::Int, j::Int, libi::Int, libj::Int)
    start = POS(board, i, j)
    pos = start
    while true
        (ai, aj) = IJ(board, pos)
        for k = 1:4
            (bi, bj) = neighbor(ai, aj, k)
            if on_board(board, bi, bj) && board[bi, bj] == EMPTY && (bi != libi || bj != libj)
                return true
            end
        end

        pos = board.next_stone[pos]
        if pos == start
            break
        end
    end

    false
end

# Does (ai, aj) provide a liberty for a stone at (i, j)?
function provides_liberty(board::Board, ai::Int, aj::Int, i::Int, j::Int, color::Int)
    # A vertex off the board does not provide a liberty.
    if !on_board(board, ai, aj)
        return false
    end

    # An empty vertex IS a liberty.
    if board[ai, aj] == EMPTY
        return true
    end

    # A friendly string provides a liberty to (i, j) if it currently
    # has more liberties than the one at (i, j).
    if board[ai, aj] == color
        return has_additional_liberty(board, ai, aj, i, j)
    end

    # An unfriendly string provides a liberty if and only if it is
    # captured, i.e. if it currently only has the liberty at (i, j).
    !has_additional_liberty(board, ai, aj, i, j)
end

# Is a move at ij suicide for color?
function suicide(board::Board, i::Int, j::Int, color::Int)
    for k = 1:4
        if provides_liberty(board, neighbor(i, j, k)..., i, j, color)
            return false
        end
    end
    true
end

# Remove a string from the board array. There is no need to modify
# the next_stone array since this only matters where there are
# stones present and the entire string is removed.
function remove_string!(board::Board, i::Int, j::Int)
    start = POS(board, i, j)
    pos = start
    removed = 0
    while true
        board.board[pos] = EMPTY
        removed += 1
        pos = board.next_stone[pos]
        if pos == start
            break
        end
    end
    removed
end

# Do two vertices belong to the same string? It is required that both
# pos1 and pos2 point to vertices with stones.
function same_string(board::Board, pos1::Int, pos2::Int)
    pos = pos1
    while true
        if pos == pos2
            return true
        end
        pos = board.next_stone[pos]
        if pos == pos1
            break
        end
    end
    false
end

# Play at (i, j) for color. No legality check is done here. We need
# to properly update the board array, the next_stone array, and the
# ko point.
function play_move!(board::Board, (i, j)::Tuple{Int,Int}, color::Int)
    pos = POS(board, i, j)
    captured_stones = 0

    # Reset the ko point.
    board.ko[] = (0, 0)

    # Nothing more happens if the move was a pass.
    if (i, j) == PASS
        return
    end

    # If the move is a suicide we only need to remove the adjacent
    # friendly stones.
    if suicide(board, i, j, color)
        for k = 1:4
            (ai, aj) = neighbor(i, j, k)
            if on_board(board, ai, aj) && board[ai, aj] == color
                remove_string!(board, ai, aj)
            end
        end
        return
    end

    # Not suicide. Remove captured opponent strings.
    for k = 1:4
        (ai, aj) = neighbor(i, j, k)
        if on_board(board, ai, aj) && board[ai, aj] == other_color(color) && !has_additional_liberty(board, ai, aj, i, j)
            captured_stones += remove_string!(board, ai, aj)
        end
    end

    # Put down the new stone. Initially build a single stone string by
    # setting next_stone[pos] pointing to itself.
    board.board[pos] = color
    board.next_stone[pos] = pos

    # If we have friendly neighbor strings we need to link the strings
    # together.
    for k = 1:4
        (ai, aj) = neighbor(i, j, k)
        pos2 = POS(board, ai, aj)
        # Make sure that the stones are not already linked together. This
        # may happen if the same string neighbors the new stone in more
        # than one direction.
        if on_board(board, ai, aj) && board[pos2] == color && !same_string(board, pos, pos2)
            # The strings are linked together simply by swapping the the
            # next_stone pointers.
            (board.next_stone[pos], board.next_stone[pos2]) = (board.next_stone[pos2], board.next_stone[pos])
        end
    end

    # If we have captured exactly one stone and the new string is a
    # single stone it may have been a ko capture.
    if captured_stones == 1 && board.next_stone[pos] == pos
        # Check whether the new string has exactly one liberty. If so it
        # would be an illegal ko capture to play there immediately. We
        # know that there must be a liberty immediately adjacent to the
        # new stone since we captured one stone.
        for k = 1:4
            (ai, aj) = neighbor(i, j, k)
            if on_board(board, ai, aj) && board[ai, aj] == EMPTY
                if !has_additional_liberty(board, i, j, ai, aj)
                    board.ko[] = (ai, aj)
                end
                break
            end
        end
    end
end

# Generate a list of moves that are legal and not filling eyes.
function possible_moves(board::Board, color::Int)
    moves = Tuple{Int, Int}[]
    for ai = 1:board.size, aj = 1:board.size
        # Consider moving at (ai, aj) if it is legal and not suicide.
        if legal_move(board, (ai, aj), color) && !suicide(board, ai, aj, color)
            # Require the move not to be suicide for the opponent, because that might be filling an eye.
            if !suicide(board, ai, aj, other_color(color))
                push!(moves, (ai, aj))
            else
                # ...however, if the move captures at least one stone, then it is not filling an eye.
                for k = 1:4
                    (bi, bj) = neighbor(ai, aj, k)
                    if on_board(board, bi, bj) && board[bi, bj] == other_color(color)
                        push!(moves, (ai, aj))
                        break
                    end
                end
            end
        end
    end
    return moves
end

# Generate a move.
function random_move(board::Board, color::Int, info=(;))
    moves = possible_moves(board, color)

    isempty(moves) && return (0, 0) # pass if there is no other legal move.

    # Choose one of the considered moves randomly with uniform distribution. 
    return rand(moves)
end

