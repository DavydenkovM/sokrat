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

  def update_ephemeral_message(args \\ []) do
    args = Keyword.merge(params(), args)
    IO.inspect args
    respose_url = args["response_url"]
    #HTTPoison.post!("#{@url}/api/chat.update", {:form, args})
    HTTPoison.post!("#{respose_url}", {:form, args})
  end

  defp params do
    token = Application.get_env(:sokrat, Sokrat.Robot)[:token]

    [token: token,
     as_user: true]
  end
end
