local Type = "SelectablePanel"
local Version = 1

local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end



-------------
-- Widgets --
-------------
--[[
	Widgets must provide the following functions
		Acquire() - Called when the object is aquired, should set everything to a default hidden state
		Release() - Called when the object is Released, should remove any anchors and hide the Widget

	And the following members
		frame - the frame or derivitive object that will be treated as the widget for size and anchoring purposes
		type - the type of the object, same as the name given to :RegisterWidget()

	Widgets contain a table called userdata, this is a safe place to store data associated with the wigdet
	It will be cleared automatically when a widget is released
	Placing values directly into a widget object should be avoided

	If the Widget can act as a container for other Widgets the following
		content - frame or derivitive that children will be anchored to

	The Widget can supply the following Optional Members
]]

--------------------------
-- Selectable Palen	    --
--------------------------
--[[
	This is a simple grouping container, that responds to move over and click.
	It will resize automatically to the height of the controls added to it

  It expects that a Key is set to identify it.
]]


local function OnAcquire(self)
	self:SetWidth(300)
	self:SetHeight(100)
end

local function OnRelease(self)
	self.frame:ClearAllPoints()
	self.frame:Hide()
	self.Clicked = false
end

local function SelectablePanel_OnClick(self, button)
  if button == "LeftButton" then
    if self.Clicked then
      self.Clicked = false
			self.obj.border:SetAlpha(0) -- half-alpha light grey
		else
			self.obj.border:SetAlpha(0.6) -- half-alpha light grey
			self.Clicked = true
    end
  end
	self.obj:Fire("OnClick", self.Clicked, button)
end


local function LayoutFinished(self, width, height)
	if self.noAutoHeight then return end
	self:SetHeight((height or 0) + 10)
end

local function OnWidthSet(self, width)
	local content = self.content
	local contentwidth = width - 20
	if contentwidth < 0 then
		contentwidth = 0
	end
	content:SetWidth(contentwidth)
	content.width = contentwidth
end

local function OnHeightSet(self, height)
	local content = self.content
	local contentheight = height - 20
	if contentheight < 0 then
		contentheight = 0
	end
	content:SetHeight(contentheight)
	content.height = contentheight
end

local function SetClicked(self, boole)
  if boole then
		self.border:SetAlpha(0.6) -- half-alpha light grey
		self.Clicked = true
	else
		self.Clicked = false
		self.border:SetAlpha(0) -- half-alpha light grey
	end
end

local function SetKey(self, key)
  self.Key = key
end

local function GetKey(self)
  return self.Key
end


local function Constructor()
	local frame = CreateFrame("Frame",nil,UIParent)

	local self = {}
	self.type = Type

	self.OnRelease = OnRelease
	self.OnAcquire = OnAcquire
	self.frame = frame
	self.LayoutFinished = LayoutFinished
	self.OnWidthSet = OnWidthSet
	self.OnHeightSet = OnHeightSet


  self.Clicked = false
	self.Key = ""
  self.SetKey = SetKey
	self.GetKey = GetKey
  self.SetClicked = SetClicked

	frame.obj = self

	frame:SetHeight(100)
	frame:SetWidth(100)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetScript("OnMouseUp", SelectablePanel_OnClick)
  local highlightTexture = frame:CreateTexture(nil, "HIGHLIGHT")
  highlightTexture:SetAllPoints(true)
  highlightTexture:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
	highlightTexture:SetAlpha(1)
  frame:EnableMouse(true)

  local border=frame:CreateTexture(nil, "BACKGROUND")
	border:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	border:SetPoint("TOPLEFT",-2,2)
  border:SetPoint("BOTTOMRIGHT",2,-2)
	border:SetVertexColor(1.0, 0.96, 0.41, 0) -- half-alpha light grey


  self.border = border

	--Container Support
	local content = CreateFrame("Frame",nil,frame)
	self.content = content
	content.obj = self
	content:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0)
	content:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)


	AceGUI:RegisterAsContainer(self)
	return self
end



AceGUI:RegisterWidgetType(Type,Constructor,Version)
