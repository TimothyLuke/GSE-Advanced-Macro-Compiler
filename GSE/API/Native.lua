-- Native GSE service layer.
-- This replaces the old addon/event/console/timer/comm/locale services
-- services while keeping the existing GSE:* call sites stable during migration.

GSE = GSE or {}
GSE.Static = GSE.Static or {}

GSE.DebugProfile = GSE.DebugProfile or function(event)
    if type(debugprofilestop) ~= "function" then
        return
    end
    local currentTimeStop = debugprofilestop()
    if GSE.ProfileStop and GSE.WagoAnalytics and type(GSE.WagoAnalytics.SetCounter) == "function" then
        GSE.WagoAnalytics:SetCounter("Init_" .. tostring(event), currentTimeStop - GSE.ProfileStop)
    end
    GSE.ProfileStop = currentTimeStop
end

local addonName = "GSE"
local currentLocale = GetLocale()

function GSE.GetAddOnMetadata(addon, field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addon, field)
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(addon, field)
    end
    return nil
end

function GSE.LoadAddOn(addon)
    if C_AddOns and C_AddOns.LoadAddOn then
        return C_AddOns.LoadAddOn(addon)
    end
    if LoadAddOn then
        return LoadAddOn(addon)
    end
    return nil, "MISSING_API"
end

function GSE.IsAddOnLoaded(addon)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addon)
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(addon)
    end
    return false
end

local function getPreviewMacroOptionCandidate(options)
    for segment in tostring(options or ""):gmatch("([^;]+)") do
        local candidate = segment:gsub("^%s+", ""):gsub("%s+$", "")
        while string.sub(candidate, 1, 1) == "[" do
            local closing = string.find(candidate, "]", 1, true)
            if not closing then
                candidate = ""
                break
            end
            candidate = string.sub(candidate, closing + 1):gsub("^%s+", ""):gsub("%s+$", "")
        end
        candidate = candidate:gsub("^reset=%S+%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
        while string.sub(candidate, 1, 1) == "!" do
            candidate = string.sub(candidate, 2):gsub("^%s+", ""):gsub("%s+$", "")
        end
        if candidate ~= "" then return candidate end
    end
end

function GSE.SafeSecureCmdOptionParse(options, suppressUIErrors)
    if not SecureCmdOptionParse or type(options) ~= "string" then return nil end
    if suppressUIErrors then
        return getPreviewMacroOptionCandidate(options)
    end
    if not suppressUIErrors then
        local ok, result, target = pcall(SecureCmdOptionParse, options)
        if ok then return result, target end
        return nil
    end

    local errorFrame = UIErrorsFrame
    local originalAddMessage
    local hadUIErrorMessageEvent
    if errorFrame and errorFrame.AddMessage then
        local unknownMacroOptionPrefix =
            type(ERR_UNKNOWN_MACRO_OPTION_S) == "string" and
            (ERR_UNKNOWN_MACRO_OPTION_S:match("^(.-)%%s") or ERR_UNKNOWN_MACRO_OPTION_S) or
            "Unknown macro option:"
        originalAddMessage = errorFrame.AddMessage
        local function filteredAddMessage(self, text, ...)
            if
                type(text) == "string" and unknownMacroOptionPrefix and unknownMacroOptionPrefix ~= "" and
                    text:find(unknownMacroOptionPrefix, 1, true)
             then
                return
            end
            return originalAddMessage(self, text, ...)
        end
        local replaced = pcall(function() errorFrame.AddMessage = filteredAddMessage end)
        if not replaced then originalAddMessage = nil end
    end
    if errorFrame and errorFrame.IsEventRegistered and errorFrame.UnregisterEvent then
        local ok, registered = pcall(errorFrame.IsEventRegistered, errorFrame, "UI_ERROR_MESSAGE")
        hadUIErrorMessageEvent = ok and registered
        if hadUIErrorMessageEvent then
            pcall(errorFrame.UnregisterEvent, errorFrame, "UI_ERROR_MESSAGE")
        end
    end

    local ok, result, target = pcall(SecureCmdOptionParse, options)

    if hadUIErrorMessageEvent and errorFrame and errorFrame.RegisterEvent then
        pcall(errorFrame.RegisterEvent, errorFrame, "UI_ERROR_MESSAGE")
    end
    if originalAddMessage and errorFrame then
        pcall(function() errorFrame.AddMessage = originalAddMessage end)
    end

    if ok then return result, target end
    return nil
end

local function newFallbackTimer(delay, callback, repeating)
    local timerFrame = CreateFrame("Frame")
    local elapsed = 0
    delay = tonumber(delay) or 0
    if repeating and delay <= 0 then
        delay = 0.01
    elseif delay < 0 then
        delay = 0
    end

    local timerHandle = {cancelled = false}
    function timerHandle:Cancel()
        if self.cancelled then
            return
        end
        self.cancelled = true
        timerFrame:SetScript("OnUpdate", nil)
        timerFrame:Hide()
    end

    timerFrame:SetScript(
        "OnUpdate",
        function(_, delta)
            elapsed = elapsed + (delta or 0)
            if elapsed < delay then
                return
            end

            if repeating then
                elapsed = 0
                callback()
            else
                timerHandle:Cancel()
                callback()
            end
        end
    )

    return timerHandle
end

function GSE.After(delay, callback)
    if C_Timer and C_Timer.After then
        return C_Timer.After(delay, callback)
    end
    return newFallbackTimer(delay, callback, false)
end

function GSE.NewTimer(delay, callback)
    if C_Timer and C_Timer.NewTimer then
        return C_Timer.NewTimer(delay, callback)
    end
    return newFallbackTimer(delay, callback, false)
end

function GSE.NewTicker(delay, callback)
    if C_Timer and C_Timer.NewTicker then
        return C_Timer.NewTicker(delay, callback)
    end
    return newFallbackTimer(delay, callback, true)
end

function GSE.GetSpellInfo(spell)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spell)
        if ok and spellInfo then
            return spellInfo
        end
    end
    if GetSpellInfo then
        local name, rank, iconID, castTime, minRange, maxRange, spellID, originalIconID = GetSpellInfo(spell)
        if name then
            return {
                name = name,
                rank = rank,
                iconID = iconID,
                castTime = castTime,
                minRange = minRange,
                maxRange = maxRange,
                spellID = spellID,
                originalIconID = originalIconID or iconID
            }
        end
    end
    return nil
