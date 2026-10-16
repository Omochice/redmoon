///|
/// The Redmine operations behind `redmine_issue_relations`.
pub(open) trait RelationPort {
  async fn list_relations(Self, issue_id : Int32) -> Array[@relations.Relation] raise @redmine.RedmineError
  async fn show_relation(Self, id : Int32) -> @relations.Relation raise @redmine.RedmineError
  async fn create_relation(
    Self,
    issue_id : Int32,
    issue_to_id : Int32,
    relation_type : @relations.Type,
    delay : Int32?,
  ) -> @relations.Relation raise @redmine.RedmineError
  async fn delete_relation(Self, id : Int32) -> Unit raise @redmine.RedmineError
}

///|
pub impl RelationPort for @redmine.Redmine with fn list_relations(
  self,
  issue_id,
) {
  self |> @relations.list(issue_id)
}

///|
pub impl RelationPort for @redmine.Redmine with fn show_relation(self, id) {
  self |> @relations.show(id)
}

///|
pub impl RelationPort for @redmine.Redmine with fn create_relation(
  self,
  issue_id,
  issue_to_id,
  relation_type,
  delay,
) {
  self |> @relations.create(issue_id, issue_to_id~, relation_type~, delay?)
}

///|
pub impl RelationPort for @redmine.Redmine with fn delete_relation(self, id) {
  self |> @relations.delete(id)
}
