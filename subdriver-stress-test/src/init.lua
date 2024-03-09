local Driver = require 'st.driver'
local log = require 'log'
local capabilities = require "st.capabilities"
local cosock = require "cosock"
local socket = cosock.socket
local config = require "config"
local utils = require "st.utils"

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
    for i=1, config.NUM_DEVICES do
      local id = string.format("device %s", i) -- DO NOT CHANGE use in subdriver can_handle functions
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

local function device_added(driver, device)
  device:emit_event(capabilities.switch.switch.on())
  device:emit_event(capabilities.switchLevel.level(0))
  device:online()
end

local subdrivers = require "subdrivers"

local driver = Driver('Subdriver Stress Test', {
  discovery = disco,
  lifecycle_handlers = {
    added = device_added,
  },
  capability_handlers = require("capability_handlers"),
  sub_drivers = subdrivers
})


log.debug('Starting lan parent child driver')
driver:run()
