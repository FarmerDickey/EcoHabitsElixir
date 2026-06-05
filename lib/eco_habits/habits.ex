defmodule EcoHabits.Habits do
  import Ecto.Query, warn: false
  alias EcoHabits.Repo
  alias EcoHabits.Habits.Habit

  def list_habits(opts \\ []) do
    category = Keyword.get(opts, :category)

    Habit
    |> maybe_filter_by_category(category)
    |> order_by([h], desc: h.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  def list_user_habits(user_id, opts \\ []) do
    category = Keyword.get(opts, :category)

    Habit
    |> where([h], h.user_id == ^user_id)
    |> maybe_filter_by_category(category)
    |> order_by([h], desc: h.inserted_at)
    |> Repo.all()
  end

  def get_habit!(id), do: Repo.get!(Habit, id)

  def get_user_habit!(user_id, id) do
    Repo.get_by!(Habit, id: id, user_id: user_id)
  end

  def create_habit(attrs, user) do
    %Habit{user_id: user.id}
    |> Habit.changeset(attrs)
    |> Repo.insert()
  end

  def update_habit(%Habit{} = habit, attrs) do
    habit
    |> Habit.changeset(attrs)
    |> Repo.update()
  end

  def delete_habit(%Habit{} = habit) do
    Repo.delete(habit)
  end

  def change_habit(%Habit{} = habit, attrs \\ %{}) do
    Habit.changeset(habit, attrs)
  end

  defp maybe_filter_by_category(query, nil), do: query
  defp maybe_filter_by_category(query, ""), do: query
  defp maybe_filter_by_category(query, category), do: where(query, [h], h.category == ^category)
end
