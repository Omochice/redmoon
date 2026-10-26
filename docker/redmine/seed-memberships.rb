# The admin who creates project demo through the API is not made a member of it, so the project has no memberships until this seed adds them.
# The group is given a user so that the listing also carries a user membership whose role is inherited from the group.
project = Project.find_by!(identifier: "demo")
role = Role.find_by!(name: "Developer")

user = User.find_or_initialize_by(login: "redmoon-member")
if user.new_record?
  user.firstname = "Redmoon"
  user.lastname = "Member"
  user.mail = "redmoon-member@example.com"
  # The user never logs in, so a random password spares the seed from holding a credential.
  user.generate_password = true
  user.save!
end

group = Group.find_or_create_by!(lastname: "Redmoon team")
group.users << user unless group.users.include?(user)

member = Member.find_or_initialize_by(project: project, user_id: group.id)
member.role_ids = [role.id]
member.save!

# Without this setting Redmine refuses a group as an assignee, which would make the seeded group useless for assignment tests.
Setting.issue_group_assignment = "1"
