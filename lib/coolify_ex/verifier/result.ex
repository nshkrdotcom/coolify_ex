defmodule CoolifyEx.Verifier.Result do
  @moduledoc """
  Aggregate result from smoke-check verification.
  """

  alias CoolifyEx.Verifier.CheckResult

  @enforce_keys [:app, :checks]
  defstruct [:app, :total, :passed, :failed, checks: []]

  @type t :: %__MODULE__{
          app: String.t(),
          total: non_neg_integer(),
          passed: non_neg_integer(),
          failed: non_neg_integer(),
          checks: [CheckResult.t()]
        }
end
