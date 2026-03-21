-- ResourceEditor v1.1
-- In-game console commands to view and edit ship resources, hull, and warp core.
-- Compatible with UE4SS experimental build for UE 5.6.
-- Author: see Nexus Mods page

local function log(s) print("[ResourceEditor] " .. s .. "\n") end

local function out(ar, s)
    log(s)
    pcall(function() ar:Log(s) end)
end

local function safeGet(fn)
    local ok, v = pcall(fn)
    return ok and v or nil
end

-- Confirmed resource names from STVResourceSettings + data tables.
local RESOURCES = {
    "Food", "Deuterium", "Energy", "Morale", "MoraleMax",
    "Happiness", "LivingSpace", "Cycles", "SciencePoints",
    "BioNeuralGelPacks", "BorgNanites",
}

-- Speculative names — shown in listresources only if the game returns a non-zero value.
local RESOURCES_SPECULATIVE = {
    "Nanites", "Nanoprobes", "BorgNanoprobes",
    "Assimilated", "HullIntegrity", "Resilience", "MaxMorale",
}

-- ── Finders ───────────────────────────────────────────────────────────────────

local function findFirst(className)
    local objs = FindAllOf(className)
    if not objs then return nil end
    for _, o in ipairs(objs) do
        if safeGet(function() return o:IsValid() end) then return o end
    end
    return nil
end

local function findResourceManager()    return findFirst("STVResourceManager")    end
local function findConstructionManager() return findFirst("STVConstructionManager") end

-- ── Resource helpers ───────────────────────────────────────────────────────────

local function readResource(rm, name)
    return safeGet(function() return rm:GetResourceAmount(name, false) end)
end

local function setResource(ar, rm, name, amount)
    local before = readResource(rm, name)
    if before == nil then
        out(ar, "Warning: '" .. name .. "' returned nil — name may be wrong.")
    end
    local ok, err = pcall(function()
        rm:SetResourceAmount(rm, {ResourceName = name, ResourceAmount = amount})
    end)
    if not ok then
        out(ar, "Error setting '" .. name .. "': " .. tostring(err)); return false
    end
    local after = readResource(rm, name)
    if after ~= nil then
        out(ar, string.format("%-16s %d -> %d", name, before or 0, after))
        if after == before then out(ar, "  (unchanged — check resource name)") end
    end
    return true
end

-- ── Resource commands ──────────────────────────────────────────────────────────

RegisterConsoleCommandHandler("listresources", function(fullCmd, params, ar)
    local rm = findResourceManager()
    if not rm then out(ar, "Error: resource manager not found"); return true end
    out(ar, "Current resource values:")
    for _, name in ipairs(RESOURCES) do
        local val = readResource(rm, name)
        if val ~= nil then
            out(ar, string.format("  %-20s = %d", name, val))
        else
            out(ar, string.format("  %-20s = (unavailable)", name))
        end
    end
    for _, name in ipairs(RESOURCES_SPECULATIVE) do
        local val = readResource(rm, name)
        if val ~= nil and val ~= 0 then
            out(ar, string.format("  %-20s = %d  (*discovered)", name, val))
        end
    end
    local cm = findConstructionManager()
    if cm then
        local hull     = safeGet(function() return cm.HullIntegrity end)
        local maxHull  = safeGet(function() return cm:GetMaxHullIntegrity() end)
        local warp     = safeGet(function() return cm:GetWarpCoreIntegrity() end)
        local maxWarp  = safeGet(function() return cm:GetMaxWarpCoreIntegrity() end)
        if hull    then out(ar, string.format("  %-20s = %.1f / %.1f  (use: repairhull / sethull)", "HullIntegrity", hull, maxHull or 0)) end
        if warp    then out(ar, string.format("  %-20s = %.1f / %.1f  (use: repairwarpcore / setwarpcore)", "WarpCoreIntegrity", warp, maxWarp or 0)) end
    end
    return true
end)

