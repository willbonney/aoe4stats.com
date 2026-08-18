defmodule Wololo.ReleaseScriptsTest do
  use ExUnit.Case, async: true

  test "release start scripts do not contain carriage returns" do
    files = [
      Path.expand("../../rel/overlays/bin/server", __DIR__),
      Path.expand("../../rel/env.sh.eex", __DIR__),
      Path.expand("../../rel/cron-runner.sh", __DIR__)
    ]

    Enum.each(files, fn path ->
      refute File.read!(path) =~ "\r", "#{path} has CRLF line endings"
    end)
  end
end
