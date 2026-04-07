defmodule CoolifyEx.Verifier.PhaseResult do
  @moduledoc """
  Aggregate result from one verification phase.
  """

  alias CoolifyEx.Verifier.CheckResult

  @enforce_keys [:name, :checks]
  defstruct [:name, :attempts, :duration_ms, :total, :passed, :failed, checks: []]

  @type t :: %__MODULE__{
          name: :readiness | :verification,
          attempts: pos_integer(),
          duration_ms: non_neg_integer(),
          total: non_neg_integer(),
          passed: non_neg_integer(),
          failed: non_neg_integer(),
          checks: [CheckResult.t()]
        }
end