end

function GSE.GetSpellCooldown(spell)
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spell)
        if ok and cooldownInfo then
            return cooldownInfo
        end
    end
    if GetSpellCooldown then
        local startTime, duration, isEnabled, modRate = GetSpellCooldown(spell)
        return {startTime = startTime, duration = duration, isEnabled = isEnabled, modRate = modRate}
    end
    return nil
end

function GSE.IsSpellUsable(spell)
    if C_Spell and C_Spell.IsSpellUsable then
        local ok, isUsable, notEnoughMana = pcall(C_Spell.IsSpellUsable, spell)
        if ok then
            return isUsable, notEnoughMana
        end
    end
    if IsUsableSpell then
        return IsUsableSpell(spell)
    end
    return false, false
end

function GSE.FindSpellBookSlotForSpell(spell)
    if C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell then
        local ok, slot = pcall(C_SpellBook.FindSpellBookSlotForSpell, spell)
        if ok then
            return slot
        end
    end
    if FindSpellBookSlotBySpellID then
        return FindSpellBookSlotBySpellID(spell)
    end
    return nil
end

function GSE.GetItemInfo(item)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(item)
    end
    if GetItemInfo then
        return GetItemInfo(item)
    end
    return nil
end

function GSE.GetCVar(name)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(name)
    end
    if GetCVar then
        return GetCVar(name)
    end
    return nil
end

function GSE.SetCVar(name, value)
    if C_CVar and C_CVar.SetCVar then
        return C_CVar.SetCVar(name, value)
    end
    if SetCVar then
        return SetCVar(name, value)
    end
    return nil, "MISSING_API"
end

function GSE.GetSpecializationInfoByID(specID)
    if GetSpecializationInfoByID then
        return GetSpecializationInfoByID(specID)
    end
    return nil
end

function GSE.GetClassInfo(classID)
    if C_CreatureInfo and C_CreatureInfo.GetClassInfo then
        return C_CreatureInfo.GetClassInfo(classID)
    end
    if GetClassInfo then
        local className, classFile, id = GetClassInfo(classID)
        if className then
            return {className = className, classFile = classFile, classID = id}
        end
    end
    return nil
end

