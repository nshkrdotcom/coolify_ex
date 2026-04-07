defmodule CoolifyEx.Config do
  @moduledoc """
  Loads and normalizes deployment manifests.

  By default, `CoolifyEx` looks for one of these manifest files, searching the
  current directory and then parent directories until it reaches the filesystem
  root:

  - `.coolify_ex.exs`
  - `.coolify.exs`
  - `coolify.exs`

  The manifest itself is a local Elixir file that returns a map or keyword list.
  Secrets can be provided directly or resolved from environment variables with
  `{:env, "NAME"}` tuples.
  """

  alias CoolifyEx.Config.App
  alias CoolifyEx.HTTPCheck

  @default_manifest_names [".coolify_ex.exs", ".coolify.exs", "coolify.exs"]

  @enforce_keys [:base_url, :token, :projects]
  defstruct [
    :base_url,
    :token,
    :default_project,
    :manifest_path,
    :repo_root,
    projects: %{}
  ]

  @type env_source :: %{optional(String.t()) => String.t()}

  @type t :: %__MODULE__{
          base_url: String.t(),
          token: String.t(),
          default_project: String.t() | nil,
          projects: %{optional(String.t()) => App.t()},
          manifest_path: Path.t(),
          repo_root: Path.t()
        }

  @spec default_manifest_names() :: [String.t()]
  def default_manifest_names, do: @default_manifest_names

  @spec load(Path.t() | nil, keyword()) :: {:ok, t()} | {:error, term()}
  def load(path \\ nil, opts \\ []) do
    env = Keyword.get(opts, :env, System.get_env())

    with {:ok, manifest_path} <- resolve_manifest_path(path, opts),
         {:ok, raw_manifest} <- read_manifest(manifest_path) do
      normalize_manifest(raw_manifest, manifest_path, env)
    end
  end

  @spec fetch_project(t(), String.t() | atom() | nil) :: {:ok, App.t()} | {:error, term()}
  def fetch_project(config, project_name \\ nil)

  def fetch_project(%__MODULE__{default_project: nil}, nil),
    do: {:error, :default_project_not_configured}

  def fetch_project(%__MODULE__{default_project: default_project} = config, nil) do
    fetch_project(config, default_project)
  end

  def fetch_project(%__MODULE__{projects: projects}, project_name) do
    key = normalize_name(project_name)

    case Map.fetch(projects, key) do
      {:ok, project} -> {:ok, project}
      :error -> {:error, {:unknown_project, key}}
    end
  end

  @spec fetch_app(t(), String.t() | atom() | nil) :: {:ok, App.t()} | {:error, term()}
  def fetch_app(config, app_name \\ nil), do: fetch_project(config, app_name)

  defp resolve_manifest_path(nil, opts) do
    cwd = Keyword.get(opts, :cwd, File.cwd!())

    case discover_manifest_path(cwd) do
      nil -> {:error, {:manifest_not_found, Path.expand(cwd), @default_manifest_names}}
      path -> {:ok, path}
    end
  end

  defp resolve_manifest_path(path, _opts) do
    manifest_path = Path.expand(path)

    if File.exists?(manifest_path) do
      {:ok, manifest_path}
    else
      {:error, {:manifest_not_found, manifest_path}}
    end
  end

  defp discover_manifest_path(start_dir) do
    start_dir
    |> Path.expand()
    |> do_discover_manifest_path()
  end

  defp do_discover_manifest_path(dir) do
    case Enum.find(@default_manifest_names, &File.exists?(Path.join(dir, &1))) do
      nil ->
        parent = Path.dirname(dir)

        if parent == dir do
          nil
        else
          do_discover_manifest_path(parent)
        end

      name ->
        Path.join(dir, name)
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
         {:ok, projects} <- normalize_projects(project_entries(manifest), repo_root, env) do
      default_project =
        manifest
        |> Map.get(:default_project)
        |> normalize_optional_name()

      {:ok,
       %__MODULE__{
         base_url: base_url,
         token: token,
         default_project: default_project,
         projects: projects,
         manifest_path: manifest_path,
         repo_root: repo_root
       }}
    end
  end

  defp normalize_projects(nil, _repo_root, _env), do: {:error, :projects_not_configured}

  defp normalize_projects(projects, repo_root, env) do
    projects
    |> normalize_container()
    |> Enum.reduce_while({:ok, %{}}, fn {name, attrs}, {:ok, acc} ->
      case normalize_project(name, attrs, repo_root, env) do
        {:ok, project} -> {:cont, {:ok, Map.put(acc, project.name, project)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_project(name, attrs, repo_root, env) do
    attrs = normalize_container(attrs)
    project_name = normalize_name(name)
    project_path = normalize_project_path(Map.get(attrs, :project_path, "."), repo_root)

    with {:ok, app_uuid} <- fetch_required(attrs, :app_uuid, env),
         :ok <- validate_project_path(project_path, repo_root, project_name) do
      public_base_url =
        attrs
        |> Map.get(:public_base_url)
        |> resolve_value(env)

      with {:ok, readiness} <- normalize_readiness(project_name, attrs, public_base_url, env),
           {:ok, verification_checks} <-
             normalize_verification(project_name, attrs, public_base_url, env) do
        {:ok,
         %App{
           name: project_name,
           app_uuid: app_uuid,
           git_branch: Map.get(attrs, :git_branch, "main"),
           git_remote: Map.get(attrs, :git_remote, "origin"),
           project_path: project_path,
           public_base_url: public_base_url,
           readiness_initial_delay_ms: readiness.initial_delay_ms,
           readiness_poll_interval_ms: readiness.poll_interval_ms,
           readiness_timeout_ms: readiness.timeout_ms,
           readiness_checks: readiness.checks,
           verification_checks: verification_checks
         }}
      end
    end
  end

  defp normalize_readiness(project_name, attrs, public_base_url, env) do
    case Map.get(attrs, :readiness) do
      nil ->
        {:error, {:missing_required_value, {:projects, project_name, :readiness}}}

      readiness ->
        readiness = normalize_container(readiness)

        with {:ok, checks} <-
               normalize_checks(Map.get(readiness, :checks, []), public_base_url, env),
             :ok <- validate_non_empty_checks(checks, {:projects, project_name, :readiness}),
             {:ok, initial_delay_ms} <-
               normalize_non_negative_integer(
                 Map.get(readiness, :initial_delay_ms, 0),
                 {:projects, project_name, :readiness_initial_delay_ms}
               ),
             {:ok, poll_interval_ms} <-
               normalize_positive_integer(
                 Map.get(readiness, :poll_interval_ms, 2_000),
                 {:projects, project_name, :readiness_poll_interval_ms}
               ),
             {:ok, timeout_ms} <-
               normalize_positive_integer(
                 Map.get(readiness, :timeout_ms, 120_000),
                 {:projects, project_name, :readiness_timeout_ms}
               ) do
          {:ok,
           %{
             initial_delay_ms: initial_delay_ms,
             poll_interval_ms: poll_interval_ms,
             timeout_ms: timeout_ms,
             checks: checks
           }}
        end
    end
  end

  defp normalize_verification(_project_name, attrs, public_base_url, env) do
    checks =
      attrs
      |> Map.get(:verification, %{})
      |> normalize_optional_container()
      |> Map.get(:checks, [])

    normalize_checks(checks, public_base_url, env)
  end

  defp normalize_checks(checks, public_base_url, env) when is_list(checks) do
    {:ok, Enum.map(checks, &normalize_check(&1, public_base_url, env))}
  end

  defp normalize_checks(_checks, _public_base_url, _env),
    do: {:error, {:invalid_checks, :expected_list}}

  defp normalize_check(raw_check, public_base_url, env) do
    check = normalize_container(raw_check)
    url = Map.fetch!(check, :url) |> resolve_value(env)

    %HTTPCheck{
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
    do: raise(ArgumentError, "unsupported HTTP check method: #{inspect(other)}")

  defp normalize_project_path(path, repo_root) do
    Path.relative_to(Path.expand(path, repo_root), repo_root)
  end

  defp project_entries(manifest) do
    Map.get(manifest, :projects)
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

  defp validate_non_empty_checks([], key), do: {:error, {:missing_required_value, key}}
  defp validate_non_empty_checks(_checks, _key), do: :ok

  defp normalize_non_negative_integer(value, _key) when is_integer(value) and value >= 0,
    do: {:ok, value}

  defp normalize_non_negative_integer(_value, key), do: {:error, {:invalid_integer, key}}

  defp normalize_positive_integer(value, _key) when is_integer(value) and value > 0,
    do: {:ok, value}

  defp normalize_positive_integer(_value, key), do: {:error, {:invalid_integer, key}}

  defp normalize_container(value) when is_map(value), do: value
  defp normalize_container(value) when is_list(value), do: Map.new(value)
  defp normalize_optional_container(nil), do: %{}
  defp normalize_optional_container(value), do: normalize_container(value)

  defp normalize_name(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_name(value) when is_binary(value), do: value

  defp normalize_optional_name(nil), do: nil
  defp normalize_optional_name(value), do: normalize_name(value)
end
