defmodule CoolifyEx.SmokeCheck do
  @moduledoc """
  A single live-app verification check.
  """

  @enforce_keys [:name, :url]
  defstruct [:name, :url, method: :get, expected_status: 200, expected_body_contains: nil]

  @type method :: :get | :head

  @type t :: %__MODULE__{
          name: String.t(),
          url: String.t(),
          method: method(),
          expected_status: pos_integer(),
          expected_body_contains: String.t() | nil
        }
end
