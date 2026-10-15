///|
/// The Redmine operations behind `redmine_issue_relations`.
pub(open) trait RelationPort {
  async fn list_relations(Self, issue_id : Int32) -> Array[@redmine.Relation] raise @redmine.RedmineError
  async fn show_relation(Self, id : Int32) -> @redmine.Relation raise @redmine.RedmineError
  async fn create_relation(
    Self,
    issue_id : Int32,
    issue_to_id : Int32,
    relation_type : @redmine.RelationType,
    delay : Int32?,
  ) -> @redmine.Relation raise @redmine.RedmineError
  async fn delete_relation(Self, id : Int32) -> Unit raise @redmine.RedmineError
}

///|
pub impl RelationPort for @redmine.Redmine with fn list_relations(
  self,
  issue_id,
) {
  self.list_relations(issue_id)
}

///|
pub impl RelationPort for @redmine.Redmine with fn show_relation(self, id) {
  self.show_relation(id)
}

///|
pub impl RelationPort for @redmine.Redmine with fn create_relation(
  self,
  issue_id,
  issue_to_id,
  relation_type,
  delay,
) {
  self.create_relation(issue_id, issue_to_id~, relation_type~, delay?)
}

///|
pub impl RelationPort for @redmine.Redmine with fn delete_relation(self, id) {
  self.delete_relation(id)
}
