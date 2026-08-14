--- Public entry point: `local harness = require("wowharness")`.
local wowharness = {
  version = require("wowharness.version"),
  cli = require("wowharness.cli"),
  environment = require("wowharness.environment"),
  loader = require("wowharness.loader"),
  profile = require("wowharness.profile"),
  report = require("wowharness.report"),
  runner = require("wowharness.runner"),
  Session = require("wowharness.session"),
  toc = require("wowharness.toc"),
  util = require("wowharness.util"),
}

--- Convenience wrapper: run a smoke test and return the result table.
function wowharness.smokeTest(options)
  return wowharness.runner.run(options)
end

return wowharness
