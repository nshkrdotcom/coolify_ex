defmodule CoolifyEx.TestSupport.FakeGit do
  @moduledoc false

  @behaviour CoolifyEx.GitBehaviour

  def set_current_branch(branch) do
    Process.put({__MODULE__, :branch}, branch)
  end

  def allow_push do
    Process.put({__MODULE__, :push_result}, :ok)
  end

  @impl true
  def current_branch(_repo_root) do
    {:ok, Process.get({__MODULE__, :branch}, "main")}
  end

  @impl true
  def push(_repo_root, _remote, _branch) do
    Process.get({__MODULE__, :push_result}, :ok)
  end
end
