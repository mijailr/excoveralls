defmodule ExCoveralls.Github do
  @moduledoc """
  Handles GitHub Actions integration with coveralls.
  """
  alias ExCoveralls.Poster

  def execute(stats, options) do
    json = generate_json(stats, Enum.into(options, %{}))

    if options[:verbose] do
      IO.puts(json)
    end

    Poster.execute(json)
  end

  def generate_json(stats, options \\ %{})

  def generate_json(stats, options) do
    %{
      repo_token: get_env("GITHUB_TOKEN"),
      service_name: "github",
      source_files: stats,
      parallel: options[:parallel],
      git: git_info()
    }
    |> Map.merge(job_data())
    |> Jason.encode!
  end
  
  defp get_env(env) do
    env
    |> System.get_env
  end

  defp job_data() do
    get_env("GITHUB_EVENT_NAME")
    |> case do
      "pull_request" ->
        %{
          service_pull_request: get_pr_id(),
          service_job_id: "PR-#{get_pr_id()}",
          git: %{
            head: %{
              id: get_pr_sha(),
              message: get_pr_message()
            }
          }
        }
      _ ->
        %{service_job_id: get_env("GITHUB_SHA")}
    end
  end

  defp get_pr_id do
    event_info()
    |> Map.get("number")
    |> Integer.to_string
  end
  
  def get_committer_name do
    event_info()
    |> Map.get("sender")
    |> Map.get("login")
  end

  def get_pr_sha do
    event_info()
    |> Map.get("pull_request")
    |> Map.get("head")
    |> Map.get("sha")
  end

  def get_pr_message do
    {message, _} = System.cmd("git", ["log", get_pr_sha(), "-1", "--pretty=format:%s"])
    message
  end

  defp event_info do
    get_env("GITHUB_EVENT_PATH")
    |> File.read!()
    |> Jason.decode!()
  end

  defp get_message do
    {message, _} = System.cmd("git", ["log", "-1", "--pretty=format:%s"])
    message
  end

  defp git_info do
    %{
      head: %{
        id: get_env("GITHUB_SHA"),
        committer_name: get_committer_name(),
        message: get_message()
      },
      branch: get_branch()
    }
  end

  defp get_branch do
    get_env("GITHUB_REF")
  end
end
