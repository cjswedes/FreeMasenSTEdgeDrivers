local zcl_clusters = require "st.zigbee.zcl.clusters"

--- Default handler for the Switch.on command
---
--- This will send the on command to the on off cluster
---
--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param command CapabilityCommand The capability command table
--- @param register_native bool|nil Register future commands to be handled natively by the hub
return function(driver, device, command, register_native)
  if register_native then
    device:register_native_capability_cmd_handler(command.capability, command.command)
  end
  device:send_to_component(command.component, zcl_clusters.OnOff.server.commands.On(device))
end

