import Config

config :logger, :default_handler,
  config: %{
    file: ~c"tui_debug.log",
    max_no_bytes: 10_000_000,
    max_no_files: 3,
    compress_on_rotate: true
  },
  format: "[$level] $message $metadata\n",
  metadata: [:mfa, :file, :line]

config :logger,
  level: :error
