defmodule Drafter.Style.CSSParserTest do
  use ExUnit.Case
  alias Drafter.Style.CSSParser
  alias Drafter.Style.Stylesheet

  describe "parse_string/1" do
    test "parses simple type selector" do
      css = "button { color: red; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      assert is_struct(stylesheet, Stylesheet)
      assert length(stylesheet.rules) == 1
    end

    test "parses multiple selectors" do
      css = """
      button { color: red; }
      label { color: blue; }
      """
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      assert length(stylesheet.rules) == 2
    end

    test "parses ID selector" do
      css = "#submit { color: green; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      assert length(stylesheet.rules) == 1
    end

    test "parses class selector" do
      css = ".primary { color: blue; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      assert length(stylesheet.rules) == 1
    end

    test "parses pseudo-class selector" do
      css = "button:hover { color: white; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      assert length(stylesheet.rules) == 1
    end

    test "parses combined selectors" do
      css = "button.primary:focus { color: yellow; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      assert length(stylesheet.rules) == 1
    end

    test "parses multiple properties" do
      css = "button { color: red; background: blue; bold: true; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      [{_selectors, properties}] = stylesheet.rules
      assert properties.color == :red
      assert properties.background == :blue
      assert properties.bold == true
    end

    test "ignores comments" do
      css = """
      // This is a comment
      button { color: red; }
      /* This is also a comment */
      label { color: blue; }
      """
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      assert length(stylesheet.rules) == 2
    end

    test "handles empty CSS" do
      css = ""
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      assert length(stylesheet.rules) == 0
    end

    test "handles whitespace and newlines" do
      css = """
      button
      {
        color:  red
        ;background:blue;
      }
      """
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      assert length(stylesheet.rules) == 1
    end
  end

  describe "parse_hex_color/1" do
    test "parses 3-digit hex colors" do
      assert {:ok, {17, 17, 17}} = CSSParser.parse_hex_color("#111")
      assert {:ok, {255, 255, 255}} = CSSParser.parse_hex_color("#fff")
      assert {:ok, {255, 0, 255}} = CSSParser.parse_hex_color("#f0f")
    end

    test "parses 6-digit hex colors" do
      assert {:ok, {255, 255, 255}} = CSSParser.parse_hex_color("#ffffff")
      assert {:ok, {255, 0, 0}} = CSSParser.parse_hex_color("#ff0000")
      assert {:ok, {0, 255, 0}} = CSSParser.parse_hex_color("#00ff00")
      assert {:ok, {0, 0, 255}} = CSSParser.parse_hex_color("#0000ff")
    end

    test "handles mixed case" do
      assert {:ok, {255, 255, 255}} = CSSParser.parse_hex_color("#FFFFFF")
      assert {:ok, {255, 0, 0}} = CSSParser.parse_hex_color("#Ff0000")
    end

    test "returns error for invalid hex" do
      assert :error = CSSParser.parse_hex_color("#gg0000")
      assert :error = CSSParser.parse_hex_color("#fffff")
      assert :error = CSSParser.parse_hex_color("ffffff")
    end
  end

  describe "parse_rgb_color/1" do
    test "parses rgb() format" do
      assert {:ok, {255, 0, 0}} = CSSParser.parse_rgb_color("rgb(255, 0, 0)")
      assert {:ok, {0, 255, 0}} = CSSParser.parse_rgb_color("rgb(0, 255, 0)")
      assert {:ok, {0, 0, 255}} = CSSParser.parse_rgb_color("rgb(0, 0, 255)")
    end

    test "handles whitespace in rgb()" do
      assert {:ok, {100, 150, 200}} = CSSParser.parse_rgb_color("rgb( 100 , 150 , 200 )")
    end

    test "returns error for invalid rgb" do
      assert :error = CSSParser.parse_rgb_color("rgb(256, 0, 0)")
      assert :error = CSSParser.parse_rgb_color("rgb(100, 200)")
      assert :error = CSSParser.parse_rgb_color("rgba(255, 0, 0)")
    end
  end

  describe "parse_rgba_color/1" do
    test "parses rgba() format" do
      assert {:ok, {:rgba, {255, 0, 0}, 0.5}} = CSSParser.parse_rgba_color("rgba(255, 0, 0, 0.5)")
      assert {:ok, {:rgba, {0, 255, 0}, 1.0}} = CSSParser.parse_rgba_color("rgba(0, 255, 0, 1)")
      assert {:ok, {:rgba, {0, 0, 255}, 0.0}} = CSSParser.parse_rgba_color("rgba(0, 0, 255, 0)")
    end

    test "handles various alpha formats" do
      assert {:ok, {:rgba, {100, 100, 100}, 0.75}} = CSSParser.parse_rgba_color("rgba(100, 100, 100, .75)")
    end

    test "returns error for invalid rgba" do
      assert :error = CSSParser.parse_rgba_color("rgba(256, 0, 0, 0.5)")
      assert :error = CSSParser.parse_rgba_color("rgba(100, 200, 0.5)")
      assert :error = CSSParser.parse_rgba_color("rgb(255, 0, 0)")
    end
  end

  describe "property value parsing" do
    test "parses boolean values" do
      css = "button { bold: true; dim: false; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      [{_selectors, props}] = stylesheet.rules
      assert props.bold == true
      assert props.dim == false
    end

    test "parses integer values" do
      css = "button { width: 100; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      [{_selectors, props}] = stylesheet.rules
      assert props.width == 100
    end

    test "parses float values" do
      css = "button { opacity: 0.5; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      [{_selectors, props}] = stylesheet.rules
      assert props.opacity == 0.5
    end

    test "parses keyword values" do
      css = "button { color: primary; background: surface; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      [{_selectors, props}] = stylesheet.rules
      assert props.color == :primary
      assert props.background == :surface
    end

    test "parses hex color values" do
      css = "button { color: #ff0000; background: #00ff00; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      [{_selectors, props}] = stylesheet.rules
      assert props.color == {255, 0, 0}
      assert props.background == {0, 255, 0}
    end

    test "parses rgb color values" do
      css = "button { color: rgb(255, 0, 0); }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      [{_selectors, props}] = stylesheet.rules
      assert props.color == {255, 0, 0}
    end

    test "parses rgba color values" do
      css = "button { color: rgba(255, 0, 0, 0.5); }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      [{_selectors, props}] = stylesheet.rules
      assert props.color == {:rgba, {255, 0, 0}, 0.5}
    end
  end

  describe "property key normalization" do
    test "normalizes color property" do
      css = "button { color: red; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      [{_selectors, props}] = stylesheet.rules
      assert Map.has_key?(props, :color)
    end

    test "normalizes background property" do
      css = "button { background-color: blue; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      [{_selectors, props}] = stylesheet.rules
      assert Map.has_key?(props, :background)
    end

    test "normalizes text-align property" do
      css = "label { text-align: center; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      [{_selectors, props}] = stylesheet.rules
      assert Map.has_key?(props, :text_align)
    end
  end

  describe "error handling" do
    test "returns error for invalid CSS rule" do
      css = "button color red"
      assert {:error, _reason} = CSSParser.parse_string(css)
    end

    test "returns error for invalid property" do
      css = "button { invalid-property: value; }"
      assert {:ok, stylesheet} = CSSParser.parse_string(css)
      [{_selectors, props}] = stylesheet.rules
      refute Map.has_key?(props, :invalid_property)
    end
  end
end
