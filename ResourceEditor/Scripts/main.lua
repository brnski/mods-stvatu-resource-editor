-- ResourceEditor v1.0
-- In-game console commands to view and edit ship resources.
-- Compatible with UE4SS experimental build for UE 5.6.
-- Author: see Nexus Mods page

local function log(s) print("[ResourceEditor] " .. s .. "\n") end

local function safeGet(fn)
    local ok, v = pcall(fn)
    return ok and v or nil
end

-- ── Find resource manager ──────────────────────────────────────────────────────

local function findResourceManager()
    local managers = FindAllOf("STVResourceManager")
    if not managers then return nil end
    for _, m in ipairs(managers) do
        if safeGet(function() return m:IsValid() end) then
            return m
        end
    end
    return nil
end

-- ── Resource name discovery ────────────────────────────────────────────────────
-- GetResourceNames() is a static BlueprintCallable on USTVResourceManager.
-- Falls back to a known list if the call fails.

local FALLBACK_RESOURCES = {
    "Food", "Deuterium", "Energy", "Morale", "MaxMorale",
    "Happiness", "LivingSpace", "Resilience",
}

local function getResourceNames(rm)
    local names = safeGet(function() return rm:GetResourceNames() end)
    if names and #names > 0 then
        local t = {}
        for i = 1, #names do t[i] = names[i] end
        return t
    end
    return FALLBACK_RESOURCES
end

-- ── List all resources ─────────────────────────────────────────────────────────

local function listResources(rm)
    local names = getResourceNames(rm)
    log("Current resource values:")
    for _, name in ipairs(names) do
        -- GetResourceAmount(ResourceName, bRemoveTemporaryModifiers)
        -- false = include temporary modifiers (current effective value)
        local val = safeGet(function() return rm:GetResourceAmount(name, false) end)
        local cap = safeGet(function() return rm:GetResourceCapacity(name) end)
        if val ~= nil then
            local line = string.format("  %-16s = %d", name, val)
            if cap and cap > 0 then line = line .. " / " .. tostring(cap) end
            log(line)
        end
    end
end

-- ── Console commands ───────────────────────────────────────────────────────────
-- Open the UE4SS console with ` (backtick) or ~ (tilde).
--
--   listresources              — print all resource values
--   getresource <Name>         — print one resource value
--   setresource <Name> <Value> — set a resource to a value

RegisterConsoleCommandHandler("listresources", function(fullCmd, params, ar)
    local rm = findResourceManager()
    if not rm then log("Error: resource manager not found (is a game loaded?)"); return true end
    listResources(rm)
    return true
end)

RegisterConsoleCommandHandler("getresource", function(fullCmd, params, ar)
    if #params < 1 then log("Usage: getresource <ResourceName>"); return true end
    local rm = findResourceManager()
    if not rm then log("Error: resource manager not found (is a game loaded?)"); return true end
    local name = params[1]
    local val = safeGet(function() return rm:GetResourceAmount(name, false) end)
    local cap = safeGet(function() return rm:GetResourceCapacity(name) end)
    if val ~= nil then
        local line = name .. " = " .. tostring(val)
        if cap and cap > 0 then line = line .. " / " .. tostring(cap) .. " (capacity)" end
        log(line)
    else
        log("Resource '" .. name .. "' not found. Use 'listresources' to see available names.")
    end
    return true
end)

RegisterConsoleCommandHandler("setresource", function(fullCmd, params, ar)
    if #params < 2 then log("Usage: setresource <ResourceName> <Value>"); return true end
    local name   = params[1]
    local amount = tonumber(params[2])
    if not amount then log("Error: value must be a number (got '" .. params[2] .. "')"); return true end

    local rm = findResourceManager()
    if not rm then log("Error: resource manager not found (is a game loaded?)"); return true end

    -- SetResourceAmount is a static function: SetResourceAmount(WorldContext, FSTVResourceParameter)
    -- FSTVResourceParameter has: ResourceName (FString), ResourceAmount (int32)
    -- Pass rm as the WorldContext; UE4SS maps the struct from a Lua table.
    local ok, err = pcall(function()
        rm:SetResourceAmount({ResourceName = name, ResourceAmount = math.floor(amount)})
    end)
    if ok then
        local newVal = safeGet(function() return rm:GetResourceAmount(name, false) end)
        log(name .. " -> " .. (newVal ~= nil and tostring(newVal) or tostring(math.floor(amount))))
    else
        log("Error setting '" .. name .. "': " .. tostring(err))
        log("Use 'listresources' to see available resource names.")
    end
    return true
end)

log("v1.0 loaded — commands: listresources | getresource <Name> | setresource <Name> <Value>")
