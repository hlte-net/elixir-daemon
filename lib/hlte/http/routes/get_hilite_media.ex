defmodule HLTE.HTTP.Route.GetHiliteMedia do
  require Logger

  def init(req, state) when req.method === "HEAD" or req.method === "GET" do
    # TODO: AUTH!
    parse_bindings(req.bindings)
    |> handle_allowed(req, state)
  end

  def init(req, state) do
    {:ok, :cowboy_req.reply(405, req), state}
  end

  def handle_allowed([type, basename, hash, ts], req, state) do
    path_expand = Path.join([Enum.at(state, 1), type]) |> Path.expand()

    case find_media(path_expand, basename) do
      {:ok, [full_path, stat]} ->
        case metadata(Enum.at(state, 1) |> Path.expand(), type, hash, ts) do
          %{"headers" => headers} ->
            req_with_meta_headers =
              Map.take(headers, ["content-type", "content-length", "last-modified", "age"])
              |> Enum.to_list()
              |> Enum.reduce(req, fn {k, v}, acc_req ->
                :cowboy_req.set_resp_header(k, v, acc_req)
              end)

            case req.method do
              "GET" ->
                {:ok,
                 :cowboy_req.reply(
                   200,
                   :cowboy_req.set_resp_body(
                     {:sendfile, 0, stat.size, full_path},
                     req_with_meta_headers
                   )
                 ), state}

              "HEAD" ->
                {:ok, :cowboy_req.reply(204, req_with_meta_headers), state}
            end

          _ ->
            Logger.warn("No metadata found! full_path:#{full_path} hash:#{hash} ts:#{ts}")
            {:ok, req, state}
        end

      {:error, reason} ->
        if reason !== :not_found do
          Logger.error("find_media failed: #{reason}")
        end

        {:ok, :cowboy_req.reply(404, req), state}
    end
  end

  def handle_allowed(:error, req, state) do
    Logger.error("bad bindings: #{inspect(req.bindings)}")
    {:ok, :cowboy_req.reply(400, req), state}
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

  def find_media(path, basename) do
    # XXX: need to flip this around: look up the metadatas FIRST, get content type from that to determine
    # extension then NO NEED to File.ls!() anything!
    case File.stat(path) do
      {:ok, _stat} ->
        # should only refresh the list when stat.mtime has changed?!
        # could store the cache in ETS
        case File.ls!(path)
             |> Enum.map(fn x -> String.split(x, ".") end)
             |> Enum.filter(fn x -> Enum.at(x, 0) === basename end)
             |> Enum.map(fn x -> Path.expand(Path.join([path, Enum.join(x, ".")])) end)
             |> Enum.map(fn x -> [x, File.stat!(x)] end) do
          found_list when length(found_list) === 1 ->
            {:ok, Enum.at(found_list, 0)}

          found_list when length(found_list) > 1 ->
            {:error, :multiple_found}

          _ ->
            {:error, :not_found}
        end

      {:error, reason} ->
        Logger.warn("Stat failure for #{path}: #{reason}")
        {:error, reason}
    end
  end
end
