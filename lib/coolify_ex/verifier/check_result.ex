defmodule CoolifyEx.Verifier.CheckResult do
  @moduledoc """
  Result of a single readiness or verification check.
  """

  @enforce_keys [:phase, :name, :url]
  defstruct [:phase, :name, :url, :status, :reason, ok?: false]

  @type phase :: :readiness | :verification

  @type t :: %__MODULE__{
          phase: phase(),
          name: String.t(),
          url: String.t(),
          status: non_neg_integer() | nil,
          reason: String.t() | nil,
          ok?: boolean()
        }
end
