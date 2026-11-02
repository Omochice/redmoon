///|
/// Largest page Redmine serves, whatever `limit` is asked for.
const PAGE_SIZE : Int32 = 100

///|
/// One page of a list response.
priv struct Page[T] {
  items : Array[T]
  total_count : Int32
}

///|
/// Collects the items of a paged resource through `fetch_page(limit, offset)`.
/// With `limit`, pages are requested until that many items are collected or a
/// page comes back short. Without it, the first page's `total_count` decides
/// which offsets remain.
async fn[T] walk_pages(
  fetch_page : async (Int32, Int32) -> Page[T] raise @redmine.RedmineError,
  limit? : Int32,
) -> Array[T] raise @redmine.RedmineError {
  match limit {
    Some(limit) => walk_up_to(fetch_page, limit)
    None => walk_all(fetch_page)
  }
}

///|
async fn[T] walk_up_to(
  fetch_page : async (Int32, Int32) -> Page[T] raise @redmine.RedmineError,
  limit : Int32,
) -> Array[T] raise @redmine.RedmineError {
  let items = []
  while items.length() < limit {
    let size = @cmp.minimum(PAGE_SIZE, limit - items.length())
    let page = fetch_page(size, items.length())
    // A server may return more than was asked for; the cap must still hold.
    for item in page.items {
      guard items.length() < limit else { break }
      items.push(item)
    }
    guard page.items.length() >= size else { break }
  }
  items
}

///|
async fn[T] walk_all(
  fetch_page : async (Int32, Int32) -> Page[T] raise @redmine.RedmineError,
) -> Array[T] raise @redmine.RedmineError {
  let first = fetch_page(PAGE_SIZE, 0)
  let items = first.items
  for offset = PAGE_SIZE
      offset < first.total_count
      offset = offset + PAGE_SIZE {
    items.append(fetch_page(PAGE_SIZE, offset).items)
  }
  items
}

///|
/// Redmine omits `total_count` when it did not run the search, for example for a one-letter query, so a missing count means no matches.
fn total_count_of(json : Json) -> Int32 raise @redmine.RedmineError {
  guard json is Object(members) && members.get("total_count") is Some(count) else {
    return 0
  }
  @decode.decode(count)
}

///|
/// Lists a paged resource whose response is `{"<key>": [...], "total_count": n}`.
/// With `limit`, at most that many items are returned.
pub async fn[T : @json.FromJson] list_all(
  redmine : @redmine.Redmine,
  segments : Array[String],
  key~ : String,
  query~ : Array[(String, String)] = [],
  limit? : Int32,
) -> Array[T] raise @redmine.RedmineError {
  walk_pages(limit?, async fn(size, offset) raise @redmine.RedmineError {
    let json = redmine
      |> @redmine.send(
        Get,
        segments,
        query=[
          ..query,
          ("limit", size.to_string()),
          ("offset", offset.to_string()),
        ],
      )
    {
      items: @decode.decode_field(json, key),
      total_count: total_count_of(json),
    }
  })
}
