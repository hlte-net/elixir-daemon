defmodule HLTE.EmailProcessor do
  require Logger
  use GenServer

  def start_link(opts) do
    Logger.notice(
      "Email processor using whitelist: #{Enum.join(Application.fetch_env!(:hlte, :sns_whitelist), ", ")}"
    )

    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def from_bucket(bucket, key, into_addr, from, subject) do
    GenServer.cast(EmailProcessor, {:process_from_bucket, bucket, key, into_addr, from, subject})
  end

  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:process_from_bucket, bucket, key, into_addr, from, subject}, state) do
    case Enum.find(Application.fetch_env!(:hlte, :sns_whitelist), fn whiteListedAddress ->
           from === whiteListedAddress
         end) do
      ^from ->
        case URI.parse(subject) |> validate_parsed_subject_uri() do
          :error ->
            case String.split(subject, " ") |> handle_subject_command(into_addr, from) do
              :error -> Logger.error("Malformed subject!")
              :ok -> :ok
            end

          host ->
            stream_and_parse(bucket, key, subject, host)
        end

      nil ->
        Logger.error("Message from non-whitelisted address <#{from}>!")
    end

    if Application.fetch_env!(:hlte, :delete_sns_s3_post_proc) === true and Mix.env() != :test do
      {:ok, _content} = ExAws.S3.delete_object(bucket, key) |> ExAws.request()
    end

    {:noreply, [state]}
  end

  def handle_subject_command([command | args], into_addr, from) do
    exec_subject_command(command, args)
    |> send(into_addr, from)
  end

  def exec_subject_command(cmd, args) when cmd == "!search" do
    query = Enum.join(args, " ")

    {search_results, runtime} = HLTE.DB.search(query, 25, true)
    Logger.info("Executed search '#{query}' (via email) in #{runtime}ms")

    {{search_results, runtime}
     |> format_search_results_plaintext(),
     "#{length(search_results)} search results for '#{query}'"}
  end

  def exec_subject_command(cmd, _args) when cmd == "!system" or cmd == "!systemInfo" do
    {[
       "Build info: #{inspect(System.build_info())}",
       "Schedulers: #{System.schedulers()} (#{System.schedulers_online()} online)",
       "Version: #{System.version()}",
       "App spec: #{inspect(Application.spec(:hlte))}",
       "No. Processes: #{length(Process.list())}",
       "CPU: #{:cpu_sup.avg1()}, #{:cpu_sup.avg5()}, #{:cpu_sup.avg15()} (util: #{:cpu_sup.util()})",
       "Memory: #{inspect(:memsup.get_system_memory_data())}",
       "Disk: #{inspect(:disksup.get_disk_data())}"
     ]
     |> Enum.join("\n"), "hlte system info"}
  end

  defp filtered_key(map, key, head, tail) do
    Map.get(map, key)
    |> then(fn
      nil ->
        ""

      val ->
        case String.length(val) do
          0 -> ""
          _ -> "#{head}#{val}#{tail}\n"
        end
    end)
  end

  def format_search_results_plaintext({search_results, runtime}) do
    search_results
    |> Enum.map(fn sr ->
      local_filt_key = fn k, h, t -> filtered_key(sr, k, h, t) end

      local_filt_key.("hilite", "\"", "\"") <>
        local_filt_key.("annotation", "[ ", " ]") <>
        "-- #{Map.get(sr, "primaryURI")}#{local_filt_key.("secondaryURI", "\n(", ")")}" <>
        "\n______________________________\n"
    end)
    |> Enum.join("\n\n")
    |> then(fn s -> s <> "\n(search ran in #{runtime}ms)" end)
  end

  def validate_parsed_subject_uri(%URI{:host => host, :scheme => s})
      when host !== nil and s !== nil,
      do: host

  def validate_parsed_subject_uri(_bad_uri), do: :error

  def stream_and_parse(bucket, key, uri, host) do
    {content_type, parsed_body, part_type} =
      ExAws.S3.download_file(bucket, key, :memory)
      |> ExAws.stream!()
      |> Stream.chunk_while(
        "",
        fn cur, acc ->
          {:cont, cur, acc <> cur}
        end,
        fn
          "" -> {:cont, ""}
          acc -> {:cont, acc, ""}
        end
      )
      |> Enum.to_list()
      |> Enum.at(0)
      |> Mail.Parsers.RFC2822.parse()
      |> extract_body()

    Logger.info(
      "Parsed #{String.length(parsed_body)} bytes of '#{content_type}' from a #{part_type} message"
    )

    {:ok, rxTime, entryID} =
      HLTE.DB.persist(
        %{
          "uri" => uri,
          "data" => parsed_body
        },
        HLTE.HTTP.calculate_body_hmac(parsed_body)
      )

    Logger.info("Persisted hilite for #{host} at #{floor(rxTime / 1.0e9)}, work ID #{entryID}")
  end

  def extract_body(%Mail.Message{:multipart => true, :parts => parts}) do
    target_part =
      Enum.find(parts, fn p ->
        Map.get(p.headers, "content-type") |> Enum.at(0) === "text/plain"
      end) ||
        Enum.at(parts, 0)

    {Map.get(target_part.headers, "content-type") |> Enum.at(0), target_part.body, "multipart"}
  end

  def extract_body(%Mail.Message{
        :multipart => false,
        :body => body,
        :headers => %{"content-type" => content_type}
      }) do
    {content_type |> Enum.at(0), body, "mono"}
  end

  def send({message, subject}, from, to), do: send(message, subject, from, to)

  def send(message, subject, from, to) do
    ts = System.os_time(:second)

    {:ok,
     %{
       body: resp_body,
       headers: [
         {"Date", send_date},
         {"Content-Type", "text/xml"},
         {"Content-Length", email_length_bytes},
         {"Connection", "keep-alive"},
         {"x-amzn-RequestId", aws_req_id}
       ],
       status_code: status
     }} =
      ExAws.SES.send_email(
        %{to: [to], cc: [], bcc: []},
        %{
          "body" => %{
            "text" => %{"data" => message <> "\n\n<< sent at #{ts} >>", "charset" => "utf8"}
          },
          "subject" => %{"data" => subject, "charset" => "utf8"}
        },
        from,
        [
          {
            :configuration_set_name,
            "default"
          }
        ]
      )
      |> ExAws.request()

    Logger.info(
      "Sent #{email_length_bytes} bytes at #{send_date}, request ID #{aws_req_id} (#{status}):\n#{resp_body}"
    )
  end
end
