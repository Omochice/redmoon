# Redmine offers no API to create saved queries, so the query is written through the model.
# Its attributes are assigned on every run rather than only on creation, so that re-seeding restores a query whose filters or visibility were changed by hand.
project = Project.find_by!(identifier: "demo")

query = IssueQuery.find_or_initialize_by(name: "Demo open issues", project: project)
query.user = User.find_by_login("admin")
query.visibility = Query::VISIBILITY_PUBLIC
query.filters = { "status_id" => { operator: "o", values: [""] } }
query.save!
