local capabilities = require "st.capabilities"
local Driver = require 'st.driver'
local log = require 'log'
local cosock = require "cosock"
local socket = cosock.socket
local st_device = require "st.device"

local function run_tests()
  local test = require "test"
  local runner = test.TestRunner:new()
  local config = test.RunnerConfig:new()
    :num_encode_tests(7)
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
  device.log.debug("handle_off")
  local stjson = require "st.json"
  local empty_array = {}
  setmetatable(empty_array, stjson.array_mt)
  local empty_object = {}
  local tbl = {
    empty_array = empty_array,
    empty_object = empty_object, 
  }
  local expected = '{"empty_array":[],"empty_object":{}}'
  local actual = stjson.encode(tbl)
  if expected ~= actual then
    print(string.format("\t\tExpected: %s", expected))
    print(string.format("\t\tActual: %s", actual))
  end
end
local function handle_on(driver, device, cmd)
  device.log.debug("handle_on")
  local dkjson = require "dkjson"
  local empty_array = {}
  setmetatable(empty_array, {__jsontype = "array"})
  local empty_object = {}
  setmetatable(empty_object, {__jsontype = "object"})
  local tbl = {
    empty_array = empty_array,
    empty_object = empty_object, 
  }
  local expected = '{"empty_array":[],"empty_object":{}}'
  local actual = dkjson.encode(tbl)
  if expected ~= actual then
    print(string.format("\t\tExpected: %s", expected))
    print(string.format("\t\tActual: %s", actual))
  end
end
local function handle_level(driver, device, cmd)
  device.log.debug("handle_level")
  device:emit_event(capabilities.switchLevel.level(cmd.args.level))
  print("!!!!! emitting empty presets event")
  device:emit_event(capabilities.mediaPresets.presets({}))
  print("!!!!! don emiting prestss eventS")
end

local function handle_refresh(driver, device, cmd)
  local stjson = require "st.json"
  local empty_array = {}
  setmetatable(empty_array, stjson.array_mt)
  print("!!!!! json.array_mt = %s, getmetatable = %s", stjson.array_mt, getmetatable(empty_array))
  print("!!!!! json.array_mt = %s, getmetatable = %s", stjson.array_mt, debug.getmetatable(empty_array))
end

local function device_init(driver, device)
  log.debug("spawning test runner")
  device:try_update_metadata({profile = "array-basic"})
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
