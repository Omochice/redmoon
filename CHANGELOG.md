# Changelog

## [0.3.0](https://github.com/Omochice/redmoon/compare/v0.2.2...v0.3.0) (2026-10-26)


### Features

* list project members to find user and group ids for assignment ([#29](https://github.com/Omochice/redmoon/issues/29)) ([2a8bc45](https://github.com/Omochice/redmoon/commit/2a8bc45fc127709acac0757fdd869769185c0f31))
* read and change RedmineUP Agile data of issues ([#26](https://github.com/Omochice/redmoon/issues/26)) ([d3f7c34](https://github.com/Omochice/redmoon/commit/d3f7c34ea9b724116e6eb4a60942450637e5287d))

## [0.2.2](https://github.com/Omochice/redmoon/compare/v0.2.1...v0.2.2) (2026-10-26)


### Bug Fixes

* return search results whose matches have a description ([#28](https://github.com/Omochice/redmoon/issues/28)) ([facb8b0](https://github.com/Omochice/redmoon/commit/facb8b0372930e7337f5d5e490ca81b8d10bebb5))

## [0.2.1](https://github.com/Omochice/redmoon/compare/v0.2.0...v0.2.1) (2026-10-21)


### Bug Fixes

* report only the errors of the update_note shape a call selects ([#17](https://github.com/Omochice/redmoon/issues/17)) ([105c8b4](https://github.com/Omochice/redmoon/commit/105c8b4c32e4c3a5e97f1ae42bad8f69db81ff77))

## [0.2.0](https://github.com/Omochice/redmoon/compare/v0.1.0...v0.2.0) (2026-10-20)


### Features

* list issues by a saved Redmine query ([#15](https://github.com/Omochice/redmoon/issues/15)) ([f588ef5](https://github.com/Omochice/redmoon/commit/f588ef5800c77fa2d5ffc65964fd41a5e0375750))
* set custom field values when creating and updating issues ([#12](https://github.com/Omochice/redmoon/issues/12)) ([aa6a449](https://github.com/Omochice/redmoon/commit/aa6a44979270fc36b7c6557c0c182fdafa6bb699))

## 0.1.0 (2026-10-18)


### Features

* add a filesystem port for attachment content ([d7e07d8](https://github.com/Omochice/redmoon/commit/d7e07d8a5da6419f680ad7619fcf3dff7d13a801))
* add a hidden secret prompt for login ([917e851](https://github.com/Omochice/redmoon/commit/917e851b1d15738bb639c641d0eb7497edb19656))
* add a named-handle object builder ([21d6792](https://github.com/Omochice/redmoon/commit/21d6792e5706cef3d9af34d16c9a5579da0afe33))
* add attachment metadata, streaming download and upload ([0abbee5](https://github.com/Omochice/redmoon/commit/0abbee5737216f89e38f17490d83f39d92efa630))
* add Clearable for fields Redmine can reset ([4a7ace3](https://github.com/Omochice/redmoon/commit/4a7ace38206c850dbcdcd543650f151680a7a726))
* add issue and journal operations ([a45e5b2](https://github.com/Omochice/redmoon/commit/a45e5b2118e9fbf81ba55d1823501230c6356227))
* add issue and journal response types ([1926e38](https://github.com/Omochice/redmoon/commit/1926e3848f70f358ecd139d46c777d6eef51d325))
* add issue date filters ([eefd1ff](https://github.com/Omochice/redmoon/commit/eefd1ff8112dc19610340c75ffbafc27afcea2a2))
* add issue list query and request bodies ([22ba5ee](https://github.com/Omochice/redmoon/commit/22ba5eee8b36d8ff5354a3bd4cfe5bc9b0835435))
* add issue relation operations ([4308b2e](https://github.com/Omochice/redmoon/commit/4308b2e1683330bf30758cf77af2d120df350e5f))
* add keyring module with macOS Keychain backend ([2607a30](https://github.com/Omochice/redmoon/commit/2607a30ca0e4b8e2e81f1d7d16ece178992c742d))
* add Linux Secret Service backend ([5dc5f71](https://github.com/Omochice/redmoon/commit/5dc5f71679ab2f435533e56f3e5449f19ecf6d70))
* add nullable and union combinators ([f5aa698](https://github.com/Omochice/redmoon/commit/f5aa6985f4409f5bc0541530415c2dd22b9510db))
* add project version operations ([b95b1c7](https://github.com/Omochice/redmoon/commit/b95b1c7c43eb79c036449e88f8aff06c4447773e))
* add RedmineError with Redmine's validation messages ([0188f7c](https://github.com/Omochice/redmoon/commit/0188f7ce9d774c714a3e0f9e3af77ae46525f0e4))
* add Schema core and primitive combinators ([c0ad7d0](https://github.com/Omochice/redmoon/commit/c0ad7d0ca4b5822fb2a65041bb2ec182043f7faa))
* add shared tool payloads and argument schemas ([bb2fd10](https://github.com/Omochice/redmoon/commit/bb2fd102b972398e98b95dce3c0a6416eccd97c7))
* add strict object builder ([7b00ac4](https://github.com/Omochice/redmoon/commit/7b00ac47624106b0f99bcf81ed9bbce83048dfe9))
* add the action-keyed object combinator ([d603f76](https://github.com/Omochice/redmoon/commit/d603f767e5509d558b34c1748c53ec5a1425206d))
* add the credential store port and login, logout, list commands ([c42ef7f](https://github.com/Omochice/redmoon/commit/c42ef7ff527ba6eb8e61855890b9ec6fc63e660e))
* add the ISO calendar date schema ([52f8e14](https://github.com/Omochice/redmoon/commit/52f8e14141fd20f5fe716bdc09f50cdeaf74f568))
* add the issue date filter schemas ([695c227](https://github.com/Omochice/redmoon/commit/695c2276400589acba5a98185171f4ec760a001c))
* add the module with JSON-RPC message parsing ([744bd32](https://github.com/Omochice/redmoon/commit/744bd328bd0324d8b36335725ee0721ba6e0f266))
* add the redmine_attachments tool ([da8c691](https://github.com/Omochice/redmoon/commit/da8c691b415d6c8d824e1dc58100d36adfe7ad44))
* add the redmine_enumerations tool ([28b37da](https://github.com/Omochice/redmoon/commit/28b37da2918008042345be1a80bf33fa4d94c93c))
* add the redmine_issue_relations read actions ([f7af713](https://github.com/Omochice/redmoon/commit/f7af713e04936907e129626b3e4a7aa37d0c4c19))
* add the redmine_issue_relations write actions ([32c3c08](https://github.com/Omochice/redmoon/commit/32c3c08cae011994e072e1e8fa2b7aac034ef5d8))
* add the redmine_issues tool ([081bc60](https://github.com/Omochice/redmoon/commit/081bc604d4d37607affac5ed69aaa6e745de8d3d))
* add the redmine_search tool ([da52b8e](https://github.com/Omochice/redmoon/commit/da52b8eb1ea7f5e9660e111ea464a4368f9b2c73))
* add the redmine_time_entries tool ([0069f38](https://github.com/Omochice/redmoon/commit/0069f388df3f081d7875cd4e6bd747a918281139))
* add the redmine_versions tool ([d022a8b](https://github.com/Omochice/redmoon/commit/d022a8b4ef6e9cbb04176f7004dfc993afb9c36a))
* add the redmine_wiki_pages tool ([0cb0d14](https://github.com/Omochice/redmoon/commit/0cb0d149881a6a763672714d5a86daa6e000e102))
* add the redmoon executable ([b810638](https://github.com/Omochice/redmoon/commit/b8106387c6215f419149ff3b0b39e63ed2eafecb))
* add the redmoon_info tool ([3da019e](https://github.com/Omochice/redmoon/commit/3da019e1294830e755be52a797952d611ad4060e))
* add the release version and build information ([49974ff](https://github.com/Omochice/redmoon/commit/49974ff0d8eea31101ea6005f320b7e114e6ca52))
* add the search operation ([209535d](https://github.com/Omochice/redmoon/commit/209535de82645dcb136da39663e8a5c14ca73af6))
* add the serve command and the tool registry ([f6b7b5b](https://github.com/Omochice/redmoon/commit/f6b7b5b9a5d50412cca40adb6cf1f338da69e328))
* add the stdio runner and an echo example ([9d19715](https://github.com/Omochice/redmoon/commit/9d197156857d67d6c072bf2b7e743b67e4a2e7cf))
* add time entry show, create, update and delete ([dfa35d6](https://github.com/Omochice/redmoon/commit/dfa35d6fa66890dcb4a777ad88b42c52abe62099))
* add time entry types and list ([97a4981](https://github.com/Omochice/redmoon/commit/97a49812056c2842e26b1d8ada856485a85c3fa0))
* add wiki page operations and ProjectRef ([1369cf2](https://github.com/Omochice/redmoon/commit/1369cf2d41bcfc18db71fbca7c9f39321fde2a77))
* add Windows Credential Manager backend ([cb3da7a](https://github.com/Omochice/redmoon/commit/cb3da7ad743f8286d9d8e338db9b9ad12f1fc260))
* answer the legacy initialize lifecycle ([95867c9](https://github.com/Omochice/redmoon/commit/95867c99e45671501d2211575bf671845f4025a2))
* build request paths under the endpoint's base path ([f82f8bc](https://github.com/Omochice/redmoon/commit/f82f8bc23acafde72f6c3fa5f1fba24c5b369d4e))
* canonicalize endpoint URLs into keyring accounts ([2dd40fb](https://github.com/Omochice/redmoon/commit/2dd40fb7fb84ee815b2ebbe580e90f1687d99d9b))
* initialize ([126baa4](https://github.com/Omochice/redmoon/commit/126baa47e706b7bcd0487b62e982d68e8d71cf27))
* let other packages construct RedmineError ([f70edc3](https://github.com/Omochice/redmoon/commit/f70edc3818af7985a26339aa73a8c3c83d03e31f))
* list and call tools ([90884d2](https://github.com/Omochice/redmoon/commit/90884d2f7d7a7b37baa408cce5fec6b82edcef66))
* list enumerations ([291d346](https://github.com/Omochice/redmoon/commit/291d3465c23255a5cd989899926756aa49c6bfe9))
* list issue templates of the redmine_issue_templates plugin ([#10](https://github.com/Omochice/redmoon/issues/10)) ([9368ef7](https://github.com/Omochice/redmoon/commit/9368ef73ffa5546bacfab55629b49d9fc8e78590))
* remove null members from responses ([4337025](https://github.com/Omochice/redmoon/commit/4337025423683bbe353084716e08c7853c8d9f21))
* run each request in its own task ([63ed4ca](https://github.com/Omochice/redmoon/commit/63ed4ca62a721d3f9029aa2e0df5f3dfb1d8806c))
* send authenticated requests to Redmine ([99e2bc2](https://github.com/Omochice/redmoon/commit/99e2bc28783c5a2d1909d1c3643a839df3373571))
* serve modern requests and server/discover ([ba98859](https://github.com/Omochice/redmoon/commit/ba98859f9f10f5eb154218856b3d2d280c6a0ded))
* serve the issue relation and search tools ([007c77b](https://github.com/Omochice/redmoon/commit/007c77b70e05a74b1bc55e512098e5aef3740224))
* serve the issues tool ([3f41cfe](https://github.com/Omochice/redmoon/commit/3f41cfeffc7d09e37d92ea21bf0020d42fe2a1c7))
* serve the wiki, version, time entry, and attachment tools ([a4b0854](https://github.com/Omochice/redmoon/commit/a4b08544063e0f4a94e05b446158b57b7e80549c))
* walk paged list responses ([44d5b8e](https://github.com/Omochice/redmoon/commit/44d5b8e5932210ad0fceb3ee9bc57eea93fc3d06))


### Bug Fixes

* accept attachments whose content type is null ([401cb43](https://github.com/Omochice/redmoon/commit/401cb4318258e04998a3f4eba83bcf2f5e2fac1e))
* bound issue limit and done_ratio in the schema ([6a024af](https://github.com/Omochice/redmoon/commit/6a024afd4164863667a8254c95335fd014e25465))
* carry the full attachment metadata on wiki pages ([e59f896](https://github.com/Omochice/redmoon/commit/e59f8967806336a3679258b03353bcd49b1ead5b))
* convert wiki titles the way Redmine does ([5da6cc8](https://github.com/Omochice/redmoon/commit/5da6cc83321eccec6170c8e051808392ae7c7b34))
* explain the keychain refusal after an upgrade ([04a37cf](https://github.com/Omochice/redmoon/commit/04a37cfbbd7a12fe43ca3dc3ca7353ecd804afc0))
* let cancellation stop attachment transfers ([8321491](https://github.com/Omochice/redmoon/commit/832149101f9241cb64d7adc79795b2715e22772f))
* reject a request whose id is already in flight ([b0ca305](https://github.com/Omochice/redmoon/commit/b0ca305d00ce5d90db84f6743bb4cb26042534b5))
* reject at login the endpoints serve cannot use ([188edf7](https://github.com/Omochice/redmoon/commit/188edf72ecca7cd5f891c2c8aa10e5ee728f8ec4))
* remove every trailing slash from endpoints ([e481a1d](https://github.com/Omochice/redmoon/commit/e481a1dd48d66266c73bbc7e560bf6b28e9e5955))
* report unknown keys of a record alone ([95ec4ef](https://github.com/Omochice/redmoon/commit/95ec4ef848926ca3a899539a003aada23adf1bcb))
* reuse the attachments type for the attachments of an issue ([c82878c](https://github.com/Omochice/redmoon/commit/c82878cb10925d6aab92c72ea8b5b9f7a59d07aa))
* send all_words when it is false ([d662df7](https://github.com/Omochice/redmoon/commit/d662df7faa199be35ca5a80188f4575d54559c93))
* send caching hints on modern list and discover results ([67ccd2a](https://github.com/Omochice/redmoon/commit/67ccd2ad690db4e0e58fe3b695acce36e7cc6bb0))
* strip only the default port when comparing origins ([3815c30](https://github.com/Omochice/redmoon/commit/3815c30a05d5ea3444b28345550940df2dbb0dc6))
