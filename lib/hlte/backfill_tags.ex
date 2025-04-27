defmodule HLTE.BackfillTags do
  require Logger

  @doc """
  Backfill the tags database with tags from existing database records.
  
  Usage: 
  ```
  # From iex shell:
  iex> HLTE.BackfillTags.run()
  
  # From mix task:
  mix run -e "HLTE.BackfillTags.run()"
  ```
  """
  def run do
    Logger.info("Starting tags database backfill...")
    
    # Ensure the databases are initialized
    db_path = Application.fetch_env!(:hlte, :db_path)
    tags_db_path = Application.fetch_env!(:hlte, :tags_db_path)
    
    # Initialize the tags database
    HLTE.TagsDB.init(Path.expand(tags_db_path))
    
    # Open connection to main database
    {:ok, conn} = Exqlite.Basic.open(Path.expand(db_path))
    
    # Count total records that have annotations
    {:ok, [[total_count]], _} = 
      Exqlite.Basic.exec(conn, "SELECT COUNT(*) FROM hlte WHERE annotation IS NOT NULL")
      |> Exqlite.Basic.rows()
    
    Logger.info("Found #{total_count} records with annotations to process")
    
    # Process in batches to avoid memory issues
    batch_size = 1000
    total_processed = 0
    total_tags = 0
    
    total_processed = process_in_batches(conn, batch_size, total_count, total_processed, total_tags)
    
    Exqlite.Basic.close(conn)
    
    Logger.info("Tags backfill complete. Processed #{total_processed} records with annotations.")
  end
  
  defp process_in_batches(conn, batch_size, total_count, processed, tags_count) when processed < total_count do
    Logger.info("Processing batch: #{processed + 1} to #{min(processed + batch_size, total_count)} of #{total_count}")
    
    # Fetch a batch of records
    {:ok, rows, _} =
      Exqlite.Basic.exec(
        conn,
        "SELECT checksum, timestamp, annotation FROM hlte WHERE annotation IS NOT NULL ORDER BY timestamp LIMIT ? OFFSET ?",
        [batch_size, processed]
      )
      |> Exqlite.Basic.rows()
    
    # Process each record
    batch_tag_count = 
      Enum.reduce(rows, 0, fn [checksum, timestamp, annotation], acc ->
        {:ok, count} = HLTE.TagsDB.store_tags(annotation, checksum, timestamp)
        acc + count
      end)
    
    new_processed = processed + length(rows)
    new_tags_count = tags_count + batch_tag_count
    
    Logger.info("Processed #{length(rows)} records with #{batch_tag_count} tags in this batch")
    
    # Process next batch
    process_in_batches(conn, batch_size, total_count, new_processed, new_tags_count)
  end
  
  defp process_in_batches(_conn, _batch_size, total_count, processed, tags_count) do
    Logger.info("Completed backfill with #{tags_count} total tags extracted from #{processed} records")
    processed
  end
end