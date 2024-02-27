local log = require "log"
local capabilities = require "st.capabilities"

local command_handlers = {}

-- callback to handle an `on` capability command
function command_handlers.switch_on(driver, device, command)
  log.debug(string.format("[%s] calling set_power(on)", device.device_network_id))
  device:emit_event(capabilities.switch.switch.on())
end

-- callback to handle an `off` capability command
function command_handlers.switch_off(driver, device, command)
  log.debug(string.format("[%s] calling set_power(off)", device.device_network_id))
  device:emit_event(capabilities.switch.switch.off())
end

function command_handlers.set_colorTemp(driver, device, command)
  log.debug(string.format("[%s] calling set_colorTemp", device.device_network_id))
  log.trace("args ", command.args.level)
  device:emit_event(capabilities.colorTemperature.colorTemperature(command.args.temperature))
end

function command_handlers.setColor(driver, device, command)
  log.debug(string.format("[%s] calling setColor", device.device_network_id))
  log.trace("args ", tostring(command.args.color))
  device:emit_event(capabilities.colorControl.saturation(command.args.color.saturation))
  device:emit_event(capabilities.colorControl.hue(command.args.color.hue))
end

function command_handlers.setHue(driver, device, command)
  log.debug(string.format("[%s] calling setHue", device.device_network_id))
  log.trace("args ", tostring(command.args.hue))
  --device:emit_event(capabilities.colorControl.colorTemperature(command.args.temperature))
end

function command_handlers.setSaturation(driver, device, command)
  log.debug(string.format("[%s] calling setSaturation", device.device_network_id))
  log.trace("args ", tostring(command.args.saturation))
  --device:emit_event(capabilities.colorControl.colorTemperature(command.args.temperature))
end

function command_handlers.setThermostatMode(driver, device, command)
  log.debug(string.format("[%s] calling setThermostatMode", device.device_network_id))
  device:emit_event(capabilities.thermostatMode.thermostatMode(command.args.mode))
end

function command_handlers.refresh(driver, device, command)
  log.debug(string.format("[%s] calling refresh", device.device_network_id))
  device:emit_event(capabilities.thermostatMode.thermostatMode("off"))
  device:emit_event(capabilities.smokeDetector.smoke("clear"))
  device:emit_event(capabilities.temperatureMeasurement.temperature({value=12, unit="C"}))
  device:emit_event(capabilities.switch.switch.on())
end

return command_handlers
