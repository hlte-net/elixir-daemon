defmodule HLTE.HTTP do
  require Logger

  use Task

  def start_link(args), do: Task.start_link(__MODULE__, :run, [args])

  def run([listen_port, header_name, media_data_path]) when is_number(listen_port) do
    {:ok, _} =
      :cowboy.start_clear(
        :http,
        [{:port, listen_port}],
        %{:env => %{:dispatch => build_dispatch(header_name, media_data_path)}}
      )

    Logger.notice("HTTP listening on port #{listen_port}")

    :ok
  end

  def build_dispatch(header_name, media_data_path) do
    :cowboy_router.compile([
      # bind to all interfaces, a la "0.0.0.0"
      {:_,
       [
         # POST
         {"/", HLTE.HTTP.Route.PostHilite, [header_name]},
         {"/sns", HLTE.HTTP.Route.SNSIngest, []},

         # GET
         {"/version", HLTE.HTTP.Route.Version, []},
         {"/search", HLTE.HTTP.Route.Search, [header_name]},
         {"/:req_ts/:hash/:ts/[:type]", HLTE.HTTP.Route.GetHiliteMedia,
          [header_name, media_data_path]}
       ]}
    ])
  end

  @doc """
  Called by route modules to provide the requisite CORS headers in
  an OPTIONS pre-flight response.

  Returns a request with the appropriate headers set.
  """
  def cors_preflight_options(method, req, header_name) do
    r1 = :cowboy_req.set_resp_header("Access-Control-Allow-Methods", "#{method}, OPTIONS", req)
    r2 = :cowboy_req.set_resp_header("Access-Control-Allow-Origin", "*", r1)

    :cowboy_req.set_resp_header(
      "Access-Control-Allow-Headers",
      "Content-Type, content-type, #{header_name}",
      r2
    )
  end

  def cors_preflight_options(method, req) do
    :cowboy_req.set_resp_header(
      "Access-Control-Allow-Origin",
      "*",
      :cowboy_req.set_resp_header("Access-Control-Allow-Methods", "#{method}, OPTIONS", req)
    )
  end

  def calculate_body_hmac(bodyText) do
    :crypto.mac(:hmac, :sha256, :persistent_term.get(:key), bodyText)
    |> :binary.encode_hex()
    |> :string.lowercase()
  end
end
