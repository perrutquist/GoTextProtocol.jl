# Go Text Protocol engine, based on the "gtp" Python package by James Tauber (MIT license)
# https://github.com/jtauber/gtp 

abstract type AbstractGTPengine end

struct GTPengine{F, B} <: AbstractGTPengine
    genmove::F
    board::Ref{B}
    size::Ref{Int}
    komi::Ref{Float64}
    time_settings::Ref{Tuple{Float64, Float64, Int}}
    time_left_black::Ref{Tuple{Float64, Int}}
    time_left_white::Ref{Tuple{Float64, Int}}
    name::String
    version::VersionNumber
    disconnect::Ref{Bool}
end

function GTPengine(genmove=random_move; board=Board(19), komi=6.5, name=default_name, version=default_version) 
    GTPengine(genmove, Ref(board), Ref(board.size), Ref(komi), Ref((0.0, 0.0, 0)), Ref((0.0, 0)), Ref((0.0, 0)), name, version, Ref(false))
end

# To add a new command: include it in this list, 
# and write a corresponding cmd method.
const known_commands = (
    :boardsize,
    :clear_board,
    :genmove,
    :known_command,
    :komi,
    :list_commands,
    :name,
    :play,
    :protocol_version,
    :quit,
    :time_settings,
    :time_left,    
    :version,
    )

function pre_engine(s)
    s = replace(s, r"[^\t\n -~]" => "")
    s = split(s, "#")[1]
    s = replace(s, "\t" => " ")
    return s
end

function pre_controller(s)
    s = replace(s, r"[^\t\n -~]" => "")
    s = replace(s, "\t" => " ")
    return s
end

gtp_boolean(b) = b ? "true" : "false"

gtp_list(l) = join(l, "\n")

function gtp_color(color)
    color == BLACK && return "B"
    color == WHITE && return "W"
    throw(ArgumentError("Unknown color"))
end

function gtp_vertex(vertex)
    if vertex == PASS
        return "pass"
    elseif vertex == RESIGN
        return "resign"
    else
        x, y = vertex
        1 ≤ x ≤ MAX_BOARD_SIZE || throw(ArgumentError("Vertex out of bounds")) 
        1 ≤ y ≤ MAX_BOARD_SIZE || throw(ArgumentError("Vertex out of bounds")) 
        return "ABCDEFGHJKLMNOPQRSTYVWYZ"[x] * string(y) # Note: no 'I' in the coordinates
    end
end

gtp_move(color, vertex) = string(gtp_color(color), " ", gtp_vertex(vertex))

function parse_message(message)
    message = strip(pre_engine(message))
    first, rest = (split(message, " ", limit=2)..., nothing)[1:2]
    if !isempty(first) && all(isdigit, first)
        message_id = parse(Int, first)
        if rest !== nothing
            command, arguments = (split(rest, " ", limit=2)..., nothing)[1:2]
        else
            command, arguments = nothing, nothing
        end
    else
        message_id = nothing
        command, arguments = first, rest
    end

    return (message_id, command, arguments)
end

function parse_color(color)
    color = lowercase(color)
    if color in ["b", "black"]
        return BLACK
    elseif color in ["w", "white"]
        return WHITE
    else
        return nothing
    end
end

function parse_vertex(vertex_string)
    isnothing(vertex_string) &&  return nothing
    vertex_string = lowercase(vertex_string)
    if vertex_string == "pass"
        return PASS
    elseif length(vertex_string) > 1
        x = findfirst(isequal(vertex_string[1]), "abcdefghjklmnopqrstuvwxyz")
        if isnothing(x)
            return nothing
        end
        if all(isdigit, vertex_string[2:end])
            y = parse(Int, vertex_string[2:end])
        else
            return nothing
        end
    else
        return nothing
    end
    return (x, y)
end

function parse_move(move_string)
    color_string, vertex_string = (split(move_string, " ")..., nothing)[1:2]
    color = parse_color(color_string)
    if isnothing(color)
        return nothing
    end
    vertex = parse_vertex(vertex_string)
    if isnothing(vertex)
        return nothing
    end

    return (color, vertex)
end

function format_success(message_id, response=nothing)
    if response !== nothing
        response = " $response"
    else
        response = ""
    end
    if message_id !== nothing
        return "=$message_id$response\n\n"
    else
        return "=$response\n\n"
    end
end

