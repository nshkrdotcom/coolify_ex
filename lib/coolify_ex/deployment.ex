defmodule CoolifyEx.Deployment do
  @moduledoc """
  Normalized deployment metadata returned by the Coolify API.
  """

  alias CoolifyEx.LogLine

  @enforce_keys [:uuid]
  defstruct [:uuid, :status, :deployment_url, :commit, logs: []]

  @type t :: %__MODULE__{
          uuid: String.t(),
          status: String.t() | nil,
          deployment_url: String.t() | nil,
          commit: String.t() | nil,
          logs: [LogLine.t()]
        }
end
