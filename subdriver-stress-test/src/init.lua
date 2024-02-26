local Driver = require 'st.driver'
local log = require 'log'
local capabilities = require "st.capabilities"
local cosock = require "cosock"
local socket = cosock.socket
local st_device = require "st.device"
local MsgDispatcher = require "dispatcher"

local NUM_DEVICES = 10
local function disco(driver, opts, cont)
  print('starting disco', cont)
  local device_list = driver.device_api.get_device_list()
  if not next(device_list) and cont() then
    local device_info = {
      type = 'LAN',
      device_network_id = "RoutineTrigger",
      label = "RoutineTrigger",
      profile = 'basic',
      manufacturer = "RoutineTrigger",
      model = "RoutineTrigger",
      vendor_provided_label = "RoutineTrigger",
    }
    driver:try_create_device(device_info)
    socket.sleep(0.2)
    for i=1, NUM_DEVICES do
      local id = string.format("device %s", i)
      local device_info = {
        type = 'LAN',
        device_network_id = id,
        label = id,
        profile = 'basic',
        manufacturer = id,
        model = id,
        vendor_provided_label = id,
      }
      driver:try_create_device(device_info)
      socket.sleep(0.2)
    end
  end
  log.debug('disco over', continues)
end

local function handle_off(driver, device, cmd)
  device.log.info("base: handle_off")
  device:emit_event(capabilities.switch.switch.off())
end
local function handle_on(driver, device, cmd)
  device.log.info("base: handle_on")
  device:emit_event(capabilities.switch.switch.on())
end
local function handle_level(driver, device, cmd)
  device.log.info("base: handle_level")
  device:emit_event(capabilities.switchLevel.level(cmd.args.level))
end
local function handle_refresh(driver, device, cmd)
  device.log.info("base: handle_refresh")
end

local function device_added(driver, device)
  device:emit_event(capabilities.switch.switch.on())
  device:emit_event(capabilities.switchLevel.level(0))
  device:online()
end

local driver = Driver('Subdriver Stress Test', {
  discovery = disco,
  lifecycle_handlers = {
    added = device_added,
  },
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = handle_on,
      [capabilities.switch.commands.off.NAME] = handle_off,
    },
    [capabilities.switchLevel.ID] = {
      [capabilities.switchLevel.commands.setLevel.NAME] = handle_level
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = handle_refresh,
    },
  },
  subdrivers = {

  },
})

log.debug('Starting lan parent child driver')
driver:run()
