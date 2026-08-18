import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :wololo, WololoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "PWo+bN8tz9i3tAaRF3P3JcNHTWK60csCgVDx2s1inD51NA7Hnk/dYkYPrlnvsYSQ",
  server: false

# In test we don't send emails
config :wololo, Wololo.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :wololo, :fly_cost_refresh_on_boot, false
config :wololo, :cache_refresh_on_boot, false
