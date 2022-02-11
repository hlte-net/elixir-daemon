defmodule HLTE.EmailProcessor do
  require Logger
  use GenServer

  def start_link(opts) do
    Logger.notice(
      "Email processor using whitelist: #{Enum.join(Application.fetch_env!(:hlte, :sns_whitelist), ", ")}"
    )

    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def from_bucket(bucket, key, from, subject) do
    GenServer.cast(EmailProcessor, {:process_from_bucket, bucket, key, from, subject})
  end

  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:process_from_bucket, bucket, key, from, subject}, state) do
    case Enum.find(Application.fetch_env!(:hlte, :sns_whitelist), fn whiteListedAddress ->
           from === whiteListedAddress
         end) do
      ^from ->
        case URI.parse(subject) |> validate_parsed_subject_uri() do
          :error -> Logger.error("Malformed URI as subject!")
          host -> stream_and_parse(bucket, key, subject, host)
        end

      nil ->
        Logger.error("Message from non-whitelisted address <#{from}>!")
    end

    # {:ok, _content} = ExAws.S3.delete_object(bucket, key) |> ExAws.request
    {:noreply, [state]}
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
          "annotation" => parsed_body
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
end
