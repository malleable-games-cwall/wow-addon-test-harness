--- Rendering of run results for humans, CI logs and machines.
local report = {}

local COLORS = {
  reset = "\27[0m",
  red = "\27[31m",
  green = "\27[32m",
  yellow = "\27[33m",
  cyan = "\27[36m",
  bold = "\27[1m",
  dim = "\27[2m",
}

local function paint(useColor, color, text)
  if not useColor then
    return text
  end
  return COLORS[color] .. text .. COLORS.reset
end

local function escapeJson(text)
  local escaped = string.gsub(text, '[%c"\\]', function(character)
    local map = {
      ['"'] = '\\"',
      ["\\"] = "\\\\",
      ["\n"] = "\\n",
      ["\r"] = "\\r",
      ["\t"] = "\\t",
    }
    return map[character] or string.format("\\u%04x", string.byte(character))
  end)
  return escaped
end

local function isArray(value)
  local count = 0
  for _ in pairs(value) do
    count = count + 1
  end
  return count == #value
end

--- Minimal JSON encoder (tables, strings, numbers, booleans).
function report.toJson(value)
  local valueType = type(value)
  if value == nil then
    return "null"
  elseif valueType == "boolean" then
    return tostring(value)
  elseif valueType == "number" then
    return string.format("%.14g", value)
  elseif valueType == "string" then
    return '"' .. escapeJson(value) .. '"'
  elseif valueType ~= "table" then
    return '"' .. escapeJson(tostring(value)) .. '"'
  end
  if isArray(value) then
    local pieces = {}
    for _, item in ipairs(value) do
      table.insert(pieces, report.toJson(item))
    end
    return "[" .. table.concat(pieces, ",") .. "]"
  end
  local keys = {}
  for key in pairs(value) do
    table.insert(keys, tostring(key))
  end
  table.sort(keys)
  local pieces = {}
  for _, key in ipairs(keys) do
    table.insert(pieces, '"' .. escapeJson(key) .. '":' .. report.toJson(value[key]))
  end
  return "{" .. table.concat(pieces, ",") .. "}"
end

--- Human readable report.
-- @param result table produced by runner.run
-- @param options table|nil { color = bool, verbose = bool }
function report.text(result, options)
  options = options or {}
  local color = options.color and true or false
  local lines = {}
  local function add(line)
    table.insert(lines, line or "")
  end

  add(paint(color, "bold", "WoW addon smoke test"))
  add()

  for _, addon in ipairs(result.addons) do
    add(string.format(
      "  %s %s%s  %d/%d files loaded",
      paint(color, "cyan", addon.name),
      addon.version and ("v" .. addon.version .. " ") or "",
      addon.interface and paint(color, "dim", "(interface " .. addon.interface .. ")") or "",
      #addon.files,
      -- XML includes add files the .toc never declared, so the denominator is
      -- whichever is larger to keep "loaded/expected" meaningful.
      math.max(#addon.files, #addon.declaredFiles)
    ))
  end
  if #result.addons == 0 then
    add("  (no addons discovered)")
  end
  add()

  add(string.format(
    "  frames created: %d    slash commands: %d    simulated time: %.1fs    pending timers: %d",
    result.frames,
    #result.slashCommands,
    result.simulatedTime,
    result.pendingTimers
  ))
  add()

  if #result.output > 0 and options.verbose then
    add(paint(color, "bold", "Addon output"))
    for _, entry in ipairs(result.output) do
      add(string.format("  [%s] %s", entry.channel, entry.message))
    end
    add()
  end

  if #result.warnings > 0 then
    add(paint(color, "yellow", string.format("Warnings (%d)", #result.warnings)))
    for _, warning in ipairs(result.warnings) do
      add("  - " .. warning.message)
    end
    add()
  end

  if #result.missingApi > 0 then
    add(paint(color, "yellow", string.format("Unmocked APIs used (%d)", #result.missingApi)))
    for _, entry in ipairs(result.missingApi) do
      add(string.format("  - %s (%d call%s)", entry.name, entry.count, entry.count == 1 and "" or "s"))
    end
    add()
  end

  local unknownGlobals = result.unknownGlobals or {}
  if #unknownGlobals > 0 then
    add(paint(color, "yellow", string.format("Globals the harness does not provide (%d)", #unknownGlobals)))
    add("  reading these yields nil; calling one raises an error the report attributes to your addon")
    local limit = options.verbose and #unknownGlobals or math.min(#unknownGlobals, 12)
    for index = 1, limit do
      add(string.format("  - %s (%d read%s)", unknownGlobals[index].name,
        unknownGlobals[index].count, unknownGlobals[index].count == 1 and "" or "s"))
    end
    if limit < #unknownGlobals then
      add(string.format("  ... %d more (use --verbose to list them all)", #unknownGlobals - limit))
    end
    add()
  end

  if #result.errors > 0 then
    add(paint(color, "red", string.format("Errors (%d)", #result.errors)))
    for _, err in ipairs(result.errors) do
      add(string.format("  %s", paint(color, "red", err.label)))
      add(string.format("    %s", err.message))
      if options.verbose and err.traceback then
        for line in string.gmatch(err.traceback, "[^\n]+") do
          add("      " .. line)
        end
      end
    end
    add()
  end

  if result.passed then
    add(paint(color, "green", "PASS") .. "  no errors raised during the simulated session")
  else
    add(paint(color, "red", "FAIL") .. string.format("  %d error(s) raised", #result.errors))
  end

  return table.concat(lines, "\n") .. "\n"
end

--- JUnit XML so CI systems can ingest harness runs.
function report.junit(result)
  local function escapeXml(text)
    return (string.gsub(tostring(text), "[&<>\"]", {
      ["&"] = "&amp;",
      ["<"] = "&lt;",
      [">"] = "&gt;",
      ['"'] = "&quot;",
    }))
  end
  local cases = {}
  for _, addon in ipairs(result.addons) do
    local failures = {}
    for _, err in ipairs(result.errors) do
      table.insert(failures, string.format(
        '      <failure message="%s">%s</failure>',
        escapeXml(err.label),
        escapeXml(err.message)
      ))
    end
    table.insert(cases, string.format(
      '    <testcase classname="wow-addon-test-harness" name="%s">\n%s    </testcase>',
      escapeXml(addon.name),
      #failures > 0 and (table.concat(failures, "\n") .. "\n") or ""
    ))
  end
  local document = table.concat({
    '<?xml version="1.0" encoding="UTF-8"?>',
    "<testsuites>",
    '  <testsuite name="smoke" tests="%d" failures="%d">',
    "%s",
    "  </testsuite>",
    "</testsuites>",
    "",
  }, "\n")
  return string.format(
    document,
    math.max(#result.addons, 1),
    #result.errors,
    table.concat(cases, "\n")
  )
end

function report.render(result, format, options)
  if format == "json" then
    return report.toJson(result) .. "\n"
  elseif format == "junit" then
    return report.junit(result)
  end
  return report.text(result, options)
end

return report
