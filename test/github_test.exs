defmodule ExCoveralls.GithubTest do
  use ExUnit.Case
  import Mock
  alias ExCoveralls.Github

  @content "defmodule Test do\n  def test do\n  end\nend\n"
  @counts [0, 1, nil, nil]
  @source_info [%{name: "test/fixtures/test.ex", source: @content, coverage: @counts}]
  setup do
    # Capture existing values
    orig_vars =
      ~w(GITHUB_ACTION GITHUB_EVENT_NAME GITHUB_EVENT_PATH GITHUB_SHA GITHUB_REF COVERALLS_REPO_TOKEN)
      |> Enum.map(fn var -> {var, System.get_env(var)} end)

    on_exit(fn ->
      # Reset env vars
      for {k, v} <- orig_vars do
        if v != nil do
          System.put_env(k, v)
        else
          System.delete_env(k)
        end
      end
    end)

    # No additional context
    {:ok, []}
  end

  test_with_mock "execute", ExCoveralls.Poster, execute: fn _ -> "result" end do
    assert(Github.execute(@source_info, []) == "result")
  end

  test "generate json for circle" do
    json = Github.generate_json(@source_info)
    assert(json =~ ~r/service_job_id/)
    assert(json =~ ~r/service_name/)
    assert(json =~ ~r/source_files/)
    assert(json =~ ~r/source_files/)
    assert(json =~ ~r/git/)
  end

  test "submits as `github` by default" do
    parsed = Github.generate_json(@source_info) |> Jason.decode!()
    assert(%{"service_name" => "github"} = parsed)
  end

  test "generate from env vars" do
    System.put_env("GITHUB_EVENT_PATH", "test/fixtures/github_event.json")
    System.put_env("GITHUB_SHA", "sha1")
    System.put_env("GITHUB_EVENT_NAME", "pull_request")
    System.put_env("GITHUB_REF", "branch")
    System.put_env("GITHUB_ACTION", "20")
    System.put_env("COVERALLS_REPO_TOKEN", "token")

    {:ok, payload} = Jason.decode(Github.generate_json(@source_info))

    %{"git" => %{"branch" => branch, "head" => %{"committer_name" => committer_name, "id" => id}}} =
      payload

    assert(payload["service_pull_request"] == "206")
    assert(branch == "branch")
    assert(id == "sha1-PR-206")
    assert(committer_name == "username")
    assert(payload["service_number"] == "20")
    assert(payload["repo_token"] == "token")
  end
end
