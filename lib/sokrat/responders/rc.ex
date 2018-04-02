defmodule Sokrat.Responders.RC do
  @moduledoc """
  Lists latest branches deployed on rc servers.
  """

  alias Sokrat.{Repo, Slack, Models}
  import Ecto.Query, only: [from: 2, join: 5, order_by: 3]
  import EctoEnum
  import RevisionServerStatus
  use Hedwig.Responder
  use Timex


#  @usage """
#  hedwig up rc101 <app> - command to reserve particular server for particular app
#                    Available options are: rails, php, js.
#  """
#  respond ~r/up\s(?<server_name>[a-z\d]*)\s(?<app_name>[a-z\d]*)$/i, msg, state do
#    server_name = msg.matches["server_name"]
#    slack_username_id = msg.user.id
#    app_name = msg.matches["app_name"]
#    app = Repo.one(from a in Models.Application, where: a.key == ^app_name)
#
#    from(a in Models.Revision, where: a.server == ^server_name and a.application_id == ^app.id)
#    |> update_revisions_status(:reserved, slack_username_id)
#
#    respond_to_rc(msg)
#  end

#  @usage """
#  hedwig up rc101 - command to reserve particular server for all available apps
#  """
#  respond ~r/up\s(?<server_name>[a-z\d]*)$/i, msg, state do
#    key = msg.matches["server_name"]
#    slack_username_id = msg.user.id
#
#    from(a in Models.Revision, where: a.server == ^key)
#    |> update_revisions_status(:reserved, slack_username_id)
#
#    respond_to_rc(msg)
#  end


#  @usage """
#  hedwig down rc101 <app> - command to release particular server for particular app (dismiss)
#                    Available options are: rails, php, js.
#  """
#  respond ~r/down\s(?<server_name>[a-z\d]*)\s(?<app_name>[a-z\d]*)$/i, msg, state do
#    server_name = msg.matches["server_name"]
#    app_name = msg.matches["app_name"]
#    app = Repo.one(from a in Models.Application, where: a.key == ^app_name)
#
#    from(a in Models.Revision, where: a.server == ^server_name and a.application_id == ^app.id)
#    |> update_revisions_status(:available, nil)
#
#    respond_to_rc(msg)
#  end

#  @usage """
#  hedwig down rc101 - command to release particular server for all available apps (dismiss)
#  """
#  respond ~r/down\s(?<server_name>[a-z\d]*)$/i, msg, state do
#    key = msg.matches["server_name"]
#
#    from(a in Models.Revision, where: a.server == ^key)
#    |> update_revisions_status(:available, nil)
#
#    respond_to_rc(msg)
#  end

#  @usage """
#  hedwig rc <app> - Shows latest deployed branches for particular <app>.
#                    Available options are: rails, php, js.
#  """
#  respond ~r/rc\s(?<app>[a-z]*)$/i, msg do
#    key = msg.matches["app"]
#    Repo.all(from a in Models.Application, where: a.key == ^key)
#    |> Enum.each(&send_revisions(&1, msg.room, false, ''))
#  end

#  @usage """
#  hedwig rc - Shows latest deployed branches.
#  """
#  respond ~r/rc$/i, msg do
#    respond_to_rc(msg)
#  end

  def update_revisions_status(query, status, slack_username_id) do
    query
    |> Repo.update_all(set: [slack_username_id: slack_username_id, status: status])
  end

#  def respond_to_rc(msg) do
#    Repo.all(Models.Application)
#    |> Enum.each(&send_revisions(&1, msg.room, msg.replace_original))
#  end

