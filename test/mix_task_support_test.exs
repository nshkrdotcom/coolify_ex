defmodule CoolifyEx.MixTaskSupportTest do
  use ExUnit.Case, async: false

  alias CoolifyEx.MixTaskSupport

  test "ensure_started!/0 starts the req runtime used by mix tasks" do
    _ = Application.stop(:req)
    _ = Application.stop(:finch)
    _ = Application.stop(:telemetry)

    assert :ok = MixTaskSupport.ensure_started!()

    started_apps =
      Application.started_applications()
      |> Enum.map(&elem(&1, 0))

    assert :req in started_apps
    assert :finch in started_apps
    assert :telemetry in started_apps
  end
end
