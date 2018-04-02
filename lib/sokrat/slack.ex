defmodule Sokrat.Slack do
  @moduledoc false

  @url "https://slack.com"

  def chat_message(args \\ []) do
    args = Keyword.merge(params(), args)
    HTTPoison.post!("#{@url}/api/chat.postMessage", {:form, args})
  end

  def update_message(args \\ []) do
    args = Keyword.merge(params(), args)
    HTTPoison.post!("#{@url}/api/chat.update", {:form, args})
  end

  def chat_ephemeral_message(args \\ []) do
    args = Keyword.merge(params(), args)
    IO.inspect args
    HTTPoison.post!("#{@url}/api/chat.postEphemeral", {:form, args})
  end

  def update_ephemeral_message(response_url, args \\ []) do
    args = Keyword.merge(params(), args)

    body = Poison.encode!(%{
      "token": args[:token],
      "as_user": true,
      "attachments": args[:attachments],
      "channel": args[:channel],
      "user": args[:user],
      "replace_original": true,
      "response_type": "ephemeral"
    })

    headers = [{"Content-type", "application/json"}]

    HTTPoison.post("#{response_url}", body, headers, [])
  end

  defp params do
    token = Application.get_env(:sokrat, Sokrat.Robot)[:token]

    [token: token,
     as_user: true]
  end
end
