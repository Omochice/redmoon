///|
/// Redmine ids start at 1.
fn record_id() -> @schema.Schema[Int32] {
  @schema.integer(min=1)
}

///|
/// A project named as in a Redmine URL path: the numeric id or the identifier.
fn project_ref() -> @schema.Schema[@redmine.ProjectRef] {
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

///|
fn status_filter() -> @schema.Schema[@issues.StatusFilter] {
  @schema.union([
    record_id().map(id => @issues.StatusFilter::Id(id)),
    @schema.choice([("open", Open), ("closed", Closed), ("*", All)]),
  ])
}

///|
/// Maps `null` to `Clear` so that a field Redmine can empty keeps "leave alone",
/// "empty" and "set" apart.
fn[T] clearable(
  schema : @schema.Schema[T],
  description : String,
) -> @schema.Schema[@redmine.Clearable[T]] {
  @schema.nullable(schema)
  .map(value => {
    match value {
      Some(value) => @redmine.Clearable::Set(value)
      None => Clear
    }
  })
  .describe(description)
}

///|
let list_limit : @schema.Field[Int32?] = @schema.optional(
  "limit",
  @schema.integer(min=1),
)

///|
/// A local file path argument described by `description`.
fn path_schema(description : String) -> @schema.Schema[String] {
  @schema.not_blank().describe(description)
}
