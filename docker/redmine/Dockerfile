FROM redmine:7.0@sha256:c0090ac1fe4208bd0e457d043efaf5450d3025ff844942695c1aeb05808b3a8c

# Pinned to a master commit rather than the v1.2.2 tag because the Redmine 7 icon fix landed after v1.2.2 and no tag carries it yet.
# The list_templates API that redmoon uses answers the same on both.
ADD --chown=redmine:redmine https://github.com/agileware-jp/redmine_issue_templates.git#87360e7db5f274b3572234c3e1806aeb2772f409 plugins/redmine_issue_templates
