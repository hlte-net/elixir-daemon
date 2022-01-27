defmodule HLTETest do
  use ExUnit.Case
  doctest HLTE.Application

  test "environment specific args are available in Application environment" do
    assert Application.fetch_env!(:hlte_daemon, :args)[:key_path] == "./test/test_keyfile"
  end

  test "opening permissions on test keyfile causes load failure" do
    expand_path = Path.expand(Application.fetch_env!(:hlte_daemon, :args)[:key_path])
    {:ok, %{mode: original_mode}} = File.stat(expand_path)
    File.chmod!(expand_path, 0o644)
    {:error, reason, ^expand_path} = HLTE.Application.load_key(expand_path)
    File.chmod!(expand_path, original_mode)
    assert true
  end

  test "can load test keyfile" do
    {:ok, key} = HLTE.Application.load_key(Application.fetch_env!(:hlte_daemon, :args)[:key_path])
    assert byte_size(key) == 4096
  end

  test "test keyfile contents are as expected" do
    {:ok, key} = HLTE.Application.load_key(Application.fetch_env!(:hlte_daemon, :args)[:key_path])
    hash = :crypto.hash(:sha256, key) |> :binary.encode_hex()
    assert hash == "01854DDEDC285DE6B39CC1DA6B8BDA00EF4FBDDC2BD1D46F16537AE34E572575"
  end
end
