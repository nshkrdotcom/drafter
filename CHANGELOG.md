# Changelog

All notable changes to Drafter are documented here.
Versions marked with ★ were published to Hex.pm.

## [0.1.20] - 2026-03-16
### Added
- `Drafter.App`: `on_scroll_active/1` optional callback — fires once on the first scroll event of a gesture; return updated state (e.g. `%{state | scrolling: true}`)
- `Drafter.App`: `on_scroll_idle/1` optional callback — fires when the 150 ms debounce settles after the last scroll event; return updated state (e.g. flush pending data, clear scrolling flag)
- `Drafter.App`: `on_message/2` optional callback — receives any process message not recognised by the drafter event loop (PubSub, `send/2`, GenServer casts, etc.); return updated state. Previously all such messages were silently dropped.
- `Drafter.run/2` / `run_session/3`: `scroll_optimization: false` opt-out — disables the fast render/debounce path and triggers a full `render_app` on every scroll tick. Default is `true`.

```elixir
def on_scroll_active(state), do: %{state | scrolling: true}

def on_scroll_idle(state) do
  state = if state.pending_data, do: apply_pending_data(state), else: state
  %{state | scrolling: false, pending_data: nil}
end

def on_message({:data_refreshed, _uid, payload}, state), do: %{state | rows: payload.rows}

Drafter.run(MyApp, scroll_optimization: false)
```

### Fixed
- `WidgetServer`: `event_sync` no longer calls `notify_render_needed` — the event loop renders after `event_sync` returns; calling it again was flooding the mailbox with one `{:widget_render_needed}` per scroll tick
- `WidgetHierarchy`: `update_widget` no longer blocks on `WidgetServer.get_state/1` after casting `update_props` — `update_props` is now a true fire-and-forget cast; ETS has the authoritative strips so rendering is unaffected
- `app_event_loop` / `shared_session_loop`: `{:widget_render_needed}` handler drains all pending notifications before doing a single `render_hierarchy`, eliminating N-fold duplicate composites when multiple widgets fire at once
- `app_event_loop` / `shared_session_loop`: `:scroll_debounce_render` handler drains all accumulated debounce messages before triggering one `render_app`, preventing update debt accumulation during slow/continuous scrolling
- `render_hierarchy` (fast scroll path): modals, popovers, and toasts are now correctly composited during scroll — previously the fast path painted only base app widgets, overwriting any open modal. Now reads screen and toast layers from stored ETS/hierarchy state with no `ComponentRenderer` re-run.
- Removed `sync_widget_states/1` — no longer needed; `render_hierarchy` reads strips directly from ETS

## [0.1.19] - 2026-03-16
### Changed
- `WidgetServer`: each widget owns its strip buffer via `WidgetStripCache` (ETS, public, `read_concurrency: true`) — rendering happens inside the widget's own GenServer process and results are written to ETS; `create_widget_layers_from_hierarchy` reads from ETS directly (no inter-process messaging, no round-trips)
- `WidgetServer`: `update_props` renders and writes to ETS when state changes but does **not** send `{:widget_render_needed}` — only autonomous widget state changes (events, timers) notify the event loop, eliminating redundant re-composites after `render_app`
- `WidgetServer`: `update_props` with identical resulting state is a no-op (no render, no ETS write)
- `ScrollableContainer`: scroll events use a fast render path — `render_hierarchy` re-clips ETS-cached strips without running `ComponentRenderer`; 150 ms debounce fires `render_app` once after scroll settles
- `MouseProcessor`: `mouse_move` while a button is held routes to the `mouse_down_widget` regardless of cursor position, enabling drag-out-of-bounds behaviour; `mouse_up` after drag-release outside the originating widget notifies the `mouse_down_widget` so it can clear drag state

### Added
- `WidgetStripCache`: ETS-backed strip store keyed by widget ID; lock-free reads from any process
- `ScrollableContainer`: click on scrollbar track jumps one viewport page toward the thumb
- `ScrollableContainer`: drag the scrollbar thumb — `mouse_down` on thumb begins drag, `mouse_move` continuously updates scroll offset, `mouse_up` ends drag

## [0.1.18] - 2026-03-15
### Fixed
- `DataTable`: click and Enter now toggle selection in both `:single` and `:multiple` modes — clicking or pressing Enter on an already-selected row deselects it; previously `change_selection/3` always set selection, while Space already toggled correctly via `action_toggle_selection`
- `DataTable`: arrow key navigation no longer inadvertently toggles selection in `:multiple` mode — `action_cursor_up/down` now pass `trigger_select: false` so moving the cursor never changes the selected set; only Enter, Space, and click change selection
- `Collapsible`: hidden children no longer receive mouse events — `find_widget_at` now excludes `hidden_widgets` from hit testing, preventing clicks intended for widgets beneath a collapsed section (e.g. a `DataTable` header) from being intercepted by invisible child widgets
- `Collapsible`: widget content (list) no longer renders over siblings below it — two root causes fixed:
  - `Collapsible.update/2` was resetting `content_height` to the default (10) on every re-render when only `content` was passed in `updated_props`, corrupting the stored height after the first render
  - `get_child_vertical_spec` / `get_preferred_height` ignored the `expanded:` and `content_height:` options when the widget was not yet in the hierarchy (first render), always returning height 1 and placing the next sibling at the wrong y position

