# Verification harness

`compose.yaml`, driven by the tasks in `Taskfile.yaml` ([ADR-015](./adr-015-task-runner.md)), brings up a throwaway Redmine instance so redmoon and its SDK can be exercised against a real Redmine REST API.
It is a verification aid, not a deployment artifact.

## Start

```sh
task redmine:up
```

The task runs `docker compose up -d` and waits until the login page answers.
Redmine is served at <http://localhost:3000>.
First sign-in is `admin` / `admin`, which forces a password change.
The image runs migrations on first boot, so the wait can take a few minutes.

The image is built from `docker/redmine/Dockerfile`, which adds the [redmine_issue_templates](https://github.com/agileware-jp/redmine_issue_templates) plugin so that its API can be exercised as well.
Its migrations run on boot because `compose.yaml` sets `REDMINE_PLUGINS_MIGRATE`.
After changing the Dockerfile, run `docker compose build` before `task redmine:up`, because `docker compose up` reuses an image it has already built.

## Enable the REST API, seed the prerequisites, and obtain an API key

The REST API is disabled by default, and redmoon authenticates with an API key.
A fresh Redmine also has no trackers, statuses, or priorities, and an issue needs a project, so issue operations fail until these exist.

```sh
task redmine:seed
```

The task enables the REST API, loads the default configuration data, creates the project `demo`, and writes the admin API key to `_build/redmine-api-key`.
The default data seeds tracker `1` (Bug), status `1` (New), and priority `2` (Normal), which the issue integration tests use.
It also enables the issue templates module on `demo` and creates one shared project template and one global template for tracker `1`, plus the subproject `demo-child` that inherits the project template, through `docker/redmine/seed-issue-templates.rb`, because the plugin offers no API to create them.
It then creates the project `demo-custom-fields` with a required string field `redmoon Severity` and a multi-value list field `redmoon Platforms` for tracker `1`, through `docker/redmine/seed-custom-fields.rb`, because Redmine offers no API to create custom fields.
The fields belong to that project alone because a required field in `demo` would reject every issue the other integration tests create there.
It also saves the public issue query `Demo open issues` on `demo`, filtering open issues, through `docker/redmine/seed-queries.rb`, because Redmine offers no API to save a query.
The default data provides only global queries, and the integration tests need a project query to show that it answers only under its own `project_id`.
The key goes to a file instead of the terminal so that no log carries it, and `_build/` is already gitignored.
`task redmine:up` and `task redmine:seed` are safe to re-run against an instance that is already prepared.

The task runs `rails runner` through `docker compose exec`, which runs outside the entrypoint that exports `SECRET_KEY_BASE`, so the task sets it explicitly.

## Run the integration tests

The tests that need a real Redmine ([ADR-009](./adr-009-testing-strategy.md)) live in `integration-test/`, a module with its own `moon.work` that the root workspace does not list as a member.
A plain `moon test` at the root therefore never compiles or runs them.
They read the instance from `REDMOON_TEST_ENDPOINT` and `REDMOON_TEST_API_KEY`, and fail naming the missing variable when either is unset, because a skipped test would count as passed.
The module uses only the public API of the SDK, the plugin SDK, and the server, since another module cannot reach their `internal/` packages.

```sh
task test:integration
```

The task sets `REDMOON_TEST_ENDPOINT` to `http://localhost:3000` and `REDMOON_TEST_API_KEY` to the contents of `_build/redmine-api-key`, then runs `moon test` in `integration-test/`.
That workspace lists every root member as well, so the run covers the unit tests together with the integration tests.
Arguments after `--` are passed on to `moon test`.
`task test:integration:coverage` runs the same tests with coverage and writes the report from the repository root, so that the file names in it stay relative to the repository.
CI performs the same steps in the `integration` job of `.github/workflows/ci.yaml`.

## Register the key with the CLI

redmoon reads its API key only from the OS keyring ([ADR-008](./adr-008-keyring-module-and-credential-cli.md)).
Register the key in `_build/redmine-api-key` with the `login` subcommand to try the compiled binary against this instance:

```sh
redmoon login --endpoint http://localhost:3000
```

## Stop

```sh
task redmine:down         # keep the data volumes
docker compose down -v    # discard all state
```
