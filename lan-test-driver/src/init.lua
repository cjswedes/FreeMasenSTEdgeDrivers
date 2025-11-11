local Driver = require 'st.driver'
local log = require 'log'
local capabilities = require "st.capabilities"
local socket = require "cosock.socket"

local function disco(driver, opts, cont)
  local NUM_DEVICES = 40
  print('starting disco', cont)
  local device_list = driver.device_api.get_device_list()
  if not next(device_list) and cont() then
    print('discovering a devices')
    for i = 0, NUM_DEVICES do
      local device_info = {
        type = 'LAN',
        device_network_id = string.format('%s', i),
        label = string.format('lan-device-%s', i),
        profile = 'basic',
        manufacturer = "asdf",
        model = "fdsa",
        vendor_provided_label = 'ffff',
    }
    driver:try_create_device(device_info)
    socket.sleep(0.25)
    end
  end
  log.debug('disco over', cont())
end

local function handle_off(driver, device, cmd)
  log.info("handle_off")
  device:emit_event(capabilities.switch.switch.off())
end
local function handle_on(driver, device, cmd)
  log.info("handle_on")
  device:emit_event(capabilities.switch.switch.on())
end
local function handle_level(driver, device, cmd)
  log.info("handle_level")
  device:emit_event(capabilities.switchLevel.level(cmd.args.level))
end

local function handle_refresh(driver, device, cmd)
  log.info_with({hub_logs=true}, "handle_refresh")
end

local function device_added(driver, device)
  device:emit_event(capabilities.switch.switch.on())
  device:emit_event(capabilities.switchLevel.level(0))
end

local driver = Driver('Lan test driver', {
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
  shared_device_thread_enabled = true,
})

log.debug('Starting lan parent child driver')
driver:run()
