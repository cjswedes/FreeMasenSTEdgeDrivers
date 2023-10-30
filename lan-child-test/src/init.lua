local Driver = require 'st.driver'
local log = require 'log'
local socket = require "socket"
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
        label = 'lan-parent',
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
  device.log.info("handle_refresh")
  device:online()
end

local NUM_CHILDREN = 3

local function device_added(driver, device)
  device:emit_event(capabilities.switch.switch.on())
  device:emit_event(capabilities.switchLevel.level(0))

  if device.network_type ~= st_device.NETWORK_TYPE_CHILD then
    -- create 3 children
    for i=1, NUM_CHILDREN do
      local child_metadata = {
        type = "EDGE_CHILD",
        label = string.format("Child %s", i),
        vendor_provided_label = string.format("LAN Child"),
        profile = "basic",
        manufacturer = "asdf",
        model = "fdsa",
        parent_device_id = device.id,
        parent_assigned_child_key = string.format("%s", i),
      }

      driver:try_create_device(child_metadata)
      socket.sleep(1)
    end
  end
end

local driver = Driver('Disco Forever', {
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
