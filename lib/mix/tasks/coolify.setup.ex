defmodule Mix.Tasks.Coolify.Setup do
  use Mix.Task

  @shortdoc "Prints a remote-server onboarding checklist for CoolifyEx"

  alias CoolifyEx.Config

  @moduledoc """
  Validates a local workstation or remote server for `CoolifyEx` usage.

      mix coolify.setup
      mix coolify.setup --config config/coolify.exs
  """

  @required_tools ~w(git curl mix)

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [config: :string])
    config_path = Keyword.get(opts, :config, "coolify.exs")

    Mix.shell().info("CoolifyEx remote setup")
    Mix.shell().info("=======================")

    Enum.each(@required_tools, fn tool ->
      status = if System.find_executable(tool), do: "ok", else: "missing"
      Mix.shell().info("tool #{tool}: #{status}")
    end)

    case Config.load(config_path) do
      {:ok, config} ->
        Mix.shell().info("manifest: ok (#{config.manifest_path})")
        Mix.shell().info("base url: #{config.base_url}")
        Mix.shell().info("apps: #{Enum.join(Map.keys(config.apps), ", ")}")

      {:error, _reason} ->
        Mix.shell().error("manifest: missing or invalid (expected #{Path.expand(config_path)})")
        Mix.shell().info("copy coolify.example.exs to coolify.exs and edit it for your project")
    end

    Enum.each(~w(COOLIFY_BASE_URL COOLIFY_TOKEN), fn name ->
      status = if System.get_env(name), do: "set", else: "missing"
      Mix.shell().info("env #{name}: #{status}")
    end)

    Mix.shell().info("")
    Mix.shell().info("Next steps:")
    Mix.shell().info("1. Edit coolify.exs with your app UUID, branch, and smoke checks.")
    Mix.shell().info("2. Export COOLIFY_BASE_URL and COOLIFY_TOKEN on this server.")
    Mix.shell().info("3. Run mix coolify.deploy to push, deploy, and verify.")
  end
end
