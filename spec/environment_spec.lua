local environment = require("wowharness.environment")

describe("sandbox environment", function()
  local context

  before_each(function()
    context = environment.create()
  end)

  it("exposes the Lua subset the client provides", function()
    assert.is_function(context.env.pairs)
    assert.is_function(context.env.string.format)
    assert.is_function(context.env.table.insert)
    assert.are.equal(context.env, context.env._G)
  end)

  it("hides io, require and dofile from addon code", function()
    assert.is_nil(rawget(context.env, "io"))
    assert.is_nil(rawget(context.env, "require"))
    assert.is_nil(rawget(context.env, "dofile"))
  end)

  it("counts reads of undefined globals", function()
    local _ = context.env.SomeNonExistentGlobal
    _ = context.env.SomeNonExistentGlobal
    assert.are.equal(2, context.unknownGlobals.SomeNonExistentGlobal)
  end)

  it("captures errors raised inside protected calls", function()
    local ok = context:protectedCall("boom", function()
      error("kaboom")
    end)
    assert.is_false(ok)
    assert.are.equal(1, #context.errors)
    assert.is_truthy(string.find(context.errors[1].message, "kaboom", 1, true))
    assert.is_truthy(context.errors[1].traceback)
  end)

  it("passes arguments and results through protected calls", function()
    local ok, sum = context:protectedCall("add", function(left, right)
      return left + right
    end, 2, 3)
    assert.is_true(ok)
    assert.are.equal(5, sum)
  end)

  describe("Blizzard lua extensions", function()
    it("implements strsplit and strjoin", function()
      local first, second, third = context.env.strsplit(" ", "a b c")
      assert.are.same({ "a", "b", "c" }, { first, second, third })
      assert.are.equal("a-b", context.env.strjoin("-", "a", "b"))
    end)

    it("implements strtrim, wipe and tContains", function()
      assert.are.equal("hi", context.env.strtrim("  hi \n"))
      local target = { a = 1 }
      context.env.wipe(target)
      assert.are.same({}, target)
      assert.is_true(context.env.tContains({ "a", "b" }, "b"))
    end)

    it("hooks existing functions with hooksecurefunc", function()
      local calls = {}
      context.env.Original = function(value)
        table.insert(calls, "original:" .. value)
        return "result"
      end
      context.env.hooksecurefunc("Original", function(value)
        table.insert(calls, "hook:" .. value)
      end)
      assert.are.equal("result", context.env.Original("x"))
      assert.are.same({ "original:x", "hook:x" }, calls)
    end)
  end)

  describe("game state APIs", function()
    it("reports the simulated player", function()
      assert.are.equal("Testdummy", context.env.UnitName("player"))
      assert.are.equal(70, context.env.UnitLevel("player"))
      local className, class = context.env.UnitClass("player")
      assert.are.equal("Mage", className)
      assert.are.equal("MAGE", class)
      assert.is_false(context.env.UnitExists("target"))
    end)

    it("tracks combat state", function()
      assert.is_false(context.env.InCombatLockdown())
      context.state.inCombat = true
      assert.is_true(context.env.InCombatLockdown())
    end)

    it("stores cvars", function()
      context.env.SetCVar("scriptErrors", "1")
      assert.are.equal("1", context.env.GetCVar("scriptErrors"))
      assert.is_true(context.env.GetCVarBool("scriptErrors"))
    end)
  end)
end)
