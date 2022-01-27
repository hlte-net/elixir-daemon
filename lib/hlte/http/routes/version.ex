defmodule HLTE.HTTP.Route.Version do
  require Logger

  def init(req, opts) do
    {:cowboy_rest, req, opts}
  end

  def allowed_methods(req, state) do
    {["OPTIONS", "GET"], req, state}
  end

  def options(req, state) do
    {:ok, HLTE.HTTP.cors_preflight_options("GET", req), state}
  end

  def content_types_provided(req, state) do
    {[
       {"text/plain", :get_version}
     ], req, state}
  end

  def get_version(req, state) do
    {Application.fetch_env!(:hlte, :api_version),
     :cowboy_req.set_resp_header("Access-Control-Allow-Origin", "*", req), state}
  end
end
