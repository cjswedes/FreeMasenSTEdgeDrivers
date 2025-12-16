local capabilities = require "st.capabilities"
local utils = require "st.utils"

local function get_device_num(device)
  return tonumber(string.match(device.device_network_id, ".+ (%d+)"))
end

local function handle_off(driver, device, cmd)
  device.log.info_with({hub_logs=true}, "handle_off")
  device:emit_event(capabilities.switch.switch.off())

  if device.preferences.doStateAccess then
    if get_device_num(device) % 2 == 0 then
      device.log.info_with({hub_logs=true}, "get_latest_state switch: "..device:get_latest_state("main", "switch", "switch", "unknown"))
    else
      device.log.info_with({hub_logs=true}, "direct index: "..tostring(device.state_cache.main.switch.switch))
    end
  end
end
local function handle_on(driver, device, cmd)
  device.log.info_with({hub_logs=true}, "handle_on")
  device:emit_event(capabilities.switch.switch.on())
  if device.preferences.doStateAccess then
    if get_device_num(device) % 2 == 0 then
      device.log.info_with({hub_logs=true}, "get_latest_state switch: "..device:get_latest_state("main", "switch", "switch", "unknown"))
    else
      device.log.info_with({hub_logs=true}, "direct index: "..tostring(device.state_cache.main.switch.switch))
    end
  end
end
local function handle_level(driver, device, cmd)
  device.log.info_with({hub_logs=true}, "handle_level")
  device:emit_event(capabilities.switchLevel.level(cmd.args.level))
  if device.preferences.doStateAccess then
    if get_device_num(device) % 2 == 0 then
      device.log.info_with({hub_logs=true}, "get_latest_state swtichLevel: "..device:get_latest_state("main", "switchLevel", "level", "unknown"))
    else
      device.log.info_with({hub_logs=true}, "direct index: "..tostring(device.state_cache.main.switchLevel.level))
    end
  end
end
local function handle_refresh(driver, device, cmd)
  device.log.info_with({hub_logs=true}, "handle_refresh")
  if device.state_cache == (device.persistent_store or {})["__state_cache"] then
    device.log.info_with({hub_logs=true}, "state_cache is in persistent store")
  elseif device.state_cache == (device.transient_store or {})["__state_cache"] then
    device.log.info_with({hub_logs=true}, "state_cache is in transient store")
  else
    device.log.info_with({hub_logs=true}, "state cache is somewhere else")
  end
  if device.preferences.testDirectIdx and device.preferences.doStateAccess then
    device.log.info_with({hub_logs = true}, "size of device.state_cache = ".. tostring(utils.table_size(device.state_cache) or 999))
  end

  if device.preferences.doStateAccess then
    device.log.info_with({hub_logs=true}, utils.stringify_table(device.state_cache.main, "device.state_cache.main", true))
  end
end

 
return {
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