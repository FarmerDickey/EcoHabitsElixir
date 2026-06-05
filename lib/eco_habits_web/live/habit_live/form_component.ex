defmodule EcoHabitsWeb.HabitLive.FormComponent do
  use EcoHabitsWeb, :live_component

  alias EcoHabits.Habits
  alias EcoHabits.Habits.Habit

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Preencha os dados do hábito sustentável.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="habit-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Nome" placeholder="Ex: Usar bicicleta no trabalho" />
        <.input
          field={@form[:description]}
          type="textarea"
          label="Descrição"
          placeholder="Descreva o hábito e seus benefícios ambientais..."
        />
        <.input
          field={@form[:category]}
          type="select"
          label="Categoria"
          options={category_options()}
          prompt="Selecione uma categoria"
        />
        <.input
          field={@form[:points]}
          type="number"
          label="Pontuação"
          min="1"
          max="1000"
          placeholder="Ex: 10"
        />
        <:actions>
          <.button phx-disable-with="Salvando...">Salvar Hábito</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{habit: habit} = assigns, socket) do
    changeset = Habits.change_habit(habit)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"habit" => habit_params}, socket) do
    changeset =
      socket.assigns.habit
      |> Habits.change_habit(habit_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"habit" => habit_params}, socket) do
    save_habit(socket, socket.assigns.action, habit_params)
  end

  defp save_habit(socket, :edit, habit_params) do
    case Habits.update_habit(socket.assigns.habit, habit_params) do
      {:ok, habit} ->
        notify_parent({:saved, habit})

        {:noreply,
         socket
         |> put_flash(:info, "Hábito atualizado com sucesso!")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_habit(socket, :new, habit_params) do
    case Habits.create_habit(habit_params, socket.assigns.current_user) do
      {:ok, habit} ->
        notify_parent({:saved, habit})

        {:noreply,
         socket
         |> put_flash(:info, "Hábito criado com sucesso!")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp category_options do
    Habit.categories()
    |> Enum.map(fn cat -> {Habit.category_label(cat), cat} end)
  end
end
