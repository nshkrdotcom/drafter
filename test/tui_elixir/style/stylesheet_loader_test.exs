defmodule Drafter.Style.StylesheetLoaderTest do
  use ExUnit.Case
  alias Drafter.Style.StylesheetLoader
  alias Drafter.Style.Stylesheet

  setup do
    on_exit(fn -> StylesheetLoader.clear_cache() end)
    :ok
  end

  describe "load_from_file/1" do
    test "loads and parses CSS file" do
      css_content = """
      button {
        color: primary;
        background: surface;
      }

      .custom-class {
        color: #ff0000;
      }
      """

      file_path = Path.join(System.tmp_dir!(), "test_styles_#{:rand.uniform(10000)}.tcss")
      File.write!(file_path, css_content)

      assert {:ok, stylesheet} = StylesheetLoader.load_from_file(file_path)
      assert is_struct(stylesheet, Stylesheet)
      assert length(stylesheet.rules) >= 2

      File.rm!(file_path)
    end

    test "caches parsed stylesheets" do
      css_content = "button { color: red; }"
      file_path = Path.join(System.tmp_dir!(), "test_cache_#{:rand.uniform(10000)}.tcss")
      File.write!(file_path, css_content)

      assert {:ok, stylesheet1} = StylesheetLoader.load_from_file(file_path)
      assert {:ok, stylesheet2} = StylesheetLoader.load_from_file(file_path)

      assert stylesheet1 == stylesheet2

      File.rm!(file_path)
    end

    test "returns error for non-existent file" do
      assert {:error, _reason} = StylesheetLoader.load_from_file("/nonexistent/file.tcss")
    end

    test "handles empty CSS file" do
      file_path = Path.join(System.tmp_dir!(), "test_empty_#{:rand.uniform(10000)}.tcss")
      File.write!(file_path, "")

      assert {:ok, stylesheet} = StylesheetLoader.load_from_file(file_path)
      assert length(stylesheet.rules) == 0

      File.rm!(file_path)
    end
  end

  describe "load_inline/1" do
    test "creates stylesheet from inline styles map" do
      inline_styles = %{
        "button" => %{color: :primary},
        ".custom" => %{background: :surface}
      }

      stylesheet = StylesheetLoader.load_inline(inline_styles)
      assert is_struct(stylesheet, Stylesheet)
      assert length(stylesheet.rules) >= 2
    end

    test "merges with default widget styles" do
      inline_styles = %{
        "button.custom" => %{color: :accent}
      }

      stylesheet = StylesheetLoader.load_inline(inline_styles)
      assert is_struct(stylesheet, Stylesheet)
    end
  end

  describe "clear_cache/0" do
    test "clears cached stylesheets" do
      css_content = "button { color: red; }"
      file_path = Path.join(System.tmp_dir!(), "test_clear_#{:rand.uniform(10000)}.tcss")
      File.write!(file_path, css_content)

      assert {:ok, stylesheet1} = StylesheetLoader.load_from_file(file_path)
      StylesheetLoader.clear_cache()

      assert {:ok, stylesheet2} = StylesheetLoader.load_from_file(file_path)

      assert is_struct(stylesheet1, Stylesheet)
      assert is_struct(stylesheet2, Stylesheet)

      File.rm!(file_path)
    end
  end

  describe "load_stylesheet/1" do
    defmodule TestAppCSS do
      def __css_path__, do: nil
      def __inline_styles__, do: %{}
    end

    defmodule TestAppWithInline do
      def __css_path__, do: nil
      def __inline_styles__, do: %{"button" => %{color: :custom}}
    end

    defmodule TestAppWithFile do
      @css_path Path.join(System.tmp_dir!(), "test_app_#{:rand.uniform(10000)}.tcss")

      def __css_path__, do: @css_path
      def __inline_styles__, do: %{}

      def setup_css do
        css_content = "button { color: fromfile; }"
        File.write!(@css_path, css_content)
      end

      def cleanup_css do
        File.rm!(@css_path)
      end
    end

    test "loads default stylesheet for app without CSS" do
      assert {:ok, stylesheet} = StylesheetLoader.load_stylesheet(TestAppCSS)
      assert is_struct(stylesheet, Stylesheet)
    end

    test "loads and merges inline styles" do
      assert {:ok, stylesheet} = StylesheetLoader.load_stylesheet(TestAppWithInline)
      assert is_struct(stylesheet, Stylesheet)
    end

    test "loads and merges file styles" do
      TestAppWithFile.setup_css()

      assert {:ok, stylesheet} = StylesheetLoader.load_stylesheet(TestAppWithFile)
      assert is_struct(stylesheet, Stylesheet)

      TestAppWithFile.cleanup_css()
    end
  end
end
