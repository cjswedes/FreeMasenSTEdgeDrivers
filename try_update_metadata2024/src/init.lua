-- require st provided libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"
local util = require "st.utils"

-- require custom handlers from driver package
local command_handlers = require "command_handlers"
local discovery = require "discovery"


local function initialize(driver, device)
  device:emit_event(capabilities.switch.switch.on())
  device:emit_event(capabilities.temperatureMeasurement.temperature({value=12, unit="C"}))
end

-- this is called once a device is added by the cloud and synchronized down to the hub
local function device_added(driver, device)
  log.info("[" .. device.id .. "] Adding new Hello World device")
  device:emit_event(capabilities.thermostatMode.thermostatMode("off"))
  device:emit_event(capabilities.smokeDetector.smoke("clear"))
  initialize(driver, device)
end

-- this is called both when a device is added (but after `added`) and after a hub reboots.
local function device_init(driver, device)
  log.info("[" .. device.id .. "] Initializing Hello World device")
  -- mark device as online so it can be controlled from the app
  device:emit_event(capabilities.thermostatMode.thermostatMode("off"))
  device:emit_event(capabilities.smokeDetector.smoke("clear"))
  initialize(driver, device)
  device:online()
end

-- this is called when a device is removed by the cloud and synchronized down to the hub
local function device_removed(driver, device)
  log.info("[" .. device.id .. "] Removing Hello World device")
end

local function info_changed(driver, device, event, args)
  print("entering infochanged")
  if device.preferences.selectIcon == 'startSwitch' then
    local success, msg = pcall(
      device.try_update_metadata,
      device,
      {profile='startSwitch', vendor_provided_label='smartthings'}) -- profile reference
      
      driver:call_with_delay(8.0,function ()
        print("call_with_delay")
        return initialize(driver, device)
      end)
    elseif device.preferences.selectIcon == 'startTemp' then
      local success, msg = pcall(
        device.try_update_metadata,
        device,
        {profile='startTemp', vendor_provided_label='smartthings'}) -- profile reference
        -- delay doesn't seem to affect the initialization of the cap after profile switch
        driver:call_with_delay(8.0,function ()
          print("call_with_delay")
          return initialize(driver, device)
        end)
        
  end
end

local function setFanSpeed(driver, device,cmd)
  device:emit_event(capabilities.fanSpeed.fanSpeed(cmd.args.speed))
end

local function setNumAttr(driver, device,cmd)
  device:emit_event(capabilities["commonsmall09402.numberfield"].numattr({value=cmd.args.value,unit="hr"}))
end
-- create the driver object
local hello_world_driver = Driver("helloworld", {
  discovery = discovery.handle_discovery,
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
    infoChanged = info_changed,
    removed = device_removed
  },
  capability_handlers={
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = command_handlers.switch_on,
      [capabilities.switch.commands.off.NAME] = command_handlers.switch_off,
    },
    [capabilities.colorTemperature.ID] = {
      [capabilities.colorTemperature.commands.setColorTemperature.NAME] = command_handlers.set_colorTemp
    },
    [capabilities.colorControl.ID] = {
      [capabilities.colorControl.commands.setColor.NAME] = command_handlers.setColor,
      [capabilities.colorControl.commands.setHue.NAME] = command_handlers.setHue,
      [capabilities.colorControl.commands.setSaturation.NAME] = command_handlers.setSaturation
    },
    [capabilities.thermostatMode.ID] = {
      [capabilities.thermostatMode.commands.setThermostatMode.NAME] = command_handlers.setThermostatMode
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = command_handlers.refresh
    }
  }
})

-- run the driver
hello_world_driver:run()
