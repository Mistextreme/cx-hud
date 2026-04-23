return function(State, Utils, Minimap, Status, Vehicle, readyToRock, Config)

    -- /hud command — unchanged
    RegisterCommand(Config.MenuCommand or 'hud', function()
        if not readyToRock() then return end
        State.menuIsOpen = true
        SetNuiFocus(true, true)
        Utils.yeet('openMenu', {})
    end, false)

    -- -------------------------------------------------------------------------
    -- ESX-Legacy: player loaded
    -- Replaces: QBCore:Client:OnPlayerLoaded
    -- -------------------------------------------------------------------------
    RegisterNetEvent('esx:playerLoaded')
    AddEventHandler('esx:playerLoaded', function(xPlayer, isNew, skin)
        Status.grabPlayerData()
        State.isLoggedIn      = true
        State.diddlyLoaded    = true
        State.actuallySpawned = true
        Wait(1500)
        Status.tryShowHud()
    end)

    -- -------------------------------------------------------------------------
    -- ESX-Legacy: player logout / unload
    -- esx:onPlayerLogout is triggered locally by the framework (TriggerEvent),
    -- so RegisterNetEvent is NOT required — AddEventHandler alone is correct.
    -- Replaces: QBCore:Client:OnPlayerUnload
    -- -------------------------------------------------------------------------
    AddEventHandler('esx:onPlayerLogout', function()
        State.isLoggedIn      = false
        State.diddlyLoaded    = false
        State.actuallySpawned = false
        State.buckledUp       = false
        Status.showHud(false)
        DisplayRadar(false)
    end)

    -- -------------------------------------------------------------------------
    -- spawnmanager: fired locally, AddEventHandler only is correct
    -- -------------------------------------------------------------------------
    AddEventHandler('playerSpawned', function()
        State.actuallySpawned = true
        Status.grabPlayerData()
        Wait(1500)
        Status.tryShowHud()
    end)

    -- -------------------------------------------------------------------------
    -- Resource restart recovery — fired locally, no RegisterNetEvent needed
    -- Replaces: LocalPlayer.state.isLoggedIn check with ESX.IsPlayerLoaded()
    -- -------------------------------------------------------------------------
    AddEventHandler('onResourceStart', function(res)
        if res ~= GetCurrentResourceName() then return end
        Status.grabPlayerData()
        if ESX.IsPlayerLoaded() then
            State.isLoggedIn   = true
            State.diddlyLoaded = true
            if NetworkIsPlayerActive(cache.playerId) and DoesEntityExist(cache.ped) then
                State.actuallySpawned = true
            end
            Wait(1000)
            Status.tryShowHud()
        else
            Status.showHud(false)
        end
    end)

    -- -------------------------------------------------------------------------
    -- ESX-Legacy: individual player data key changes
    -- Replaces: QBCore:Player:SetPlayerData, QBCore:Client:OnJobUpdate,
    --           QBCore:Client:OnMoneyChange (all three collapse into this one)
    -- -------------------------------------------------------------------------
    RegisterNetEvent('esx:setPlayerData')
    AddEventHandler('esx:setPlayerData', function(key, value)
        if key == 'accounts' then
            -- value is an array of { name, money, label }
            -- ESX account 'money' maps to the original 'cash' key
            -- ESX account 'bank'  maps to the original 'bank' key
            State.whoAmI.money = State.whoAmI.money or {}
            for _, acc in ipairs(value) do
                if acc.name == 'money' then
                    State.whoAmI.money.cash = acc.money or 0
                elseif acc.name == 'bank' then
                    State.whoAmI.money.bank = acc.money or 0
                end
            end
            Status.refreshMoneyCache()
            if State.hudShowing then Status.pushStatus(false) end

        elseif key == 'job' then
            State.whoAmI.job = value
            Status.refreshStaticCache()
            if State.hudShowing then Status.pushStatus(false) end

        elseif key == 'metadata' then
            State.whoAmI.metadata = value or {}
            if State.hudShowing then Status.pushStatus(false) end
        end
    end)

    -- -------------------------------------------------------------------------
    -- Hunger/thirst sync — network event sent from external resources
    -- FIX: was RegisterNetEvent('hud:client:UpdateNeeds', function...)
    --      RegisterNetEvent() ignores any second argument; the handler was
    --      never registered. Split into correct two-call pattern.
    -- -------------------------------------------------------------------------
    RegisterNetEvent('hud:client:UpdateNeeds')
    AddEventHandler('hud:client:UpdateNeeds', function(hunger, thirst)
        State.whoAmI.metadata        = State.whoAmI.metadata or {}
        State.whoAmI.metadata.hunger = hunger
        State.whoAmI.metadata.thirst = thirst
        if State.hudShowing then Status.pushStatus(false) end
    end)

    -- -------------------------------------------------------------------------
    -- pma-voice mode sync — network event from pma-voice resource
    -- FIX: same bug as above — handler was silently dropped by RegisterNetEvent.
    -- -------------------------------------------------------------------------
    RegisterNetEvent('pma-voice:setTalkingMode')
    AddEventHandler('pma-voice:setTalkingMode', function(mode)
        local modes = { [1] = 'Whisper', [2] = 'Normal', [3] = 'Shout' }
        State.voiceLabel = modes[mode] or Config.DefaultVoice
        if State.hudShowing then Status.pushStatus(false) end
    end)

    -- -------------------------------------------------------------------------
    -- Version check result — network event from server/version.lua
    -- FIX: same bug as above — handler was silently dropped by RegisterNetEvent.
    --      Version badge in /hud menu would never update.
    -- -------------------------------------------------------------------------
    RegisterNetEvent('cx-hud:versionResult')
    AddEventHandler('cx-hud:versionResult', function(current, latest, outdated)
        Utils.yeet('versionInfo', { current = current, latest = latest, outdated = outdated })
    end)
end