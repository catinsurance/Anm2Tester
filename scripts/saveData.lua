local json = require("json")
local anm2Tester = anmTester

anm2Tester.DefaultData = {
    Options = {},
    Configs = {},
    DSS = {}, -- filled automatically
}


-- Patches table `deposit` with table `source`.
local function patchFile(deposit, source)
    for i, v in pairs(source) do
        if deposit[i] ~= nil then
            if type(v) == "table" then
                if type(deposit[i]) ~= "table" then
                    deposit[i] = {}
                end

                deposit[i] = patchFile(deposit[i], v)
            end
        else
            if type(v) == "table" then
                if type(deposit[i]) ~= "table" then
                    deposit[i] = {}
                end

                deposit[i] = patchFile({}, v)
            else
                deposit[i] = v
            end
        end
    end

    return deposit
end

function anm2Tester:RefreshSaveData()
    local loaded
    if anm2Tester:HasData() then
        loaded = json.decode(anm2Tester:LoadData())

        if type(anm2Tester) ~= "table" then
            loaded = {}
        end
    else
        loaded = {}
    end

    if loaded == nil then
        loaded = {}
    end

    -- Patch, then save patched data.
    anm2Tester.ModData = patchFile(loaded, anm2Tester.DefaultData)

    anm2Tester:SaveData(json.encode(anm2Tester.ModData))
end

anm2Tester:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, anm2Tester.RefreshSaveData)

function anm2Tester:Save()
    if anm2Tester.ModData then
        for _, config in pairs(anm2Tester.ModData.Configs) do
            config.Sprite = nil
        end
    end

    anm2Tester:SaveData(json.encode(anm2Tester.ModData))
end

anm2Tester:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, anm2Tester.Save)

function anm2Tester:HandleLuamodSave(mod)
    if mod.Name == self.Name and Game():GetNumPlayers() > 0 and anm2Tester.ModData then
        anm2Tester:Save()
    end
end

anm2Tester:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, anm2Tester.HandleLuamodSave)


--[[ You don't have to use these, but it's safer since item works before and during MC_POST_GAME_STARTED]]
function anm2Tester:GetOption(name)
    if not anm2Tester.ModData then
        anm2Tester:RefreshSaveData()
    end

    return anm2Tester.ModData.Options[name]
end

function anm2Tester:SetOption(name, value)
    if not anm2Tester.ModData then
        anm2Tester:RefreshSaveData()
    end

    anm2Tester.ModData.Options[name] = value
end

-- Gets a config.
function anm2Tester:GetConfig(name)
    if not anm2Tester.ModData then
        anm2Tester:RefreshSaveData()
    end

    return anm2Tester.ModData.Configs[name]
end

function anm2Tester:GetDssData()
    if not anm2Tester.ModData then
        anm2Tester:RefreshSaveData()
    end

    return anm2Tester.ModData.DSS
end