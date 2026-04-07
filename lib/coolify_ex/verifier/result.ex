defmodule CoolifyEx.Verifier.Result do
  @moduledoc """
  Aggregate result from readiness waiting plus post-ready verification.
  """

  alias CoolifyEx.Verifier.PhaseResult

  @enforce_keys [:app, :readiness, :verification]
  defstruct [:app, :readiness, :verification]

  @type t :: %__MODULE__{
          app: String.t(),
          readiness: PhaseResult.t(),
          verification: PhaseResult.t()
        }
end