function GSE.CreateContextMenu(owner, initializer)
    if MenuUtil and MenuUtil.CreateContextMenu then
        return MenuUtil.CreateContextMenu(owner, initializer)
    end
    if not EasyMenu then
        return nil
    end

    local menu = {}
    local rootDescription = {}

    -- Build a description object that mirrors the MenuUtil API so callers
    -- can add children to a button (creating a submenu) using the same code
    -- on both the modern MenuUtil path and this legacy EasyMenu path.
    -- Children added via :CreateButton() on the returned element populate
    -- menuItem.menuList and set hasArrow = true -- the EasyMenu
    -- convention for cascading submenus.
    local function makeDescriptionElement(menuItem, subList)
        local el = {}
        function el:SetEnabled(enabled)
            menuItem.disabled = not enabled
        end
        function el:SetTooltip(func)
            -- Legacy EasyMenu shows tooltips via tooltipTitle/tooltipText on
            -- the menu item.  We harvest the text by running the modern-style
            -- callback against a tiny proxy that records AddLine calls.
            if type(func) ~= "function" then return end
            local lines = {}
            local proxy = {
                AddLine        = function(_, text) if text then table.insert(lines, text) end end,
                AddNormalLine  = function(_, text) if text then table.insert(lines, text) end end,
                SetText        = function(_, text) if text then table.insert(lines, text) end end,
            }
            pcall(func, proxy, el)
            if #lines > 0 then
                menuItem.tooltipTitle   = menuItem.text
                menuItem.tooltipText    = table.concat(lines, "\n")
                menuItem.tooltipOnButton = true
            end
        end
        function el:CreateButton(text, callback)
            local subItem = {text = text, notCheckable = true, func = callback}
            table.insert(subList, subItem)
            menuItem.hasArrow = true
            return makeDescriptionElement(subItem, {})
        end
        function el:CreateTitle(text)
            table.insert(subList, {text = text, isTitle = true, notCheckable = true})
            menuItem.hasArrow = true
        end
        function el:CreateDivider()
            table.insert(subList, {text = "", disabled = true, notCheckable = true})
            menuItem.hasArrow = true
        end
        return el
    end

    function rootDescription:CreateTitle(text)
        table.insert(menu, {text = text, isTitle = true, notCheckable = true})
    end

    function rootDescription:CreateDivider()
        table.insert(menu, {text = "", disabled = true, notCheckable = true})
    end

    function rootDescription:CreateButton(text, callback)
        local subList = {}
        local menuItem = {text = text, notCheckable = true, func = callback, menuList = subList}
        table.insert(menu, menuItem)
        return makeDescriptionElement(menuItem, subList)
    end

    function rootDescription:CreateCheckbox(text, isSelected, setSelected)
        local menuItem = {
            text = text,
            checked = function()
                return isSelected and isSelected()
            end,
            func = function()
                if setSelected then setSelected() end
            end,
            isNotRadio = true,
            keepShownOnClick = false
        }
        table.insert(menu, menuItem)
        return makeDescriptionElement(menuItem, {})
    end

    function rootDescription:CreateRadio(text, isSelected, setSelected)
        local menuItem = {
            text = text,
            checked = function()
                return isSelected and isSelected()
            end,
            func = function()
                if setSelected then setSelected() end
            end,
            keepShownOnClick = false
        }
        table.insert(menu, menuItem)
        return makeDescriptionElement(menuItem, {})
    end

    initializer(owner, rootDescription)
    if #menu == 0 then
        return nil
    end

    GSE.ContextMenuFrame = GSE.ContextMenuFrame or CreateFrame("Frame", "GSEContextMenuFrame", UIParent, "UIDropDownMenuTemplate")
    EasyMenu(menu, GSE.ContextMenuFrame, "cursor", 0, 0, "MENU")
    return GSE.ContextMenuFrame
end

local function normalizeLocaleValue(key, value)
    if value == true then
        return key
    end
    return value
end

GSE.L =
    GSE.L or
    setmetatable(
        {},
        {
            __index = function(_, key)
                return key
            end,
            __newindex = function(tableRef, key, value)
                rawset(tableRef, key, normalizeLocaleValue(key, value))
            end
        }
    )

function GSE.RegisterLocale(localeName, isDefault)
    if isDefault or localeName == currentLocale then
        return GSE.L
    end
    return nil
end

local eventFrame = CreateFrame("Frame", "GSENativeEventFrame")
local eventHandlers = {}
local messageHandlers = {}

local function addCallback(registry, owner, eventName, method, arg)
    method = method or eventName

    local key = owner
    local callback

    if type(method) == "function" then
        key = method
        if arg ~= nil then
            callback = function(...)
                method(arg, ...)
            end
        else
            callback = method
        end
    elseif type(method) == "string" then
        if type(arg) == "function" and (type(owner) ~= "table" or type(owner[method]) ~= "function") then
            key = method
            callback = arg
        elseif type(owner) == "table" and type(owner[method]) == "function" then
            if arg ~= nil then
                callback = function(...)
                    owner[method](owner, arg, ...)
                end
            else
                callback = function(...)
                    owner[method](owner, ...)
                end
            end
        else
            error(("Callback method '%s' was not found."):format(tostring(method)), 3)
        end
    else
        error("Callback method must be a function or method name.", 3)
    end

    registry[eventName] = registry[eventName] or {}
    registry[eventName][key] = callback
    return key
