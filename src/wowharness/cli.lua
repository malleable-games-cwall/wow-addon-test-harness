--- Terminal front end for the harness.
local runner = require("wowharness.runner")
local report = require("wowharness.report")
local profileModule = require("wowharness.profile")
local util = require("wowharness.util")
local version = require("wowharness.version")

local cli = {}

local USAGE = [[
wowtest - offline smoke tester for World of Warcraft addons

Usage:
  wowtest [options] <addon-directory-or-toc> [...]

Options:
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
  -V, --version             print the harness version
  -h, --help                show this help

Exit codes:
  0 the addon loaded and ran without errors
  1 at least one error was raised
  2 the harness could not be started (bad arguments)
]]

local function fail(message)
  return nil, message
end

--- Parse argv into an options table.
-- @return table|nil options, string|nil error
function cli.parse(argv)
  local options = {
    addons = {},
    format = "text",
    color = true,
    verbose = false,
    advance = 1,
    combat = true,
    playerOverrides = {},
  }
  local index = 1
  local function nextValue(flag)
    index = index + 1
    local value = argv[index]
    if value == nil then
      return nil, string.format("missing value for %s", flag)
    end
    return value
  end

  while index <= #argv do
    local argument = argv[index]
    if argument == "-h" or argument == "--help" then
      options.help = true
    elseif argument == "-V" or argument == "--version" then
      options.showVersion = true
    elseif argument == "-s" or argument == "--strict" then
      options.strict = true
    elseif argument == "-v" or argument == "--verbose" then
      options.verbose = true
    elseif argument == "--no-color" then
      options.color = false
    elseif argument == "--no-combat" then
      options.combat = false
    elseif argument == "--no-slash" then
      options.slashCommands = {}
    elseif argument == "-f" or argument == "--flavor" or argument == "--flavour" then
      local value, err = nextValue(argument)
      if not value then
        return fail(err)
      end
      options.flavor = value
    elseif argument == "-t" or argument == "--advance" then
      local value, err = nextValue(argument)
      if not value then
        return fail(err)
      end
      options.advance = tonumber(value)
      if not options.advance then
        return fail("--advance expects a number of seconds")
      end
    elseif argument == "--slash" then
      local value, err = nextValue(argument)
      if not value then
        return fail(err)
      end
      options.slashCommands = options.slashCommands or {}
      table.insert(options.slashCommands, value)
    elseif argument == "--scenario" then
      local value, err = nextValue(argument)
      if not value then
        return fail(err)
      end
      options.scenario = value
    elseif argument == "--saved-vars" then
      local value, err = nextValue(argument)
      if not value then
        return fail(err)
      end
      options.savedVariables = value
    elseif argument == "--save-vars" then
      local value, err = nextValue(argument)
      if not value then
        return fail(err)
      end
      options.saveVariablesTo = value
    elseif argument == "--player" then
      local value, err = nextValue(argument)
      if not value then
        return fail(err)
      end
      options.playerOverrides.name = value
    elseif argument == "--class" then
      local value, err = nextValue(argument)
      if not value then
        return fail(err)
      end
      options.playerOverrides.class = string.upper(value)
      options.playerOverrides.className = value:sub(1, 1):upper() .. value:sub(2):lower()
    elseif argument == "--level" then
      local value, err = nextValue(argument)
      if not value then
        return fail(err)
      end
      local level = tonumber(value)
      if not level then
        return fail("--level expects a number")
      end
      options.playerOverrides.level = level
    elseif argument == "--locale" then
      local value, err = nextValue(argument)
      if not value then
        return fail(err)
      end
      options.locale = value
    elseif argument == "-F" or argument == "--format" then
      local value, err = nextValue(argument)
      if not value then
        return fail(err)
      end
      if value ~= "text" and value ~= "json" and value ~= "junit" then
        return fail(string.format("unknown format '%s'", value))
      end
      options.format = value
    elseif argument == "-o" or argument == "--output" then
      local value, err = nextValue(argument)
      if not value then
        return fail(err)
      end
      options.output = value
    elseif util.startsWith(argument, "-") and argument ~= "-" then
      return fail(string.format("unknown option '%s'", argument))
    else
      table.insert(options.addons, argument)
    end
    index = index + 1
  end

  return options
end

--- Build the simulated character profile from parsed options.
function cli.buildProfile(options)
  local profile = profileModule.new()
  if options.locale then
    profile.locale = options.locale
  end
  for key, value in pairs(options.playerOverrides or {}) do
    profile.units.player[key] = value
  end
  return profile
end

--- Run the CLI.
-- @param argv table command line arguments (without the program name)
-- @param io_ table|nil injectable io for tests { write = function(text) end }
-- @return number exit code
function cli.main(argv, io_)
  local out = io_ or {
    write = function(text)
      io.stdout:write(text)
    end,
    writeError = function(text)
      io.stderr:write(text)
    end,
  }
  out.writeError = out.writeError or out.write

  local options, parseError = cli.parse(argv or {})
  if not options then
    out.writeError("wowtest: " .. parseError .. "\n")
    out.writeError(USAGE)
    return 2
  end
  if options.help then
    out.write(USAGE)
    return 0
  end
  if options.showVersion then
    out.write(version.string .. "\n")
    return 0
  end
  if #options.addons == 0 then
    out.writeError("wowtest: no addon directory supplied\n")
    out.writeError(USAGE)
    return 2
  end
  for _, path in ipairs(options.addons) do
    if not util.isDirectory(path) and not util.fileExists(path) then
      out.writeError(string.format("wowtest: '%s' does not exist\n", path))
      return 2
    end
  end

  options.profile = cli.buildProfile(options)
  local result = runner.run(options)
  local rendered = report.render(result, options.format, {
    color = options.color and options.format == "text",
    verbose = options.verbose,
  })

  if options.output then
    local handle, err = io.open(options.output, "w")
    if not handle then
      out.writeError(string.format("wowtest: cannot write '%s': %s\n", options.output, tostring(err)))
      return 2
    end
    handle:write(rendered)
    handle:close()
  else
    out.write(rendered)
  end

  return result.passed and 0 or 1
end

cli.USAGE = USAGE

return cli
