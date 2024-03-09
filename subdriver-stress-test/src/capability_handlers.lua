local capabilities = require "st.capabilities"

local function handle_off(driver, device, cmd)
  device.log.info("handle_off")
  device:emit_event(capabilities.switch.switch.off())
end
local function handle_on(driver, device, cmd)
  device.log.info("handle_on")
  device:emit_event(capabilities.switch.switch.on())
end
local function handle_level(driver, device, cmd)
  device.log.info("handle_level")
  device:emit_event(capabilities.switchLevel.level(cmd.args.level))
end
local function handle_refresh(driver, device, cmd)
  device.log.info("handle_refresh")
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