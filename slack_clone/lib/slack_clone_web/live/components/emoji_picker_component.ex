defmodule SlackCloneWeb.EmojiPickerComponent do
  use SlackCloneWeb, :live_component
  
  @emoji_categories [
    %{name: "Frequently used", key: "frequent", emojis: ["😀", "😂", "👍", "❤️", "😍", "🔥", "👏", "🎉"]},
    %{name: "People", key: "people", emojis: ["😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊", "😇", "😍", "🤩", "😘", "😗", "😚", "😙", "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐", "😑", "😶", "😏", "😒", "🙄", "😬", "🤥", "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕", "🤢", "🤮", "🤧", "😵", "🤯", "🤠", "😎", "🤓", "🧐"]},
    %{name: "Nature", key: "nature", emojis: ["🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐽", "🐸", "🐵", "🙈", "🙉", "🙊", "🐒", "🐔", "🐧", "🐦", "🐤", "🐣", "🐥", "🦆", "🦅", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄", "🐝", "🐛", "🦋", "🐌", "🐞", "🐜", "🦗", "🕷", "🦂", "🐢", "🐍", "🦎", "🦖", "🦕", "🐙", "🦑", "🦐", "🦞", "🦀", "🐡", "🐠", "🐟", "🐬", "🐳", "🐋", "🦈", "🐊", "🐅", "🐆", "🦓", "🦍", "🐘", "🦏", "🐪", "🐫", "🦒", "🐃", "🐂", "🐄", "🐎", "🐖", "🐏", "🐑", "🐐", "🦌", "🐕", "🐩", "🐈", "🐓", "🦃", "🕊", "🐇", "🐁", "🐀", "🐿", "🦔"]},
    %{name: "Food", key: "food", emojis: ["🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍈", "🍒", "🍑", "🍍", "🥭", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥕", "🌽", "🌶", "🥒", "🥬", "🥖", "🍞", "🥨", "🥯", "🧀", "🥚", "🍳", "🥞", "🥓", "🥩", "🍗", "🍖", "🌭", "🍔", "🍟", "🍕", "🌮", "🌯", "🥙", "🥗", "🥘", "🥫", "🍝", "🍜", "🍲", "🍛", "🍣", "🍱", "🥟", "🍤", "🍙", "🍚", "🍘", "🍥", "🥠", "🍢", "🍡", "🍧", "🍨", "🍦", "🥧", "🍰", "🎂", "🍮", "🍭", "🍬", "🍫", "🍿", "🍩", "🍪", "🌰", "🥜", "🍯"]},
    %{name: "Activity", key: "activity", emojis: ["⚽", "🏀", "🏈", "⚾", "🎾", "🏐", "🏉", "🎱", "🏓", "🏸", "🥅", "🏒", "🏑", "🥍", "🏏", "⛳", "🏹", "🎣", "🥊", "🥋", "🎽", "⛸", "🥌", "🛷", "🎿", "⛷", "🏂", "🏋", "🤼", "🤸", "⛹", "🤺", "🏇", "🧘", "🏄", "🏊", "🤽", "🚣", "🧗", "🚴", "🚵", "🏆", "🥇", "🥈", "🥉", "🏅", "🎖", "🏵", "🎗", "🎫", "🎟", "🎪", "🤹", "🎭", "🎨", "🎬", "🎤", "🎧", "🎼", "🎹", "🥁", "🎷", "🎺", "🎸", "🎻", "🎲", "🎯", "🎳", "🎮", "🎰"]},
    %{name: "Travel", key: "travel", emojis: ["🚗", "🚕", "🚙", "🚌", "🚎", "🏎", "🚓", "🚑", "🚒", "🚐", "🚚", "🚛", "🚜", "🏍", "🚲", "🛴", "🛹", "🚁", "🚟", "🚠", "🚡", "🚂", "🚃", "🚄", "🚅", "🚆", "🚇", "🚈", "🚉", "🚊", "🚝", "🚞", "🚋", "🚃", "🚖", "🚘", "🚍", "🚔", "🚨", "🚪", "🚧", "⛽", "🚥", "🚦", "🛣", "🗺", "🗿", "🗽", "🗼", "🏰", "🏯", "🏟", "🎡", "🎢", "🎠", "⛱", "🏖", "🏝", "🏜", "🌋", "⛰", "🏔", "🗻", "🏕", "⛺", "🏠", "🏡", "🏘", "🏚", "🏗", "🏭", "🏢", "🏬", "🏣", "🏤", "🏥", "🏦", "🏨", "🏪", "🏫", "🏩", "💒", "🏛", "⛪", "🕌", "🕍", "🕋"]},
    %{name: "Objects", key: "objects", emojis: ["⌚", "📱", "📲", "💻", "⌨", "🖥", "🖨", "🖱", "🖲", "🕹", "🗜", "💽", "💾", "💿", "📀", "📼", "📷", "📸", "📹", "🎥", "📽", "🎞", "📞", "☎", "📟", "📠", "📺", "📻", "🎙", "🎚", "🎛", "⏱", "⏲", "⏰", "🕰", "⌛", "⏳", "📡", "🔋", "🔌", "💡", "🔦", "🕯", "🗑", "🛢", "💸", "💵", "💴", "💶", "💷", "💰", "💳", "💎", "⚖", "🔧", "🔨", "⚒", "🛠", "⛏", "🔩", "⚙", "⛓", "🔫", "💣", "🔪", "🗡", "⚔", "🛡", "🚬", "⚰", "⚱", "🏺", "📿", "💈", "⚗", "🔭", "🔬", "🕳", "💊", "💉", "🌡", "🚽", "🚰", "🚿", "🛁", "🛀", "🛎", "🔑", "🗝", "🚪", "🛋", "🛏", "🛌", "🖼", "🛍", "🛒", "🎁", "🎈", "🎏", "🎀", "🎊", "🎉", "🎎", "🏮", "🎐", "📩", "📨", "📧", "💌", "📥", "📤", "📦", "🏷", "📪", "📫", "📬", "📭", "📮", "📯", "📜", "📃", "📄", "📑", "📊", "📈", "📉", "🗒", "🗓", "📆", "📅", "📇", "🗃", "🗳", "🗄", "📋", "📁", "📂", "🗂", "🗞", "📰", "📓", "📔", "📒", "📕", "📗", "📘", "📙", "📚", "📖", "🔖", "🔗", "📎", "🖇", "📐", "📏", "📌", "📍", "✂", "🖊", "🖋", "✒", "🖌", "🖍", "📝", "✏", "🔍", "🔎", "🔏", "🔐", "🔒", "🔓"]},
    %{name: "Symbols", key: "symbols", emojis: ["❤", "🧡", "💛", "💚", "💙", "💜", "🖤", "💔", "❣", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮", "✝", "☪", "🕉", "☸", "✡", "🔯", "🕎", "☯", "☦", "🛐", "⛎", "♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓", "🆔", "⚛", "🉑", "☢", "☣", "📴", "📳", "🈶", "🈚", "🈸", "🈺", "🈷", "✴", "🆚", "💮", "🉐", "㊙", "㊗", "🈴", "🈵", "🈹", "🈲", "🅰", "🅱", "🆎", "🆑", "🅾", "🆘", "❌", "⭕", "🛑", "⛔", "📛", "🚫", "💯", "💢", "♨", "🚷", "🚯", "🚳", "🚱", "🔞", "📵", "🚭", "❗", "❕", "❓", "❔", "‼", "⁉", "🔅", "🔆", "〽", "⚠", "🚸", "🔱", "⚜", "🔰", "♻", "✅", "🈯", "💹", "❇", "✳", "❎", "🌐", "💠", "Ⓜ", "🌀", "💤", "🏧", "🚾", "♿", "🅿", "🈳", "🈂", "🛂", "🛃", "🛄", "🛅", "🚹", "🚺", "🚼", "🚻", "🚮", "🎦", "📶", "🈁", "🔣", "ℹ", "🔤", "🔡", "🔠", "🆖", "🆗", "🆙", "🆒", "🆕", "🆓", "0⃣", "1⃣", "2⃣", "3⃣", "4⃣", "5⃣", "6⃣", "7⃣", "8⃣", "9⃣", "🔟", "🔢", "#⃣", "*⃣", "⏏", "▶", "⏸", "⏯", "⏹", "⏺", "⏭", "⏮", "⏩", "⏪", "⏫", "⏬", "◀", "🔼", "🔽", "➡", "⬅", "⬆", "⬇", "↗", "↘", "↙", "↖", "↕", "↔", "↪", "↩", "⤴", "⤵", "🔀", "🔁", "🔂", "🔄", "🔃", "🎵", "🎶", "➕", "➖", "➗", "✖", "💲", "💱", "™", "©", "®", "〰", "➰", "➿", "🔚", "🔙", "🔛", "🔝", "🔜", "✔", "☑", "🔘", "⚪", "⚫", "🔴", "🔵", "🔺", "🔻", "🔸", "🔹", "🔶", "🔷", "🔳", "🔲", "▪", "▫", "⬛", "⬜", "🔈", "🔇", "🔉", "🔊", "🔔", "🔕", "📣", "📢", "👁‍🗨", "💬", "💭", "🗯", "♠", "♣", "♥", "♦", "🃏", "🎴", "🀄", "🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚", "🕛", "🕜", "🕝", "🕞", "🕟", "🕠", "🕡", "🕢", "🕣", "🕤", "🕥", "🕦", "🕧"]}
  ]
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Search -->
      <div class="p-3 border-b border-slack-border">
        <input 
          type="text" 
          placeholder="Search emojis..."
          class="w-full px-3 py-2 text-sm border border-slack-border rounded focus:outline-none focus:border-slack-blue"
          phx-target={@myself}
          phx-keyup="search_emojis"
        />
      </div>
      
      <!-- Categories -->
      <div class="flex border-b border-slack-border">
        <%= for category <- @emoji_categories do %>
          <button 
            class={[
              "flex-1 px-2 py-2 text-xs font-medium transition-colors",
              if(@active_category == category.key, 
                do: "text-slack-blue border-b-2 border-slack-blue", 
                else: "text-slack-text-muted hover:text-slack-text-primary"
              )
            ]}
            phx-click="switch_category"
            phx-value-category={category.key}
            phx-target={@myself}
          >
            {String.slice(category.name, 0, 1)}
          </button>
        <% end %>
      </div>
      
      <!-- Emoji Grid -->
      <div class="flex-1 overflow-y-auto p-2">
        <%= if @search_results do %>
          <!-- Search Results -->
          <div class="grid grid-cols-8 gap-1">
            <%= for emoji <- @search_results do %>
              <button 
                class="w-8 h-8 flex items-center justify-center text-lg hover:bg-slack-bg-secondary rounded transition-colors"
                phx-click="select_emoji"
                phx-value-emoji={emoji}
                phx-target={@target}
                title={emoji}
              >
                {emoji}
              </button>
            <% end %>
          </div>
        <% else %>
          <!-- Category View -->
          <%= for category <- @emoji_categories do %>
            <%= if @active_category == category.key do %>
              <div>
                <h4 class="text-xs font-medium text-slack-text-muted mb-2 uppercase tracking-wide px-1">
                  {category.name}
                </h4>
                <div class="grid grid-cols-8 gap-1 mb-4">
                  <%= for emoji <- category.emojis do %>
                    <button 
                      class="w-8 h-8 flex items-center justify-center text-lg hover:bg-slack-bg-secondary rounded transition-colors"
                      phx-click="select_emoji"
                      phx-value-emoji={emoji}
                      phx-target={@target}
                      title={emoji}
                    >
                      {emoji}
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
  
  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:active_category, fn -> "frequent" end)
     |> assign_new(:search_results, fn -> nil end)
     |> assign(:emoji_categories, @emoji_categories)}
  end
  
  @impl true
  def handle_event("switch_category", %{"category" => category}, socket) do
    {:noreply, 
     socket
     |> assign(:active_category, category)
     |> assign(:search_results, nil)}
  end
  
  @impl true
  def handle_event("search_emojis", %{"value" => query}, socket) do
    results = if String.trim(query) == "" do
      nil
    else
      query = String.downcase(query)
      
      @emoji_categories
      |> Enum.flat_map(& &1.emojis)
      |> Enum.filter(fn _emoji ->
        # Simple search - in a real app, you'd have emoji names/keywords
        String.contains?(query, String.slice(query, 0, 1))
      end)
      |> Enum.take(40)
    end
    
    {:noreply, assign(socket, :search_results, results)}
  end
end