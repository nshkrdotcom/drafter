defmodule Drafter.Style.CSSIntegrationTest do
  use ExUnit.Case
  alias Drafter.Style.{CSSParser, Stylesheet, Selector, WidgetStyles}

  describe "CSS integration" do
    test "parses and applies class selectors" do
      css = """
      button { color: default; }
      button.primary { color: blue; }
      button.success { color: green; }
      """

      assert {:ok, stylesheet} = CSSParser.parse_string(css)

      context = %{
        widget_type: :button,
        classes: [:primary],
        focused: false,
        hovered: false
      }

      computed = Stylesheet.compute_style(stylesheet, context)
      assert computed.color == :blue
    end

    test "combines multiple classes" do
      css = """
      .bold { bold: true; }
      .large { text_align: center; }
      button { color: default; }
      """

      assert {:ok, stylesheet} = CSSParser.parse_string(css)

      context = %{
        widget_type: :button,
        classes: [:bold, :large],
        focused: false,
        hovered: false
      }

      computed = Stylesheet.compute_style(stylesheet, context)
      assert computed.bold == true
      assert computed.text_align == :center
    end

    test "handles pseudo-class selectors with classes" do
      css = """
      button:hover { color: white; }
      button.primary:hover { color: yellow; }
      """

      assert {:ok, stylesheet} = CSSParser.parse_string(css)

      context = %{
        widget_type: :button,
        classes: [:primary],
        focused: false,
        hovered: true
      }

      computed = Stylesheet.compute_style(stylesheet, context)
      assert computed.color == :yellow
    end

    test "applies style specificity correctly" do
      css = """
      button { color: red; }
      #special { color: blue; }
      button#special { color: green; }
      """

      assert {:ok, stylesheet} = CSSParser.parse_string(css)

      context = %{
        widget_type: :button,
        id: :special,
        classes: [],
        focused: false,
        hovered: false
      }

      computed = Stylesheet.compute_style(stylesheet, context)
      assert computed.color == :green
    end
  end

  describe "Selector specificity" do
    test "calculates specificity for type selectors" do
      selector = Selector.new(widget_type: :button)
      assert Selector.specificity(selector) == {0, 0, 1}
    end

    test "calculates specificity for class selectors" do
      selector = Selector.new(classes: [:primary])
      assert Selector.specificity(selector) == {0, 1, 0}
    end

    test "calculates specificity for ID selectors" do
      selector = Selector.new(id: :submit)
      assert Selector.specificity(selector) == {1, 0, 0}
    end

    test "calculates specificity for combined selectors" do
      selector = Selector.new(widget_type: :button, id: :submit, classes: [:primary])
      assert Selector.specificity(selector) == {1, 1, 1}
    end

    test "compares specificity correctly" do
      type_selector = Selector.new(widget_type: :button)
      class_selector = Selector.new(classes: [:primary])
      id_selector = Selector.new(id: :submit)

      assert Selector.compare_specificity(id_selector, class_selector) == :gt
      assert Selector.compare_specificity(class_selector, type_selector) == :gt
      assert Selector.compare_specificity(type_selector, type_selector) == :eq
    end
  end

  describe "CSS merges with default styles" do
    test "default styles are always present" do
      default_stylesheet = WidgetStyles.default_stylesheet()
      assert is_struct(default_stylesheet, Stylesheet)
      assert length(default_stylesheet.rules) > 0
    end

    test "custom CSS can override default styles" do
      css = "button { color: custom_color; }"
      assert {:ok, custom_stylesheet} = CSSParser.parse_string(css)

      merged = Stylesheet.merge(default_stylesheet = WidgetStyles.default_stylesheet(), custom_stylesheet)

      context = %{
        widget_type: :button,
        classes: [],
        focused: false,
        hovered: false
      }

      computed = Stylesheet.compute_style(merged, context)
      assert computed.color == :custom_color
    end
  end
end
