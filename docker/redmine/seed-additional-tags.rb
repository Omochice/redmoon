# Additional Tags ignores issue and wiki page tags until each kind is switched on, and both settings start off.
# The plugin reads its settings by symbol, so a string key would be stored beside the default and never read.
Setting.plugin_additional_tags = Setting.plugin_additional_tags.symbolize_keys.merge(active_issue_tags: "1", active_wiki_tags: "1")

# The member seeded by seed-memberships.rb acts through the Developer role.
# The role may attach existing tags but not create new ones, so the live tests can see both a saved write and one the plugin drops.
role = Role.find_by!(name: "Developer")
%i[view_issue_tags edit_issue_tags].each do |permission|
  role.add_permission!(permission) unless role.permissions.include?(permission)
end
role.remove_permission!(:create_issue_tags) if role.permissions.include?(:create_issue_tags)

# A second member may also create tags, so the live tests can see a new tag saved for someone who is not an administrator.
tagger_role = Role.find_or_initialize_by(name: "Redmoon tagger")
tagger_role.permissions = role.permissions | [:create_issue_tags]
tagger_role.save!

tagger = User.find_or_initialize_by(login: "redmoon-tagger")
if tagger.new_record?
  tagger.firstname = "Redmoon"
  tagger.lastname = "Tagger"
  tagger.mail = "redmoon-tagger@example.com"
  # The user never logs in, so a random password spares the seed from holding a credential.
  tagger.generate_password = true
  tagger.save!
end

membership = Member.find_or_initialize_by(project: Project.find_by!(identifier: "demo"), user_id: tagger.id)
membership.role_ids = [tagger_role.id]
membership.save!

# The live tests act as these members, and printing the keys here spares the seed a Rails boot per key.
puts "member #{User.find_by_login!('redmoon-member').api_key}"
puts "tagger #{tagger.api_key}"