function format_error(message_id, response)
    if response !== nothing
        response = " $response"
    else
        response = ""
    end
    if message_id !== nothing
        return "?$message_id$response\n\n"
    else
        return "?$response\n\n"
    end
end

function send(engine, message)
    message_id, command, arguments = parse_message(message)
    if Symbol(command) in known_commands
        try
            return format_success(message_id, cmd(Val(Symbol(command)), engine, arguments))
        catch e
            return format_error(message_id, e isa ArgumentError ? e.msg : string(e))
        end
    else
        return format_error(message_id, string("unknown command: ", command, " ", something(arguments, "")))
    end
end

function vertex_in_range(engine, vertex)
    vertex == PASS || all(1 .≤ vertex .≤ engine.size[])
end

function cmd(::Val{:protocol_version}, engine, arguments)
    return 2
end

function cmd(::Val{:name}, engine, arguments)
    return engine.name
end

function cmd(::Val{:version}, engine, arguments)
    return engine.version
end

function cmd(::Val{:known_command}, engine, arguments)
    return gtp_boolean(Symbol(arguments) in known_commands)
end

function cmd(::Val{:list_commands}, engine, arguments)
    return gtp_list(known_commands)
end

function cmd(::Val{:quit}, engine, arguments)
    engine.disconnect[] = true
    return nothing
end

function cmd(::Val{:boardsize}, engine, arguments)
    if all(isdigit, arguments)
        size = parse(Int, arguments)
        if MIN_BOARD_SIZE <= size <= MAX_BOARD_SIZE
            engine.size[] = size
            engine.board[] = new_board(engine.board[], size)
        else
            throw(ArgumentError("unacceptable size"))
        end
    else
        throw(ArgumentError("non digit size"))
    end
    return nothing
end

function cmd(::Val{:clear_board}, engine, arguments)
    engine.board[] = clear!(engine.board[])
    return nothing
end

function cmd(::Val{:komi}, engine, arguments)
    komi = parse(Float64, arguments)
    engine.komi[] = komi
    return nothing
end

function cmd(::Val{:time_settings}, engine, arguments)
    time_settings = parse.((Float64, Float64, Int), Tuple(split(arguments, " ")))
    engine.time_settings[] = time_settings
    return nothing
end

function cmd(::Val{:time_left}, engine, arguments)
    args = split(arguments, " ")
    time_left = parse.((Float64, Int), (args[2], args[3]))
    if parse_color(args[1]) == BLACK
        engine.time_left_black[] = time_left
    elseif parse_color(args[1]) == WHITE
            engine.time_left_white[] = time_left
    end
    return nothing
end

function cmd(::Val{:play}, engine, arguments)
    move = parse_move(arguments)
    isnothing(move) && throw(ArgumentError("illegal move"))
    color, vertex = move
    vertex_in_range(engine, vertex) || throw(ArgumentError("move is outside the board"))
    legal_move(engine.board[], vertex, color) || throw(ArgumentError("illegal move"))

    play_move!(engine.board[], vertex, color)
    return nothing
end

function cmd(::Val{:genmove}, engine, arguments)
    c = parse_color(arguments)
    isnothing(c) && throw(ArgumentError("unknown player: $arguments"))
    info = (komi=engine.komi[], 
            time_settings=engine.time_settings[], 
            time_left_black=engine.time_left_black[],
            time_left=engine.time_left_white[]
            )
    move = engine.genmove(engine.board[], c, info)
    play_move!(engine.board[], move, c)
    return gtp_vertex(move)
end

"""
gtp_repl(genmove) runs a read-execute-print-loop (REPL) implementing the Go Text Protocol,
which calls the user-provided `genmove(board, color, info)` when asked to generate a move.

Go clients that connect to a Julia script will typically expect that script to start
a REPL on stdin/stdout, which is the default behaviour for `gtp_repl`. Alternative input/output
streams can be specified via the 'input' and 'output' keyword arguments.

The `name` and `version` keyword arguments can be used set the name and version given that
are communicated to the client if it asks for them.
"""
function gtp_repl(genmove; input=stdin, output=stdout, kwargs...)
    engine = GTPengine(genmove; kwargs...)
    gtp_repl(engine; input, output)
end

function gtp_repl(engine::GTPengine; input=stdin, output=stdout)
    while(!engine.disconnect[])
        c = readline(input)
        r = send(engine, c)
        print(output, r)
    end
end