RegisterConsoleCommandHandler("getresource", function(fullCmd, params, ar)
    if #params < 1 then out(ar, "Usage: getresource <ResourceName>"); return true end
    local rm = findResourceManager()
    if not rm then out(ar, "Error: resource manager not found"); return true end
    local val = readResource(rm, params[1])
    if val ~= nil then out(ar, params[1] .. " = " .. tostring(val))
    else out(ar, "'" .. params[1] .. "' not found. Try: listresources") end
    return true
end)

RegisterConsoleCommandHandler("setresource", function(fullCmd, params, ar)
    if #params < 2 then out(ar, "Usage: setresource <ResourceName> <Value>"); return true end
    local amount = tonumber(params[2])
    if not amount then out(ar, "Error: value must be a number"); return true end
    local rm = findResourceManager()
    if not rm then out(ar, "Error: resource manager not found"); return true end
    setResource(ar, rm, params[1], math.floor(amount))
    return true
end)

RegisterConsoleCommandHandler("addresource", function(fullCmd, params, ar)
    if #params < 2 then out(ar, "Usage: addresource <ResourceName> <Amount>"); return true end
    local amount = tonumber(params[2])
    if not amount then out(ar, "Error: amount must be a number"); return true end
    local rm = findResourceManager()
    if not rm then out(ar, "Error: resource manager not found"); return true end
    local cur = readResource(rm, params[1]) or 0
    setResource(ar, rm, params[1], math.floor(cur + amount))
    return true
end)

RegisterConsoleCommandHandler("removeresource", function(fullCmd, params, ar)
    if #params < 2 then out(ar, "Usage: removeresource <ResourceName> <Amount>"); return true end
    local amount = tonumber(params[2])
    if not amount then out(ar, "Error: amount must be a number"); return true end
    local rm = findResourceManager()
    if not rm then out(ar, "Error: resource manager not found"); return true end
    local cur = readResource(rm, params[1]) or 0
    setResource(ar, rm, params[1], math.max(0, math.floor(cur - amount)))
    return true
end)

RegisterConsoleCommandHandler("addallresources", function(fullCmd, params, ar)
    if #params < 1 then out(ar, "Usage: addallresources <Amount>"); return true end
    local amount = tonumber(params[1])
    if not amount then out(ar, "Error: amount must be a number"); return true end
    local rm = findResourceManager()
    if not rm then out(ar, "Error: resource manager not found"); return true end
    for _, name in ipairs(RESOURCES) do
        local cur = readResource(rm, name) or 0
        setResource(ar, rm, name, math.floor(cur + amount))
    end
    return true
end)

-- ── Hull integrity commands ────────────────────────────────────────────────────
-- HullIntegrity is a BlueprintReadWrite float on STVConstructionManager.
-- GetMaxHullIntegrity() returns the cap so we can set to full.

RegisterConsoleCommandHandler("repairhull", function(fullCmd, params, ar)
    local cm = findConstructionManager()
    if not cm then out(ar, "Error: construction manager not found"); return true end
    local maxHull = safeGet(function() return cm:GetMaxHullIntegrity() end)
    if not maxHull then out(ar, "Error: could not read max hull integrity"); return true end
    local before = safeGet(function() return cm.HullIntegrity end) or 0
    local ok, err = pcall(function() cm.HullIntegrity = maxHull end)
    if not ok then out(ar, "Error: " .. tostring(err)); return true end
    local after = safeGet(function() return cm.HullIntegrity end) or maxHull
    out(ar, string.format("Hull integrity: %.1f -> %.1f (max: %.1f)", before, after, maxHull))
    return true
end)

