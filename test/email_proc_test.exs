defmodule HLTE.EmailProcessor.Test do
  use ExUnit.Case

  test "good validate_parsed_subject_uri" do
    "bar" = URI.parse("foo://bar") |> HLTE.EmailProcessor.validate_parsed_subject_uri()
  end

  test "bad validate_parsed_subject_uri" do
    :error = URI.parse("foobar") |> HLTE.EmailProcessor.validate_parsed_subject_uri()
  end

  test "manual from_bucket" do
    {:noreply, [[]]} =
      HLTE.EmailProcessor.handle_cast(
        {:process_from_bucket, "bucket", "key", "bad_from", "subject"},
        []
      )
  end
end
