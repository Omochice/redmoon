///|
/// `Full` advertises every action; `Readonly` drops the mutating ones, so a
/// write is inexpressible rather than rejected.
pub(all) enum Mode {
  Full
  Readonly
}
