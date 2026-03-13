defmodule Drafter.Session.Worker do
  @moduledoc false

  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    app_module = Keyword.fetch!(opts, :app_module)
    driver_pid = Keyword.fetch!(opts, :driver_pid)
    mode = Keyword.get(opts, :mode, :isolated)
    shared_state = Keyword.get(opts, :shared_state)
    mount_props = Keyword.get(opts, :mount_props, %{})

    {:ok, em} = Drafter.Event.Manager.start_link(name: nil)

    {:ok, comp} =
      Drafter.Compositor.start_link(
        name: nil,
        terminal_driver: {Drafter.Transport.SessionDriver, driver_pid},
        event_manager: em
      )

    {:ok, sm} = Drafter.ScreenManager.start_link(name: nil)
    {:ok, tm} = Drafter.ThemeManager.start_link(name: nil)
    {:ok, eh} = Drafter.EventHandler.start_link(name: nil)

    Process.link(em)
    Process.link(comp)
    Process.link(sm)
    Process.link(tm)
    Process.link(eh)
    Process.link(driver_pid)

    session_ctx = %{
      event_manager: em,
      compositor: comp,
      screen_manager: sm,
      theme_manager: tm,
      event_handler: eh
    }

    session_opts = [mode: mode, shared_state: shared_state] ++ Map.to_list(mount_props)

    app_pid =
      spawn_link(fn ->
        Drafter.run_session(app_module, session_ctx, session_opts)
      end)

    Drafter.Transport.SessionDriver.set_event_manager(driver_pid, em)
    Drafter.Event.Manager.subscribe_to(em, app_pid, :all)

    Process.monitor(app_pid)

    {:ok, %{app_pid: app_pid, session_ctx: session_ctx, driver_pid: driver_pid}}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:stop, :normal, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