end

local function removeCallback(registry, owner, eventName, key)
    if not registry[eventName] then
        return
    end

    registry[eventName][key or owner] = nil
end

local function dispatch(registry, eventName, ...)
    local callbacks = registry[eventName]
    if not callbacks then
        return
    end

    for _, callback in pairs(callbacks) do
        callback(eventName, ...)
    end
end

function GSE:RegisterEvent(eventName, method, arg)
    addCallback(eventHandlers, self, eventName, method, arg)
    eventFrame:RegisterEvent(eventName)
end

function GSE:UnregisterEvent(eventName, key)
    removeCallback(eventHandlers, self, eventName, key)
    if not eventHandlers[eventName] or not next(eventHandlers[eventName]) then
        eventFrame:UnregisterEvent(eventName)
    end
end

function GSE:UnregisterAllEvents()
    for eventName, callbacks in pairs(eventHandlers) do
        callbacks[self] = nil
        if not next(callbacks) then
            eventFrame:UnregisterEvent(eventName)
        end
    end
end

function GSE:RegisterMessage(messageName, method, arg)
    addCallback(messageHandlers, self, messageName, method, arg)
end

function GSE:UnregisterMessage(messageName, key)
    removeCallback(messageHandlers, self, messageName, key)
end

function GSE:UnregisterAllMessages()
    for _, callbacks in pairs(messageHandlers) do
        callbacks[self] = nil
    end
end

function GSE:SendMessage(messageName, ...)
    dispatch(messageHandlers, messageName, ...)
end

local function callTimer(owner, method, ...)
    if type(method) == "function" then
        method(...)
    elseif type(method) == "string" and type(owner[method]) == "function" then
        owner[method](owner, ...)
    else
        error(("Timer callback '%s' was not found."):format(tostring(method)), 3)
    end
end

function GSE:ScheduleTimer(method, delay, ...)
    local args = {...}
    return GSE.NewTimer(
        delay,
        function()
            callTimer(self, method, unpack(args))
        end
    )
end

function GSE:ScheduleRepeatingTimer(method, delay, ...)
    local args = {...}
    return GSE.NewTicker(
        delay,
        function()
            callTimer(self, method, unpack(args))
        end
    )
end

function GSE:CancelTimer(timerHandle)
    if timerHandle and timerHandle.Cancel then
        timerHandle:Cancel()
    end
end

function GSE:RegisterChatCommand(command, method)
    local token = ("%s_%s"):format(addonName, command):upper():gsub("[^A-Z0-9_]", "_")
    _G["SLASH_" .. token .. "1"] = "/" .. command
    SlashCmdList[token] = function(input)
        if type(method) == "function" then
            method(input)
        elseif type(method) == "string" and type(self[method]) == "function" then
            self[method](self, input)
        end
    end
end

-- /rl is a near-universal "reload the UI" shortcut. Its effect (ReloadUI) is
-- identical no matter which addon owns it, so registering it unconditionally is
-- safe -- there is no behavioural collision even if another addon also claims it.
GSE:RegisterChatCommand("rl", function()
    if ReloadUI then ReloadUI() end
end)

local commFrame = CreateFrame("Frame", "GSENativeCommFrame")
local commHandlers = {}
local multipartSpool = {}
local sendQueue = {}
local sendActive = false

local MSG_MULTI_FIRST = string.char(1)
local MSG_MULTI_NEXT = string.char(2)
local MSG_MULTI_LAST = string.char(3)
local MSG_ESCAPE = string.char(4)

local function sendAddonMessage(prefix, text, distribution, target)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        return C_ChatInfo.SendAddonMessage(prefix, text, distribution, target)
    end
    return SendAddonMessage(prefix, text, distribution, target)
end

local function pumpSendQueue()
    if sendActive then
        return
    end

    local item = table.remove(sendQueue, 1)
    if not item then
        return
    end

    sendAddonMessage(item.prefix, item.text, item.distribution, item.target)

    sendActive = true
    GSE.After(
        0.05,
        function()
            sendActive = false
            pumpSendQueue()
        end
    )
