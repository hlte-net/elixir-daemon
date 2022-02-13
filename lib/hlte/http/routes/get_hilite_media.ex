defmodule HLTE.HTTP.Route.GetHiliteMedia do
  require Logger

  def init(req, [header_name, data_path])
      when is_map_key(req.headers, header_name) and
             (req.method === "HEAD" or req.method === "GET") do
    HLTE.HTTP.calculate_body_hmac(req.path)
    |> auth_check(Map.get(req.headers, header_name), req, [header_name, data_path])
  end

  def init(req, state) do
    {:ok, :cowboy_req.reply(405, req), state}
  end

  def auth_check(calced_hmac, sent_hmac, req, [header_name, data_path])
      when sent_hmac === calced_hmac do
    # XXX: must check that the request timestamp isn't too much in the past, to close the reuse vector!!
    parse_bindings(req.bindings)
    |> handle_allowed(req, [header_name, data_path])
  end

  def auth_check(calced_hmac, _sent_hmac, req, [header_name, data_path]) do
    HLTE.LoggingUtil.log_unauthorized_req(req, calced_hmac, header_name)
    {:ok, :cowboy_req.reply(403, req), [header_name, data_path]}
  end

  def handle_allowed([type, basename, hash, ts], req, [header_name, data_path]) do
    case metadata_parse(data_path |> Path.expand(), type, hash, ts) do
      %{"headers" => headers} when is_map_key(headers, "content-type") ->
        [_type, subtype] = Map.get(headers, "content-type") |> String.split("/")
        full_path = Path.join([data_path, type, "#{basename}.#{subtype}"]) |> Path.expand()
        IO.puts("PATH #{full_path}")
        # FIX!
        stat = File.stat!(full_path)

        Map.take(headers, ["content-type", "content-length", "last-modified", "age"])
        |> Enum.to_list()
        |> Enum.reduce(req, fn {k, v}, acc_req ->
          :cowboy_req.set_resp_header(k, v, acc_req)
        end)
        |> success_reply(stat, full_path, [header_name, data_path])

      error ->
        if error !== :not_found do
          Logger.critical("Unknown error! #{inspect(error)}")
        end

        Logger.warn("Full request: #{inspect(req)}")
        not_found_reply(req, [header_name, data_path])
    end
  end

  def handle_allowed(:error, req, state) do
    Logger.error("bad bindings: #{inspect(req.bindings)}")
    {:ok, :cowboy_req.reply(400, req), state}
  end

  def success_reply(req_with_meta_headers, stat, full_path, [header_name, data_path])
      when req_with_meta_headers.method === "GET" do
    {:ok,
     :cowboy_req.reply(
       200,
       :cowboy_req.set_resp_body(
         {:sendfile, 0, stat.size, full_path},
         req_with_meta_headers
       )
     ), [header_name, data_path]}
  end

  def success_reply(req_with_meta_headers, _s, _fp, [header_name, data_path])
      when req_with_meta_headers.method === "HEAD" do
    {:ok, :cowboy_req.reply(204, req_with_meta_headers), [header_name, data_path]}
  end

  def not_found_reply(req, [header_name, data_path]) do
    {:ok, :cowboy_req.reply(404, req), [header_name, data_path]}
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

  def metadata_parse(path, type, hash, ts) do
    full_path = Path.join([path, "metadata", "#{hash}-#{ts}.#{type}.json"]) |> Path.expand()

    try do
      Jason.decode!(File.read!(full_path))
    rescue
      fe in File.Error ->
        Logger.error("Metadata missing, expected at '#{fe.path}'")
        :not_found

      je in Jason.DecodeError ->
        HLTE.LoggingUtil.log_json_error(je, "metadata file at '#{full_path}")
        :not_found
    end
  end
end
