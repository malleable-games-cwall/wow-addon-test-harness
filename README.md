# wow-addon-test-harness

Offline smoke tester for World of Warcraft addons.

`wowtest` loads an addon straight from its `.toc` into a sandboxed simulation of the
WoW Lua environment, drives the login → play → logout event sequence, and reports every
error the addon raised. It is meant to catch hard failures (syntax errors, missing files,
`nil` indexing during `PLAYER_LOGIN`, exploding timers) in CI or on a dev box, before
anyone launches the game client.

It is **not** an emulator of the game. Nothing is rendered, no server exists, and only a
subset of the client API is implemented — enough for an addon to load and run.

## Quick start

```bash
# from a release: a single self contained binary, no Lua needed
./wowtest /path/to/Interface/AddOns/MyAddon

# from a checkout
lua bin/wowtest.lua /path/to/MyAddon
```

```text
WoW addon smoke test

  SampleAddon v1.2.3 (interface 110002)  2/2 files loaded

  frames created: 3    slash commands: 1    simulated time: 2.5s    pending timers: 0

Warnings (1)
  - SampleAddon declares optional dependency 'MissingLibrary' which is not loaded

PASS  no errors raised during the simulated session
```

Exit codes: `0` clean run, `1` the addon raised at least one error or could not be loaded
(missing `.toc`, unreadable scenario file), `2` the harness could not start (bad arguments).

## What the default run does

1. Parses the `.toc`, resolving file paths case-insensitively like the client does.
2. Loads every listed `.lua` file (and follows `<Script>`/`<Include>` in `.xml`) with the
   addon name and private table passed as `...`.
3. Fires `ADDON_LOADED`, then `VARIABLES_LOADED`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`,
   `SPELLS_CHANGED`, `PLAYER_ALIVE`, `UPDATE_BINDINGS`.
4. Advances a virtual clock so `C_Timer` callbacks and `OnUpdate` scripts actually run.
5. Runs every slash command the addon registered.
6. Enters and leaves combat (`PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`) plus a few
   unit events.
7. Fires `PLAYER_LEAVING_WORLD` and `PLAYER_LOGOUT`, then reports.

Errors never abort the run: every handler is called through an error trap, so one broken
event handler still lets the rest of the session finish and be reported.

## Usage

```text
wowtest [options] <addon-directory-or-toc> [...]

  -f, --flavor <name>       .toc flavour to prefer (mainline, classic, vanilla...)
  -s, --strict              treat use of an unmocked API as an error
  -t, --advance <seconds>   seconds of virtual time to simulate (default 1)
      --slash <command>     run a slash command (repeatable; default: all registered)
      --no-slash            do not run any slash command
      --no-combat           skip the combat enter/leave phase
      --scenario <file>     Lua scenario file run after the default sequence
      --saved-vars <file>   load SavedVariables.lua before the run
      --save-vars <file>    write SavedVariables.lua after the run
      --player <name>       simulated player name (default Testdummy)
      --class <CLASS>       simulated player class token (default MAGE)
      --level <n>           simulated player level (default 70)
      --locale <locale>     simulated client locale (default enUS)
  -F, --format <format>     text (default), json, or junit
  -o, --output <file>       write the report to a file instead of stdout
  -v, --verbose             include addon chat output and tracebacks
      --no-color            disable ANSI colours
```

Pass several addons at once (a library plus its consumer, for example) and they load in
dependency order based on `## Dependencies` / `## OptionalDeps`.

`--format junit` writes a JUnit XML report, so a harness run can be published as a test
result by most CI systems.

## Scenario files

Anything the default sequence does not cover goes in a scenario file, run after the
default sequence. Return either a list of steps:

```lua
return {
  { "fire", "PLAYER_ENTERING_WORLD", false, true },
  { "slash", "/myaddon config" },
  { "click", "MyAddonButton" },
  { "advance", 5 },
}
```

or a function that receives the session:

