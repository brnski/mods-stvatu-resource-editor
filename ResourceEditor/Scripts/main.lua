-- ResourceEditor v1.0
-- In-game console commands to view and edit ship resources.
-- Compatible with UE4SS experimental build for UE 5.6.
-- Author: see Nexus Mods page

local function log(s) print("[ResourceEditor] " .. s .. "\n") end

-- Write to both UE4SS.log and the in-game console output device.
local function out(ar, s)
    log(s)
    pcall(function() ar:Log(s) end)
end

local function safeGet(fn)
    local ok, v = pcall(fn)
    return ok and v or nil
end

-- Known resource name keys passed to GetResourceAmount / SetResourceAmount.
-- GetResourceNames() returns TArray<FString> which crashes UE4SS Lua — use hardcoded list.
local RESOURCES = {
    "Food", "Deuterium", "Energy", "Morale", "MaxMorale",
    "Happiness", "LivingSpace", "Resilience",
}

-- ── Find resource manager ──────────────────────────────────────────────────────

local function findResourceManager()
    local managers = FindAllOf("STVResourceManager")
    if not managers then return nil end
    for _, m in ipairs(managers) do
        if safeGet(function() return m:IsValid() end) then return m end
    end
    return nil
end

-- ── Read a resource amount safely ──────────────────────────────────────────────

local function readResource(rm, name)
    -- GetResourceAmount(ResourceName, bRemoveTemporaryModifiers)
    -- false = keep temporary modifiers, giving the current effective value
    return safeGet(function() return rm:GetResourceAmount(name, false) end)
end

-- ── Console commands ───────────────────────────────────────────────────────────

RegisterConsoleCommandHandler("listresources", function(fullCmd, params, ar)
    local rm = findResourceManager()
    if not rm then out(ar, "Error: resource manager not found (is a game loaded?)"); return true end
    out(ar, "Current resource values:")
    for _, name in ipairs(RESOURCES) do
        local val = readResource(rm, name)
        if val ~= nil then
            out(ar, string.format("  %-16s = %d", name, val))
        else
            out(ar, string.format("  %-16s = (unavailable)", name))
        end
    end
    return true
end)

RegisterConsoleCommandHandler("getresource", function(fullCmd, params, ar)
    if #params < 1 then out(ar, "Usage: getresource <ResourceName>"); return true end
    local rm = findResourceManager()
    if not rm then out(ar, "Error: resource manager not found (is a game loaded?)"); return true end
    local name = params[1]
    local val = readResource(rm, name)
    if val ~= nil then
        out(ar, name .. " = " .. tostring(val))
    else
        out(ar, "'" .. name .. "' not found. Try: listresources")
    end
    return true
end)

RegisterConsoleCommandHandler("setresource", function(fullCmd, params, ar)
    if #params < 2 then out(ar, "Usage: setresource <ResourceName> <Value>"); return true end
    local name   = params[1]
    local amount = tonumber(params[2])
    if not amount then out(ar, "Error: value must be a number"); return true end
    amount = math.floor(amount)

    local rm = findResourceManager()
    if not rm then out(ar, "Error: resource manager not found (is a game loaded?)"); return true end

    local before = readResource(rm, name)
    if before == nil then
        out(ar, "Warning: '" .. name .. "' returned nil — name may be wrong.")
    end

    -- SetResourceAmount is a static function: (UObject* WorldContext, FSTVResourceParameter Resource)
    -- FSTVResourceParameter fields: ResourceName (FString), ResourceAmount (int32)
    -- rm is passed explicitly as the WorldContext (UE4SS does not auto-fill it).
    local ok, err = pcall(function()
        rm:SetResourceAmount(rm, {ResourceName = name, ResourceAmount = amount})
    end)

    if not ok then
        out(ar, "SetResourceAmount error: " .. tostring(err))
        return true
    end

    local after = readResource(rm, name)
    if after ~= nil then
        out(ar, name .. ": " .. tostring(before) .. " -> " .. tostring(after))
        if after == before then
            out(ar, "Value unchanged — struct mapping may have failed.")
        end
    end

    return true
end)

log("v1.0 loaded — commands: listresources | getresource <Name> | setresource <Name> <Value>")
