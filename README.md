# EcoHabits — Documentação Técnica

**Disciplina:** T300 - Programação Funcional  
**Instituição:** UNIFOR  
**Tecnologia:** Elixir + Phoenix Framework

---

## Visão Geral

EcoHabits é uma aplicação web para rastreamento de hábitos ecológicos, desenvolvida com **Elixir/Phoenix**, demonstrando os princípios da programação funcional aplicados ao desenvolvimento web moderno.

---

## Como Executar

### Pré-requisitos

- Elixir 1.17+
- Erlang/OTP 25+
- PostgreSQL 14+

### Instalação

```bash
# Instalar dependências
mix deps.get

# Criar e migrar banco de dados
mix ecto.setup

# Iniciar servidor de desenvolvimento
mix phx.server
```

Acesse: `http://localhost:4000`

---

## Módulo A — Autenticação e Perfil

### RF01 — Cadastro de Usuário

**Requisito:** Cadastro com nome, e-mail e senha.

**Implementação:**

O cadastro foi gerado com `mix phx.gen.auth`, que cria toda a infraestrutura de autenticação. O campo `name` foi adicionado manualmente ao schema.

**Arquivos envolvidos:**

`lib/eco_habits/accounts/user.ex` — Schema e changesets do usuário:

```elixir
schema "users" do
  field :email, :string
  field :password, :string, virtual: true, redact: true
  field :hashed_password, :string, redact: true
  field :name, :string, default: ""
  field :bio, :string, default: ""
  field :total_score, :integer, default: 0
  timestamps(type: :utc_datetime)
end

def registration_changeset(user, attrs, opts \\ []) do
  user
  |> cast(attrs, [:email, :password, :name])
  |> validate_required([:name])
  |> validate_length(:name, min: 2, max: 100)
  |> validate_email(opts)
  |> validate_password(opts)
end
```

- `cast/3` — função pura que filtra e converte os atributos recebidos
- `validate_required/2` — garante que nome, e-mail e senha estejam presentes
- `validate_length/3` — valida tamanho dos campos
- A senha é hasheada com `Bcrypt` antes de ser salva (campo `hashed_password`)

`lib/eco_habits_web/controllers/user_registration_html/new.html.heex` — Formulário de cadastro:

```html
<.input field={f[:name]} type="text" label="Nome" required />
<.input field={f[:email]} type="email" label="E-mail" required />
<.input field={f[:password]} type="password" label="Senha" required />
```

`priv/repo/migrations/20260527184151_create_users_auth_tables.exs` — Migração do banco:

```elixir
create table(:users) do
  add :email, :citext, null: false      # citext = case-insensitive
  add :hashed_password, :string, null: false
  add :name, :string, null: false, default: ""
  add :bio, :text, default: ""
  add :total_score, :integer, null: false, default: 0
  timestamps(type: :utc_datetime)
end
```

---

### RF02 — Login e Logout com Sessão Persistente

**Requisito:** Autenticação com sessão que persiste entre visitas.

**Implementação:**

`lib/eco_habits_web/user_auth.ex` — Gerenciamento de sessão:

```elixir
def log_in_user(conn, user, params \\ %{}) do
  token = Accounts.generate_user_session_token(user)
  conn
  |> renew_session()           # Previne fixação de sessão
  |> put_token_in_session(token)
  |> maybe_write_remember_me_cookie(token, params)  # Sessão persistente
  |> redirect(to: signed_in_path(conn))
end
```

- O token de sessão é armazenado no banco de dados (`users_tokens`), não apenas no cookie — isso permite invalidar sessões individuais
- O cookie "lembre-me" (`remember_me`) persiste por **60 dias**
- `renew_session/1` gera novo ID de sessão a cada login para prevenir ataques de fixação

```elixir
def log_out_user(conn) do
  user_token = get_session(conn, :user_token)
  user_token && Accounts.delete_user_session_token(user_token)
  conn
  |> renew_session()
  |> delete_resp_cookie(@remember_me_cookie)
  |> redirect(to: ~p"/")
end
```

- No logout, o token é **deletado do banco** — todas as sessões ativas do usuário naquele token são invalidadas
- O cookie é removido da resposta

`lib/eco_habits/accounts/user_token.ex` — Tokens de sessão:

```elixir
def build_session_token(user) do
  token = :crypto.strong_rand_bytes(32)  # 32 bytes aleatórios
  {token, %UserToken{token: token, context: "session", user_id: user.id}}
end
```

---

### RF03 — Página de Perfil

**Requisito:** Página de perfil com nome e bio editáveis, e pontuação total acumulada.

**Implementação com Phoenix LiveView (RT01):**

`lib/eco_habits_web/live/profile_live.ex` — LiveView do perfil:

