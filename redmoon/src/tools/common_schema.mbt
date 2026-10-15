///|
/// Redmine ids start at 1.
pub fn record_id() -> @schema.Schema[Int32] {
  @schema.integer(min=1)
}

///|
/// A project named as in a Redmine URL path: the numeric id or the identifier.
pub fn project_ref() -> @schema.Schema[@redmine.ProjectRef] {
  @schema.union([
    record_id().map(id => @redmine.ProjectRef::Id(id)),
    @schema.string()
    .refine(
      s => !s.iter().any(c => c.is_whitespace()) && !s.is_empty(),
      "must not contain whitespace",
      keywords=[("pattern", "^\\S+$")],
    )
    .map(s => @redmine.ProjectRef::Identifier(s)),
  ]).describe(
    "Numeric project id, or the project identifier from a Redmine URL (the <identifier> in /projects/<identifier>/...).",
  )
}
