defmodule HLTE.HTTP.Route.GetHiliteMedia do
  require Logger

  def init(req, [headerName, data_path])
      when is_map_key(req.headers, headerName) and (req.method === "HEAD" or req.method === "GET") do
    HLTE.HTTP.calculate_body_hmac(req.path)
    |> auth_check(Map.get(req.headers, headerName), req, [headerName, data_path])
  end

  def init(req, state) do
    {:ok, :cowboy_req.reply(405, req), state}
  end

  def auth_check(calced_hmac, sent_hmac, req, [headerName, data_path])
      when sent_hmac === calced_hmac do
    # XXX: must check that the request timestamp isn't too much in the past, to close the reuse vector!!
    parse_bindings(req.bindings)
    |> handle_allowed(req, [headerName, data_path])
  end

  def auth_check(calced_hmac, sent_hmac, req, [headerName, data_path]) do
    Logger.critical("Unauthorized! #{req.method} #{req.path}")
    Logger.warn("#{calced_hmac} !== #{sent_hmac}")
    Logger.warn("Full request: #{inspect(req)}")
    {:ok, :cowboy_req.reply(403, req), [headerName, data_path]}
  end

  def handle_allowed([type, basename, hash, ts], req, [headerName, data_path]) do
    case metadata(data_path |> Path.expand(), type, hash, ts) do
      %{"headers" => headers} when is_map_key(headers, "content-type") ->
        IO.puts("cool!")
        [_type, subtype] = Map.get(headers, "content-type") |> String.split("/")
        full_path = Path.expand(Path.join([data_path, type, "#{basename}.#{subtype}"]))
        IO.puts("PATH #{full_path}")
        # FIX!
        stat = File.stat!(full_path)

        Map.take(headers, ["content-type", "content-length", "last-modified", "age"])
        |> Enum.to_list()
        |> Enum.reduce(req, fn {k, v}, acc_req ->
          :cowboy_req.set_resp_header(k, v, acc_req)
        end)
        |> success_reply(stat, full_path, [headerName, data_path])

      _ ->
        Logger.error("bad metadata!")
        not_found_reply(req, [headerName, data_path])
    end
  end

  def handle_allowed(:error, req, state) do
    Logger.error("bad bindings: #{inspect(req.bindings)}")
    {:ok, :cowboy_req.reply(400, req), state}
  end

  def success_reply(req_with_meta_headers, stat, full_path, [headerName, data_path])
      when req_with_meta_headers.method === "GET" do
    {:ok,
     :cowboy_req.reply(
       200,
       :cowboy_req.set_resp_body(
         {:sendfile, 0, stat.size, full_path},
         req_with_meta_headers
       )
     ), [headerName, data_path]}
  end

  def success_reply(req_with_meta_headers, _s, _fp, [headerName, data_path])
      when req_with_meta_headers.method === "HEAD" do
    {:ok, :cowboy_req.reply(204, req_with_meta_headers), [headerName, data_path]}
  end

  def not_found_reply(req, [headerName, data_path]) do
    {:ok, :cowboy_req.reply(404, req), [headerName, data_path]}
  end

  def parse_bindings(%{:hash => hash, :ts => ts, :type => "primary"}) do
    ["primary", "#{hash}-#{ts}", hash, ts]
  end

  def parse_bindings(%{:hash => hash, :ts => ts, :type => "secondary"}) do
    ["secondary", "#{hash}-#{ts}", hash, ts]
  end

  def parse_bindings(%{:hash => hash, :ts => ts}) do
    parse_bindings(%{:hash => hash, :ts => ts, :type => "primary"})
  end

  def parse_bindings(_) do
    :error
  end

  def metadata(path, type, hash, ts) do
    Jason.decode!(
      File.read!(Path.expand(Path.join([path, "metadata", "#{hash}-#{ts}.#{type}.json"])))
    )
  end
end