## [0.1.17] - 2026-03-15
### Added
- `Digits`: `bg_data:` prop renders a braille line chart (4× vertical resolution per terminal row) behind the digit glyphs; `color:` sets the line colour; digits take priority where glyphs overlap braille dots
- `Sparkline`: `orientation: :horizontal` renders each data point as a left-to-right bar using left-aligned eighth-block characters (`▏▎▍▌▋▊▉█`)
- `Chart`: `pixel_style: :quadrant` option for line and scatter charts — uses quadrant block characters (`▖▗▘▝▚▞▛▜▟▙▀▄▌▐█`) at 2×2 pixel resolution per cell, giving larger/more visible dots than braille

## [0.1.16] - 2026-03-15
### Changed
- `Digits`: improved `B` glyph in both large and small sizes — more distinguishable from `8` and `6`; large uses flat `├` spine with `╲`/`╱` bump sides, small uses `╲` divider in the middle row

### Added
- `Rule`: new widget — horizontal/vertical divider line with optional embedded title, `title_align`, and `line_style` (`:solid`, `:double`, `:dashed`, `:thick`)
- `Tree`: `on_node_highlight:` callback fires whenever cursor moves to a new node; `Shift+←`/`Shift+→` navigates to previous/next sibling at the same depth
- `SelectionList`: `on_item_toggle:` callback fires with `{index, selected?}` on each individual item toggle; `Home`/`End` jump to first/last item; `Ctrl+A` toggles select-all / deselect-all in `:multiple` mode
- `MaskedInput`: `on_submit:` callback fires with the raw unmasked value on `Enter`
- `TextArea`: text selection (`Shift+Arrow`, `Ctrl+A`), copy/cut/paste (`Ctrl+C`/`X`/`V`), undo/redo (`Ctrl+Z`/`Y`), `read_only:`, `tab_behavior:` (`:focus` or `:indent`), `tab_size:`, `max_checkpoints:`, word navigation (`Ctrl+←`/`→`), page up/down, `highlight_cursor_line:`

## [0.1.15] - 2026-03-15
### Added
- `DataTable`: per-cell background colouring via `color_fn: (raw_value -> {r,g,b} | nil)` on column definitions; applied when the row is not selected
- `DataTable`: 3-state column sort cycle — click cycles ascending → descending → unsorted (restores original data order); `↕` indicator shown on all sortable-but-unsorted columns when `sortable: true`
- `DataTable`: table-level `sortable: false` option disables all sort indicators and click-to-sort
- `DataTable`: column width drag-resize — drag a column header to resize (when `locked: true`, the default); minimum 3 characters
- `DataTable`: column reorder — `Shift+←` / `Shift+→` moves the cursor column; drag a header while `locked: false` swaps columns live
- `DataTable`: `locked:` option — `true` (default) makes header-drag resize; `false` makes header-drag reorder
- `DataTable`: `on_layout_change:` callback — fires with `%{col_widths: [...], col_order: [...]}` after any resize or reorder
- `DataTable`: `col_widths:` and `col_order:` mount/update props to restore a previously saved layout
- `DataTable`: keyboard resize (`+`/`-`) fires `on_layout_change` after each step
- `DataTable`: `FocusRegistry` integration — footer key-binding bar updates dynamically when the table gains focus
- `FocusRegistry`: new `GenServer` tracking the focused widget's key bindings; consumed by `Footer` for dynamic display
- `EventRouter`: `{:key, key, mods}` events now dispatch to `handle_key/3` if exported, falling back to `handle_key/2`

## [0.1.14] - 2026-03-14
### Fixed
- Timer-driven re-renders skipped when `on_timer/2` returns state unchanged (`===`);
  applies to both `app_event_loop` and `shared_session_loop`. Eliminates redundant
  `render_app` / widget tree traversal on poll timers that find no new data.
- `{:widget_render_needed}` (fired by widget-internal timers such as the header clock)
  no longer triggers `ComponentRenderer.render_tree`. It now calls `render_hierarchy`
  which re-composites directly from the already-synced widget states, avoiding
  `update_widget` calls — and therefore `filter_list` — on every clock tick.

