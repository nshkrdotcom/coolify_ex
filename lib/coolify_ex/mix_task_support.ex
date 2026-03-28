defmodule CoolifyEx.MixTaskSupport do
  @moduledoc false

  def ensure_started! do
    case Application.ensure_all_started(:req) do
      {:ok, _started} -> :ok
      {:error, reason} -> Mix.raise("Could not start CoolifyEx task runtime: #{inspect(reason)}")
    end
  end
end
