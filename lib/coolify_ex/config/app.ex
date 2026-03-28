defmodule CoolifyEx.Config.App do
  @moduledoc """
  One app entry from a `coolify.exs` manifest.
  """

  alias CoolifyEx.SmokeCheck

  @enforce_keys [:name, :app_uuid]
  defstruct [
    :name,
    :app_uuid,
    git_branch: "main",
    git_remote: "origin",
    project_path: ".",
    public_base_url: nil,
    smoke_checks: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          app_uuid: String.t(),
          git_branch: String.t(),
          git_remote: String.t(),
          project_path: String.t(),
          public_base_url: String.t() | nil,
          smoke_checks: [SmokeCheck.t()]
        }
end
