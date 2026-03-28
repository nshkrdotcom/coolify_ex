defmodule CoolifyEx.Config do
  @moduledoc """
  Loads and normalizes `coolify.exs` manifests.

  A manifest is a local Elixir file that returns a map or keyword list. Secrets
  can be provided directly or resolved from environment variables with
  `{:env, "NAME"}` tuples.
  """

  alias CoolifyEx.Config.App
  alias CoolifyEx.SmokeCheck

  @enforce_keys [:base_url, :token, :apps]
  defstruct [:base_url, :token, :default_app, :manifest_path, :repo_root, apps: %{}]

  @type env_source :: %{optional(String.t()) => String.t()}

  @type t :: %__MODULE__{
          base_url: String.t(),
          token: String.t(),
          default_app: String.t() | nil,
          apps: %{optional(String.t()) => App.t()},
          manifest_path: Path.t(),
          repo_root: Path.t()
        }

  @spec load(Path.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def load(path \\ "coolify.exs", opts \\ []) do
    env = Keyword.get(opts, :env, System.get_env())
    manifest_path = Path.expand(path)

    with true <- File.exists?(manifest_path) or {:error, {:manifest_not_found, manifest_path}},
         {:ok, raw_manifest} <- read_manifest(manifest_path) do
      normalize_manifest(raw_manifest, manifest_path, env)
    end
  end

  @spec fetch_app(t(), String.t() | atom() | nil) :: {:ok, App.t()} | {:error, term()}
  def fetch_app(config, app_name \\ nil)

  def fetch_app(%__MODULE__{default_app: nil}, nil), do: {:error, :default_app_not_configured}

  def fetch_app(%__MODULE__{default_app: default_app} = config, nil) do
    fetch_app(config, default_app)
  end

  def fetch_app(%__MODULE__{apps: apps}, app_name) do
    key = normalize_name(app_name)

    case Map.fetch(apps, key) do
      {:ok, app} -> {:ok, app}
      :error -> {:error, {:unknown_app, key}}
    end
  end

  defp read_manifest(path) do
    {manifest, _binding} = Code.eval_file(path)
    {:ok, manifest}
  rescue
    error -> {:error, {:manifest_eval_failed, path, error}}
  end

  defp normalize_manifest(raw_manifest, manifest_path, env) do
    manifest = normalize_container(raw_manifest)
    repo_root = Path.dirname(manifest_path)

    with {:ok, base_url} <- fetch_required(manifest, :base_url, env),
         {:ok, token} <- fetch_required(manifest, :token, env),
         {:ok, apps} <- normalize_apps(Map.get(manifest, :apps), repo_root, env) do
      {:ok,
       %__MODULE__{
         base_url: base_url,
         token: token,
         default_app: normalize_optional_name(Map.get(manifest, :default_app)),
         apps: apps,
         manifest_path: manifest_path,
         repo_root: repo_root
       }}
    end
  end

  defp normalize_apps(nil, _repo_root, _env), do: {:error, :apps_not_configured}

  defp normalize_apps(apps, repo_root, env) do
    apps
    |> normalize_container()
    |> Enum.reduce_while({:ok, %{}}, fn {name, attrs}, {:ok, acc} ->
      case normalize_app(name, attrs, repo_root, env) do
        {:ok, app} -> {:cont, {:ok, Map.put(acc, app.name, app)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_app(name, attrs, repo_root, env) do
    attrs = normalize_container(attrs)
    app_name = normalize_name(name)
    project_path = normalize_project_path(Map.get(attrs, :project_path, "."), repo_root)

    with {:ok, app_uuid} <- fetch_required(attrs, :app_uuid, env),
         :ok <- validate_project_path(project_path, repo_root, app_name) do
      public_base_url =
        attrs
        |> Map.get(:public_base_url)
        |> resolve_value(env)

      smoke_checks =
        attrs
        |> Map.get(:smoke_checks, [])
        |> Enum.map(&normalize_smoke_check(&1, public_base_url, env))

      {:ok,
       %App{
         name: app_name,
         app_uuid: app_uuid,
         git_branch: Map.get(attrs, :git_branch, "main"),
         git_remote: Map.get(attrs, :git_remote, "origin"),
         project_path: project_path,
         public_base_url: public_base_url,
         smoke_checks: smoke_checks
       }}
    end
  end

  defp normalize_smoke_check(raw_check, public_base_url, env) do
    check = normalize_container(raw_check)
    url = Map.fetch!(check, :url) |> resolve_value(env)

    %SmokeCheck{
      name: Map.fetch!(check, :name),
      url: normalize_check_url(url, public_base_url),
      method: normalize_method(Map.get(check, :method, :get)),
      expected_status: Map.get(check, :expected_status, 200),
      expected_body_contains: Map.get(check, :expected_body_contains)
    }
  end

  defp normalize_check_url("/" <> _ = path, public_base_url) when is_binary(public_base_url) do
    String.trim_trailing(public_base_url, "/") <> path
  end

  defp normalize_check_url(url, _public_base_url), do: url

  defp normalize_method(method) when method in [:get, :head], do: method
  defp normalize_method("GET"), do: :get
  defp normalize_method("HEAD"), do: :head
  defp normalize_method("get"), do: :get
  defp normalize_method("head"), do: :head

  defp normalize_method(other),
    do: raise(ArgumentError, "unsupported smoke check method: #{inspect(other)}")

  defp normalize_project_path(path, repo_root) do
    Path.relative_to(Path.expand(path, repo_root), repo_root)
  end

  defp validate_project_path(project_path, repo_root, app_name) do
    project_dir = Path.expand(project_path, repo_root)

    if File.dir?(project_dir) do
      :ok
    else
      {:error, {:project_path_not_found, app_name, project_path}}
    end
  end

  defp fetch_required(source, key, env) do
    case Map.fetch(source, key) do
      {:ok, value} ->
        case resolve_value(value, env) do
          nil -> {:error, {:missing_required_value, key}}
          resolved -> {:ok, resolved}
        end

      :error ->
        {:error, {:missing_required_value, key}}
    end
  end

  defp resolve_value({:env, name}, env) when is_binary(name), do: Map.get(env, name)
  defp resolve_value(value, _env), do: value

  defp normalize_container(value) when is_map(value), do: value
  defp normalize_container(value) when is_list(value), do: Map.new(value)

  defp normalize_name(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_name(value) when is_binary(value), do: value

  defp normalize_optional_name(nil), do: nil
  defp normalize_optional_name(value), do: normalize_name(value)
end
