defmodule HLTE.HTTP.Route.GetHiliteMedia do
  require Logger

  def init(req, state) when req.method === "HEAD" or req.method === "GET" do
    # TODO: AUTH!
    handle_allowed(req, state)
  end

  def init(req, state) do
    {:ok, :cowboy_req.reply(405, req), state}
  end

  def handle_allowed(req, state) do
    case parse_bindings(req.bindings) do
      [type, fileName, hash, ts] ->
        path_expand = Path.join([Enum.at(state, 1), type]) |> Path.expand()

        case find_media(path_expand, fileName) do
          {:ok, [[[base, ext], full_path], stat]} ->
            case metadata(Enum.at(state, 1) |> Path.expand(), type, hash, ts) do
              %{"headers" => headers} ->
                final_req =
                  Map.take(headers, ["content-type", "content-length", "last-modified", "age"])
                  |> Enum.to_list()
                  |> Enum.reduce(req, fn {k, v}, acc_req ->
                    IO.puts("\n\n!!!! #{k}:#{v} -- #{inspect(acc_req)}")
                    :cowboy_req.set_resp_header(k, v, acc_req)
                  end)

                IO.puts("FINAL REQ #{inspect(final_req)}")

                case req.method do
                  "GET" ->
                    IO.puts("GET! Adding body -- #{inspect({:sendfile, 0, stat.size, full_path})}")
                    {:ok, :cowboy_req.reply(200,
                      :cowboy_req.set_resp_body({:sendfile, 0, stat.size, full_path}, final_req)), state}

                  "HEAD" ->
                    {:ok, :cowboy_req.reply(204, final_req), state}
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

      :error ->
        Logger.error("bad bindings: #{inspect(req.bindings)}")
        {:ok, :cowboy_req.reply(400, req), state}
    end
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

  def find_media(path, fileName) do
    case File.stat(path) do
      {:ok, _stat} ->
        # should only refresh the list when stat.mtime has changed?!
        # could store the cache in ETS
        case File.ls!(path)
             |> Enum.map(fn x -> String.split(x, ".") end)
             |> Enum.filter(fn x -> Enum.at(x, 0) === fileName end)
             |> Enum.map(fn x -> [x, Path.expand(Path.join([path, Enum.join(x, ".")]))] end)
             |> Enum.map(fn x -> [x, File.stat!(Enum.at(x, 1))] end) do
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
