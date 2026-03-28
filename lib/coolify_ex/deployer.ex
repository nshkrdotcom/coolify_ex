defmodule CoolifyEx.Deployer do
  @moduledoc """
  High-level deployment orchestration for a configured Coolify app.
  """

  alias CoolifyEx.Config
  alias CoolifyEx.Deployment

  @success_statuses ~w(finished success)
  @failure_statuses ~w(failed canceled cancelled error)

  @spec deploy(Config.t(), String.t() | atom(), keyword()) ::
          {:ok, Deployment.t()} | {:error, term()}
  def deploy(%Config{} = config, app_name, opts \\ []) do
    client = Keyword.get(opts, :client, CoolifyEx.Client)
    git = Keyword.get(opts, :git, CoolifyEx.Git)
    sleep_fun = Keyword.get(opts, :sleep, &:timer.sleep/1)
    push? = Keyword.get(opts, :push?, true)
    poll_interval = Keyword.get(opts, :poll_interval, 3_000)
    timeout = Keyword.get(opts, :timeout, 900_000)

    with {:ok, app} <- Config.fetch_app(config, app_name),
         :ok <- maybe_push(git, config.repo_root, app.git_remote, app.git_branch, push?),
         {:ok, deployment} <-
           client.start_deployment(config.base_url, config.token, app.app_uuid,
             force: Keyword.get(opts, :force, false),
             instant: Keyword.get(opts, :instant, false)
           ) do
      poll_deployment(client, config, deployment.uuid, sleep_fun, poll_interval, timeout)
    end
  end

  defp maybe_push(_git, _repo_root, _remote, _branch, false), do: :ok

  defp maybe_push(git, repo_root, remote, branch, true) do
    with {:ok, current_branch} <- git.current_branch(repo_root),
         true <- current_branch == branch or {:error, {:branch_mismatch, current_branch, branch}} do
      git.push(repo_root, remote, branch)
    end
  end

  defp poll_deployment(client, config, deployment_uuid, sleep_fun, poll_interval, timeout) do
    started_at = System.monotonic_time(:millisecond)
    do_poll(client, config, deployment_uuid, sleep_fun, poll_interval, timeout, started_at)
  end

  defp do_poll(client, config, deployment_uuid, sleep_fun, poll_interval, timeout, started_at) do
    with {:ok, deployment} <-
           client.fetch_deployment(config.base_url, config.token, deployment_uuid) do
      cond do
        deployment.status in @success_statuses ->
          {:ok, deployment}

        deployment.status in @failure_statuses ->
          {:error, {:deployment_failed, deployment}}

        System.monotonic_time(:millisecond) - started_at > timeout ->
          {:error, {:deployment_timeout, deployment}}

        true ->
          sleep_fun.(poll_interval)
          do_poll(client, config, deployment_uuid, sleep_fun, poll_interval, timeout, started_at)
      end
    end
  end
end
