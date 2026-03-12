defmodule Drafter.ThemeHelper do
  @moduledoc false

  # Theme module alias available but unused

  @doc """
  Generate themed styles for buttons based on button type and theme.
  """
  def button_style(theme, button_type, custom_style \\ %{}) do
    base_style =
      case button_type do
        :primary ->
          %{fg: theme.background, bg: theme.primary, bold: true}

        :success ->
          %{fg: theme.background, bg: theme.success, bold: true}

        :warning ->
          %{fg: theme.background, bg: theme.warning, bold: true}

        :error ->
          %{fg: theme.background, bg: theme.error, bold: true}

        :secondary ->
          %{fg: theme.text_primary, bg: theme.secondary}

        _ ->
          %{fg: theme.text_primary, bg: theme.panel, border: true}
      end

    Map.merge(base_style, custom_style)
  end

  @doc """
  Generate themed styles for DataTable components.
  """
  def data_table_styles(theme, custom_styles \\ %{}) do
    styles = %{
      style: %{fg: theme.text_primary, bg: theme.surface},
      header_style: %{fg: theme.text_primary, bg: theme.panel, bold: true},
      selected_style: %{fg: theme.background, bg: theme.primary},
      cursor_style: %{fg: theme.text_primary, bg: theme.accent, bold: true}
    }

    Map.merge(styles, custom_styles)
  end

  @doc """
  Generate themed styles for text inputs.
  """
  def text_input_style(theme, focused \\ false, custom_style \\ %{}) do
    base_style =
      if focused do
        %{fg: theme.text_primary, bg: theme.surface, border_color: theme.accent}
      else
        %{fg: theme.text_primary, bg: theme.surface, border_color: theme.border}
      end

    Map.merge(base_style, custom_style)
  end

  @doc """
  Generate themed styles for checkboxes.
  """
  def checkbox_style(theme, checked \\ false, custom_style \\ %{}) do
    base_style =
      if checked do
        %{fg: theme.background, bg: theme.accent, bold: true}
      else
        %{fg: theme.text_primary, bg: theme.surface}
      end

    Map.merge(base_style, custom_style)
  end

  @doc """
  Generate themed styles for option lists.
  """
  def option_list_styles(theme, custom_styles \\ %{}) do
    styles = %{
      style: %{fg: theme.text_primary, bg: theme.surface},
      highlighted_style: %{fg: theme.text_primary, bg: theme.accent},
      selected_style: %{fg: theme.background, bg: theme.primary, bold: true}
    }

    Map.merge(styles, custom_styles)
  end

  @doc """
  Generate themed scrollbar styles with hover support.
  """
  def scrollbar_styles(theme, hovering \\ false) do
    if hovering do
      %{
        thumb: %{fg: theme.background, bg: theme.accent},
        track: %{fg: theme.border, bg: theme.panel}
      }
    else
      %{
        thumb: %{fg: theme.text_muted, bg: theme.border},
        track: %{fg: theme.text_disabled, bg: theme.panel}
      }
    end
  end

  @doc """
  Generate themed styles for labels.
  """
  def label_style(theme, variant \\ :default, custom_style \\ %{}) do
    base_style =
      case variant do
        :primary -> %{fg: theme.primary, bg: theme.background}
        :success -> %{fg: theme.success, bg: theme.background}
        :warning -> %{fg: theme.warning, bg: theme.background}
        :error -> %{fg: theme.error, bg: theme.background}
        :muted -> %{fg: theme.text_muted, bg: theme.background}
        _ -> %{fg: theme.text_primary, bg: theme.background}
      end

    Map.merge(base_style, custom_style)
  end

  @doc """
  Generate themed styles for collapsible widgets.
  """
  def collapsible_styles(theme, state \\ :default) do
    case state do
      :focused ->
        %{
          title: %{fg: theme.text_primary, bg: theme.primary, bold: true},
          arrow: %{fg: theme.accent, bg: theme.primary}
        }

      :hovered ->
        hovered_bg = darken_color(theme.background, 15)

        %{
          title: %{fg: theme.text_primary, bg: hovered_bg},
          arrow: %{fg: theme.primary, bg: hovered_bg}
        }

      _ ->
        %{
          title: %{fg: theme.text_primary, bg: theme.background},
          arrow: %{fg: theme.primary, bg: theme.background}
        }
    end
  end

  defp darken_color({r, g, b}, amount) do
    {max(0, r - amount), max(0, g - amount), max(0, b - amount)}
  end

  defp darken_color(_, _), do: {30, 30, 30}
end
