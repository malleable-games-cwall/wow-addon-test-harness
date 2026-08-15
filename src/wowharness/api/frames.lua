--- Minimal re-implementation of the WoW widget (frame) system.
--
-- The goal is not pixel accurate layout, it is to let addon code build its
-- frames, register scripts and events, and run without raising errors.
local frames = {}

local unpack = unpack or table.unpack -- luacheck: ignore 121 143

local Widget = {}
Widget.__index = Widget

local nextAnonymousId = 0

local POINTS = {
  TOPLEFT = true,
  TOP = true,
  TOPRIGHT = true,
  LEFT = true,
  CENTER = true,
  RIGHT = true,
  BOTTOMLEFT = true,
  BOTTOM = true,
  BOTTOMRIGHT = true,
}

local function newWidget(context, objectType, name, parent, template)
  nextAnonymousId = nextAnonymousId + 1
  local widget = setmetatable({
    context = context,
    objectType = objectType,
    name = name,
    parent = parent,
    template = template,
    id = nextAnonymousId,
    scripts = {},
    children = {},
    regions = {},
    attributes = {},
    points = {},
    shown = true,
    width = 0,
    height = 0,
    alpha = 1,
    scale = 1,
    strata = "MEDIUM",
    level = 1,
    mouseEnabled = false,
    keyboardEnabled = false,
    movable = false,
    resizable = false,
    text = nil,
    userPlaced = false,
    registeredForDrag = {},
  }, Widget)
  if parent and parent.children then
    table.insert(parent.children, widget)
  end
  return widget
end

function Widget:GetObjectType()
  return self.objectType
end

function Widget:IsObjectType(objectType)
  return self.objectType == objectType
end

function Widget:GetName()
  return self.name
end

function Widget:GetDebugName()
  return self.name or string.format("<%s#%d>", self.objectType, self.id)
end

function Widget:GetParent()
  return self.parent
end

function Widget:SetParent(parent)
  self.parent = parent
end

-- Scripts ------------------------------------------------------------------

function Widget:SetScript(handlerName, handler)
  self.scripts[handlerName] = handler
end

function Widget:GetScript(handlerName)
  return self.scripts[handlerName]
end

function Widget:HasScript()
  return true
end

function Widget:HookScript(handlerName, handler)
  local existing = self.scripts[handlerName]
  if not existing then
    self.scripts[handlerName] = handler
    return
  end
  self.scripts[handlerName] = function(...)
    existing(...)
    handler(...)
  end
end

--- Invoke a script handler through the harness error trap.
function Widget:RunScript(handlerName, ...)
  local handler = self.scripts[handlerName]
  if not handler then
    return false
  end
  self.context:protectedCall(
    string.format("%s for %s", handlerName, self:GetDebugName()),
    handler,
    self,
    ...
  )
  return true
end

-- Events -------------------------------------------------------------------

function Widget:RegisterEvent(event)
  return self.context.events:register(self, event)
end

function Widget:UnregisterEvent(event)
  return self.context.events:unregister(self, event)
end

function Widget:UnregisterAllEvents()
  self.context.events:unregisterAll(self)
end

function Widget:RegisterAllEvents()
  return self.context.events:registerAllEvents(self)
end

function Widget:IsEventRegistered(event)
  return self.context.events:isRegistered(self, event)
end

function Widget:RegisterUnitEvent(event)
  return self.context.events:register(self, event)
end

-- Visibility ---------------------------------------------------------------

function Widget:Show()
  local wasShown = self.shown
  self.shown = true
  if not wasShown then
    self:RunScript("OnShow")
  end
end

function Widget:Hide()
  local wasShown = self.shown
  self.shown = false
  if wasShown then
    self:RunScript("OnHide")
  end
end

function Widget:SetShown(shown)
  if shown then
    self:Show()
  else
    self:Hide()
  end
end

function Widget:IsShown()
  return self.shown
end

function Widget:IsVisible()
  if not self.shown then
    return false
  end
  local parent = self.parent
  while parent do
    if parent.shown == false then
      return false
    end
    parent = parent.parent
  end
  return true
end

-- Geometry -----------------------------------------------------------------

function Widget:SetPoint(point, ...)
  if not POINTS[point] then
    self.context:addWarning(string.format(
      "%s:SetPoint called with unknown anchor point '%s'",
      self:GetDebugName(),
      tostring(point)
    ))
  end
  table.insert(self.points, { point = point, args = { ... } })
end

function Widget:SetAllPoints()
  table.insert(self.points, { point = "ALL" })
end

function Widget:GetNumPoints()
  return #self.points
end

function Widget:ClearAllPoints()
  self.points = {}
end

function Widget:SetSize(width, height)
  self.width = width or 0
  self.height = height or 0
end

function Widget:GetSize()
  return self.width, self.height
end

function Widget:SetWidth(width)
  self.width = width or 0
end

function Widget:GetWidth()
  return self.width
end

