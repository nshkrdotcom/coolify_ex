defmodule CoolifyEx.Target do
  @moduledoc false

  alias CoolifyEx.Config

  @type t :: %__MODULE__{
          project_name: String.t() | nil,
          app_uuid: String.t()
        }

  defstruct [:project_name, :app_uuid]

  @spec resolve(Config.t(), String.t() | atom() | nil, keyword()) :: {:ok, t()} | {:error, term()}
  def resolve(%Config{} = config, project_name \\ nil, opts \\ []) do
    app_uuid = Keyword.get(opts, :app_uuid)

    cond do
      is_binary(app_uuid) and project_name not in [nil, ""] ->
        {:error, {:ambiguous_target, normalize_name(project_name), app_uuid}}

      is_binary(app_uuid) ->
        {:ok, %__MODULE__{app_uuid: app_uuid}}

      true ->
        resolve_project(config, project_name)
    end
  end

  defp resolve_project(config, project_name) do
    with {:ok, app} <- Config.fetch_app(config, project_name) do
      case Map.get(app, :app_uuid) do
        app_uuid when is_binary(app_uuid) and app_uuid != "" ->
          {:ok, %__MODULE__{project_name: app.name, app_uuid: app_uuid}}

        _other ->
          {:error, {:missing_app_uuid, app.name}}
      end
    end
  end

  defp normalize_name(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_name(value) when is_binary(value), do: value
end
