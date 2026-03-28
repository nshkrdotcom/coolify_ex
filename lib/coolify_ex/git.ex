defmodule CoolifyEx.Git do
  @moduledoc """
  Thin Git wrapper used by deployment orchestration.
  """

  @behaviour CoolifyEx.GitBehaviour

  @impl true
  def current_branch(repo_root) do
    case System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"],
           cd: repo_root,
           stderr_to_stdout: true
         ) do
      {branch, 0} -> {:ok, String.trim(branch)}
      {output, code} -> {:error, {:git_command_failed, code, output}}
    end
  end

  @impl true
  def push(repo_root, remote, branch) do
    case System.cmd("git", ["push", remote, branch], cd: repo_root, stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, code} -> {:error, {:git_command_failed, code, output}}
    end
  end
end
