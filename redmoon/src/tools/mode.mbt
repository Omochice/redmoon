///|
/// `Full` advertises every action; `Readonly` drops the mutating ones, so a
/// write is inexpressible rather than rejected.
pub(all) enum Mode {
  Full
  Readonly
}

///|
/// The operations a tool advertises in `mode`: `write` ones are left out of
/// `Readonly`, so they are rejected as unknown keys rather than by a handler.
pub fn[T] actions(
  mode : Mode,
  read~ : Array[(String, @schema.Schema[T])],
  write~ : Array[(String, @schema.Schema[T])],
) -> @schema.Schema[T] {
  match mode {
    Full => @schema.keyed([..read, ..write])
    Readonly => @schema.keyed(read)
  }
}
