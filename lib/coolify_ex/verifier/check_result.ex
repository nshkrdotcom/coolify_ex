defmodule CoolifyEx.Verifier.CheckResult do
  @moduledoc """
  Result of a single smoke check.
  """

  @enforce_keys [:name, :url]
  defstruct [:name, :url, :status, :reason, ok?: false]

  @type t :: %__MODULE__{
          name: String.t(),
          url: String.t(),
          status: non_neg_integer() | nil,
          reason: String.t() | nil,
          ok?: boolean()
        }
end
