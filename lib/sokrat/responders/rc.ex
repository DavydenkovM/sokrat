defmodule Sokrat.Responders.RC do
  @moduledoc """
  Lists latest branches deployed on rc servers.
  """

  alias Sokrat.{Repo, Slack, Models}
  import Ecto.Query, only: [from: 2, join: 5, order_by: 3]
  use Hedwig.Responder
  use Timex

  @usage """
  hedwig up rc101 - Command to show that particular staging server reserved
  """
  respond ~r/up\s(?<server_name>[a-z\d]*)$/i, msg, state do
    key = msg.matches["server_name"]
    slack_username_id = msg.user.id

    from(a in Models.Revision, where: a.server == ^key)
    |> Repo.update_all(set: [slack_username_id: slack_username_id, status: :reserved])

    respond_to_rc(msg)
  end

  @usage """
  hedwig down rc101 - Command to show that particular staging server available
  """
  respond ~r/down\s(?<server_name>[a-z\d]*)$/i, msg, state do
    key = msg.matches["server_name"]
    slack_username_id = msg.user.id

    from(a in Models.Revision, where: a.server == ^key)
    |> Repo.update_all(set: [slack_username_id: nil, status: :available])

    respond_to_rc(msg)
  end

  @usage """
  hedwig rc - Shows latest deployed branches.
  """
  respond ~r/rc$/i, msg do
    respond_to_rc(msg)
  end

  defp respond_to_rc(msg) do
    Repo.all(Models.Application)
    |> Enum.each(&send_revisions(&1, msg.room))
  end

  @usage """
  hedwig rc <app> - Shows latest deployed branches for particular <app>.
                    Available options are: rails, php, js.
  """
  respond ~r/rc\s(?<app>[a-z]*)$/i, msg do
    key = msg.matches["app"]
    Repo.all(from a in Models.Application, where: a.key == ^key)
    |> Enum.each(&send_revisions(&1, msg.room))
  end

  defp send_revisions(app, room) do
    revisions = revisions_list(app)
    Keyword.merge(message_opts(app, revisions), [channel: room])
    |> Slack.chat_message
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
    attachments = [
      %{
        "color": "good",
        "pretext": app.name,
        "fields": Enum.map(revisions, &revision_info/1)
      }
    ]
    [attachments: Poison.encode!(attachments)]
  end

  defp revision_info(revision) do
    deployed_at = revision.deployed_at
    |> Timex.shift(hours: 3)
    |> Timex.format!("%Y-%m-%d %H:%M", :strftime)

    %{
      "title": "#{revision.server} [#{revision.status |> format_status}] ",
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
