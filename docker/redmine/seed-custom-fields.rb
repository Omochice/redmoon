# Redmine offers no API to create custom fields, so they are written through the models.
# The fields belong to a project of their own because a required field in demo would reject every issue the other live tests create there.
# Their attributes are assigned on every run rather than only on creation, so that re-seeding repairs a field whose project was recreated.
tracker = Tracker.find(1)
project = Project.find_by(identifier: "demo-custom-fields") ||
  Project.create!(name: "Demo custom fields", identifier: "demo-custom-fields")
project.trackers << tracker unless project.trackers.include?(tracker)

severity = IssueCustomField.find_or_initialize_by(name: "redmoon Severity")
severity.update!(
  field_format: "string",
  is_required: true,
  is_for_all: false,
  visible: true,
  trackers: [tracker],
  projects: [project],
)

platforms = IssueCustomField.find_or_initialize_by(name: "redmoon Platforms")
platforms.update!(
  field_format: "list",
  possible_values: ["linux", "macos", "windows"],
  multiple: true,
  is_required: false,
  is_for_all: false,
  visible: true,
  trackers: [tracker],
  projects: [project],
)
