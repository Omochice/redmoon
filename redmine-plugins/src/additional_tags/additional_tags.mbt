///|
/// A tag in the plugin's catalogue and the number of records that carry it.
pub(all) struct Tag {
  name : String
  count : Int32
} derive(FromJson, ToJson, Eq, Debug)

///|
pub extend Tag with @json.FromJson::{from_json}

///|
pub extend Tag with ToJson::{to_json}

///|
pub extend Tag with Eq::{equal, not_equal}

///|
pub extend Tag with @debug.Debug::{to_repr}

///|
/// The plugin's controller rejects every user but an administrator before it looks at a permission.
const ADMIN_NEEDED : String = "the tag list needs a Redmine administrator, and the API key may belong to a user who is not one"

///|
/// A record answers its tags as `{"id", "name"}` pairs, and ids are left out because the plugin gives a reused name a new one.
priv struct TagName {
  name : String
} derive(FromJson)

///|
/// Trims `names` as the plugin does, so that the merge and the read-back compare what the plugin stores.
/// The plugin splits a name at commas, so such a name could never be read back as the tag that was asked for.
fn validate(names : Array[String]) -> Array[String] raise @redmine.RedmineError {
  guard !names.is_empty() else {
    raise @redmine.Transport(message="at least one tag name is needed")
  }
  names.map(name => {
    let trimmed = name.trim().to_owned()
    guard !trimmed.is_empty() else {
      raise @redmine.Transport(
        message="a tag name must not be empty or only spaces",
      )
    }
    guard !trimmed.contains_char(',') else {
      raise @redmine.Transport(
        message="the tag name `\{trimmed}` contains a comma, which the plugin would split into several tags",
      )
    }
    trimmed
  })
}

///|
/// The plugin folds names that differ only in case into one tag.
fn holds(names : Array[String], name : String) -> Bool {
  let wanted = name.to_lower()
  names.iter().any(held => held.to_lower() == wanted)
}

///|
/// How a write changes a record's tags, given that the plugin can only replace them all.
priv enum Change {
  Add
  Remove
}

///|
/// The names to send for `requested`, or `None` when the record already looks as asked, so that a no-op leaves no empty journal.
fn Change::merge(
  self : Change,
  current : Array[String],
  requested : Array[String],
) -> Array[String]? {
  let next = match self {
    Add => {
      let next = current.copy()
      for name in requested {
        if !holds(next, name) {
          next.push(name)
        }
      }
      next
    }
    Remove => current.filter(held => !holds(requested, held))
  }
  if next.length() == current.length() {
    None
  } else {
    Some(next)
  }
}

///|
fn Change::unsaved(
  self : Change,
  after : Array[String],
  requested : Array[String],
) -> Array[String] {
  match self {
    Add => requested.filter(name => !holds(after, name))
    Remove => requested.filter(name => holds(after, name))
  }
}

///|
/// The plugin answers 204 even when it drops `tag_list`, so only a second read can tell whether the write was saved.
async fn Change::apply(
  self : Change,
  names : Array[String],
  read~ : async () -> Array[String] raise @redmine.RedmineError,
  write~ : async (Array[String]) -> Unit raise @redmine.RedmineError,
  causes~ : String,
) -> Array[String] raise @redmine.RedmineError {
  let requested = validate(names)
  let current = read()
  guard self.merge(current, requested) is Some(next) else { return current }
  write(next)
  let after = read()
  let unsaved = self.unsaved(after, requested)
  guard unsaved.is_empty() else {
    let listed = unsaved.map(name => "`\{name}`").join(", ")
    raise @redmine.Decode(
      message="Redmine accepted the update without saving the tags \{listed}; \{causes}",
    )
  }
  after
}

///|
/// The plugin leaves `tags` out of a record whose tags the user may not see, so `absent` says why that can happen for this kind of record.
fn names_in(
  record : Json,
  absent~ : String,
) -> Array[String] raise @redmine.RedmineError {
  let tags : Array[TagName] = @decode.decode_field(record, "tags") catch {
    Decode(message~) if !(record is Object(members) && members.contains("tags")) =>
      raise @redmine.Decode(message="\{message}; \{absent}")
    error => raise error
  }
  tags.map(tag => tag.name)
}

///|
/// Redmine sends this 403 with an empty body, which cannot be told from a project or permission problem.
fn admin_needed(error : @redmine.RedmineError) -> @redmine.RedmineError {
  match error {
    Response(status=403, errors=[]) =>
      @redmine.Response(status=403, errors=[ADMIN_NEEDED])
    error => error
  }
}

///|
async fn catalogue(
  redmine : @redmine.Redmine,
  tag_type : String,
) -> Array[Tag] raise @redmine.RedmineError {
  let json = (redmine
  |> @redmine.send(Get, ["additional_tags.json"], query=[("type", tag_type)])) catch {
    error => raise admin_needed(error)
  }
  @decode.decode_field(json, "tags")
}
