try do
  Ecto.Adapters.SQL.query(Sokrat.Repo, "SELECT 1")
rescue _e in DBConnection.ConnectionError ->
  Mix.Shell.cmd("mix ecto.create", fn(output) -> IO.write(output) end)
end

IO.inspect "Perform migrations..."
Mix.Shell.cmd("mix ecto.migrate", fn(output) -> IO.write(output) end)
IO.inspect "Perform seeding..."
Mix.Shell.cmd("PORT=4001 mix run priv/repo/seeds.exs", fn(output) -> IO.write(output) end)

IO.inspect "FINISH SETUP"

