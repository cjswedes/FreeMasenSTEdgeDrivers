local Driver = require 'st.driver'
local log = require 'log'
local cosock = require "cosock"
local socket = cosock.socket
local capabilities = require "st.capabilities"
local st_device = require "st.device"

-- local old_print = print
-- print = function(...)
--   log.info_with({hub_logs = true}, ...)
-- end

local function run_tests()
  local test = require "test"
  local runner = test.TestRunner:new()
  local config = test.RunnerConfig:new()
    :num_encode_tests(0)
    :num_decode_tests(7)
  print("Registering test cases")
  runner:register_tests(config)
  runner:run_tests()
end

--- Discover a single device once
local function disco(driver, opts, cont)
  print('starting disco', cont)
  local device_list = driver.device_api.get_device_list()
  if not next(device_list) and cont() then
    print('discovering a device')
    local device_info = {
        type = 'LAN',
        device_network_id = string.format('parent-%s', os.time()),
        label = 'dkjson vs stjson',
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
local function handle_refresh(driver, device, cmd)
  run_tests()
end

local function device_init(driver, device)
  log.info("spawning test runner")
  cosock.spawn(function()
    run_tests()
  end)
end

local driver = Driver('dk vs st json', {
  discovery = disco,
  lifecycle_handlers = {
    init = device_init,
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
