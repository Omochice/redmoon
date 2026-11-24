name = "omochice/redmoon"

// x-release-please-start-version

version = "1.0.0"
// x-release-please-end

license = "Zlib"

import {
  "Omochice/keyring@0.6.0",
  "Omochice/mcp@0.6.0",
  "Omochice/schema@0.6.0",
  "moonbitlang/async@0.22.9",
  // x-release-please-start-version
  "omochice/redmine@1.0.0",
  "omochice/redmine-plugins@1.0.0",
  // x-release-please-end
}

preferred_target = "native"

source = "src"

warnings = "+unused_optional_argument+unused_default_value"
