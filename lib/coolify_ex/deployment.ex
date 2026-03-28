defmodule CoolifyEx.Deployment do
  @moduledoc """
  Normalized deployment metadata returned by the Coolify API.
  """

  alias CoolifyEx.LogLine

  @enforce_keys [:uuid]
  defstruct [
    :uuid,
    :status,
    :deployment_url,
    :commit,
    :commit_message,
    :created_at,
    :finished_at,
    logs: []
  ]

  @type t :: %__MODULE__{
          uuid: String.t(),
          status: String.t() | nil,
          deployment_url: String.t() | nil,
          commit: String.t() | nil,
          commit_message: String.t() | nil,
          created_at: String.t() | nil,
          finished_at: String.t() | nil,
          logs: [LogLine.t()]
        }
end
