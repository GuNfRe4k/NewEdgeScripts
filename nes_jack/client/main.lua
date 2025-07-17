local Framework = nil
local FrameworkType = "standalone"

CreateThread(function()
    if Config.framework == "esx" then
        Framework = exports["es_extended"]:getSharedObject()
        FrameworkType = "esx"
    elseif Config.framework == "qb" then
        Framework = exports["qb-core"]:GetCoreObject()
        FrameworkType = "qb"
    elseif Config.framework == "auto" then
        if pcall(function() return exports["es_extended"]:getSharedObject() end) then
            Framework = exports["es_extended"]:getSharedObject()
            FrameworkType = "esx"
            print("[nes_jack] ESX detected")
        elseif pcall(function() return exports["qb-core"]:GetCoreObject() end) then
            Framework = exports["qb-core"]:GetCoreObject()
            FrameworkType = "qb"
            print("[nes_jack] QBCore detected")
        else
            print("[nes_jack] No framework detected (standalone mode)")
        end
    end
end)

local jackObject = nil
local jackActive = false

function isJobAllowed(jobName)
    for _, job in ipairs(Config.allowedJobs) do
        if job == jobName then return true end
    end
    return false
end

function notify(msg)
    if FrameworkType == "esx" then
        Framework.ShowNotification(msg)
    elseif FrameworkType == "qb" then
        TriggerEvent("QBCore:Notify", msg, "primary")
    else
        print("[nes_jack] " .. msg)
    end
end

function getPlayerJob()
    if FrameworkType == "esx" then
        return Framework.GetPlayerData().job.name
    elseif FrameworkType == "qb" then
        return Framework.Functions.GetPlayerData().job.name
    end
    return nil
end

function useJack()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh = GetClosestVehicle(coords, 5.0, 0, 71)

    if not veh or veh == 0 then
        notify("~r~No vehicle nearby.")
        return
    end

    if jackActive then
        if jackObject then
            DeleteObject(jackObject)
            jackObject = nil
        end
        FreezeEntityPosition(veh, false)
        local lower = GetEntityCoords(veh)
        SetEntityCoords(veh, lower.x, lower.y, lower.z - Config.liftHeight, false, false, false, false)
        notify("~r~Jack removed. Vehicle lowered.")
        jackActive = false
        return
    end

    local offset = GetOffsetFromEntityInWorldCoords(veh, -1.0, 0.0, -1.0)
    RequestModel(Config.jackModel)
    while not HasModelLoaded(Config.jackModel) do Wait(10) end

    jackObject = CreateObject(Config.jackModel, offset.x, offset.y, offset.z, true, true, false)
    PlaceObjectOnGroundProperly(jackObject)
    FreezeEntityPosition(jackObject, true)

    PlaySoundFromCoord(-1, "Air_Brake_Loop", coords.x, coords.y, coords.z, "SUSPENSION_SOUNDS", false, Config.jackSoundVolume, false)

    local raise = GetEntityCoords(veh)
    SetEntityCoords(veh, raise.x, raise.y, raise.z + Config.liftHeight, false, false, false, false)
    FreezeEntityPosition(veh, true)

    notify("~g~Jack placed. Vehicle lifted.")
    jackActive = true
end

RegisterCommand("jack", function()
    useJack()
end, false)

CreateThread(function()
    while Framework == nil and Config.framework ~= "standalone" do Wait(100) end

    if Config.thirdEye == "ox_target" then
        exports.ox_target:addGlobalVehicle({
            {
                label = 'Use Jack',
                icon = 'fa-solid fa-car',
                distance = 2.5,
                canInteract = function(entity, distance, coords, name)
                    return isJobAllowed(getPlayerJob())
                end,
                onSelect = function()
                    useJack()
                end
            }
        })
    elseif Config.thirdEye == "qb_target" then
        exports["qb-target"]:AddGlobalVehicle({
            options = {
                {
                    icon = "fas fa-wrench",
                    label = "Use Jack",
                    action = function(entity)
                        useJack()
                    end,
                    canInteract = function(entity)
                        return isJobAllowed(getPlayerJob())
                    end
                }
            },
            distance = 2.5
        })
    else
        print("[nes_jack] 3rd eye disabled — use /jack command.")
    end
end)
