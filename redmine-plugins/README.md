# omochice/redmine-plugins

Typed clients for the APIs that Redmine plugins add, with one package per plugin, built on the `send` function of [omochice/redmine](../redmine/README.md).

The packages and the plugins they speak to are listed below.

- `issue_templates` for [redmine_issue_templates](https://github.com/agileware-jp/redmine_issue_templates).
- `agile` for [RedmineUP Agile](https://www.redmineup.com/pages/plugins/agile).
- `additional_tags` for [Additional Tags](https://github.com/AlphaNodes/additional_tags).

Each package covers only the endpoints of its plugin that redmoon uses, and nothing of Redmine's own API.
Plugin APIs are a module of their own because they change with the plugin rather than with Redmine, so a consumer who uses none of them pulls in none of them.
