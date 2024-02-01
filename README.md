# GoTextProtocol.jl

This Julia package implements a subset of the [Go Text Protocol (GTP), version 2](https://www.lysator.liu.se/~gunnar/gtp/gtp2-spec-draft2/gtp2-spec.html), as well as keeping track of the go board (captures, etc). (Here, "go" refers to the [board game](https://en.wikipedia.org/wiki/Go_(game)), not the programming language.)

If a go playing engine is written in Julia, then this package should make it easy to connect it to any [go client](https://senseis.xmp.net/?GoClient) that speaks the GTP protocol. That will allow it to play humans or other engines via a GUI or over the internet.

## Usage

All that is needed to create a go playing engine is to write a function `genmove(board, color, info)` that decides which move to make, given the `board` state and `color` to play (and some additional `info` like komi and time left.) This function is then passed to the `GoTextProtocol.gtp_repl` function, which implements the GTP protocol. This REPL can be used directly from the terminal (for testing), but most commonly it will be accessed by a go client that provides a more friendly user interface.

The file [example_engine.jl](./example_engine.jl) demonstrates how to write a Julia script that can be used by a go client. The go client will typically have an "add go engine" option in the settings, where the path to this script can be entered.

# Notes

* The aim of this package is not to provide a go playing engine. The example script is barely better than random play!
* I have only tested this with a single go client so far. Please file an issue if you encounter problems.
* At the moment, only the bare minimum of GTP commands are supported. PRs are welcome!

## Credit

This package is based on the [gtp Python package](https://github.com/jtauber/gtp) by James Tauber and on [Julia go board code](https://gist.github.com/GunnarFarneback/3373404) by by Gunnar Farnebäck.
