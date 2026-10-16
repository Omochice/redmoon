# ADR-015: Task as the Task Runner

## Status

Proposed

## Context

The repository has no task runner.
Every command is typed in full, such as `nix develop -c moon check --deny-warn`, and each GitHub Actions job repeats the same commands in its own YAML.
Preparing the throwaway Redmine for integration tests (enabling the REST API with `rails runner`, reading the admin key, loading default data, creating the `demo` project) is written twice, in `.github/workflows/ci.yaml` and in `docs/verification.md`.

The commands have to run on every runner of [ADR-002](./adr-002-native-backend-and-target-platforms.md): macOS and Linux x86_64 inside the nix devShell, and Linux arm64 and Windows with the official MoonBit installer and no nix.
On Windows there is no POSIX shell unless one is installed.

## Decision Drivers

- **One definition per command**, shared by developers and every CI job.
- **Runs on every target runner**, Windows included, without a different script per OS.
- **Few new dependencies**, available from nixpkgs so the devShell provides it.

## Considered Options

### Option 1: just

**Pros:**

- Widely used, small, in nixpkgs (1.58.0 at the time of writing).

**Cons:**

- Recipes run through `sh` by default, so Windows needs a shell setting or a POSIX shell on the runner.

### Option 2: Task (go-task) (chosen)

**Pros:**

- In nixpkgs (3.53.1 at the time of writing).
- Commands run through the Go shell interpreter `mvdan.cc/sh`, and on Windows Task enables Go implementations of common core utilities (`cat`, `cp`, `mkdir`, `mv`, `rm`, and others), so one command line serves every OS.
- `sources` and `generates` let a task be skipped when its inputs have not changed.

**Cons:**

- YAML is less pleasant to read than a `justfile`.

### Option 3: pkfire

**Pros:**

- Typed task definitions in Pkl, content-addressed caching, and a remote cache; written in MoonBit.

**Cons:**

- Its README states that Windows is not supported, which conflicts with the Windows build of ADR-002.
- Not in nixpkgs, and it also needs the Pkl CLI.

### Option 4: flake apps run with `nix run`

**Pros:**

- No new tool.

**Cons:**

- The Windows and Linux arm64 runners have no nix, so the tasks could not run there.

## Decision

We will define the project's commands as Task tasks in a `Taskfile.yml` at the repository root, provide `go-task` in the nix devShell, and have every CI job call the tasks instead of repeating commands.

### 1. The tasks cover the commands that are repeated today

Checking, testing, formatting, the release build, stamping and verifying the build information, and preparing the throwaway Redmine for integration tests.

**Rationale**: these are the commands that already appear in more than one place, so they are where a single definition removes drift.

### 2. CI installs Task where nix is not available

The nix jobs get `task` from the devShell; the Windows and Linux arm64 jobs install the same version with a pinned setup action.

**Rationale**: the shell interpreter built into Task is what makes one command line work on Windows, so every runner has to run the commands through Task rather than through its own shell.

## Consequences

### Positive

1. **One place per command**: a change to how tests run is one edit.
2. **The same commands on every OS**, including Windows.
3. **The Redmine preparation is runnable locally**, not only in CI and as prose in the docs.

### Negative

1. **A new tool** that contributors need, and a version to keep in step between nix and the setup action.
2. **Windows behaviour depends on Task's core utilities**, which cover common commands but not every POSIX utility.

### Mitigations

- The devShell provides Task, so a contributor using nix needs nothing else.
- Tasks use only the commands Task provides on Windows or programs that exist on every runner (`moon`, `git`, `docker`), and the Windows CI job exercises them on every pull request.

## References

- [Task: Windows core utils](https://taskfile.dev/blog/windows-core-utils)
- [Task FAQ](https://taskfile.dev/docs/faq)
- [mizchi/pkfire README](https://github.com/mizchi/pkfire)
- [ADR-002](./adr-002-native-backend-and-target-platforms.md) — the runners the tasks must run on.
