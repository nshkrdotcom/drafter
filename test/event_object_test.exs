defmodule Drafter.Event.ObjectTest do
  use ExUnit.Case
  alias Drafter.Event.Object, as: EventObject

  describe "event object creation" do
    test "creates event with new/2" do
      event = EventObject.new(:key, :enter)
      assert event.type == :key
      assert event.data == :enter
      assert event.phase == :bubble
      assert event.default_prevented == false
      assert event.propagation_stopped == false
    end

    test "creates event with options" do
      event = EventObject.new(:mouse, %{x: 10, y: 20}, target: :button1, phase: :capture)
      assert event.target == :button1
      assert event.phase == :capture
      assert event.timestamp != nil
    end
  end

  describe "event control methods" do
    test "prevent_default/1 sets flag" do
      event = EventObject.new(:key, :enter)
      event = EventObject.prevent_default(event)
      assert event.default_prevented == true
    end

    test "stop_propagation/1 sets flag" do
      event = EventObject.new(:key, :enter)
      event = EventObject.stop_propagation(event)
      assert event.propagation_stopped == true
    end

    test "stop_immediate_propagation/1 sets both flags" do
      event = EventObject.new(:key, :enter)
      event = EventObject.stop_immediate_propagation(event)
      assert event.propagation_stopped == true
      assert event.immediate_propagation_stopped == true
    end
  end

  describe "tuple conversion" do
    test "from_tuple converts key events" do
      event = EventObject.from_tuple({:key, :enter})
      assert event.type == :key
      assert event.data == :enter
    end

    test "from_tuple converts key events with modifiers" do
      event = EventObject.from_tuple({:key, :c, [:ctrl]})
      assert event.type == :key
      assert event.data == %{key: :c, modifiers: [:ctrl]}
    end

    test "from_tuple converts mouse events" do
      event = EventObject.from_tuple({:mouse, %{type: :click, x: 10, y: 20}})
      assert event.type == :mouse
      assert event.data == %{type: :click, x: 10, y: 20}
    end

    test "from_tuple converts focus events" do
      event = EventObject.from_tuple({:focus, :button1})
      assert event.type == :focus
      assert event.data == :button1
    end

    test "to_tuple converts back to tuples" do
      event = EventObject.new(:key, :enter)
      assert EventObject.to_tuple(event) == {:key, :enter}
    end

    test "to_tuple converts key with modifiers" do
      event = EventObject.new(:key, %{key: :c, modifiers: [:ctrl]})
      assert EventObject.to_tuple(event) == {:key, :c, [:ctrl]}
    end

    test "to_tuple converts mouse events" do
      data = %{type: :click, x: 10, y: 20}
      event = EventObject.new(:mouse, data)
      assert EventObject.to_tuple(event) == {:mouse, data}
    end

    test "roundtrip conversion preserves event data" do
      original = {:key, :enter}
      event = EventObject.from_tuple(original)
      result = EventObject.to_tuple(event)
      assert result == original
    end
  end

  describe "Drafter.Event delegation" do
    test "delegates from_tuple" do
      event = Drafter.Event.from_tuple({:key, :enter})
      assert %EventObject{} = event
      assert event.type == :key
    end

    test "delegates to_tuple" do
      event = EventObject.new(:key, :enter)
      tuple = Drafter.Event.to_tuple(event)
      assert tuple == {:key, :enter}
    end

    test "delegates prevent_default" do
      event = EventObject.new(:key, :enter)
      event = Drafter.Event.prevent_default(event)
      assert event.default_prevented == true
    end
  end
end
