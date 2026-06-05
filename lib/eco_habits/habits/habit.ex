defmodule EcoHabits.Habits.Habit do
  use Ecto.Schema
  import Ecto.Changeset

  @categories ~w(alimentação transporte energia água resíduos)

  schema "habits" do
    field :name, :string
    field :description, :string
    field :category, :string
    field :points, :integer, default: 0

    belongs_to :user, EcoHabits.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(habit, attrs) do
    habit
    |> cast(attrs, [:name, :description, :category, :points])
    |> validate_required([:name, :category, :points])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:category, @categories, message: "deve ser uma categoria válida")
    |> validate_number(:points,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 1000,
      message: "deve ser entre 1 e 1000"
    )
  end

  def categories, do: @categories

  def category_label("alimentação"), do: "Alimentação"
  def category_label("transporte"), do: "Transporte"
  def category_label("energia"), do: "Energia"
  def category_label("água"), do: "Água"
  def category_label("resíduos"), do: "Resíduos"
  def category_label(other), do: other

  def category_color("alimentação"), do: "bg-green-100 text-green-800"
  def category_color("transporte"), do: "bg-blue-100 text-blue-800"
  def category_color("energia"), do: "bg-yellow-100 text-yellow-800"
  def category_color("água"), do: "bg-cyan-100 text-cyan-800"
  def category_color("resíduos"), do: "bg-orange-100 text-orange-800"
  def category_color(_), do: "bg-gray-100 text-gray-800"
end
