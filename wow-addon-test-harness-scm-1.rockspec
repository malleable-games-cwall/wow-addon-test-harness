rockspec_format = "3.0"
package = "wow-addon-test-harness"
version = "scm-1"

source = {
  url = "git+https://github.com/malleable-games-cwall/wow-addon-test-harness.git",
}

description = {
  summary = "Offline smoke tester for World of Warcraft addons.",
  detailed = [[
    Loads a WoW addon from its .toc into a sandboxed simulation of the WoW Lua
    environment, drives the login/combat/logout event sequence and reports any
    hard failure before the addon is ever loaded in the live client.
  ]],
  homepage = "https://github.com/malleable-games-cwall/wow-addon-test-harness",
  license = "MIT",
}

dependencies = {
  "lua >= 5.1",
  "luafilesystem >= 1.6.3",
}

test_dependencies = {
  "busted >= 2.0",
  "luacheck >= 0.25",
}

build = {
  type = "builtin",
  modules = {
    ["wowharness"] = "src/wowharness/init.lua",
    ["wowharness.cli"] = "src/wowharness/cli.lua",
    ["wowharness.context"] = "src/wowharness/context.lua",
    ["wowharness.environment"] = "src/wowharness/environment.lua",
    ["wowharness.loader"] = "src/wowharness/loader.lua",
    ["wowharness.profile"] = "src/wowharness/profile.lua",
    ["wowharness.report"] = "src/wowharness/report.lua",
    ["wowharness.runner"] = "src/wowharness/runner.lua",
    ["wowharness.session"] = "src/wowharness/session.lua",
    ["wowharness.toc"] = "src/wowharness/toc.lua",
    ["wowharness.util"] = "src/wowharness/util.lua",
    ["wowharness.version"] = "src/wowharness/version.lua",
    ["wowharness.api.chat"] = "src/wowharness/api/chat.lua",
    ["wowharness.api.events"] = "src/wowharness/api/events.lua",
    ["wowharness.api.frames"] = "src/wowharness/api/frames.lua",
    ["wowharness.api.game"] = "src/wowharness/api/game.lua",
    ["wowharness.api.savedvariables"] = "src/wowharness/api/savedvariables.lua",
    ["wowharness.api.timers"] = "src/wowharness/api/timers.lua",
  },
  install = {
    bin = {
      wowtest = "bin/wowtest.lua",
    },
  },
}

test = {
  type = "busted",
}
