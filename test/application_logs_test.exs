defmodule CoolifyEx.ApplicationLogsTest do
  use ExUnit.Case, async: true

  alias CoolifyEx.ApplicationLogs
  alias CoolifyEx.LogLine
  alias CoolifyEx.TestSupport.FakeClient

  setup do
    System.put_env("COOLIFY_BASE_URL", "https://coolify.example.com")
    System.put_env("COOLIFY_TOKEN", "token-123")
    System.put_env("COOLIFY_WEB_APP_UUID", "app-123")

    on_exit(fn ->
      System.delete_env("COOLIFY_BASE_URL")
      System.delete_env("COOLIFY_TOKEN")
      System.delete_env("COOLIFY_WEB_APP_UUID")
    end)

    %{config: config()}
  end

  test "fetch resolves the manifest app before calling the client", %{config: config} do
    FakeClient.set_fetch_application_log_responses([
      {:ok,
       %ApplicationLogs{
         app_uuid: "app-123",
         raw: "booted\nhandled request",
         logs: [%LogLine{output: "booted"}, %LogLine{output: "handled request"}]
       }}
    ])

    assert {:ok, application_logs} =
             ApplicationLogs.fetch(config, nil, client: FakeClient, lines: 150)

    assert application_logs.app_name == "web"
    assert application_logs.app_uuid == "app-123"
    assert Enum.map(application_logs.logs, & &1.output) == ["booted", "handled request"]
  end

  test "delta only returns newly observed lines across overlapping tails" do
    previous = %ApplicationLogs{app_uuid: "app-123", logs: outputs(["a", "b", "c"])}
    current = %ApplicationLogs{app_uuid: "app-123", logs: outputs(["b", "c", "d"])}

    assert Enum.map(ApplicationLogs.delta(previous, current), & &1.output) == ["d"]
  end

  test "follow emits the initial tail and then only new lines", %{config: config} do
    FakeClient.set_fetch_application_log_responses([
      {:ok, %ApplicationLogs{app_uuid: "app-123", logs: outputs(["booted", "listening"])}},
      {:ok,
       %ApplicationLogs{app_uuid: "app-123", logs: outputs(["booted", "listening", "req 1"])}},
      {:ok, %ApplicationLogs{app_uuid: "app-123", logs: outputs(["listening", "req 1", "req 2"])}}
    ])

    collector = self()

    assert :ok =
             ApplicationLogs.follow(
               config,
               nil,
               fn line -> send(collector, {:line, line.output}) end,
               client: FakeClient,
               lines: 100,
               poll_interval: 0,
               sleep_fun: fn _ -> :ok end,
               max_polls: 2
             )

    assert_received {:line, "booted"}
    assert_received {:line, "listening"}
    assert_received {:line, "req 1"}
    assert_received {:line, "req 2"}
  end

  defp config do
    path = Path.join([__DIR__, "fixtures", "coolify_manifest.exs"])
    {:ok, config} = CoolifyEx.Config.load(path)
    config
  end

  defp outputs(lines) do
    Enum.map(lines, &%LogLine{output: &1})
  end
end
