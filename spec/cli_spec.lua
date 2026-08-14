local cli = require("wowharness.cli")

local function capture(argv)
  local out, err = {}, {}
  local code = cli.main(argv, {
    write = function(text)
      table.insert(out, text)
    end,
    writeError = function(text)
      table.insert(err, text)
    end,
  })
  return code, table.concat(out), table.concat(err)
end

describe("cli", function()
  describe("argument parsing", function()
    it("collects addon paths and defaults", function()
      local options = assert(cli.parse({ "AddonA", "AddonB" }))
      assert.are.same({ "AddonA", "AddonB" }, options.addons)
      assert.are.equal("text", options.format)
      assert.are.equal(1, options.advance)
      assert.is_true(options.color)
    end)

    it("parses flags with values", function()
      local options = assert(cli.parse({
        "--flavor", "classic",
        "--advance", "2.5",
        "--format", "json",
        "--slash", "/foo",
        "--slash", "/bar",
        "--level", "60",
        "Addon",
      }))
      assert.are.equal("classic", options.flavor)
      assert.are.equal(2.5, options.advance)
      assert.are.equal("json", options.format)
      assert.are.same({ "/foo", "/bar" }, options.slashCommands)
      assert.are.equal(60, options.playerOverrides.level)
    end)

    it("rejects unknown options and formats", function()
      local options, err = cli.parse({ "--nope" })
      assert.is_nil(options)
      assert.is_truthy(string.find(err, "unknown option", 1, true))

      local _, formatError = cli.parse({ "--format", "yaml" })
      assert.is_truthy(string.find(formatError, "unknown format", 1, true))
    end)

    it("reports missing values", function()
      local options, err = cli.parse({ "--flavor" })
      assert.is_nil(options)
      assert.is_truthy(string.find(err, "missing value", 1, true))
    end)

    it("builds a profile from the character overrides", function()
      local options = assert(cli.parse({ "--player", "Bob", "--class", "druid", "--locale", "frFR", "A" }))
      local profile = cli.buildProfile(options)
      assert.are.equal("Bob", profile.units.player.name)
      assert.are.equal("DRUID", profile.units.player.class)
      assert.are.equal("Druid", profile.units.player.className)
      assert.are.equal("frFR", profile.locale)
    end)
  end)

  describe("main", function()
    it("prints usage and exits 0 for --help", function()
      local code, out = capture({ "--help" })
      assert.are.equal(0, code)
      assert.is_truthy(string.find(out, "wowtest", 1, true))
    end)

    it("prints the version", function()
      local code, out = capture({ "--version" })
      assert.are.equal(0, code)
      assert.is_truthy(string.find(out, "wowtest 0.", 1, true))
    end)

    it("exits 2 when no addon is supplied", function()
      local code, _, err = capture({})
      assert.are.equal(2, code)
      assert.is_truthy(string.find(err, "no addon directory supplied", 1, true))
    end)

    it("exits 2 when the addon path does not exist", function()
      local code, _, err = capture({ "spec/fixtures/NoSuchAddon" })
      assert.are.equal(2, code)
      assert.is_truthy(string.find(err, "does not exist", 1, true))
    end)

    it("exits 0 for a healthy addon", function()
      local code, out = capture({ "--no-color", "spec/fixtures/SampleAddon" })
      assert.are.equal(0, code)
      assert.is_truthy(string.find(out, "PASS", 1, true))
      assert.is_truthy(string.find(out, "SampleAddon", 1, true))
    end)

    it("exits 1 for an addon that raises errors", function()
      local code, out = capture({ "--no-color", "spec/fixtures/BrokenAddon" })
      assert.are.equal(1, code)
      assert.is_truthy(string.find(out, "FAIL", 1, true))
    end)

    it("emits machine readable json", function()
      local code, out = capture({ "--format", "json", "spec/fixtures/SampleAddon" })
      assert.are.equal(0, code)
      assert.is_truthy(string.find(out, '"passed":true', 1, true))
    end)

    it("emits junit xml", function()
      local code, out = capture({ "--format", "junit", "spec/fixtures/SampleAddon" })
      assert.are.equal(0, code)
      assert.is_truthy(string.find(out, "<testsuites>", 1, true))
    end)

    it("writes the report to a file", function()
      local path = os.tmpname()
      local code = capture({ "--no-color", "--output", path, "spec/fixtures/SampleAddon" })
      assert.are.equal(0, code)
      local handle = assert(io.open(path, "r"))
      local contents = handle:read("*a")
      handle:close()
      os.remove(path)
      assert.is_truthy(string.find(contents, "PASS", 1, true))
    end)
  end)
end)
