defmodule HLTE.Test do
  use ExUnit.Case

  setup do
    expand_path = Path.expand(Application.fetch_env!(:hlte, :key_path))
    File.chmod!(expand_path, 0o400)
  end

  test "environment specific args are available in Application environment" do
    assert Application.fetch_env!(:hlte, :key_path) == "./test/test_keyfile"
  end

  test "opening permissions on test keyfile causes load failure" do
    expand_path = Path.expand(Application.fetch_env!(:hlte, :key_path))
    {:ok, %{mode: original_mode}} = File.stat(expand_path)
    File.chmod!(expand_path, 0o644)
    {:error, _reason, ^expand_path} = HLTE.Application.load_key(expand_path)
    File.chmod!(expand_path, original_mode)
  end

  test "can load test keyfile" do
    {:ok, key} = HLTE.Application.load_key(Application.fetch_env!(:hlte, :key_path))
    assert byte_size(key) == 4096
  end

  test "test keyfile contents are as expected" do
    {:ok, key} = HLTE.Application.load_key(Application.fetch_env!(:hlte, :key_path))
    hash = :crypto.hash(:sha256, key) |> :binary.encode_hex()
    assert hash == "01854DDEDC285DE6B39CC1DA6B8BDA00EF4FBDDC2BD1D46F16537AE34E572575"
  end

  test "HLTE.Redis.key_prefix/0" do
    "hlte:20220126:01854dded..4e572575" = HLTE.Redis.key_prefix()
  end
end
