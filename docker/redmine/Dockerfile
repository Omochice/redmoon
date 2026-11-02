FROM redmine:7.0.3@sha256:a029fcc48b9794c753cafb9c1085e8d782463c0e06e18f86e55084a31f5a20ab

# Pinned to a master commit rather than the v1.2.2 tag because the Redmine 7 icon fix landed after v1.2.2 and no tag carries it yet.
# The list_templates API that redmoon uses answers the same on both.
ADD --chown=redmine:redmine https://github.com/agileware-jp/redmine_issue_templates.git#87360e7db5f274b3572234c3e1806aeb2772f409 plugins/redmine_issue_templates

# Pinned to the 4.6.0 tags because main of additionals requires Redmine 7.0.3, which has no image yet, while 4.6.0 accepts any 7.0.
# Additional Tags refuses to load without additionals.
ADD --chown=redmine:redmine https://github.com/AlphaNodes/additionals.git#5f5ff955dcff00e5fef47c7609f9e0d4fb038178 plugins/additionals
ADD --chown=redmine:redmine https://github.com/AlphaNodes/additional_tags.git#3d503b183ae9254d89bc8f71a517f1f3ec1662c4 plugins/additional_tags
