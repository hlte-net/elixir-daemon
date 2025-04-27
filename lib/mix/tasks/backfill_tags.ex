defmodule Mix.Tasks.BackfillTags do
  use Mix.Task
  require Logger

  @shortdoc "Backfill the tags database from existing records"
  
  @moduledoc """
  Backfills the tags database from existing hilite records.
  
  This task will scan all records in the main database that have annotations,
  extract tags (words starting with #), and store them in the tags database.
  
  ## Usage
  
      mix backfill_tags
  
  """
  
  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    HLTE.BackfillTags.run()
  end
end