```elixir
defmodule EcoHabitsWeb.ProfileLive do
  use EcoHabitsWeb, :live_view
  alias EcoHabits.Accounts

  # Inicializa o estado da página
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    form = user |> Accounts.change_user_profile() |> to_form()
    {:ok, socket |> assign(:form, form) |> assign(:saved, false)}
  end

  # Validação em tempo real enquanto o usuário digita
  def handle_event("validate", %{"user" => params}, socket) do
    form =
      socket.assigns.current_user
      |> Accounts.change_user_profile(params)
      |> Map.put(:action, :validate)
      |> to_form()
    {:noreply, assign(socket, :form, form)}
  end

  # Salva as alterações no banco
  def handle_event("save", %{"user" => params}, socket) do
    case Accounts.update_user_profile(socket.assigns.current_user, params) do
      {:ok, user} ->
        form = user |> Accounts.change_user_profile() |> to_form()
        {:noreply, socket |> assign(:current_user, user) |> assign(:form, form) |> assign(:saved, true)}
      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
```

- `mount/3` — inicializa a LiveView com os dados do usuário logado
- `handle_event("validate", ...)` — valida os campos **em tempo real** sem recarregar a página
- `handle_event("save", ...)` — persiste as alterações no banco de dados
- `to_form/1` — converte um changeset Ecto em um formulário compatível com Phoenix LiveView

`lib/eco_habits/accounts/user.ex` — Changeset de perfil:

```elixir
def profile_changeset(user, attrs) do
  user
  |> cast(attrs, [:name, :bio])
  |> validate_required([:name])
  |> validate_length(:name, min: 2, max: 100)
  |> validate_length(:bio, max: 500)
end
```

`lib/eco_habits/accounts.ex` — Funções de contexto:

```elixir
def update_user_profile(%User{} = user, attrs) do
  user |> User.profile_changeset(attrs) |> Repo.update()
end

def change_user_profile(%User{} = user, attrs \\ %{}) do
  User.profile_changeset(user, attrs)
end
```

---

## Arquitetura e Conceitos Funcionais

### Separação de Responsabilidades (Contextos)

```
lib/
├── eco_habits/              # Lógica de negócio (domínio)
│   ├── accounts.ex          # Contexto: funções públicas de usuários
│   ├── accounts/
│   │   ├── user.ex          # Schema + Changesets (transformações puras)
│   │   ├── user_token.ex    # Schema de tokens de sessão
│   │   └── user_notifier.ex # Envio de e-mails
│   └── repo.ex              # Interface com o banco de dados
│
└── eco_habits_web/          # Interface web (apresentação)
    ├── router.ex            # Definição de rotas
    ├── user_auth.ex         # Plugs de autenticação
    ├── live/
    │   └── profile_live.ex  # LiveView do perfil (RF03)
    └── controllers/         # Controllers HTTP (RF01, RF02)
```

### Changesets — Transformações Puras de Dados

Os **Changesets** do Ecto implementam o conceito funcional de transformações imutáveis:

```elixir
# Cada função recebe um changeset e retorna um novo changeset (sem mutação)
user
|> cast(attrs, [:name, :bio])          # Filtra atributos permitidos
|> validate_required([:name])          # Adiciona erro se ausente
|> validate_length(:name, min: 2)      # Adiciona erro se inválido
```

Nenhum dado é modificado até `Repo.update/1` ser chamado — o changeset é apenas uma **descrição da mudança**.

### Pipeline com Operador `|>`

O operador `|>` (pipe) passa o resultado de uma função como primeiro argumento da próxima, tornando o código legível como uma sequência de transformações:

```elixir
conn
|> renew_session()
|> put_token_in_session(token)
|> maybe_write_remember_me_cookie(token, params)
|> redirect(to: ~p"/")
```

### Pattern Matching

Usado extensivamente para tratar diferentes casos de forma expressiva:

```elixir
case Accounts.update_user_profile(user, params) do
  {:ok, user}        -> # sucesso: atualiza assigns
  {:error, changeset} -> # falha: mostra erros no formulário
end
```

---

## Requisitos Técnicos Atendidos

| Requisito | Descrição | Como foi atendido |
|-----------|-----------|-------------------|
| RT01 | Phoenix LiveView | Página de perfil (`ProfileLive`) usa LiveView com validação em tempo real |
| RT02 | Ecto + PostgreSQL | Todos os dados persistidos via Ecto; migrations versionadas |
| RT03 | mix phx.gen.auth | Autenticação gerada com o gerador oficial do Phoenix |
| RT04 | HEEx + Tailwind CSS | Templates `.heex` com classes Tailwind em todos os componentes |
| RT06 | Changesets com validações | `registration_changeset`, `profile_changeset` com validações explícitas |
| RT07 | Routing via Router | `router.ex` define todos os escopos, pipelines e rotas |

---

## Rotas Implementadas

```
GET  /                          → Página inicial
GET  /users/register            → Formulário de cadastro (RF01)
POST /users/register            → Processar cadastro (RF01)
GET  /users/log_in              → Formulário de login (RF02)
POST /users/log_in              → Processar login (RF02)
DELETE /users/log_out           → Logout (RF02)
GET  /profile                   → Perfil do usuário - LiveView (RF03)
GET  /users/settings            → Configurações (e-mail/senha)
GET  /users/reset_password      → Recuperação de senha
```
