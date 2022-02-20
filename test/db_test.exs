defmodule HLTE.DB.Test do
  use ExUnit.Case

  test "simple init, persist, search" do
    db_path = Application.fetch_env!(:hlte, :db_path)
    Path.expand(db_path) |> File.rm()
    :ok = HLTE.DB.init(db_path)

    {:ok, timestamp, -42} = HLTE.DB.persist(%{"uri" => "foo://bar", "data" => "foobar"}, "abcd")
    assert System.os_time(:nanosecond) >= timestamp

    {[
       %{
         "annotation" => nil,
         "checksum" => "abcd",
         "hilite" => "foobar",
         "primaryURI" => "foo://bar",
         "secondaryURI" => nil,
         "timestamp" => timestamp
       }
     ], runtime} = HLTE.DB.search("foo", 1)

    {parsed_ts, ""} = Integer.parse(timestamp)
    assert System.os_time(:nanosecond) >= parsed_ts
    assert runtime < 100
  end
end
