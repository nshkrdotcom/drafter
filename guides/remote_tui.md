# Remote TUI

Drafter apps can be served over the network using SSH or Telnet. Each connecting client gets a full interactive TUI session in their terminal.

## Session Modes

Two modes control how state is managed across connections:

- **`:isolated`** (default) — each client runs an independent app instance with its own state. Suitable for single-user tools, personal dashboards, and games.
- **`:shared`** — all connected clients share a single app state. Any input from any client updates the shared state and triggers a re-render for everyone. Suitable for collaborative apps, shared dashboards, and multiplayer experiences.

## SSH

SSH is the recommended transport. It handles authentication, encryption, and terminal capability negotiation automatically via Erlang's built-in `:ssh` application.

### Starting an SSH server

```elixir
:application.ensure_all_started(:ssh)

{:ok, _pid} = Drafter.Server.start_ssh(MyApp,
  port: 2222,
  mode: :isolated,
  auth: [{"alice", "secret"}, {"bob", "secret"}]
)
```

Clients connect with any standard SSH client:

```bash
ssh -p 2222 alice@localhost
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `:port` | `2222` | TCP port to listen on |
| `:ip` | `{127, 0, 0, 1}` | Interface to bind (use `{0, 0, 0, 0}` for all interfaces) |
| `:mode` | `:isolated` | `:isolated` or `:shared` |
| `:auth` | `[{"admin", "admin"}]` | `[{username, password}]` tuples for password authentication |
| `:system_dir` | auto-generated | Path to directory containing SSH host keys |
| `:mount_props` | `%{}` | Map merged into `props` passed to `mount/1` for every session |

### SSH host keys

If `:system_dir` is not provided, Drafter generates RSA host keys automatically and caches them in a temp directory. Clients will see an "unknown host" warning on first connect.

For production deployments, generate persistent host keys and pass the directory explicitly:

```bash
mkdir -p /etc/drafter/ssh
ssh-keygen -t rsa -b 2048 -f /etc/drafter/ssh/ssh_host_rsa_key -N ""
```

```elixir
Drafter.Server.start_ssh(MyApp,
  system_dir: "/etc/drafter/ssh",
  auth: [{"alice", "secret"}]
)
```

### Username in mount props

The authenticated username is always injected into `mount/1` props as `:username`:

```elixir
def mount(props) do
  %{username: props.username, messages: []}
end
```

### Shared chat example

The `examples/ssh_chat.exs` example demonstrates a shared multi-user chat app:

```bash
elixir examples/ssh_chat.exs
```

Then connect from multiple terminals:

```bash
ssh -p 2222 alice@localhost   # password: pass
ssh -p 2222 bob@localhost     # password: pass
```

Messages sent by any user appear in all connected sessions in real time.

## Telnet

Telnet is a simpler transport with no authentication or encryption. Useful for development, local network tools, or environments where SSH is unavailable.

### Starting a Telnet server

```elixir
{:ok, _pid} = Drafter.Server.start_telnet(MyApp,
  port: 2323,
  mode: :isolated
)
```

Connect with any Telnet client:

```bash
telnet localhost 2323
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `:port` | `2323` | TCP port to listen on |
| `:mode` | `:isolated` | `:isolated` or `:shared` |
| `:mount_props` | `%{}` | Map merged into `props` passed to `mount/1` |

## Supervision

For production use, start the server under your application's supervision tree:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    :application.ensure_all_started(:ssh)

    children = [
      {Task, fn ->
        Drafter.Server.start_ssh(MyTuiApp,
          port: 2222,
          auth: [{"admin", System.fetch_env!("TUI_PASSWORD")}]
        )
        Process.sleep(:infinity)
      end}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```
