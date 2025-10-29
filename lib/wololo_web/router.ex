defmodule WololoWeb.Router do
  use WololoWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {WololoWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", WololoWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
    live("/civs_by_map", CivsByMapLive)
    live("/player/:profile_id/:section", PlayerLive)
    live("/player", PlayerLive)
  end

  # API routes
  scope "/api", WololoWeb do
    pipe_through(:api)

    get("/leaderboard", LeaderboardController, :index)
    get("/leaderboard/search", LeaderboardController, :search)
    get("/leaderboard/:profile_id", LeaderboardController, :show)
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:wololo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: WololoWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
