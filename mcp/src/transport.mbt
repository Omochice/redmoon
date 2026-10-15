///|
/// Serves requests read from `input` as lines, writing responses to `output`
/// as lines, until `input` reaches end of file and every request in flight has
/// been answered.
///
/// Raises when `output` fails, since no further response could be delivered.
pub async fn Server::serve(
  self : Server,
  input : &@io.Reader,
  output : &@io.Writer,
) -> Unit {
  let write_lock = @async.Mutex()
  let in_flight : Map[String, @async.Task[Unit]] = Map([])
  async fn send(message : Json) -> Unit {
    write_lock.acquire()
    defer write_lock.release()
    @async.protect_from_cancel(() => output.write(message.stringify() + "\n"))
  }

  @async.with_task_group(group => {
    while input.read_until("\n") is Some(line) {
      let line = line.trim(chars="\r")
      if line.is_empty() {
        continue
      }
      match self.dispatch(line.to_owned()) {
        Reply(message) => send(message)
        Nothing => ()
        Cancel(request_id~) =>
          if in_flight.remove_and_get(request_id.stringify()) is Some(task) {
            task.cancel()
          }
        Call(id~, tool~, arguments~, era~) => {
          let key = id.stringify()
          in_flight[key] = group.spawn(async fn() {
            let response = self.respond(id~, tool~, arguments~, era~)
            if in_flight.contains(key) {
              in_flight.remove(key)
              send(response)
            }
          })
        }
      }
    }
  })
}

///|
/// Serves the process's standard input and output until standard input closes.
///
/// Raises when standard output fails.
pub async fn Server::serve_stdio(self : Server) -> Unit {
  self.serve(@stdio.stdin, @stdio.stdout)
}
