# Additional Tags saves no tag until its issue tags are switched on, and the setting starts off.
# The plugin reads its settings by symbol, so a string key would be stored beside the default and never read.
Setting.plugin_additional_tags = Setting.plugin_additional_tags.symbolize_keys.merge(active_issue_tags: "1")

# The member seeded by seed-memberships.rb acts through the Developer role, so the role is given the tag permissions that a non-admin caller needs.
role = Role.find_by!(name: "Developer")
%i[view_issue_tags edit_issue_tags create_issue_tags].each do |permission|
  role.add_permission!(permission) unless role.permissions.include?(permission)
end
