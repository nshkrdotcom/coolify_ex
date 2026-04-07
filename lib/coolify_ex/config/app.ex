defmodule CoolifyEx.Config.App do
  @moduledoc """
  One project entry from a deployment manifest.
  """

  alias CoolifyEx.HTTPCheck

  @enforce_keys [:name, :app_uuid]
  defstruct [
    :name,
    :app_uuid,
    git_branch: "main",
    git_remote: "origin",
    project_path: ".",
    public_base_url: nil,
    readiness_initial_delay_ms: 0,
    readiness_poll_interval_ms: 2_000,
    readiness_timeout_ms: 120_000,
    readiness_checks: [],
    verification_checks: []
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          app_uuid: String.t(),
          git_branch: String.t(),
          git_remote: String.t(),
          project_path: String.t(),
          public_base_url: String.t() | nil,
          readiness_initial_delay_ms: non_neg_integer(),
          readiness_poll_interval_ms: pos_integer(),
          readiness_timeout_ms: pos_integer(),
          readiness_checks: [HTTPCheck.t()],
          verification_checks: [HTTPCheck.t()]
        }
end
