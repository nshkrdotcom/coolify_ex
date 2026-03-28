defmodule CoolifyEx.ApplicationLogs do
  @moduledoc """
  Normalized runtime logs returned by the Coolify application logs API.

  Use `fetch/3` to resolve a manifest project and retrieve its current runtime
  log tail. Use `follow/4` to poll the same endpoint and emit only newly
  observed lines.
  """

  alias CoolifyEx.Client
  alias CoolifyEx.Config
  alias CoolifyEx.LogLine

  @enforce_keys [:app_uuid]
  defstruct [:app_name, :app_uuid, :raw, logs: []]

  @type t :: %__MODULE__{
          app_name: String.t() | nil,
          app_uuid: String.t(),
          raw: String.t() | nil,
          logs: [LogLine.t()]
        }

  @spec fetch(Config.t(), String.t() | atom() | nil, keyword()) :: {:ok, t()} | {:error, term()}
  def fetch(%Config{} = config, app_name \\ nil, opts \\ []) do
    client = Keyword.get(opts, :client, Client)
    lines = normalize_lines(Keyword.get(opts, :lines, 100))

    with {:ok, app} <- Config.fetch_app(config, app_name),
         {:ok, %__MODULE__{} = application_logs} <-
           client.fetch_application_logs(config.base_url, config.token, app.app_uuid,
             lines: lines
           ) do
      {:ok, %__MODULE__{application_logs | app_name: app.name}}
    end
  end

  @spec follow(Config.t(), String.t() | atom() | nil, (LogLine.t() -> term()), keyword()) ::
          :ok | {:error, term()}
  def follow(%Config{} = config, app_name, callback, opts \\ []) when is_function(callback, 1) do
    sleep_fun = Keyword.get(opts, :sleep_fun, &:timer.sleep/1)
    poll_interval = normalize_poll_interval(Keyword.get(opts, :poll_interval, 2_000))
    max_polls = Keyword.get(opts, :max_polls, :infinity)

    with {:ok, %__MODULE__{} = initial} <- fetch(config, app_name, opts) do
      emit_logs(initial.logs, callback)
      do_follow(config, app_name, callback, initial, opts, sleep_fun, poll_interval, max_polls)
    end
  end

  @spec delta(t() | nil, t()) :: [LogLine.t()]
  def delta(nil, %__MODULE__{logs: logs}), do: logs

  def delta(%__MODULE__{logs: previous_logs}, %__MODULE__{logs: current_logs}) do
    overlap_size = overlap_size(previous_logs, current_logs)
    Enum.drop(current_logs, overlap_size)
  end

  defp do_follow(_config, _app_name, _callback, _previous, _opts, _sleep_fun, _poll_interval, 0),
    do: :ok

  defp do_follow(config, app_name, callback, previous, opts, sleep_fun, poll_interval, max_polls) do
    sleep_fun.(poll_interval)

    case fetch(config, app_name, opts) do
      {:ok, %__MODULE__{} = current} ->
        previous
        |> delta(current)
        |> emit_logs(callback)

        do_follow(
          config,
          app_name,
          callback,
          current,
          opts,
          sleep_fun,
          poll_interval,
          decrement_poll_budget(max_polls)
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp emit_logs(logs, callback) do
    Enum.each(logs, callback)
  end

  defp overlap_size(previous_logs, current_logs) do
    max_overlap = min(length(previous_logs), length(current_logs))

    Enum.find(max_overlap..0//-1, 0, fn size ->
      Enum.take(previous_logs, -size) == Enum.take(current_logs, size)
    end)
  end

  defp decrement_poll_budget(:infinity), do: :infinity

  defp decrement_poll_budget(remaining) when is_integer(remaining) and remaining > 0,
    do: remaining - 1

  defp decrement_poll_budget(remaining), do: remaining

  defp normalize_lines(lines) when is_integer(lines) and lines > 0, do: lines

  defp normalize_lines(lines),
    do:
      raise(
        ArgumentError,
        "application log lines must be a positive integer, got: #{inspect(lines)}"
      )

  defp normalize_poll_interval(interval) when is_integer(interval) and interval >= 0, do: interval

  defp normalize_poll_interval(interval),
    do:
      raise(
        ArgumentError,
        "application log poll interval must be a non-negative integer, got: #{inspect(interval)}"
      )
end
