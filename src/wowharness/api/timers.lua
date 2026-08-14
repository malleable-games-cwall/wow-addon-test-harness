--- Virtual clock plus the C_Timer / OnUpdate scheduling APIs.
--
-- Time never advances on its own: the runner drives it with `advance`, which
-- keeps smoke tests deterministic and instant.
local timers = {}

local Clock = {}
Clock.__index = Clock

function Clock.new(context)
  return setmetatable({
    context = context,
    now = 0,
    scheduled = {},
    sequence = 0,
  }, Clock)
end

function Clock:GetTime()
  return self.now
end

--- Schedule `callback` to run `delay` seconds from now.
-- @return table handle with Cancel/IsCancelled
function Clock:after(delay, callback, options)
  options = options or {}
  self.sequence = self.sequence + 1
  local timer = {
    at = self.now + math.max(delay or 0, 0),
    callback = callback,
    interval = options.interval,
    iterations = options.iterations,
    label = options.label or "C_Timer callback",
    sequence = self.sequence,
    cancelled = false,
  }
  function timer:Cancel()
    self.cancelled = true
  end
  function timer:IsCancelled()
    return self.cancelled
  end
  table.insert(self.scheduled, timer)
  return timer
end

local function nextTimer(scheduled, deadline)
  local best
  for _, timer in ipairs(scheduled) do
    if not timer.cancelled and timer.at <= deadline then
      if not best or timer.at < best.at or (timer.at == best.at and timer.sequence < best.sequence) then
        best = timer
      end
    end
  end
  return best
end

local function removeTimer(scheduled, target)
  for index, timer in ipairs(scheduled) do
    if timer == target then
      table.remove(scheduled, index)
      return
    end
  end
end

--- Advance the virtual clock, running due callbacks and OnUpdate scripts.
-- @param seconds number amount of virtual time to run
-- @param step number|nil OnUpdate tick size (default 1/60s, capped iterations)
-- @return number number of callbacks executed
function Clock:advance(seconds, step)
  step = step or (1 / 60)
  local deadline = self.now + seconds
  local executed = 0
  local guard = 0
  while true do
    guard = guard + 1
    if guard > 100000 then
      self.context:addWarning("timer loop guard tripped; a ticker may be rescheduling forever")
      break
    end
    local timer = nextTimer(self.scheduled, deadline)
    local nextTick = math.min(self.now + step, deadline)
    if timer and timer.at <= nextTick then
      self:tickFrames(timer.at - self.now)
      self.now = timer.at
      removeTimer(self.scheduled, timer)
      executed = executed + 1
      self.context:protectedCall(timer.label, timer.callback, timer)
      if timer.iterations then
        timer.iterations = timer.iterations - 1
      end
      local repeats = timer.interval and not timer.cancelled
        and (not timer.iterations or timer.iterations > 0)
      if repeats then
        -- Re-arm the same handle so a captured ticker can still be cancelled.
        timer.at = self.now + timer.interval
        self.sequence = self.sequence + 1
        timer.sequence = self.sequence
        table.insert(self.scheduled, timer)
      end
    else
      if nextTick <= self.now then
        break
      end
      self:tickFrames(nextTick - self.now)
      self.now = nextTick
      if self.now >= deadline then
        break
      end
    end
  end
  return executed
end

--- Run OnUpdate handlers for every visible frame.
function Clock:tickFrames(elapsed)
  if elapsed <= 0 then
    return
  end
  for _, frame in ipairs(self.context.frames) do
    if frame.scripts.OnUpdate and frame:IsVisible() then
      frame:RunScript("OnUpdate", elapsed)
    end
  end
end

function Clock:pendingCount()
  local count = 0
  for _, timer in ipairs(self.scheduled) do
    if not timer.cancelled then
      count = count + 1
    end
  end
  return count
end

function timers.install(context)
  local env = context.env
  local clock = Clock.new(context)
  context.clock = clock

  env.GetTime = function()
    return clock:GetTime()
  end
  env.GetTimePreciseSec = env.GetTime
  env.debugprofilestop = function()
    return clock:GetTime() * 1000
  end

  env.C_Timer = {
    After = function(delay, callback)
      clock:after(delay, callback, { label = "C_Timer.After" })
    end,
    NewTimer = function(delay, callback)
      return clock:after(delay, callback, { label = "C_Timer.NewTimer" })
    end,
    NewTicker = function(interval, callback, iterations)
      return clock:after(interval, callback, {
        interval = interval,
        iterations = iterations,
        label = "C_Timer.NewTicker",
      })
    end,
  }

  return clock
end

timers.Clock = Clock

return timers