RegisterConsoleCommandHandler("sethull", function(fullCmd, params, ar)
    if #params < 1 then out(ar, "Usage: sethull <0.0-1.0>  (ratio of max)"); return true end
    local ratio = tonumber(params[1])
    if not ratio then out(ar, "Error: ratio must be a number"); return true end
    ratio = math.max(0.0, math.min(1.0, ratio))
    local cm = findConstructionManager()
    if not cm then out(ar, "Error: construction manager not found"); return true end
    local maxHull = safeGet(function() return cm:GetMaxHullIntegrity() end)
    if not maxHull then out(ar, "Error: could not read max hull integrity"); return true end
    local target = maxHull * ratio
    local before = safeGet(function() return cm.HullIntegrity end) or 0
    local ok, err = pcall(function() cm.HullIntegrity = target end)
    if not ok then out(ar, "Error: " .. tostring(err)); return true end
    local after = safeGet(function() return cm.HullIntegrity end) or target
    out(ar, string.format("Hull integrity: %.1f -> %.1f (max: %.1f)", before, after, maxHull))
    return true
end)

-- ── Warp core commands ─────────────────────────────────────────────────────────
-- SetWarpCoreIntegrity(float) is a BlueprintCallable instance method.

RegisterConsoleCommandHandler("repairwarpcore", function(fullCmd, params, ar)
    local cm = findConstructionManager()
    if not cm then out(ar, "Error: construction manager not found"); return true end
    local maxWarp = safeGet(function() return cm:GetMaxWarpCoreIntegrity() end)
    if not maxWarp then out(ar, "Error: could not read max warp core integrity"); return true end
    local before = safeGet(function() return cm:GetWarpCoreIntegrity() end) or 0
    local ok, err = pcall(function() cm:SetWarpCoreIntegrity(maxWarp) end)
    if not ok then out(ar, "Error: " .. tostring(err)); return true end
    local after = safeGet(function() return cm:GetWarpCoreIntegrity() end) or maxWarp
    out(ar, string.format("Warp core: %.1f -> %.1f (max: %.1f)", before, after, maxWarp))
    return true
end)

RegisterConsoleCommandHandler("setwarpcore", function(fullCmd, params, ar)
    if #params < 1 then out(ar, "Usage: setwarpcore <0.0-1.0>  (ratio of max)"); return true end
    local ratio = tonumber(params[1])
    if not ratio then out(ar, "Error: ratio must be a number"); return true end
    ratio = math.max(0.0, math.min(1.0, ratio))
    local cm = findConstructionManager()
    if not cm then out(ar, "Error: construction manager not found"); return true end
    local maxWarp = safeGet(function() return cm:GetMaxWarpCoreIntegrity() end)
    if not maxWarp then out(ar, "Error: could not read max warp core integrity"); return true end
    local before = safeGet(function() return cm:GetWarpCoreIntegrity() end) or 0
    local ok, err = pcall(function() cm:SetWarpCoreIntegrity(maxWarp * ratio) end)
    if not ok then out(ar, "Error: " .. tostring(err)); return true end
    local after = safeGet(function() return cm:GetWarpCoreIntegrity() end) or maxWarp * ratio
    out(ar, string.format("Warp core: %.1f -> %.1f (max: %.1f)", before, after, maxWarp))
    return true
end)

RegisterConsoleCommandHandler("rehelp", function(fullCmd, params, ar)
    out(ar, "ResourceEditor commands:")
    out(ar, "  listresources                     — show all current values")
    out(ar, "  getresource <Name>                — show one resource value")
    out(ar, "  setresource <Name> <Value>        — set resource to exact value")
    out(ar, "  addresource <Name> <Amount>       — add to current value")
    out(ar, "  removeresource <Name> <Amount>    — subtract from current value")
    out(ar, "  addallresources <Amount>          — add to all resources")
    out(ar, "  repairhull                        — restore hull to max")
    out(ar, "  sethull <0.0-1.0>                 — set hull as ratio of max")
    out(ar, "  repairwarpcore                    — restore warp core to max")
    out(ar, "  setwarpcore <0.0-1.0>             — set warp core as ratio of max")
    out(ar, "  rehelp                            — show this help")
    out(ar, "Resource names: " .. table.concat(RESOURCES, ", "))
    return true
end)

log("v1.1 loaded — type 'rehelp' for a list of commands")