#  def respond_to_rc_ephemeral(msg) do
#    Repo.all(Models.Application)
#    |> Enum.each(&send_revisions_ephemeral(&1, msg.room, msg.user))
#  end

  def send_revisions(app, room) do
    send_revisions(app, room, false)
  end

  def send_revisions(app, room, replace_original) do
    send_revisions(app, room, replace_original, "")
  end

  def send_revisions(app, room, replace_original, timestamp) do
    revisions = revisions_list(app)

    if replace_original == true do
      Keyword.merge(message_opts(app, revisions), [channel: room, ts: timestamp])
      |> Slack.update_message
    else
      Keyword.merge(message_opts(app, revisions), [channel: room])
      |> Slack.chat_message
    end
  end

  def send_revisions_ephemeral(app, room, user_id) do
    send_revisions_ephemeral(app, room, user_id, false)
  end

  def send_revisions_ephemeral(app, room, user_id, replace_original) do
    send_revisions_ephemeral(app, room, user_id, replace_original, "")
  end

  def send_revisions_ephemeral(app, room, user_id, replace_original, response_url) do
    revisions = revisions_list(app)

    if replace_original == true do
      #Keyword.merge(message_opts(app, revisions, true), [channel: room, user: user_id, response_url: response_url, replace_original: true])
      #|> Slack.update_ephemeral_message

      Slack.update_ephemeral_message(response_url, Keyword.merge(message_opts(app, revisions, true, true), [channel: room, user: user_id, replace_original: true, response_type: "ephemeral"]))
    else
      Keyword.merge(message_opts(app, revisions, true), [channel: room, user: user_id, response_type: "ephemeral"])
      |> Slack.chat_ephemeral_message
    end
  end

  defp revisions_list(app) do
    Models.Revision
    |> join(:inner_lateral, [r], l in fragment("select t.id from revisions t where t.application_id = ? and t.server = ? order by deployed_at desc limit 1", ^app.id, r.server), r.id == l.id)
    |> order_by([r], [asc: r.server])
    |> Repo.all
  end

  defp message_opts(app, []) do
    attachments = [
      %{
        "color": "warning",
        "pretext": app.name,
        "text": "No revisions"
      }
    ]
    [attachments: Poison.encode!(attachments)]
  end

  defp message_opts(app, revisions) do
    message_opts(app, revisions, false, false)
  end

  defp message_opts(app, revisions, ephemeral) do
    message_opts(app, revisions, ephemeral, false)
  end

  defp message_opts(app, revisions, ephemeral, replace_original) do
    callback_id = if ephemeral == true do "ephemeral" else "common" end

    actions = Enum.map(revisions, fn revisiion -> %{ "name": "rc_action", "text": rc_button_text(revisiion), "type": "button", "style": rc_button_style(revisiion), "value": rc_button_value(app, revisiion) } end)

    options = actions = Enum.map(revisions, fn revision -> %{ "text": rc_button_text(revision), "value": rc_button_value(app, revision) } end)

    actions = [
      %{
        "name": "rc_action",
        "text": "What do you want?",
        "type": "select",
        "options": options
      }
    ]

    attachments = [
      %{
        "color": "good",
        "pretext": app.name,
        "fields": Enum.map(revisions, fn revisiion -> revision_info(app, revisiion) end),
        "callback_id": callback_id,
        #"replace_original": true,
        "actions": actions
      }
    ]

    if ephemeral == true and replace_original == true  do 
      [attachments: attachments] 
    else 
      [attachments: Poison.encode!(attachments)]
    end
  end

  defp rc_button_text(revision) do
    if revision.status == :reserved do
      "Make Free #{String.upcase(revision.server)}"
    else
      "Reserve #{String.upcase(revision.server)}"
    end
  end

  defp rc_button_style(revision) do
    if revision.status == :reserved do
      "danger"
    else
      "primary"
    end
  end

  defp rc_button_value(app, revision) do
    if revision.status == :reserved do
      "free___#{revision.server}___#{app.key}"
    else
      "reserve___#{revision.server}___#{app.key}"
    end
  end

  defp revision_info(app, revision) do
    deployed_at = revision.deployed_at
    |> Timex.shift(hours: 3)
    |> Timex.format!("%Y-%m-%d %H:%M", :strftime)

    %{
      "title": "#{revision.server} #{revision.status |> format_status}",
      "value": "#{format_value(revision.slack_username_id)}\n #{revision.branch}\n #{deployed_at}",
      "short": true
    }
  end

  defp format_value(_slack_username_id = nil) do
    ""
  end
  defp format_value(slack_username_id) do
    "<@#{slack_username_id}>"
  end

  defp format_status(:reserved) do
    "[Reserved] :name_badge:"
  end
  defp format_status(p) do
    "[Available] :white_check_mark:"
  end
end