```lua
return function(session)
  session:slash("/myaddon reset")
  session:setCombat(true)
  session:advance(10)
  session:setCombat(false)
  assert(session.env.MyAddonDB.profile, "profile should exist after a reset")
end
```

Session methods: `addAddon`, `loadAddons`, `fire`, `advance`, `slash`, `slashCommands`,
`setCombat`, `click`, `collectSavedVariables`, `writeSavedVariables`, `errors`,
`warnings`, `output`.

## Using it as a library

```lua
local harness = require("wowharness")

local result = harness.smokeTest({ addons = { "MyAddon" }, strict = true })
if not result.passed then
  for _, err in ipairs(result.errors) do
    print(err.label, err.message)
  end
end
```

`harness.Session` gives full control if you want to write assertions in your own busted
suite instead of using the CLI.

## What is simulated

| Area | Coverage |
| --- | --- |
| Widgets | `CreateFrame`, frames/buttons/textures/font strings/animations, scripts, `HookScript`, show/hide, size/anchors, attributes |
| Events | Registration per frame, `RegisterAllEvents`, ordered dispatch, error trapping |
| Timers | Virtual clock, `C_Timer.After/NewTimer/NewTicker`, `OnUpdate` ticks, `GetTime` |
| Chat | `print`, `SendChatMessage`, `DEFAULT_CHAT_FRAME:AddMessage`, addon messages |
| Slash commands | `SLASH_*n` globals plus `SlashCmdList` dispatch |
| Units | `UnitName/Class/Level/Race/Health/...` for a configurable simulated player |
| Addon info | `C_AddOns` / `GetAddOnMetadata` / `IsAddOnLoaded` backed by the parsed `.toc` |
| SavedVariables | Declared globals persisted to and loaded from a `SavedVariables.lua` |
| Lua extensions | `strsplit`, `strjoin`, `strtrim`, `wipe`, `tContains`, `hooksecurefunc`, `Mixin`, ... |

Unknown *widget methods* (`frame:SetResizeBounds(...)`) resolve to a stub that records
itself instead of erroring; the report lists them under "Unmocked APIs used" and
`--strict` turns them into errors. Unknown *globals* behave like they do in Lua: reading
one yields `nil`, so calling an unmocked client API errors exactly the way a typo would.
The report lists every global the addon read but the harness does not provide, so you can
tell a missing mock from your own typo — open an issue (or a PR adding the mock) for the
former. XML frame definitions are reported but not built.

## Development

```bash
make deps     # busted, luacheck, luafilesystem
make check    # luacheck + busted
make binary   # ./dist/wowtest, self contained (needs luastatic and a C compiler)
make bundle   # ./dist/wowtest.lua, single file, runs on any Lua 5.1+
make smoke    # run the harness against the fixture addons
```

Supported interpreters: Lua 5.1, 5.4 and LuaJIT (WoW itself runs 5.1, so the harness
stays 5.1 compatible).

Layout:

```
bin/wowtest.lua          CLI entry point
src/wowharness/          harness modules (api/ holds the WoW API mocks)
spec/                    busted unit tests
spec/fixtures/           sample addons: healthy, broken and xml based
scripts/                 binary and bundle build scripts
```

## CI

`.github/workflows/ci.yml` lints, runs the unit tests on Lua 5.1 and 5.4 (plus a
dependency-free CLI run under LuaJIT), then builds
and verifies the terminal application: native `wowtest` binaries for Linux and macOS
(x86_64 and arm64) plus a portable single file `wowtest.lua`, all uploaded as artifacts.
Tagging `v*` runs `.github/workflows/release.yml`, which attaches the same artifacts to a
GitHub release.

To smoke test your own addon in your addon repository's CI:

```yaml
- name: Smoke test the addon
  run: |
    curl -sSL -o wowtest https://github.com/malleable-games-cwall/wow-addon-test-harness/releases/latest/download/wowtest-linux-x86_64
    chmod +x wowtest
    ./wowtest --no-color --strict MyAddon
```

## License

MIT — see [LICENSE](LICENSE).
