# Redmine offers no API to create custom fields, so they are written through the models.
# The fields belong to a project of their own because a required field in demo would reject every issue the other live tests create there.
tracker = Tracker.find(1)
project = Project.find_by(identifier: "demo-custom-fields") ||
  Project.create!(name: "Demo custom fields", identifier: "demo-custom-fields")
project.trackers << tracker unless project.trackers.include?(tracker)

IssueCustomField.find_or_create_by!(name: "Severity") do |field|
  field.field_format = "string"
  field.is_required = true
  field.is_for_all = false
  field.visible = true
  field.trackers = [tracker]
  field.projects = [project]
end

IssueCustomField.find_or_create_by!(name: "Platforms") do |field|
  field.field_format = "list"
  field.possible_values = ["linux", "macos", "windows"]
  field.multiple = true
  field.is_for_all = false
  field.visible = true
  field.trackers = [tracker]
  field.projects = [project]
end
