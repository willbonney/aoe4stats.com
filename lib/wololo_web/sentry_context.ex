defmodule WololoWeb.SentryContext do
  def set_player_context(profile_id) when not is_nil(profile_id) do
    Sentry.Context.set_user_context(%{id: profile_id})
  end

  def set_player_context(_profile_id), do: :ok
end
