defmodule CoolifyEx.GitBehaviour do
  @moduledoc false

  @callback current_branch(Path.t()) :: {:ok, String.t()} | {:error, term()}
  @callback push(Path.t(), String.t(), String.t()) :: :ok | {:error, term()}
end