function Widget:SetHeight(height)
  self.height = height or 0
end

function Widget:GetHeight()
  return self.height
end

function Widget:GetLeft()
  return 0
end
Widget.GetRight = Widget.GetWidth
Widget.GetBottom = Widget.GetLeft
Widget.GetTop = Widget.GetHeight

function Widget:GetCenter()
  return self.width / 2, self.height / 2
end

function Widget:GetEffectiveScale()
  return self.scale
end

function Widget:SetScale(scale)
  self.scale = scale
end

function Widget:GetScale()
  return self.scale
end

function Widget:SetAlpha(alpha)
  self.alpha = alpha
end

function Widget:GetAlpha()
  return self.alpha
end

function Widget:SetFrameStrata(strata)
  self.strata = strata
end

function Widget:GetFrameStrata()
  return self.strata
end

function Widget:SetFrameLevel(level)
  self.level = level
end

function Widget:GetFrameLevel()
  return self.level
end

-- Interaction --------------------------------------------------------------

function Widget:EnableMouse(enabled)
  self.mouseEnabled = enabled and true or false
end

function Widget:EnableMouseWheel(enabled)
  self.mouseWheelEnabled = enabled and true or false
end

function Widget:IsMouseWheelEnabled()
  return self.mouseWheelEnabled
end

function Widget:IsMouseEnabled()
  return self.mouseEnabled
end

function Widget:EnableKeyboard(enabled)
  self.keyboardEnabled = enabled and true or false
end

function Widget:EnableGamePadButton(enabled)
  self.gamePadButtonEnabled = enabled and true or false
end

function Widget:IsGamePadButtonEnabled()
  return self.gamePadButtonEnabled
end

function Widget:EnableGamePadStick(enabled)
  self.gamePadStickEnabled = enabled and true or false
end

function Widget:IsGamePadStickEnabled()
  return self.gamePadStickEnabled
end

function Widget:SetPropagateGamePadInput() end

function Widget:SetMovable(movable)
  self.movable = movable and true or false
end

function Widget:IsMovable()
  return self.movable
end

function Widget:SetResizable(resizable)
  self.resizable = resizable and true or false
end

function Widget:RegisterForDrag(...)
  self.registeredForDrag = { ... }
end

function Widget:RegisterForClicks(...)
  self.registeredForClicks = { ... }
end

function Widget:SetClampedToScreen(clamped)
  self.clamped = clamped and true or false
end

function Widget:SetUserPlaced(placed)
  self.userPlaced = placed and true or false
end

function Widget:IsUserPlaced()
  return self.userPlaced
end

function Widget:StartMoving() end
function Widget:StopMovingOrSizing() end
function Widget:Raise() end
function Widget:Lower() end
function Widget:SetToplevel() end
function Widget:SetPropagateKeyboardInput() end

function Widget:Click(button)
  self:RunScript("OnClick", button or "LeftButton", false)
end

-- Attributes ---------------------------------------------------------------

function Widget:SetAttribute(key, value)
  self.attributes[key] = value
  self:RunScript("OnAttributeChanged", key, value)
end

function Widget:GetAttribute(key)
  return self.attributes[key]
end

-- Text / textures ----------------------------------------------------------

function Widget:SetText(text)
  self.text = text
end

function Widget:GetText()
  return self.text
end

function Widget:SetFormattedText(format, ...)
  self.text = string.format(format, ...)
end

function Widget:SetFont(font, size, flags)
  self.font = { font = font, size = size, flags = flags }
  return true
end

function Widget:GetFont()
  local font = self.font or {}
  return font.font, font.size, font.flags
end

function Widget:SetTextColor(r, g, b, a)
  self.textColor = { r, g, b, a }
end

function Widget:SetJustifyH(justify)
  self.justifyH = justify
end

function Widget:SetJustifyV(justify)
  self.justifyV = justify
end

function Widget:GetStringWidth()
  return self.text and #self.text * 6 or 0
end

function Widget:GetStringHeight()
  return 12
end

function Widget:SetTexture(texture)
  self.texture = texture
end

function Widget:GetTexture()
  return self.texture
end

function Widget:SetDesaturated(desaturated)
  self.desaturated = desaturated and true or false
end

function Widget:IsDesaturated()
  return self.desaturated
end

function Widget:SetColorTexture(r, g, b, a)
  self.texture = { r = r, g = g, b = b, a = a }
end

function Widget:SetVertexColor(r, g, b, a)
  self.vertexColor = { r, g, b, a }
end

function Widget:SetTexCoord() end
function Widget:SetBackdrop(backdrop)
  self.backdrop = backdrop
end
function Widget:SetBackdropColor() end
function Widget:SetBackdropBorderColor() end

function Widget:CreateTexture(name, layer)
  local texture = newWidget(self.context, "Texture", name, self)
  texture.layer = layer
  table.insert(self.regions, texture)
  if name then
    self.context:setGlobal(name, texture)
  end
  return texture
