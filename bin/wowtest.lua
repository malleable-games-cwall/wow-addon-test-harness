#!/usr/bin/env lua
--- wowtest entry point. Also the chunk luastatic compiles into the binary.
local scriptPath = arg and arg[0] or ""
local scriptDirectory = string.match(scriptPath, "^(.*)[/\\][^/\\]*$")
if scriptDirectory then
  package.path = table.concat({
    scriptDirectory .. "/../src/?.lua",
    scriptDirectory .. "/../src/?/init.lua",
    package.path,
  }, ";")
end

local cli = require("wowharness.cli")

os.exit(cli.main(arg or {}))
