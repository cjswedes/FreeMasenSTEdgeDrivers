local Driver = require 'st.driver'
local log = require 'log'
local capabilities = require "st.capabilities"
local socket = require "cosock.socket"
-- local socket = require "cosock.socket"
-- local cosock = require "cosock"
-- local st_device = require "st.device"
-- local utils = require "st.utils"

local function disco(driver, opts, cont)
  print('starting disco', cont)
  local device_list = driver.device_api.get_device_list()
  if not next(device_list) and cont() then
    print('discovering a device')
    local device_info = {
        type = 'LAN',
        device_network_id = string.format('parent-%s', os.time()),
        label = 'lan-device',
        profile = 'basic',
        manufacturer = "asdf",
        model = "fdsa",
        vendor_provided_label = 'parent',
    }
    driver:try_create_device(device_info)
  end
  log.debug('disco over', continues)
end

local function handle_off(driver, device, cmd)
  log.info("handle_off")
  device:emit_event(capabilities.switch.switch.off())
  driver.tcp_sock = socket.tcp()
end
local function handle_on(driver, device, cmd)
  log.info("handle_on")
  device:emit_event(capabilities.switch.switch.on())
  driver.udp_sock = socket.udp()
end
local function handle_level(driver, device, cmd)
  log.info("handle_level")
  device:emit_event(capabilities.switchLevel.level(cmd.args.level))
  driver.zwave_sock = socket.zwave()
end

local function handle_refresh(driver, device, cmd)
  log.info_with({hub_logs=true}, "handle_refresh")
end

local function device_added(driver, device)
  device:emit_event(capabilities.switch.switch.on())
  device:emit_event(capabilities.switchLevel.level(0))

end

local driver = Driver('Lan Child Test', {
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
}
})

log.debug('Starting lan parent child driver')
driver:run()
