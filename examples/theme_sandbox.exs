Mix.install([{:drafter, path: Path.join(__DIR__, "..")}])

defmodule ThemeSandbox do
  use Drafter.App
  import Drafter.App

  def mount(_props) do
    %{
      progress: 65.0,
      sparkline_data: Enum.map(1..20, fn _ -> :rand.uniform(10) end),
      current_time: current_time(),
      table_data: [
        %{name: "Alice", age: 28, city: "New York",    status: "Active"},
        %{name: "Bob",   age: 34, city: "Los Angeles", status: "Pending"},
        %{name: "Carol", age: 22, city: "Chicago",     status: "Active"},
        %{name: "Dave",  age: 45, city: "Houston",     status: "Inactive"},
        %{name: "Eve",   age: 31, city: "Phoenix",     status: "Active"},
        %{name: "Frank", age: 29, city: "Seattle",     status: "Pending"}
      ],
      tree_data: [
        %{id: :docs, label: "Documents", icon: "📁", expanded: true, children: [
          %{id: :doc1, label: "report.pdf",  icon: "📄", children: []},
          %{id: :doc2, label: "notes.txt",   icon: "📝", children: []},
          %{id: :proj, label: "Projects",    icon: "📁", children: [
            %{id: :pa, label: "project_a", icon: "📁", children: []},
            %{id: :pb, label: "project_b", icon: "📁", children: []}
          ]}
        ]},
        %{id: :dl, label: "Downloads", icon: "📁", children: [
          %{id: :img, label: "image.png", icon: "🖼️",  children: []},
          %{id: :vid, label: "video.mp4", icon: "🎬", children: []}
        ]}
      ]
    }
  end

  def keybindings, do: [{"tab", "next"}, {"q", "quit"}]

  def on_ready(state) do
    Drafter.set_interval(500, :tick)
    state
  end

  def on_timer(:tick, state) do
    [_ | rest] = state.sparkline_data
    %{state | sparkline_data: rest ++ [:rand.uniform(10)], current_time: current_time()}
  end

  def render(state) do
    table_columns = [
      %{key: :name,   label: "Name",   sortable: true},
      %{key: :age,    label: "Age",    sortable: true, align: :right},
      %{key: :city,   label: "City",   sortable: true},
      %{key: :status, label: "Status", sortable: true}
    ]

    menu_tabs = [
      %{id: "foods",    label: "Foods",
        content: option_list([{"Pizza", :pizza}, {"Pasta", :pasta}, {"Salad", :salad}],        on_select: :food_selected)},
      %{id: "drinks",   label: "Drinks",
        content: option_list([{"Water", :water}, {"Coffee", :coffee}, {"Tea", :tea}],           on_select: :drink_selected)},
      %{id: "desserts", label: "Desserts",
        content: option_list([{"Cake", :cake}, {"Ice Cream", :ice_cream}, {"Pie", :pie}],       on_select: :item_selected)},
      %{id: "extras",   label: "Extras",
        content: option_list([{"Bread", :bread}, {"Butter", :butter}, {"Sauce", :sauce}],      on_select: :item_selected)}
    ]

    vertical([
      header("Theme Sandbox", show_clock: true),
      horizontal(
        [
          vertical([theme_selector()], width: 22),
          scrollable(
            [
              label("Buttons:", style: %{bold: true}),
              horizontal([
                button("Primary", variant: :primary, on_click: :primary_clicked),
                button("Success", variant: :success, on_click: :success_clicked),
                button("Warning", variant: :warning, on_click: :warning_clicked),
                button("Error",   variant: :error,   on_click: :error_clicked)
              ], gap: 1),
              label(""),
              horizontal([
                vertical([
                  label("Switches:"),
                  switch(enabled: false),
                  switch(enabled: true)
                ]),
                vertical([
                  label("Checkboxes:"),
                  checkbox("Option A", checked: false),
                  checkbox("Option B", checked: true)
                ])
              ], gap: 4),
              label(""),
              horizontal([
                vertical([
                  label("Radio Set:"),
                  radio_set([
                    {"Amanda",        "option1"},
                    {"Connor MacLeod","option2"},
                    {"Duncan MacLeod","option3"},
                    {"Heather",       "option4"}
                  ], selected: "option1", height: 4)
                ], width: 22),
                vertical([
                  label("Selection List:"),
                  selection_list([
                    {"Falken's Maze", "item1"},
                    {"Black Jack",    "item2"},
                    {"Gin Rummy",     "item3"},
                    {"Hearts",        "item4"}
                  ], selected: ["item2"], height: 4)
                ], width: 22)
              ], gap: 2),
              label(""),
              tabbed_content(menu_tabs, title: "Menu", height: 8, width: 44),
              label(""),
              collapsible(
                "Collapsible Section",
                "This content appears when expanded. It can contain multiple lines of text.",
                wrap: :word, expanded: false
              ),
              label(""),
              label("Text Input:"),
              text_input(placeholder: "Type something..."),
              label(""),
              label("Progress:"),
              progress_bar(progress: state.progress, show_percentage: true),
              label(""),
              horizontal([
                vertical([
                  label("Tree:"),
                  tree(data: state.tree_data, height: 6)
                ], width: 32),
                vertical([
                  label("DataTable:"),
                  data_table(columns: table_columns, data: state.table_data, height: 6)
                ], width: 40)
              ], gap: 2),
              label(""),
              label("Sparkline (live):"),
              sparkline(state.sparkline_data),
              label(""),
              label("Loading Indicators:"),
              horizontal([
                loading_indicator(spinner_type: :default),
                loading_indicator(spinner_type: :dots),
                loading_indicator(spinner_type: :line),
                loading_indicator(spinner_type: :arrow)
              ], gap: 2),
              label(""),
              label("Links:"),
              horizontal([
                link("Elixir Lang", url: "https://elixir-lang.org"),
                link("GitHub", url: "https://github.com")
              ], gap: 2),
              label(""),
              horizontal([
                vertical([
                  label("Masked Input:"),
                  masked_input(mask: "(###) ###-####", placeholder: "Phone")
                ], width: 22),
                vertical([
                  label("Pretty:"),
                  pretty(%{app: :drafter, version: "1.0", features: [:widgets, :themes]})
                ])
              ], gap: 2),
              label(""),
              label("Clock (Digits):"),
              digits(state.current_time),
              label("")
            ],
            flex: 1
          )
        ],
        flex: 1
      ),
      footer()
    ])
  end

  def handle_event(:food_selected,  food,  _state), do: {:show_toast, "Food: #{food}",  [variant: :info]}
  def handle_event(:drink_selected, drink, _state), do: {:show_toast, "Drink: #{drink}", [variant: :info]}
  def handle_event(:item_selected,  item,  _state), do: {:show_toast, "Item: #{item}",  [variant: :info]}
  def handle_event(_widget_event, _data, state), do: {:noreply, state}

  def handle_event({:key, :q}, _state), do: {:stop, :normal}
  def handle_event(_event, state), do: {:noreply, state}

  defp current_time do
    {_, {h, m, s}} = :calendar.local_time()
    [h, m, s] |> Enum.map_join(":", &(Integer.to_string(&1) |> String.pad_leading(2, "0")))
  end
end

Drafter.run(ThemeSandbox)
