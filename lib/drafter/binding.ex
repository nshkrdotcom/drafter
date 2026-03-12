defmodule Drafter.Binding do
  @moduledoc false

  defp send_app_callback(callback_name, data) do
    case Drafter.ScreenManager.get_active_screen() do
      nil ->
        send(:tui_app_loop, {:app_event, callback_name, data})

      _screen ->
        send(:tui_app_loop, {:tui_event, {:app_callback, callback_name, data}})
    end
  end

  def get_bound_value(opts, app_state, default \\ nil) do
    case Keyword.get(opts, :bind) do
      nil -> Keyword.get(opts, :value, default)
      key when is_atom(key) -> Map.get(app_state, key, default)
    end
  end

  def create_bound_callback(opts, _value_key) do
    case Keyword.get(opts, :bind) do
      nil ->
        case Keyword.get(opts, :on_change) do
          nil -> nil
          callback -> fn value -> send_app_callback(callback, value) end
        end

      bind_key when is_atom(bind_key) ->
        on_change = Keyword.get(opts, :on_change)

        fn value ->
          send(:tui_app_loop, {:bound_state_update, bind_key, value})

          if on_change do
            send_app_callback(on_change, value)
          end
        end
    end
  end

  def has_binding?(opts) do
    Keyword.has_key?(opts, :bind)
  end

  def get_binding_key(opts) do
    Keyword.get(opts, :bind)
  end
end
