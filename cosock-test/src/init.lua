local Driver = require 'st.driver'
local log = require 'log'
local socket = require "cosock.socket"
local cosock = require "cosock"
local capabilities = require "st.capabilities"
local st_device = require "st.device"

local function disco(driver, opts, cont)
  print('starting disco', cont)
  local device_list = driver.device_api.get_device_list()
  if not next(device_list) and cont() then
    print('discovering a device')
    local device_info = {
        type = 'LAN',
        device_network_id = string.format('parent-%s', os.time()),
        label = 'cosock-test',
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
  device.log.info("handle_off")
  device:offline()
end
local function handle_on(driver, device, cmd)
  device.log.info("handle_on")
end
local function handle_level(driver, device, cmd)
  device.log.info("handle_level")
  device:emit_event(capabilities.switchLevel.level(cmd.args.level))
  if cmd.args.level > 80 then
    device:online()
  end
end

local utils = require "st.utils"
local function channel_handler(driver, ch)
  log.info_with({hub_logs=true}, "channel_handler starting")
  local val, err = ch:receive()
  log.info_with({hub_logs=true}, string.format("received: %s, %s", val, err))
end

local tx, rx = cosock.channel.new()
log.info_with({hub_logs=true}, "created channel")

local function handle_refresh(driver, device, cmd)
  log.info_with({hub_logs=true}, "handle_refresh")
  driver:register_channel_handler(rx, channel_handler, "channel_handler")
  cosock.spawn(function()
    log.info_with({hub_logs=true}, "send and unregister start")
    tx:send("asdf")
    driver:unregister_channel_handler(rx)
    log.info_with({hub_logs=true}, "send and unregister end")
  end)
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
