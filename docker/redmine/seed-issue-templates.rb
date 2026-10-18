# The plugin offers no API to create templates, so they are written through the models.
project = Project.find_by!(identifier: "demo")
project.enable_module!(:issue_templates)
tracker = Tracker.find(1)
project.trackers << tracker unless project.trackers.include?(tracker)
admin = User.find_by_login("admin")

IssueTemplate.find_or_create_by!(project: project, title: "Bug report") do |template|
  template.tracker = tracker
  template.author = admin
  template.issue_title = "[Bug] "
  template.description = "Steps to reproduce:\n"
  template.enabled = true
  template.enabled_sharing = true
end

child = Project.find_by(identifier: "demo-child") ||
  Project.create!(name: "Demo child", identifier: "demo-child", parent: project)
child.enable_module!(:issue_templates)
child.trackers << tracker unless child.trackers.include?(tracker)
IssueTemplateSetting.find_or_create(child.id).update!(inherit_templates: true)

GlobalIssueTemplate.find_or_create_by!(title: "Global bug report", tracker: tracker) do |template|
  template.author = admin
  template.description = "Global steps to reproduce:\n"
  template.enabled = true
  template.projects = [project]
end
