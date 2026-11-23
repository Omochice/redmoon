name = "omochice/redmine"

// x-release-please-start-version

version = "1.0.0"
// x-release-please-end

license = "Zlib"

import {
  "moonbitlang/async@0.22.9",
}

preferred_target = "native"

source = "src"

warnings = "+unused_optional_argument+unused_default_value"
