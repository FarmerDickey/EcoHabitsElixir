defmodule EcoHabits.Repo do
  use Ecto.Repo,
    otp_app: :eco_habits,
    adapter: Ecto.Adapters.Postgres
end
