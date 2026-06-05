defmodule EcoHabitsWeb.ProfileLive do
  use EcoHabitsWeb, :live_view

  alias EcoHabits.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    form = user |> Accounts.change_user_profile() |> to_form()

    {:ok,
     socket
     |> assign(:page_title, "Meu Perfil")
     |> assign(:form, form)
     |> assign(:saved, false)}
  end

  def handle_event("validate", %{"user" => params}, socket) do
    form =
      socket.assigns.current_user
      |> Accounts.change_user_profile(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"user" => params}, socket) do
    case Accounts.update_user_profile(socket.assigns.current_user, params) do
      {:ok, user} ->
        form = user |> Accounts.change_user_profile() |> to_form()

        {:noreply,
         socket
         |> assign(:current_user, user)
         |> assign(:form, form)
         |> assign(:saved, true)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl">
      <.header>
        Meu Perfil
        <:subtitle>Gerencie suas informações pessoais</:subtitle>
      </.header>

      <div class="mt-6 bg-white shadow rounded-lg p-6">
        <div class="flex items-center mb-6">
          <div class="w-16 h-16 rounded-full bg-green-100 flex items-center justify-center text-2xl font-bold text-green-700">
            <%= String.first(@current_user.name || @current_user.email) |> String.upcase() %>
          </div>
          <div class="ml-4">
            <h2 class="text-xl font-semibold text-gray-900"><%= @current_user.name %></h2>
            <p class="text-gray-500"><%= @current_user.email %></p>
          </div>
          <div class="ml-auto text-center">
            <span class="text-3xl font-bold text-green-600"><%= @current_user.total_score %></span>
            <p class="text-sm text-gray-500">pontos totais</p>
          </div>
        </div>

        <.simple_form
          for={@form}
          phx-change="validate"
          phx-submit="save"
        >
          <.input field={@form[:name]} type="text" label="Nome" required />
          <.input field={@form[:bio]} type="textarea" label="Bio" placeholder="Conte um pouco sobre você e suas metas ambientais..." />

          <:actions>
            <.button phx-disable-with="Salvando...">Salvar Perfil</.button>
            <span :if={@saved} class="text-green-600 text-sm ml-2">Perfil atualizado!</span>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end
end

