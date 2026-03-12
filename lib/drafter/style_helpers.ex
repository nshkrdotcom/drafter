defmodule Drafter.StyleHelpers do
  @moduledoc """
  Helper functions for resolving the active stylesheet for an app module.

  Combines the default widget stylesheet with any CSS file or inline styles
  declared by the app module. If the app does not declare a stylesheet,
  the default widget styles are returned.
  """

  alias Drafter.Style.{StylesheetLoader, WidgetStyles}

  @doc """
  Get the stylesheet for the current app.
  Combines default styles, CSS file (if any), and inline styles (if any).
  """
  def get_app_stylesheet(app_module) when is_atom(app_module) do
    if function_exported?(app_module, :__css_path__, 1) or
       function_exported?(app_module, :__inline_styles__, 1) do
      StylesheetLoader.load_stylesheet(app_module)
    else
      WidgetStyles.default_stylesheet()
    end
  end

  @doc """
  Get the default stylesheet (widget styles only).
  """
  def default_stylesheet do
    WidgetStyles.default_stylesheet()
  end
end
