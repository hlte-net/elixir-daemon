# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands
- `mix deps.get` - Install dependencies
- `mix compile` - Compile the project
- `mix run --no-halt` - Run the application
- `mix format` - Format code
- `mix test` - Run all tests
- `mix test test/specific_test.exs` - Run a specific test file
- `mix test test/specific_test.exs:42` - Run a specific test on line 42
- `mix backfill_tags` - Run custom task to backfill tags database

## Code Style Guidelines
- Use 2-space indentation
- Required module attributes: `@moduledoc`, `@impl` for callbacks
- Keep functions small and focused
- Put imports at the top, followed by `alias` and `require`
- Prefer pattern matching over conditionals
- Use appropriate logging levels (`Logger.notice`, `Logger.emergency`)
- Group related functions together
- Use `fe/1` pattern for `Application.fetch_env!` calls
- Follow standard Elixir naming conventions (snake_case)
- Use proper error tuple returns: `{:error, reason, context}`
- Document public API functions and custom mix tasks