end

local function queueAddonMessage(prefix, text, distribution, target)
    table.insert(sendQueue, {prefix = prefix, text = text, distribution = distribution, target = target})
    pumpSendQueue()
end

local function fireComm(prefix, message, distribution, sender)
    local callbacks = commHandlers[prefix]
    if not callbacks then
        return
    end

    for _, callback in pairs(callbacks) do
        callback(prefix, message, distribution, sender)
    end
end

function GSE:RegisterComm(prefix, method)
    method = method or "OnCommReceived"
    if #prefix > 16 then
        error("RegisterComm prefix length is limited to 16 characters.", 2)
    end

    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    else
        RegisterAddonMessagePrefix(prefix)
    end

    commHandlers[prefix] = commHandlers[prefix] or {}
    commHandlers[prefix][self] = function(...)
        if type(method) == "function" then
            method(...)
        elseif type(method) == "string" and type(self[method]) == "function" then
            self[method](self, ...)
        end
    end
end

function GSE:UnregisterComm(prefix)
    if commHandlers[prefix] then
        commHandlers[prefix][self] = nil
    end
end

function GSE:UnregisterAllComm()
    for _, callbacks in pairs(commHandlers) do
        callbacks[self] = nil
    end
end

function GSE:SendCommMessage(prefix, text, distribution, target)
    if type(prefix) ~= "string" or type(text) ~= "string" or type(distribution) ~= "string" then
        error('Usage: SendCommMessage("prefix", "text", "distribution"[, "target"])', 2)
    end

    local textLength = #text
    local maxTextLength = 255
    local forceMultipart

    if text:match("^[\001-\009]") then
        if textLength + 1 > maxTextLength then
            forceMultipart = true
        else
            text = MSG_ESCAPE .. text
        end
    end

    if not forceMultipart and textLength <= maxTextLength then
        queueAddonMessage(prefix, text, distribution, target)
        return
    end

    maxTextLength = maxTextLength - 1
    queueAddonMessage(prefix, MSG_MULTI_FIRST .. text:sub(1, maxTextLength), distribution, target)

    local position = 1 + maxTextLength
    while position + maxTextLength <= textLength do
        queueAddonMessage(prefix, MSG_MULTI_NEXT .. text:sub(position, position + maxTextLength - 1), distribution, target)
        position = position + maxTextLength
    end

    queueAddonMessage(prefix, MSG_MULTI_LAST .. text:sub(position), distribution, target)
end

commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:SetScript(
    "OnEvent",
    function(_, _, prefix, message, distribution, sender)
        sender = Ambiguate(sender, "none")
        local control, rest = message:match("^([\001-\009])(.*)")

        if not control then
            fireComm(prefix, message, distribution, sender)
        elseif control == MSG_ESCAPE then
            fireComm(prefix, rest, distribution, sender)
        elseif control == MSG_MULTI_FIRST then
            multipartSpool[prefix .. "\t" .. distribution .. "\t" .. sender] = rest
        elseif control == MSG_MULTI_NEXT then
            local key = prefix .. "\t" .. distribution .. "\t" .. sender
            local existing = multipartSpool[key]
            if not existing then
                return
            end
            if type(existing) ~= "table" then
                multipartSpool[key] = {existing, rest}
            else
                table.insert(existing, rest)
            end
        elseif control == MSG_MULTI_LAST then
            local key = prefix .. "\t" .. distribution .. "\t" .. sender
            local existing = multipartSpool[key]
            multipartSpool[key] = nil
            if not existing then
                return
            end
            if type(existing) == "table" then
                table.insert(existing, rest)
                fireComm(prefix, table.concat(existing, ""), distribution, sender)
            else
                fireComm(prefix, existing .. rest, distribution, sender)
            end
        end
    end
)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript(
    "OnEvent",
    function(_, eventName, ...)
        local loadedAddon = ...
        if eventName == "ADDON_LOADED" and loadedAddon == addonName then
            if type(GSE.OnInitialize) == "function" and not GSE.__NativeInitialized then
                GSE.__NativeInitialized = true
                GSE:OnInitialize()
            end
            if type(GSE.OnEnable) == "function" and not GSE.__NativeEnabled then
                GSE.__NativeEnabled = true
                GSE:OnEnable()
            end
            if not eventHandlers.ADDON_LOADED or not next(eventHandlers.ADDON_LOADED) then
                eventFrame:UnregisterEvent("ADDON_LOADED")
            end
        end

        dispatch(eventHandlers, eventName, ...)
    end
)
