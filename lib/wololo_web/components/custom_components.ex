defmodule WololoWeb.CustomComponents do
  use WololoWeb, :html
  # from https://fly.io/phoenix-files/phoenix-liveview-and-sqlite-autocomplete/
  attr(:id, :string, required: true)
  attr(:show, :boolean, default: false)
  attr(:on_cancel, JS, default: %JS{})
  attr(:allow_outside_clicks, :boolean, default: true)
  slot(:inner_block, required: true)

  def search_modal(assigns) do
    ~H"""
    <%= if @show do %>
      <div
        id={@id}
        phx-mounted={show_modal(@id)}
        phx-remove={hide_modal(@id)}
        class="relative z-50 hidden"
      >
        <div
          id={"#{@id}-bg"}
          class="fixed inset-0 bg-zinc-50/90 dark:bg-stone-900/90 transition-opacity"
          aria-hidden="true"
        />
        <div
          class="fixed inset-0 overflow-y-auto"
          aria-labelledby={"#{@id}-title"}
          aria-describedby={"#{@id}-description"}
          role="dialog"
          aria-modal="true"
          tabindex="0"
        >
          <div class="flex min-h-full justify-center items-center">
            <div class="w-full min-h-12 max-w-3xl p-2 sm:p-4 lg:py-6">
              <.focus_wrap
                id={"#{@id}-container"}
                phx-mounted={@show && show_modal(@id)}
                phx-window-keydown={hide_modal(@on_cancel, @id)}
                phx-key="escape"
                phx-click-away={@allow_outside_clicks && hide_modal(@on_cancel, @id)}
                class="hidden relative rounded-2xl bg-white dark:bg-stone-800 p-2 shadow-lg shadow-zinc-700/10 ring-1 ring-zinc-700/10 transition min-h-[30vh] max-h-[50vh] overflow-y-scroll"
              >
                <button
                  phx-click={hide_modal(@on_cancel, @id)}
                  type="button"
                  class="absolute top-3 right-3 z-50 text-stone-600 hover:text-stone-900 dark:text-zinc-300 dark:hover:text-zinc-100 transition-colors"
                  aria-label="Close"
                >
                  <.icon name="hero-x-mark" class="h-7 w-7" />
                </button>
                
                <div id={"#{@id}-content"}>
                  {render_slot(@inner_block)}
                </div>
              </.focus_wrap>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  attr(:players, :any, required: true)
  attr(:has_searched, :boolean, required: true)

  def search_results(assigns) do
    ~H"""
    <ul class="-mb-2 py-2 text-sm text-gray-800 flex flex-col space-y-2 " id="options" role="listbox">
      <li
        :if={@players == [] && @has_searched}
        id="option-none"
        role="option"
        tabindex="-1"
        class="cursor-default select-none px-4 py-2 text-xl"
      >
        No Results
      </li>
      
      <%= for player <- @players do %>
        <.link navigate={~p"/player/#{player["profile_id"]}/rating"}>
          <li
            class="cursor-pointer select-none rounded-md px-4 py-2 text-xl text-stone-800 dark:text-zinc-100 bg-zinc-100 dark:bg-stone-800 hover:bg-zinc-200 hover:dark:bg-stone-700 flex flex-row space-x-2 items-center"
            id={"option-#{player["profile_id"]}"}
            role="option"
            tabindex="-1"
          >
            <div>
              <img class="mr-2" src={player["avatars"]["medium"]} />
            </div>
            
            <div class="flex flex-col">
              <h2 class="text-xl font-bold">{player["name"]}</h2>
              
              <div class="flex flex-row">
                <p class="text-gray-400 mr-2">#{player["rank"]}</p>
                
                <p class="text-gray-400 mr-2">{player["rating"]}</p>
                
                <p class="text-gray-400 mr-2">{player["win_rate"]}%</p>
              </div>
            </div>
          </li>
        </.link>
      <% end %>
    </ul>
    """
  end

  attr(:rest, :global)

  def search_input(assigns) do
    ~H"""
    <div class="relative ">
      <input
        {@rest}
        type="text"
        class="h-12 w-full border-none focus:ring-0 pl-11 pr-4 text-gray-800 dark:text-zinc-100 dark:bg-stone-800 placeholder:text-gray-400 placeholder:text-lg"
        placeholder="Search solo ladder (eg. Elyona)"
        role="combobox"
        aria-expanded="false"
        aria-controls="options"
      />
    </div>
    """
  end
end
