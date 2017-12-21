defmodule Sokrat.Seeder do
  alias Sokrat.{Repo, Models}

  def applications do
    Repo.insert_all(Models.Application, [
      [key: "rails", name: "Ruby on Rails"],
      [key: "php",   name: "PHP"],
      [key: "js",    name: "JavaScript"]
    ])
  end

  def revisions do
    rails_app = Repo.get_by!(Models.Application, key: "rails")
    Repo.insert_all(Models.Revision, [
      [application_id: rails_app.id, server: "rc101", branch: "feature/1", revision: "ahs213c", deployed_at: NaiveDateTime.utc_now],
      [application_id: rails_app.id, server: "rc102", branch: "feature/2", revision: "ahs213c", deployed_at: NaiveDateTime.utc_now],
      [application_id: rails_app.id, server: "rc103", branch: "feature/3", revision: "ahs213c", deployed_at: NaiveDateTime.utc_now],
      [application_id: rails_app.id, server: "rc104", branch: "feature/3", revision: "ahs213c", deployed_at: NaiveDateTime.utc_now]
    ])

    php_app = Repo.get_by!(Models.Application, key: "php")
    Repo.insert_all(Models.Revision, [
      [application_id: php_app.id, server: "rc101", branch: "feature/10", revision: "ahs213c", deployed_at: NaiveDateTime.utc_now],
      [application_id: php_app.id, server: "rc102", branch: "feature/20", revision: "ahs213c", deployed_at: NaiveDateTime.utc_now],
      [application_id: php_app.id, server: "rc103", branch: "feature/30", revision: "ahs213c", deployed_at: NaiveDateTime.utc_now],
      [application_id: php_app.id, server: "rc104", branch: "feature/30", revision: "ahs213c", deployed_at: NaiveDateTime.utc_now]
    ])

    js_app = Repo.get_by!(Models.Application, key: "js")
    Repo.insert_all(Models.Revision, [
      [application_id: js_app.id, server: "rc101", branch: "feature/10", revision: "ahs213c", deployed_at: NaiveDateTime.utc_now],
      [application_id: js_app.id, server: "rc102", branch: "feature/20", revision: "ahs213c", deployed_at: NaiveDateTime.utc_now],
      [application_id: js_app.id, server: "rc103", branch: "feature/30", revision: "ahs213c", deployed_at: NaiveDateTime.utc_now],
      [application_id: js_app.id, server: "rc104", branch: "feature/30", revision: "ahs213c", deployed_at: NaiveDateTime.utc_now]
    ])
  end

  def conflict_users do
    Repo.insert_all(Models.ConflictUser, [
      [bitbucket_username: "alexey.ivanov", slack_username: "alexey.ivanov"]
    ])
  end
end

IO.inspect "seed applications"
Sokrat.Seeder.applications()
IO.inspect "seed revisions"
Sokrat.Seeder.revisions()
IO.inspect "seed conflict_users"
Sokrat.Seeder.conflict_users()
