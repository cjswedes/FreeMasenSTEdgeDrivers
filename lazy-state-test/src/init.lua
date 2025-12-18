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
    local label = config.CAN_HANDLE_DISTRIBUTION
    if config.RANDOM_HEALTHSTATE_CHANGES then
      label = string.format("%s-%s", label, "HEALTH")
    end
    local device_info = {
      type = 'LAN',
      device_network_id = string.format("%s Trigger", label),
      label = string.format("%s Trigger", label),
      profile = 'basic',
      manufacturer = string.format("%s Trigger", label),
      model = string.format("%s Trigger", label),
      vendor_provided_label = string.format("%s Trigger", label),
    }
    driver:try_create_device(device_info)
    socket.sleep(0.2)
    for i=1, config.NUM_DEVICES do
      local id = string.format("%s %s", label, i) -- DO NOT CHANGE used in subdriver can_handle functions
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

local function device_init(driver, device)
  if config.RANDOM_HEALTHSTATE_CHANGES then
    cosock.spawn(function()
      device:set_field("health_state_toggle", true)
      while true do
        socket.sleep(math.random(15, 90))
        if device == nil then
          return
        end
        local health_state_toggle = device:get_field("health_state_toggle")
        if health_state_toggle then
          device:offline()
        else
          device:online()
        end
        device:set_field("health_state_toggle", not health_state_toggle)
      end
    end)
  end
  log.info_with({hub_logs=true},"lazy_device_state_config is: "..utils.stringify_table((driver.hub_augmented_driver_data or {}).lazy_device_state_config))
end

local subdrivers = require "subdrivers"

local driver = Driver('Subdriver Stress Test', {
  discovery = disco,
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
  },
  capability_handlers = require("capability_handlers"),
  sub_drivers = subdrivers
})

log.debug('Starting lan parent child driver')
driver:run()
