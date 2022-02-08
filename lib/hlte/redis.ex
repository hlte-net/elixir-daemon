defmodule HLTE.Redis do
  @moduledoc """
  Manages connection to Redis
  """

  require Logger

  @joiner_char ":"

  def post_persistence_work(rxTime, hmac, %{"uri" => uri, "secondaryURI" => suri})
      when is_integer(rxTime) do
    {:ok, conn} = new_conn()

    {:ok, entryID} =
      Redix.command(conn, [
        "XADD",
        key(["persistence"]),
        "*",
        "checksum",
        hmac,
        "timestamp",
        rxTime,
        "primaryURI",
        uri,
        "secondaryURI",
        suri
      ])

    Redix.stop(conn)
    entryID
  end

  defp key_prefix() do
    case :persistent_term.get(:key_prefix, nil) do
      nil ->
        key_hash = :persistent_term.get(:key_hash)

        key_prefix =
          Enum.join(
            [
              "hlte",
              Application.fetch_env!(:hlte, :api_version),
              String.slice(key_hash, 0..8) <>
                "-" <>
                String.slice(key_hash, String.length(key_hash) - 8, String.length(key_hash))
            ],
            @joiner_char
          )

        :persistent_term.put(:key_prefix, key_prefix)
        Logger.notice("Set redis key prefix to \"#{key_prefix}\"")
        key_prefix

      cached_prefix ->
        cached_prefix
    end
  end

  defp key(suffixList), do: Enum.join(Enum.concat([key_prefix()], suffixList), @joiner_char)

  defp new_conn(), do: Redix.start_link(Application.fetch_env!(:hlte, :redis_url))
end
