using GoTextProtocol
using GoTextProtocol: GTPengine, pre_engine, pre_controller, parse_message, parse_move, parse_vertex, parse_color,
           gtp_boolean, gtp_list, gtp_color, gtp_vertex, gtp_move, send,
           WHITE, BLACK, PASS, RESIGN
using Test

@testset "PreProcessingTest" begin
    @test pre_engine("foo\rbar") == "foobar"
    @test pre_engine("foo\nbar") == "foo\nbar"
    @test pre_engine("foo\tbar") == "foo bar"
    @test pre_engine("foo # bar") == "foo "
    
    @test pre_controller("foo\rbar") == "foobar"
    @test pre_controller("foo\nbar") == "foo\nbar"
    @test pre_controller("foo\tbar") == "foo bar"
end

@testset "ParseTest" begin
    @test parse_message("foo") == (nothing, "foo", nothing)
    @test parse_message("foo bar") == (nothing, "foo", "bar")
    @test parse_message("1 foo") == (1, "foo", nothing)
    @test parse_message("1 foo bar") == (1, "foo", "bar")
    @test parse_message("1") == (1, nothing, nothing)
    @test parse_message("") == (nothing, "", nothing)
    @test parse_message(" ") == (nothing, "", nothing)

    @test parse_color("B") == BLACK
    @test parse_vertex("D4") == (4, 4)
    @test parse_move("B D4") == (BLACK, (4, 4))

    @test isnothing(parse_move("C X"))
    @test isnothing(parse_move("B 55"))
    @test isnothing(parse_move("B dd"))
    @test isnothing(parse_move("B X"))
    @test isnothing(parse_move("B"))

    @test parse_move("WHITE q16 XXX") == (WHITE, (16, 16))
    @test parse_move("black pass") == (BLACK, PASS)
end

@testset "FormatTest" begin
    @test gtp_boolean(true) == "true"
    @test gtp_boolean(false) == "false"

    @test gtp_list(["foo", "bar"]) == "foo\nbar"

    @test gtp_color(BLACK) == "B"
    @test gtp_color(WHITE) == "W"

    @test gtp_vertex((4, 4)) == "D4"
    @test gtp_vertex((16, 16)) == "Q16"
    @test gtp_vertex(PASS) == "pass"
    @test gtp_vertex(RESIGN) == "resign"

    @test gtp_move(BLACK, (3, 2)) == "B C2"
end

@testset "CommandsTest" begin
    engine = GTPengine(Returns(PASS))

    @testset "admin_commands" begin
        # Some of the error responses are not exactly according to the specification,
        # in order to provide more information and help with debugging.
        response = send(engine, "foo\n")
        @test response == "? unknown command: foo \n\n"

        response = send(engine, "protocol_version\n")
        @test response == "= 2\n\n"
        response = send(engine, "1 protocol_version\n")
        @test response == "=1 2\n\n"

        response = send(engine, "2 name\n")
        @test response == "=2 GoTextProtocol.jl\n\n"

        response = send(engine, "3 version\n")
        @test response == "=3 0.1.0\n\n"

        response = send(engine, "4 known_command name\n")
        @test response == "=4 true\n\n"
        response = send(engine, "5 known_command foo\n")
        @test response == "=5 false\n\n"

        response = send(engine, "6 list_commands\n")
        @test response == "=6 boardsize\nclear_board\ngenmove\nknown_command\nkomi\nlist_commands\nname\nplay\nprotocol_version\nquit\ntime_settings\ntime_left\nversion\n\n"

        response = send(engine, "99 quit\n")
        @test response == "=99\n\n"
    end

    @testset "core_play_commands" begin
        response = send(engine, "7 boardsize 100")
        @test response == "?7 unacceptable size\n\n"
        response = send(engine, "8 boardsize 19")
        @test response == "=8\n\n"
        response = send(engine, "9 boardsize foo")
        @test response == "?9 non digit size\n\n"
    
        response = send(engine, "9 clear_board")
        @test response == "=9\n\n"
    
        response = send(engine, "10 komi 6.5")
        @test response == "=10\n\n"
        response = send(engine, "11 komi foo")
        @test response == "?11 cannot parse \"foo\" as Float64\n\n"
    end
    
    @testset "core_play" begin
        response = send(engine, "12 play black D4")
        @test response == "=12\n\n"
    
        response = send(engine, "13 genmove white")
        # GTPengine(Returns(PASS)) will always return this
        @test response == "=13 pass\n\n"
    
        response = send(engine, "14 play black Z25")
        @test response == "?14 move is outside the board\n\n"
    
        response = send(engine, "15 play white D4")
        @test response == "?15 illegal move\n\n"
    
        response = send(engine, "16 play black pass")
        @test response == "=16\n\n"
    
        response = send(engine, "17 genmove orange")
        @test response == "?17 unknown player: orange\n\n"
    end
end
