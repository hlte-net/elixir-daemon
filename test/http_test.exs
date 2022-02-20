defmodule HLTE.HTTP.Test do
  use ExUnit.Case

  test "calculate_body_hmac" do
    :persistent_term.put(:key, "012345")
    calced = HLTE.HTTP.calculate_body_hmac("foobar")
    assert calced == "0e64e82d19c0941bd4f8552f915ec04c43917e491c16f273af550b7c6c77af7b"
  end

  test "cors_preflight_options/2" do
    %{
      resp_headers: %{
        "Access-Control-Allow-Methods" => "GET, OPTIONS",
        "Access-Control-Allow-Origin" => "*"
      }
    } = HLTE.HTTP.cors_preflight_options("GET", %{})
  end

  test "cors_preflight_options/3" do
    %{
      resp_headers: %{
        "Access-Control-Allow-Headers" => "Content-Type, content-type, x-hlte",
        "Access-Control-Allow-Methods" => "GET, OPTIONS",
        "Access-Control-Allow-Origin" => "*"
      }
    } = HLTE.HTTP.cors_preflight_options("GET", %{}, "x-hlte")
  end

  test "build_dispatch/2" do
    [
      {:_, [],
       [
         {[], [], HLTE.HTTP.Route.PostHilite, ["x-hlte"]},
         {["sns"], [], HLTE.HTTP.Route.SNSIngest, []},
         {["version"], [], HLTE.HTTP.Route.Version, []},
         {["search"], [], HLTE.HTTP.Route.Search, ["x-hlte"]},
         {[:req_ts, :hash, :ts], [], HLTE.HTTP.Route.GetHiliteMedia, ["x-hlte", "./"]},
         {[:req_ts, :hash, :ts, :type], [], HLTE.HTTP.Route.GetHiliteMedia, ["x-hlte", "./"]}
       ]}
    ] = HLTE.HTTP.build_dispatch("x-hlte", "./")
  end
end
