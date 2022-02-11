# HLTE

Work-in-progress rewrite of the current `go` daemon in elixir, while also removing much of the cruft from an older, now-dead usage model.

Use [`tools/keygen`](https://github.com/hlte-net/tools/blob/main/keygen) to create an appropriate key file and get the hexadecimal representation needed for the extension's settings.

## Building & Running

You'll need [Elixir 1.13]() or later.

### Runtime configuration

Via the following environment variables:

* `HLTE_REDIS_URL`: Redis server connection URL
* `HLTE_SNS_WHITELIST_JSON`: SNS ingest email whitelist as JSON
* `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`: AWS credentials for S3 email lookup

In this directory, run:

```shell
$ mix deps.gets       # sources all the required dependencies
$ mix run --no-halt   # runs the application without exiting immediately
```