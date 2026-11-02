# Additional Tags saves no tag until its issue tags are switched on, and the setting starts off.
# The plugin reads its settings by symbol, so a string key would be stored beside the default and never read.
Setting.plugin_additional_tags = Setting.plugin_additional_tags.symbolize_keys.merge(active_issue_tags: "1")

# The member seeded by seed-memberships.rb acts through the Developer role.
# The role may attach existing tags but not create new ones, so the live tests can see both a saved write and one the plugin drops.
role = Role.find_by!(name: "Developer")
%i[view_issue_tags edit_issue_tags].each do |permission|
  role.add_permission!(permission) unless role.permissions.include?(permission)
end
role.remove_permission!(:create_issue_tags) if role.permissions.include?(:create_issue_tags)

# The live tests act as this member, and printing the key here spares the seed a second Rails boot to read it.
puts User.find_by_login!("redmoon-member").api_key
