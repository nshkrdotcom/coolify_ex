defmodule CoolifyEx.LogLine do
  @moduledoc """
  One normalized Coolify deployment log line.
  """

  @enforce_keys [:output]
  defstruct [:timestamp, :output]

  @type t :: %__MODULE__{
          timestamp: String.t() | nil,
          output: String.t()
        }
end
