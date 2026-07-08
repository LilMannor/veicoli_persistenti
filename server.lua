local savedVehiclesFile = "saved_vehicles.json"
local vehiclesToSpawn = {}
local giorniScadenza = 10

-- Mi salvo i veicoli
local function SaveVehicles()
    local vehicles = GetAllVehicles()
    local dataToSave = {}
    local tempoAttuale = os.time()

    for _, veh in ipairs(vehicles) do
        if DoesEntityExist(veh) then
            local model = GetEntityModel(veh)
            local coords = GetEntityCoords(veh)
            local heading = GetEntityHeading(veh)
            local plate = GetVehicleNumberPlateText(veh)

            if model and model ~= 0 then
                table.insert(dataToSave, {
                    model = model,
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    heading = heading,
                    plate = plate,
                    lastUsed = tempoAttuale
                })
            end
        end
    end

    local secondiScadenza = giorniScadenza * 24 * 60 * 60

    for _, v in ipairs(vehiclesToSpawn) do
        if not v.lastUsed then
            v.lastUsed = tempoAttuale
        end

        if (tempoAttuale - v.lastUsed) < secondiScadenza then
            table.insert(dataToSave, v)
        else
            print("^1[Persistenza] Veicolo rimosso per inattività di 10 giorni! Targa: " .. v.plate .. "^0")
        end
    end

    SaveResourceFile(GetCurrentResourceName(), savedVehiclesFile, json.encode(dataToSave, { indent = true }), -1)
    print("^2[Persistenza] [AUTO-SAVE] Salvati " .. #dataToSave .. " veicoli.^0")
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000)
        SaveVehicles()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    SaveVehicles()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    local loadFile = LoadResourceFile(GetCurrentResourceName(), savedVehiclesFile)

    if loadFile then
        vehiclesToSpawn = json.decode(loadFile) or {}
        print("^2[Persistenza] Caricati " .. #vehiclesToSpawn .. " veicoli dal database JSON.^0")
    end
end)

local function SafeSpawnVehicle(v, index)
    local players = GetPlayers()

    if #players == 0 then
        table.insert(vehiclesToSpawn, v)
        return
    end

    local offsetX = v.x + (index * 0.1)
    local veh = CreateVehicle(v.model, offsetX, v.y, v.z, v.heading, true, true)

    local timeout = 0

    while not DoesEntityExist(veh) and timeout < 1000 do
        Citizen.Wait(50)
        timeout = timeout + 50
    end

    if DoesEntityExist(veh) then
        SetVehicleNumberPlateText(veh, v.plate)
    else
        table.insert(vehiclesToSpawn, v)
    end
end

-- Controllo lo spawn  dei veicoli
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2000)

        if #vehiclesToSpawn > 0 then
            local players = GetPlayers()

            if #players > 0 then
                local targetPed = GetPlayerPed(players[1])

                if DoesEntityExist(targetPed) then
                    local pCoords = GetEntityCoords(targetPed)
                    local delay = 0

                    for i = #vehiclesToSpawn, 1, -1 do
                        local v = vehiclesToSpawn[i]
                        local dist = #(pCoords - vector3(v.x, v.y, v.z))

                        if dist < 140.0 then
                            delay = delay + 200

                            local currentVehicle = v
                            local currentIndex = i

                            Citizen.SetTimeout(delay, function()
                                SafeSpawnVehicle(currentVehicle, currentIndex)
                            end)

                            table.remove(vehiclesToSpawn, i)
                        end
                    end
                end
            end
        end
    end
end)

RegisterCommand('wipauto', function(source, args, rawCommand)
    if source == 0 or IsPlayerAceAllowed(source, "command") then
        local vehicles = GetAllVehicles()
        local contatore = 0

        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) then
                DeleteEntity(veh)
                contatore = contatore + 1
            end
        end

        print("^1[WIP] Cancellati " .. contatore .. " veicoli dalla mappa!^0")
    else
        print("^1Non hai i permessi per usare questo comando.^0")
    end
end, false)