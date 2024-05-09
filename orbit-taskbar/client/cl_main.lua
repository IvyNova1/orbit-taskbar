
local lockpos = false
local insidePrompt = false
local isDead = false
local inventoryDisabled = false
local forceInventoryDisabled = false
local taskInProcessId = 0
local agilityReduction = 1
local currentEmployment, currentDepartment = nil, nil


-- openGui(length,math.random(1000000))
function openGui(sentLength, taskID, label, keepWeapon)
  if not keepWeapon then
      TriggerEvent("actionbar:setEmptyHanded", true)
  end
  guiEnabled = true
  -- exports["np-interface"]:sendAppEvent("taskbar", {
  --   display = true,
  --   duration = sentLength,
  --   taskID = taskID,
  --   label = label,
  -- })
  SendNUIMessage({
    TaskBar = {
      display = true,
      duration = sentLength,
      taskID = taskID,
      label = label,
    }
  })
end
local activeTasks = {}
function closeGuiFail()
  guiEnabled = false
  -- maybe we let the task clear the anims etc.
  --ClearPedTasks(PlayerPedId())
  -- exports["np-ui"]:sendAppEvent("taskbar", {
  --   display = false,
  -- })
  SendNUIMessage({
    TaskBar = {
      display = false
    }
  })
  inventoryDisabled = false
  forceInventoryDisabled = false
end
function closeGui()
  guiEnabled = false
  -- exports["np-ui"]:sendAppEvent("taskbar", {
  --   display = false,
  -- })
  SendNUIMessage({
    TaskBar = {
      display = false
    }
  })
  inventoryDisabled = false
  forceInventoryDisabled = false
  -- maybe we let the task clear the anims etc.
  --ClearPedTasks(PlayerPedId())
end

function closeNormalGui()
  guiEnabled = false
  
end

function taskCancel()
  closeGui()
  local taskIdentifier = taskInProcessId
  activeTasks[taskIdentifier] = 2
end

exports('taskCancel', taskCancel)

RegisterNUICallback('taskEnd', function(data, cb)
  closeNormalGui()

  local taskIdentifier = data.tasknum
  activeTasks[taskIdentifier] = 3
end)
local coffeetimer = 0

RegisterNetEvent('coffee:drink')
AddEventHandler('coffee:drink', function()
  if coffeetimer > 0 then
      coffeetimer = 6000
      TriggerEvent("Evidence:StateSet",27,6000)
      return
  else
      TriggerEvent("Evidence:StateSet",27,6000)
      coffeetimer = 6000
  end

  while coffeetimer > 0 do
      coffeetimer = coffeetimer - 1
      Wait(1000)
  end
end)

AddEventHandler('orbit-taskbar:client:agilityBonus', function (_agilityReduction)
  agilityReduction = _agilityReduction
end)

-- command is something we do in the loop if we want to disable more, IE a vehicle engine.
-- return true or false, if false, gives the % completed.
local taskInProcess = false

function taskBarFail(maxcount,curTime,length)
  local totaldone = math.ceil(100 - (((maxcount - curTime) / length) * 100))
  totaldone = math.min(100, totaldone)
  taskInProcess = false
  closeGuiFail()
  return totaldone
end


function taskBar(length, name, runCheck, keepWeapon, vehicle, vehCheck, cb, moveCheck, distEntity, opts)
  local playerPed = PlayerPedId()
  local firstPosition = GetEntityCoords(playerPed)

  if taskInProcess then
      if cb then cb(0) end
      return 0
  end
  if coffeetimer > 0 then
      length = math.ceil(length * 0.66)
  end
  if agilityReduction < 1 then
      length = length * agilityReduction
  end
  taskInProcess = true
  local taskIdentifier = "taskid" .. math.random(1000000)
  taskInProcessId = taskIdentifier
  openGui(length,taskIdentifier,name,keepWeapon)
  activeTasks[taskIdentifier] = 1
  inventoryDisabled = true
  forceInventoryDisabled = true

  local maxcount = GetGameTimer() + length
  local curTime
  local playerPed = PlayerPedId()
  while activeTasks[taskIdentifier] == 1 do
      Citizen.Wait(0)
      curTime = GetGameTimer()
      if curTime > maxcount or not guiEnabled then
          activeTasks[taskIdentifier] = 2
      end
      local fuck = 100 - (((maxcount - curTime) / length) * 100)
      fuck = math.min(100, fuck)


      if runCheck then
          if   IsPedClimbing(playerPed)
            or IsPedJumping(playerPed)
            or IsPedSwimming(playerPed)
            or IsPedRagdoll(playerPed)
            or IsPedBeingStunned(playerPed, 0)
          then
              SetPlayerControl(PlayerId(), 0, 0)
              local totaldone = taskBarFail(maxcount,curTime,length)
              Citizen.Wait(1000)
              SetPlayerControl(PlayerId(), 1, 1)
              if cb then cb(totaldone) end
              return totaldone
          end
      end

      if moveCheck ~= nil then
        if #(firstPosition-GetEntityCoords(playerPed)) > moveCheck or (distEntity ~= nil and #(GetEntityCoords(distEntity)-GetEntityCoords(playerPed)) > moveCheck) then
            local totaldone = taskBarFail(maxcount,curTime,length)
            if cb then cb(totaldone) end
            return totaldone
        end
      end

      if vehicle ~= nil and vehicle ~= 0 then
          local driverPed = GetPedInVehicleSeat(vehicle, -1)
          if driverPed ~= playerPed and vehCheck then
              local totaldone = taskBarFail(maxcount,curTime,length)
              if cb then cb(totaldone) end
              return totaldone
          end

          local model = GetEntityModel(vehicle)
          if IsThisModelACar(model) or IsThisModelABike(model) or IsThisModelAQuadbike(model) then
              if IsEntityInAir(vehicle) then
                  Wait(1000)
                  if IsEntityInAir(vehicle) then
                      local totaldone = taskBarFail(maxcount,curTime,length)
                      if cb then cb(totaldone) end
                      return totaldone
                  end
              end
          end
      end
  end

  local resultTask = activeTasks[taskIdentifier]
  if resultTask == 2 then
      local totaldone = taskBarFail(maxcount,curTime,length)
      if cb then cb(totaldone) end
      return totaldone
      
  else
      closeGui()
      taskInProcess = false
      
      if cb then cb(100) end
      return 100
  end 
  
