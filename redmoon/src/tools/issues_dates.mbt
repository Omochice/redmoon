///|
/// Redmine reads a relative bound as a whole number of days and counts 0 as
/// today, so a negative or fractional count has no wire form.
fn days_ago() -> @schema.Schema[Int32] {
  only("days_ago", @schema.integer(min=0))
}

///|
fn days_from_now() -> @schema.Schema[Int32] {
  only("days_from_now", @schema.integer(min=0))
}

///|
fn[T] only(name : String, schema : @schema.Schema[T]) -> @schema.Schema[T] {
  let value = @schema.required(name, schema)
  @schema.record([value.as_member()], v => v.get(value))
}

///|
fn[A, B] pair(
  first : @schema.Field[A],
  second : @schema.Field[B],
) -> @schema.Schema[(A, B)] {
  @schema.record([first.as_member(), second.as_member()], v => {
    (v.get(first), v.get(second))
  })
}

///|
fn date_period() -> @schema.Schema[@issues.DatePeriod] {
  @schema.choice([
    ("today", Today),
    ("yesterday", Yesterday),
    ("thisWeek", ThisWeek),
    ("lastWeek", LastWeek),
    ("lastTwoWeeks", LastTwoWeeks),
    ("thisMonth", ThisMonth),
    ("lastMonth", LastMonth),
    ("thisYear", ThisYear),
    ("any", Any),
    ("none", Blank),
  ])
}

///|
/// `from` and `to` are separate alternatives instead of one object with two
/// optional bounds: every form is a strict object, so `{from}` cannot also
/// match a call carrying `to` and silently drop the upper bound.
fn past_date_filters() -> Array[@schema.Schema[@issues.PastDateFilter]] {
  let iso = @schema.iso_date
  [
    iso()
    |> @schema.Schema::map(day => @issues.PastDateFilter::On(day))
    |> @schema.Schema::describe("That day."),
    date_period() |> @schema.Schema::map(period => Period(period)),
    days_ago()
    |> @schema.Schema::map(days => @issues.PastDateFilter::DaysAgo(days))
    |> @schema.Schema::describe("The single day that many days ago."),
    pair(@schema.required("from", iso()), @schema.optional("to", iso()))
    |> @schema.Schema::map(bounds => {
      match bounds {
        (from, Some(to)) => Between(from~, to~)
        (from, None) => Since(from)
      }
    })
    |> @schema.Schema::describe(
      "On or after `from`, and on or before `to` when it is given.",
    ),
    pair(@schema.optional("from", iso()), @schema.required("to", iso()))
    |> @schema.Schema::map(bounds => {
      match bounds {
        (Some(from), to) => Between(from~, to~)
        (None, to) => Until(to)
      }
    })
    |> @schema.Schema::describe("On or before `to`."),
    pair(
      @schema.required("from", days_ago()),
      @schema.optional("to", @schema.literal("today")),
    )
    |> @schema.Schema::map(bounds => {
      match bounds {
        (days, Some(_)) => LastDays(days)
        (days, None) => SinceDaysAgo(days)
      }
    })
    |> @schema.Schema::describe(
      "The last n days: on or after the day n days ago.",
    ),
    only("to", days_ago())
    |> @schema.Schema::map(days => UntilDaysAgo(days))
    |> @schema.Schema::describe("On or before the day n days ago."),
  ]
}

///|
/// The filter of `created_on`, `updated_on` and `closed_on`. Redmine types
/// them as `:date_past` and answers 422 to a forward-looking form.
pub fn past_date_filter() -> @schema.Schema[@issues.PastDateFilter] {
  @schema.union(past_date_filters())
}

///|
/// The filter of `start_date` and `due_date`: the past forms plus the
/// forward-looking ones.
pub fn date_filter() -> @schema.Schema[@issues.DateFilter] {
  let forward : Array[@schema.Schema[@issues.DateFilter]] = [
    @schema.choice([
      ("tomorrow", Tomorrow),
      ("nextWeek", NextWeek),
      ("nextMonth", NextMonth),
    ]),
    days_from_now()
    |> @schema.Schema::map(days => @issues.DateFilter::DaysFromNow(days))
    |> @schema.Schema::describe("The single day that many days from now."),
    only("from", days_from_now())
    |> @schema.Schema::map(days => SinceDaysFromNow(days))
    |> @schema.Schema::describe("On or after the day n days from now."),
    only("to", days_from_now())
    |> @schema.Schema::map(days => UntilDaysFromNow(days))
    |> @schema.Schema::describe("On or before the day n days from now."),
    pair(
      @schema.required("from", @schema.literal("today")),
      @schema.required("to", days_from_now()),
    )
    |> @schema.Schema::map(bounds => NextDays(bounds.1))
    |> @schema.Schema::describe(
      "The next n days: today through the day n days from now.",
    ),
  ]
  @schema.union(
    [
      ..past_date_filters().map(filter => {
        filter |> @schema.Schema::map(past => @issues.DateFilter::Past(past))
      }),
      ..forward,
    ],
  )
}
