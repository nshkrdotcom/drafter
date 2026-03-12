defmodule Drafter.Event.Mouse do
  @moduledoc false

  @type button :: :left | :right | :middle | :none
  @type modifiers :: [:shift | :ctrl | :alt | :meta]
  @type coordinates :: {non_neg_integer(), non_neg_integer()}

  @type mouse_event :: %{
    type: :mouse_move | :mouse_down | :mouse_up | :click | :enter | :leave,
    x: non_neg_integer(),
    y: non_neg_integer(),
    button: button(),
    modifiers: modifiers(),
    widget: module() | nil,
    timestamp: integer()
  }

  @doc "Create a new mouse event"
  @spec new(atom(), non_neg_integer(), non_neg_integer(), button(), modifiers()) :: mouse_event()
  def new(type, x, y, button \\ :none, modifiers \\ []) do
    %{
      type: type,
      x: x,
      y: y,
      button: button,
      modifiers: modifiers,
      widget: nil,
      timestamp: System.monotonic_time(:millisecond)
    }
  end

  @doc "Create a mouse move event"
  @spec move(non_neg_integer(), non_neg_integer()) :: mouse_event()
  def move(x, y), do: new(:mouse_move, x, y)

  @doc "Create a mouse down event"
  @spec down(non_neg_integer(), non_neg_integer(), button(), modifiers()) :: mouse_event()
  def down(x, y, button \\ :left, modifiers \\ []), do: new(:mouse_down, x, y, button, modifiers)

  @doc "Create a mouse up event"
  @spec up(non_neg_integer(), non_neg_integer(), button(), modifiers()) :: mouse_event()
  def up(x, y, button \\ :left, modifiers \\ []), do: new(:mouse_up, x, y, button, modifiers)

  @doc "Create a click event from down/up events"
  @spec click(mouse_event(), mouse_event()) :: mouse_event()
  def click(down_event, up_event) do
    %{down_event | type: :click, timestamp: up_event.timestamp}
  end

  @doc "Create an enter event"
  @spec enter(non_neg_integer(), non_neg_integer()) :: mouse_event()
  def enter(x, y), do: new(:enter, x, y)

  @doc "Create a leave event"
  @spec leave(non_neg_integer(), non_neg_integer()) :: mouse_event()
  def leave(x, y), do: new(:leave, x, y)

  @doc "Check if coordinates are within a rectangle"
  @spec within_rect?(mouse_event(), map()) :: boolean()
  def within_rect?(event, rect) do
    event.x >= rect.x and event.x < rect.x + rect.width and
    event.y >= rect.y and event.y < rect.y + rect.height
  end

  @doc "Translate event coordinates relative to a widget"
  @spec translate(mouse_event(), map()) :: mouse_event()
  def translate(event, rect) do
    %{event | x: event.x - rect.x, y: event.y - rect.y}
  end
end