end

function CheckCancels()
  if IsPedRagdoll(PlayerPedId()) then
      return true
  end
  return false
end
-- trigger this way for the timer with out stopping another thread
RegisterNetEvent('hud:taskBar')
AddEventHandler('hud:taskBar', function(length,name)
  taskBar(length,name)
end)

RegisterNetEvent('hud:insidePrompt')
AddEventHandler('hud:insidePrompt', function(bool)
  insidePrompt = bool
end)

local function canUsePhone()
  return not isDead
      and not exports["isPed"]:isPed("disabled")
      and not exports["isPed"]:isPed("handcuffed")
end

function LoadAnimationDic(dict)
  if not HasAnimDictLoaded(dict) then
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
      Citizen.Wait(0)
    end
  end
end

local myIdentifiers = {}
Citizen.CreateThread(function()
  Wait(10000)
  TriggerServerEvent("orbit-taskbar:setIdentifiers")
end)
RegisterNetEvent("orbit-taskbar:setIdentifiersClient")
AddEventHandler("orbit-taskbar:setIdentifiersClient", function(identifiers)
  myIdentifiers = identifiers
end)

-- RegisterNetEvent("np-jobmanager:playerBecameJob")
-- AddEventHandler("np-jobmanager:playerBecameJob", function(job, name, notify)
--   currentEmployment = job
--   if currentEmployment == "police" then
--     currentDepartment = exports['np-dispatch']:GetCurrentDepartment()
--   else
--     currentDepartment = nil
--   end
-- end)

RegisterNetEvent("police:setCallSign")
AddEventHandler("police:setCallSign", function(pCallSign, pDepartment)
  currentDepartment = pDepartment
end)

-- function generalPhone()
--   if not insidePrompt and hasPhone() and canUsePhone() and not inventoryDisabled and not forceInventoryDisabled then
--     local _, isAnimalModel = pcall(function () return exports["np-misc-code"]:isAnimalModel(GetEntityModel(PlayerPedId())) end)
--     if not isAnimalModel then
--       LoadAnimationDic("cellphone@")
--       TaskPlayAnim(PlayerPedId(), "cellphone@", "cellphone_text_read_base", 2.0, 3.0, -1, 49, 0, 0, 0, 0)
--       if currentDepartment == "sdso" or exports["np-inventory"]:hasEnoughOfItem("bananaphone", 1, false, true) then
--         TriggerEvent("attachItemPhone", "bananaphone")
--       else
--         TriggerEvent("attachItemPhone", "phone01")
--       end
--     end
--     TriggerEvent("phoneGui2")
--   end
-- end

function generalInventory()
  if not insidePrompt and not inventoryDisabled and not forceInventoryDisabled then
    TriggerEvent("inventory-open-request")
  end
end

function generalEscapeMenu()
  if guiEnabled then
    closeGuiFail()
  end
end

-- Citizen.CreateThread(function()
--   exports["np-keybinds"]:registerKeyMapping("", "Phone", "Open", "+generalPhone", "-generalPhone", "P")
--   RegisterCommand('+generalPhone', generalPhone, false)
--   RegisterCommand('-generalPhone', function() end, false)
  
--   exports["np-keybinds"]:registerKeyMapping("", "Inventory", "Open", "+generalInventory", "-generalInventory", "K")
--   RegisterCommand('+generalInventory', generalInventory, false)
--   RegisterCommand('-generalInventory', function() end, false)
  
--   exports["np-keybinds"]:registerKeyMapping("", "Player", "Escape menu", "+generalEscapeMenu", "-generalEscapeMenu", "ESCAPE")
--   RegisterCommand('+generalEscapeMenu', generalEscapeMenu, false)
--   RegisterCommand('-generalEscapeMenu', function() end, false)
  
-- end)


RegisterNetEvent('pd:deathcheck')
AddEventHandler('pd:deathcheck', function()
  if not isDead then
      isDead = true
  else
      isDead = false
  end
end)

exports("taskbarDisableInventory", function(pState)
  inventoryDisabled = pState
end)

exports("forceTaskbarDisableInventory", function(pState)
  forceInventoryDisabled = pState
end)