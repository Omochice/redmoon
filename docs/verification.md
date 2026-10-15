# Verification harness

`compose.yaml` brings up a throwaway Redmine instance so redmoon and its SDK can be exercised against a real Redmine REST API.
It is a verification aid, not a deployment artifact.

## Start

```sh
docker compose up -d
```

Redmine is served at <http://localhost:3000>.
First sign-in is `admin` / `admin`, which forces a password change.
The image runs migrations on first boot, so wait until the login page loads.

## Enable the REST API and obtain an API key

The REST API is disabled by default, and redmoon authenticates with an API key.
Both are database settings, so they are applied once against the running container:

```sh
docker compose exec redmine sh -c \
  'SECRET_KEY_BASE="$REDMINE_SECRET_KEY_BASE" bundle exec rails runner \
   "Setting.rest_api_enabled = %q(1); puts User.find_by_login(%q(admin)).api_key"'
```

`docker compose exec` runs outside the entrypoint that exports `SECRET_KEY_BASE`, so the command sets it explicitly; otherwise `rails runner` aborts with a missing-secret error.
The command is safe to re-run.

## Seed issue prerequisites

A fresh Redmine has no trackers, statuses, or priorities, and an issue needs a project, so issue operations fail until these exist.
Load the default configuration data and create one project (replace `<key>` with the API key from above):

```sh
docker compose exec redmine sh -c \
  'SECRET_KEY_BASE="$REDMINE_SECRET_KEY_BASE" REDMINE_LANG=en bundle exec rake redmine:load_default_data'

curl -s -X POST -H "X-Redmine-API-Key: <key>" -H "Content-Type: application/json" \
  -d '{"project":{"name":"Demo","identifier":"demo"}}' http://localhost:3000/projects.json
```

The default data seeds tracker `1` (Bug), status `1` (New), and priority `2` (Normal), which the issue integration tests use.

## Run the integration tests

The tests that need a real Redmine run when both variables below are set, and are skipped otherwise ([ADR-009](./adr-009-testing-strategy.md)).

| Variable                | Value                                      |
| ----------------------- | ------------------------------------------ |
| `REDMOON_TEST_ENDPOINT` | `http://localhost:3000`                    |
| `REDMOON_TEST_API_KEY`  | the API key printed by the `rails` command |

```sh
REDMOON_TEST_ENDPOINT=http://localhost:3000 \
REDMOON_TEST_API_KEY=<key> \
  moon test
```

CI performs the same steps in the `integration` job of `.github/workflows/ci.yaml`.

## Register the key with the CLI

redmoon reads its API key only from the OS keyring ([ADR-008](./adr-008-keyring-module-and-credential-cli.md)).
Register the printed key with the `login` subcommand to try the compiled binary against this instance:

```sh
redmoon login --endpoint http://localhost:3000
```

## Stop

```sh
docker compose down       # keep the data volumes
docker compose down -v    # discard all state
```
