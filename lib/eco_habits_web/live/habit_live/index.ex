defmodule EcoHabitsWeb.HabitLive.Index do
  use EcoHabitsWeb, :live_view

  alias EcoHabits.Habits
  alias EcoHabits.Habits.Habit

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:category_filter, "")
     |> assign(:page_title, "Meus Hábitos")
     |> load_habits()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    habit = Habits.get_user_habit!(socket.assigns.current_user.id, id)

    socket
    |> assign(:page_title, "Editar Hábito")
    |> assign(:habit, habit)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Novo Hábito")
    |> assign(:habit, %Habit{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Meus Hábitos")
    |> assign(:habit, nil)
  end

  @impl true
  def handle_info({EcoHabitsWeb.HabitLive.FormComponent, {:saved, _habit}}, socket) do
    {:noreply, load_habits(socket)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    habit = Habits.get_user_habit!(socket.assigns.current_user.id, id)
    {:ok, _} = Habits.delete_habit(habit)

    {:noreply,
     socket
     |> put_flash(:info, "Hábito removido com sucesso!")
     |> load_habits()}
  end

  def handle_event("filter", %{"category" => category}, socket) do
    {:noreply,
     socket
     |> assign(:category_filter, category)
     |> load_habits(category)}
  end

  defp load_habits(socket, category \\ nil) do
    category = category || socket.assigns[:category_filter] || ""
    habits = Habits.list_user_habits(socket.assigns.current_user.id, category: category)
    assign(socket, :habits, habits)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl">
      <.header>
        Meus Hábitos Sustentáveis
        <:subtitle>Gerencie os hábitos que você pratica no dia a dia.</:subtitle>
        <:actions>
          <.link patch={~p"/habits/new"}>
            <.button class="bg-green-600 hover:bg-green-700">Novo Hábito</.button>
          </.link>
        </:actions>
      </.header>

      <div class="mt-6 flex flex-wrap gap-2">
        <button
          phx-click="filter"
          phx-value-category=""
          class={filter_btn_class(@category_filter == "")}
        >
          Todos
        </button>
        <button
          :for={cat <- Habit.categories()}
          phx-click="filter"
          phx-value-category={cat}
          class={filter_btn_class(@category_filter == cat)}
        >
          {Habit.category_label(cat)}
        </button>
      </div>

      <div class="mt-6 space-y-4">
        <div
          :if={@habits == []}
          class="text-center py-12 text-gray-500 bg-gray-50 rounded-lg border-2 border-dashed border-gray-200"
        >
          <p class="text-lg font-medium">Nenhum hábito encontrado.</p>
          <p class="text-sm mt-1">Crie seu primeiro hábito sustentável!</p>
        </div>

        <div :for={habit <- @habits} class="bg-white rounded-lg shadow p-5 flex items-start gap-4">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <h3 class="text-base font-semibold text-gray-900">{habit.name}</h3>
              <span class={"text-xs font-medium px-2 py-0.5 rounded-full #{Habit.category_color(habit.category)}"}>
                {Habit.category_label(habit.category)}
              </span>
            </div>
            <p :if={habit.description} class="mt-1 text-sm text-gray-600 line-clamp-2">
              {habit.description}
            </p>
            <p class="mt-2 text-sm font-medium text-green-700">+{habit.points} pontos</p>
          </div>

          <div class="flex items-center gap-2 shrink-0">
            <.link patch={~p"/habits/#{habit}/edit"} class="text-sm text-blue-600 hover:text-blue-800 font-medium">
              Editar
            </.link>
            <button
              phx-click="delete"
              phx-value-id={habit.id}
              data-confirm="Tem certeza que deseja remover este hábito?"
              class="text-sm text-red-600 hover:text-red-800 font-medium"
            >
              Remover
            </button>
          </div>
        </div>
      </div>

      <.modal
        :if={@live_action in [:new, :edit]}
        id="habit-modal"
        show
        on_cancel={JS.patch(~p"/habits")}
      >
        <.live_component
          module={EcoHabitsWeb.HabitLive.FormComponent}
          id={@habit.id || :new}
          title={@page_title}
          action={@live_action}
          habit={@habit}
          current_user={@current_user}
          patch={~p"/habits"}
        />
      </.modal>
    </div>
    """
  end

  defp filter_btn_class(true),
    do:
      "px-3 py-1.5 rounded-full text-sm font-medium bg-green-600 text-white transition-colors"

  defp filter_btn_class(false),
    do:
      "px-3 py-1.5 rounded-full text-sm font-medium bg-gray-100 text-gray-700 hover:bg-gray-200 transition-colors"
end
