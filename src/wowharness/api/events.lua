--- Event registry shared between frames and the harness runner.
local Events = {}
Events.__index = Events

function Events.new(context)
  return setmetatable({
    context = context,
    byEvent = {},
    allEventListeners = {},
    fired = {},
  }, Events)
end

function Events:register(listener, event)
  local listeners = self.byEvent[event]
  if not listeners then
    listeners = {}
    self.byEvent[event] = listeners
  end
  for _, existing in ipairs(listeners) do
    if existing == listener then
      return false
    end
  end
  table.insert(listeners, listener)
  return true
end

function Events:unregister(listener, event)
  local listeners = self.byEvent[event]
  if not listeners then
    return false
  end
  for index, existing in ipairs(listeners) do
    if existing == listener then
      table.remove(listeners, index)
      return true
    end
  end
  return false
end

function Events:unregisterAll(listener)
  for _, listeners in pairs(self.byEvent) do
    for index = #listeners, 1, -1 do
      if listeners[index] == listener then
        table.remove(listeners, index)
      end
    end
  end
  for index = #self.allEventListeners, 1, -1 do
    if self.allEventListeners[index] == listener then
      table.remove(self.allEventListeners, index)
    end
  end
end

function Events:registerAllEvents(listener)
  for _, existing in ipairs(self.allEventListeners) do
    if existing == listener then
      return false
    end
  end
  table.insert(self.allEventListeners, listener)
  return true
end

function Events:isRegistered(listener, event)
  local listeners = self.byEvent[event]
  if not listeners then
    return false
  end
  for _, existing in ipairs(listeners) do
    if existing == listener then
      return true
    end
  end
  return false
end

--- Collect the listeners that should receive `event`, in registration order.
function Events:listenersFor(event)
  local collected = {}
  for _, listener in ipairs(self.byEvent[event] or {}) do
    table.insert(collected, listener)
  end
  for _, listener in ipairs(self.allEventListeners) do
    table.insert(collected, listener)
  end
  return collected
end

--- Dispatch an event to every registered frame.
-- Handler errors are captured through the context so a broken addon does not
-- abort the smoke test.
-- @return number count of handlers invoked
function Events:fire(event, ...)
  table.insert(self.fired, { event = event, args = { ... } })
  local invoked = 0
  for _, frame in ipairs(self:listenersFor(event)) do
    local handler = frame:GetScript("OnEvent")
    if handler then
      invoked = invoked + 1
      self.context:protectedCall(
        string.format("OnEvent(%s) for %s", event, frame:GetDebugName()),
        handler,
        frame,
        event,
        ...
      )
    end
  end
  return invoked
end

return Events
