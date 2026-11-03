# omochice/redmine-plugins

Typed clients for the APIs that Redmine plugins add, with one package per plugin, built on the `send` function of [omochice/redmine](../redmine/README.md).

The packages and the plugins they speak to are listed below, each with the ADR that measured or assumed the plugin's answers.

- `issue_templates` for [redmine_issue_templates](https://github.com/agileware-jp/redmine_issue_templates), recorded in [ADR-017](../doc/adr/adr-017-redmine-plugin-sdk-module.md).
- `agile` for [RedmineUP Agile](https://www.redmineup.com/pages/plugins/agile), recorded in [ADR-025](../doc/adr/adr-025-redmineup-agile-data.md).
- `additional_tags` for [Additional Tags](https://github.com/AlphaNodes/additional_tags), recorded in [ADR-030](../doc/adr/adr-030-additional-tags-issue-tags.md) and [ADR-031](../doc/adr/adr-031-additional-tags-wiki-page-search.md).

The module covers only the endpoints those ADRs name, and nothing of Redmine's own API.
ADR-017 records why plugin APIs are a module of their own.