## [0.1.13] - 2026-03-14 *
### Added
- Multi-series line charts: pass a list of series (list of lists) to `chart_type: :line`
- Multi-series scatter charts: pass a list of point-lists to `chart_type: :scatter`
- `:clustered_bar` chart type — grouped multi-series bars with half-block resolution
- `:stacked_bar` chart type — series stack from baseline; supports mixed positive/negative values
- `:range_bar` chart type — each bar spans a `[low, high]` range
- Negative value support documented and verified across all chart types
- `multi_series_charts.exs` example demonstrating all new chart variants

### Fixed
- Area chart crash (`ArithmeticError`) when passed multi-series data; now dispatches to
  `render_multi_series` matching the same guard added to line chart

### Changed
- `Chart` moduledoc expanded with sections for negative values, multi-series API, and all bar types

## [0.1.11] - 2026-03-14 ★
### Added
- Scrollable viewport culling: off-screen children skipped during `render_component` calls,
  reducing GenServer traffic per frame for large scrollable lists

### Changed
- `count_component_slots/1` introduced to advance the ID counter for culled components,
  preserving auto-generated widget IDs for on-screen widgets

## [0.1.10] - 2026-03-14
### Fixed
- Chart axis labels: float concatenation crash in `format_axis_value/1` for values ≥ 1000

## [0.1.9] - 2026-03-14
### Fixed
- Binding resolution: `Checkbox` now reads `:checked` from opts at mount (was always `false`)
- `ComponentRenderer` checkbox update path now syncs `:checked` and `:on_change` on re-render
- `ComponentRenderer` `radio_set` update path now passes `:options` and `:selected` (was only
  `:on_change` and `:classes`, leaving options frozen after mount)
- `RadioSet.update/2` no longer resets `highlighted_index` on every timer-driven re-render

## [0.1.8] - 2026-03-14 ★
### Added
- Differential rendering in compositor: row-level dirty detection via `Strip.cache_key`
  (`:erlang.phash2` hash); unchanged rows skipped each frame, drastically reducing
  terminal output on static or partially-static screens
- Stale test cleanup: removed 10 test files referencing renamed/removed modules

### Fixed
- `TextInput`: scroll offset was double-subtracting border width, causing scroll to
  trigger 2 characters early
- `TextInput`: typed text no longer reset on re-render when widget has no `:bind` or
  `:value` prop

## [0.1.6] - 2026-03-14 ★
### Fixed
- `RadioSet`: options passed as raw tuples were not normalised at mount; now always
  stored as `%{id: _, label: _}` maps
- `RadioSet`: options not updating on re-render after first mount
- `RadioSet`: `highlighted_index` frozen after navigating before first selection

## [0.1.5] - 2026-03-14 ★
### Added
- `Collapsible` widget now supports interactive child widgets (buttons, inputs, etc.)
  inside the expanded body, not just plain text

### Fixed
- `Collapsible.update/2`: `content_height` no longer inherits stale value when content
  type changes between renders

## [0.1.4] - 2026-03-13 ★
### Fixed
- SSH: reverse entry bug introduced when SSH support was added
- Local startup issues with terminal initialisation

## [0.1.3] - 2026-03-13 ★
### Fixed
- Input handling cleanup following SSH integration

## [0.1.2] - 2026-03-13 ★
### Added
- Guide: Remote TUI over SSH/Telnet (`guides/remote_tui.md`)

## [0.1.1] - 2026-03-13 ★
### Added
- SSH and Telnet remote TUI support via `Drafter.Server`
- Remote client connects over standard SSH; full terminal interaction over the wire

### Fixed
- Theme switching between light and dark modes

## [0.1.0] - 2026-03-12 ★
### Added
- Initial public release
- Core framework: `Drafter.App` behaviour, widget lifecycle, event system
- Widget library: Label, Button, TextInput, TextArea, Checkbox, Switch, RadioSet,
  SelectionList, OptionList, MaskedInput, Link, DataTable, Tree, DirectoryTree,
  Chart, Sparkline, ProgressBar, LoadingIndicator, Pretty, Digits, Log, RichLog,
  Rule, Placeholder, Markdown, CodeView, Collapsible, TabbedContent, Card,
  Container, ScrollableContainer, Grid, Header, Footer
- Theming system with light/dark built-in themes and custom theme support
- Braille-dot chart rendering with line, area, bar, scatter, and candlestick types
- Layout engine: vertical, horizontal, scrollable containers with flex sizing
- Focus management: tab and arrow-key geometric navigation
- Multi-screen navigation stack with modal support
- Toast notification system with 9 positions and stack limiting
- Tree-sitter syntax highlighting integration (opt-in)
- Windows terminal support
- Dynamic actions and native alert/confirm dialogs
- Custom action handler API
