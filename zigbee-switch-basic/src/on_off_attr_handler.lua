local capabilities = require "st.capabilities"

--- Default handler for on off attribute on the on off cluster
---
--- This converts the boolean value from true -> Switch.switch.on and false to Switch.switch.off.
---
--- @param driver ZigbeeDriver The current driver running containing necessary context for execution
--- @param device st.zigbee.Device The device this message was received from containing identifying information
--- @param value st.zigbee.data_types.Boolean the value of the On Off cluster On Off attribute
--- @param zb_rx st.zigbee.ZigbeeMessageRx the full message this report came in
--- @param register_native bool|nil Register future rx messages to be handled natively by the hub
return function(driver, device, value, zb_rx, register_native)
  local attr = capabilities.switch.switch
  local event = attr.on()
  if value.value == false or value.value == 0 then
    event = attr.off()
  end
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, event)
  if register_native then
    device:register_native_capability_attr_handler("switch", "switch")
  end
end
