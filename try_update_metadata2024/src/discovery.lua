local log = require "log"
local discovery = {}
local socket = require "cosock.socket"
-- handle discovery events, normally you'd try to discover devices on your
-- network in a loop until calling `should_continue()` returns false.
function discovery.handle_discovery(driver, _should_continue)
  log.info("Starting Hello World Discovery")

  local metadata1 = {
    type = "LAN",
    -- the DNI must be unique across your hub, using static ID here so that we
    -- only ever have a single instance of this "device"
    device_network_id = "startTemp",
    label = "startTemp",
    profile = "startTemp",
    manufacturer = "startTemp",
    model = "startTemp",
    vendor_provided_label = nil
  }

  local metadata2 = {
    type = "LAN",
    -- the DNI must be unique across your hub, using static ID here so that we
    -- only ever have a single instance of this "device"
    device_network_id = "startSwitch",
    label = "startSwitch",
    profile = "startSwitch",
    manufacturer = "startSwitch",
    model = "startSwitch",
    vendor_provided_label = nil
  }
  -- tell the cloud to create a new device record, will get synced back down
  -- and `device_added` and `device_init` callbacks will be called
  driver:try_create_device(metadata2)
  socket.sleep(1)
  driver:try_create_device(metadata1)
end

return discovery
