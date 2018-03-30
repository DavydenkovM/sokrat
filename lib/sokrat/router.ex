defmodule Sokrat.Router do
  alias Sokrat.{Slack, Repo, Models.Application, Models.ConflictUser, Models.Revision, Responders.RC}
  import Ecto.Query, only: [select: 3, from: 2]
  import RevisionServerStatus
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug Plug.Parsers, parsers: [:json, :urlencoded],
                     pass: ["application/json", "application/x-www-form-urlencoded"],
                     json_decoder: Poison
  plug :set_resp_content_type
  plug :dispatch

  get "/ping" do
    send_resp(conn, 200, Poison.encode!("pong"))
  end

  get "/applications" do
    apps = Application |> select([a], map(a, [:id, :key, :name])) |> Repo.all
    send_resp(conn, 200, Poison.encode!(apps))
  end

  post "/applications" do
    params = conn.body_params

    {status, changeset} = create_application(params)
    respond(conn, status, changeset)
  end

  post "/applications/:app_key/revisions" do
    params = conn.body_params

    app = Repo.get_by!(Application, key: app_key)
    {status, changeset} = create_revision(app, params)
    respond(conn, status, changeset)
  end

  post "/conflict" do
    params = conn.body_params
    username = Map.get(params, "author", "")

    ConflictUser
    |> Ecto.Query.where(bitbucket_username: ^username, enabled: true)
    |> Repo.one
    |> case do
         nil -> send_resp(conn, 400, "")
         user ->
           # TODO: should be async
           notify_about_conflict(user, params)
           send_resp(conn, 200, "")
       end
  end

  defp send_revisions(app, %{"channel_id" => channel_id}) do
    RC.send_revisions(app, channel_id)
  end

  post "/slash-commands/status" do
    IO.inspect "123123"
    params = conn.body_params

    IO.inspect params

    Repo.all(Application)
    |> Enum.each(&RC.send_revisions_ephemeral(&1, params["channel_id"], params["user_id"]))

    send_resp(conn, 200, "")
  end

  post "/slash-commands/status/:app_key" do
    params = conn.body_params

    IO.inspect params

    app = Repo.get_by!(Application, key: app_key)
    RC.send_revisions_ephemeral(app, params["channel_id"], params["user_id"])

    send_resp(conn, 200, "")
  end

  post "/slash-commands/status-public" do
    params = conn.body_params

    Repo.all(Application)
    |> Enum.each(&send_revisions(&1, params))

    send_resp(conn, 200, "")
  end

  post "/slash-commands/status-public/:app_key" do
    params = conn.body_params
    IO.inspect params
    app = Repo.get_by!(Application, key: app_key)
    RC.send_revisions(app, params["channel_id"])

    send_resp(conn, 200, "")
  end

#  post "/rc_status" do
#    params = conn.body_params
#
#    channel_id = params["channel_id"]
#    user_id = params["user_id"]
#    text = params["text"]
#
#    if text == "public" do
#      Repo.all(Application)
#      |> Enum.each(&RC.send_revisions(&1, channel_id))
#    else
#      Repo.all(Application)
#      |> Enum.each(&RC.send_revisions_ephemeral(&1, channel_id, user_id))
#    end
#
#    send_resp(conn, 200, "")
#  end

  post "/rc_actions" do
    params = conn.body_params

    callback_id = params["callback_id"]

    actions = Map.get(params, "actions", [])

    # Value examples:
    # "reserve_rc101_rails"
    # "free_rc102_js"
    button_value = Enum.at(actions, 0)["value"]

    button_value_params = String.split(button_value, "_")
    action = Enum.at(button_value_params, 0)
    server_name = Enum.at(button_value_params, 1)
    app_key = Enum.at(button_value_params, 2)

    user = Map.get(params, "user", %{})
    channel = Map.get(params, "channel", %{})

    slack_username_id = user["id"]

    app = Repo.one(from a in Application, where: a.key == ^app_key)

    if action == "reserve" do
      from(a in Revision, where: a.server == ^server_name and a.application_id == ^app.id)
      |> RC.update_revisions_status(:reserved, slack_username_id)
    end

    if action == "free" do
      from(a in Revision, where: a.server == ^server_name and a.application_id == ^app.id)
      |> RC.update_revisions_status(:available, nil)
    end

    if callback_id == "ephemeral" do
      RC.send_revisions_ephemeral(app, channel["id"], slack_username_id, true, params["response_url"])
    else
      RC.send_revisions(app, channel["id"], true, params["message_ts"])
      send_resp(conn, 200, "")
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end

  defp create_application(params) do
    changeset = Application.changeset(%Application{}, params)
    Repo.insert(changeset)
  end

  defp create_revision(application, params) do
    revision = Ecto.build_assoc(application, :revisions, deployed_at: NaiveDateTime.utc_now)
    changeset = Revision.changeset(revision, params)
    Repo.insert(changeset)
  end

  defp notify_about_conflict(user, %{"title" => title, "url" => url, "toBranch" => branch}) do
    text = "Your PR conflicts with #{branch}"
    attachments = [
      %{
        "color": "warning",
        "pretext": text,
        "fallback": text,
        "fields": [
          %{
            "title": "Title",
            "value": "#{title}"
          },
          %{
            "title": "URL",
            "value": "#{url}"
          }
        ]
      }
    ]

    Slack.chat_message(
      channel: "@#{user.slack_username}",
      attachments: Poison.encode!(attachments)
    )
  end

  defp respond(conn, :ok, _) do
    send_resp(conn, 201, "")
  end

  defp respond(conn, :error, changeset) do
    errors = for {field, {message, _}} <- changeset.errors, into: %{}, do: {field, message}
    send_resp(conn, 422, Poison.encode!(%{errors: errors}))
  end

  defp set_resp_content_type(conn, _opts) do
    put_resp_content_type(conn, "application/json")
  end
end
