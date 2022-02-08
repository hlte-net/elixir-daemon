# HLTE

Work-in-progress rewrite of the current `go` daemon in elixir, while also removing much of the cruft from an older, now-dead usage model.

Use [`tools/keygen`](https://github.com/hlte-net/tools/blob/main/keygen) to create an appropriate key file and get the hexadecimal representation needed for the extension's settings.

## Building

You'll need [Elixir 1.13]() or later.

In this directory, run:

```shell
$ mix deps.gets       # sources all the required dependencies
$ mix run --no-halt   # runs the application without exiting immediately
```