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
      Keyword.merge(message_opts(app, revisions), [channel: room, user: user_id, response_url: response_url, replace_original: true])
      |> Slack.update_ephemeral_message
    else
      Keyword.merge(message_opts(app, revisions), [channel: room, user: user_id])
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
    message_opts(app, revisions, false)
  end

  defp message_opts(app, revisions, ephemeral) do
    callback_id = if ephemeral == true do "ephemeral" else "common" end

    attachments = [
      %{
        "color": "good",
        "pretext": app.name,
        "fields": Enum.map(revisions, fn revisiion -> revision_info(app, revisiion) end),
        "callback_id": callback_id,
        #"replace_original": true,
        "actions": [
          %{
            "name": "rc_action",
            "text": rc_button_text(Enum.at(revisions, 0)),
            "type": "button",
            "style": rc_button_style(Enum.at(revisions, 0)),
            "value": rc_button_value(app, Enum.at(revisions, 0))
          },
          %{
            "name": "rc_action",
            "text": rc_button_text(Enum.at(revisions, 1)),
            "type": "button",
            "style": rc_button_style(Enum.at(revisions, 1)),
            "value": rc_button_value(app, Enum.at(revisions, 1))
          },
          %{
            "name": "rc_action",
            "text": rc_button_text(Enum.at(revisions, 2)),
            "type": "button",
            "style": rc_button_style(Enum.at(revisions, 2)),
            "value": rc_button_value(app, Enum.at(revisions, 2))
          },
          %{
            "name": "rc_action",
            "text": rc_button_text(Enum.at(revisions, 3)),
            "type": "button",
            "style": rc_button_style(Enum.at(revisions, 3)),
            "value": rc_button_value(app, Enum.at(revisions, 3))
          }
        ]
      }
    ]
    [attachments: Poison.encode!(attachments)]
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
      "free_#{revision.server}_#{app.key}"
    else
      "reserve_#{revision.server}_#{app.key}"
    end
  end

  defp revision_info(app, revision) do
    deployed_at = revision.deployed_at
    |> Timex.shift(hours: 3)
    |> Timex.format!("%Y-%m-%d %H:%M", :strftime)

    %{
      "title": "#{revision.server} [#{revision.status |> format_status}]",
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
    "Reserved"
  end
  defp format_status(p) do
    "Available"
  end
end