end

function Widget:CreateFontString(name, layer)
  local fontString = newWidget(self.context, "FontString", name, self)
  fontString.layer = layer
  table.insert(self.regions, fontString)
  if name then
    self.context:setGlobal(name, fontString)
  end
  return fontString
end

function Widget:CreateLine()
  return newWidget(self.context, "Line", nil, self)
end

function Widget:GetRegions()
  return unpack(self.regions)
end

function Widget:GetChildren()
  return unpack(self.children)
end

function Widget:GetNumChildren()
  return #self.children
end

-- Sliders / editboxes / status bars ----------------------------------------

function Widget:SetMinMaxValues(minimum, maximum)
  self.minValue, self.maxValue = minimum, maximum
end

function Widget:GetMinMaxValues()
  return self.minValue or 0, self.maxValue or 0
end

function Widget:SetValue(value)
  self.value = value
  self:RunScript("OnValueChanged", value)
end

function Widget:GetValue()
  return self.value or 0
end

function Widget:SetValueStep(step)
  self.valueStep = step
end

function Widget:SetStatusBarTexture(texture)
  self.statusBarTexture = texture
end

function Widget:SetStatusBarColor(r, g, b, a)
  self.statusBarColor = { r, g, b, a }
end

function Widget:SetChecked(checked)
  self.checked = checked and true or false
end

function Widget:GetChecked()
  return self.checked
end

function Widget:SetAutoFocus() end
function Widget:ClearFocus() end
function Widget:SetFocus() end
function Widget:SetMaxLetters() end
function Widget:HighlightText() end
function Widget:Insert(text)
  self.text = (self.text or "") .. tostring(text)
end

function Widget:Enable()
  self.enabled = true
end

function Widget:Disable()
  self.enabled = false
end

function Widget:IsEnabled()
  return self.enabled ~= false
end

function Widget:SetNormalTexture() end
function Widget:SetHighlightTexture() end
function Widget:SetPushedTexture() end
function Widget:SetDisabledTexture() end
function Widget:SetNormalFontObject() end
function Widget:SetHighlightFontObject() end
function Widget:SetDisabledFontObject() end
function Widget:SetFontObject() end
function Widget:GetFontObject()
  return nil
end

function Widget:CreateAnimationGroup()
  local group = newWidget(self.context, "AnimationGroup", nil, self)
  group.animations = {}
  return group
end

function Widget:CreateAnimation(animationType)
  local animation = newWidget(self.context, animationType or "Animation", nil, self)
  if self.animations then
    table.insert(self.animations, animation)
  end
  return animation
end

function Widget:Play()
  self:RunScript("OnPlay")
  self:RunScript("OnFinished")
end

function Widget:Stop()
  self:RunScript("OnStop")
end

function Widget:SetDuration() end
function Widget:SetOrder() end
function Widget:SetChange() end
function Widget:SetSmoothing() end
function Widget:SetLooping() end
function Widget:IsPlaying()
  return false
end

--- Unknown widget methods resolve to a recording stub instead of erroring so a
-- single unmocked API does not mask the rest of the smoke test.
Widget.__index = function(widget, key)
  local member = rawget(Widget, key)
  if member ~= nil then
    return member
  end
  if type(key) ~= "string" or not string.match(key, "^%u") then
    return nil
  end
  local context = rawget(widget, "context")
  return function(...)
    context:noteMissingApi(string.format("%s:%s", rawget(widget, "objectType"), key))
    return nil, ...
  end
end

--- Install CreateFrame and the base UI frames into the sandbox globals.
function frames.install(context)
  local env = context.env

  local function createFrame(objectType, name, parent, template, id)
    objectType = objectType or "Frame"
    local widget = newWidget(context, objectType, name, parent or env.UIParent, template)
    widget.frameId = id
    if name then
      context:setGlobal(name, widget)
    end
    if template then
      for templateName in string.gmatch(template, "[^,%s]+") do
        context:noteTemplate(templateName)
      end
    end
    context:trackFrame(widget)
    widget:RunScript("OnLoad")
    return widget
  end

  env.CreateFrame = createFrame

  local uiParent = newWidget(context, "Frame", "UIParent", nil, nil)
  uiParent.width, uiParent.height = 1024, 768
  env.UIParent = uiParent
  context:setGlobal("UIParent", uiParent)

  -- Frames registered here are closed by Escape in the real client.
  env.UISpecialFrames = {}
  context:setGlobal("UISpecialFrames", env.UISpecialFrames)

  local worldFrame = newWidget(context, "Frame", "WorldFrame", nil, nil)
  env.WorldFrame = worldFrame
  context:setGlobal("WorldFrame", worldFrame)

  env.GetMouseFocus = function()
    return nil
  end

  context.createFrame = createFrame
  context.newWidget = function(objectType, name, parent)
    return newWidget(context, objectType, name, parent)
  end
end

frames.Widget = Widget

return frames
