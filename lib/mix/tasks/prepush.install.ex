defmodule Mix.Tasks.Prepush.Install do
  @shortdoc "Opt in to the critical-path pre-push hook"
  @moduledoc """
  Points this repo's `core.hooksPath` at `.githooks/` so `git push` runs `mix prepush`.

  This is local and optional. Undo with `git config --unset core.hooksPath`.
  Skip one push with `SKIP_PREPUSH=1 git push`.
  """
  use Mix.Task

  @impl true
  def run(_args) do
    {_, 0} = System.cmd("git", ["config", "core.hooksPath", ".githooks"], cd: File.cwd!())
    Mix.shell().info("Pre-push hook enabled. `git push` will run mix prepush.")
    Mix.shell().info("Skip once with SKIP_PREPUSH=1. Disable with git config --unset core.hooksPath.")
  end
end
