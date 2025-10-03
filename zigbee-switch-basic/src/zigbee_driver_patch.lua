-- Copyright 2021 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
local log = require "log"
local Driver = require "st.driver"
local device_management = require "st.zigbee.device_management"
local ZigbeeMessageDispatcher = require "st.zigbee.dispatcher"
local socket = require "cosock.socket"
local utils = require "st.utils"

--- @class st.zigbee.AttributeConfiguration
---
--- @field public cluster number Cluster ID this attribute is a part of
--- @field public attribute number the attribute ID
--- @field public minimum_interval number the minimum reporting interval for this configuration
--- @field public maximum_interval number the maximum reporting interval for this configuration
--- @field public data_type st.zigbee.data_types.DataType the data type class for this attribute
--- @field public reportable_change st.zigbee.data_types.DataType (optional) the amount of change needed to trigger a report.  Only necessary for non-discrete attributes
--- @field public mfg_code number the manufacturer-specific code
--- @field public configurable boolean (optional default = true) Should this result in a Configure Reporting command to the device
--- @field public monitored boolean (optional default = true) Should this result in a expected report monitoring
local attribute_config = {}


---@alias ZigbeeHandler fun(type: Driver, type: Device, ...):void

--- @class ZigbeeDriver: Driver
---
--- @field public zigbee_channel message_channel the communication channel for Zigbee devices
--- @field public cluster_configurations st.zigbee.AttributeConfiguration[] A list of configurations for reporting attributes
--- @field public zigbee_handlers table A structure definining different ZigbeeHandlers mapped to what they handle (only used on creation)
local ZigbeeDriver = {}
ZigbeeDriver.__index = ZigbeeDriver

--- this will return a table that can go through the existing dispatcher
--- and handlers, but is more light weight
local function parse_zigbee_channel_message(zb_channel_data)

	local data_type_length_map = {
	    -- Enum8
	    [0x30] = 1,
	    -- Uint16
	    [0x21] = 2,
	    -- Boolean
	    [0x10] = 1
	}
	local ON_OFF_CLUSTER_ID = 0x0006
	-- assume little endian for zigbee
	local function bytes_to_int(byte_arr) 
	    local num = 0
	    for i, byte in ipairs(byte_arr) do
	        num = num | (byte << ((i - 1) * 8))
	    end
	    return num
	end

  local bytes = { zb_channel_data:byte(1, #zb_channel_data) }

  if #bytes < 15 then
    -- Invalid message, need at least 15 bytes for header information
    return nil, "message not long enough"
  end

  local zb_rx = {
  	address_header = {},
    body = {
    	zcl_header = {},
    	zcl_body = {
    		attr_records = {},
    	},	
    },
  }
  -- Address info

  -- byte 1 is type, don't need it
  -- byte 2-3 is source addr, already have device_uuid so not needed
  -- byte 4 is src_endpoint won't use for this driver, but could be used  so I'll pull it  out
  local src_endpoint = bytes[4]
  -- bytes 5-6 are dest_addr which is the hub so don't need
  -- byte 7 is dest_endpoint which is the hub so don't need
  -- bytes 8-9 are profile, won't need it for this driver but could be used so I'll pull it out
  local profile = bytes_to_int( {bytes[8], bytes[9]})
  -- bytes 10-11 are cluster, needed to identify message
  local cluster = bytes_to_int( { bytes[10], bytes[11] })
  zb_rx.address_header.src_endpoint = { value = src_endpoint }
  zb_rx.address_header.profile = { value = profile }
  zb_rx.address_header.cluster = { value = cluster }

  -- For this example we are only processing on/off events
  if cluster ~= ON_OFF_CLUSTER_ID then
    return nil, "not the on off cluster"
  end
  -- byte 12 is lqi
  -- byte 13 is rssi
  -- bytes 14-15 are body length
  local body_len = bytes_to_int( { bytes[14], bytes[15] } ) 

  -- body length check
  if body_len < 3 then
    return nil, "invalid body_len"
  end
  
  -- get zcl header
  -- byte 16 is frame_ctrl
  local frame_ctrl = bytes[16]
  local is_mfg_spcfc = (frame_ctrl & 0x04) ~= 0
  local is_cluster_spcfc = (frame_ctrl & 0x01) ~= 0
  -- byte 17 is seqno
  -- byte 18 is cmd
  local cmd = bytes[18]
  zb_rx.body.zcl_header.frame_ctrl = {
  	value = frame_ctrl,
  	is_cluster_specific_set = function(...) return is_cluster_spcfc end
  }
  zb_rx.body.zcl_header.cmd = { value = cmd }
  -- minimal driver doesn't handle mfg specific commands
  if is_mfg_spcfc then
    return nil, "mfr specific message"
  end

  -- Handle read attribute response
  if not is_cluster_spcfc and cmd == 0x01 then
    -- body is repeating set of attribute records
    local pos = 19
    while pos < #bytes do
    	local attr_record = {}
      local attr_id = bytes_to_int( { bytes[pos], bytes[pos + 1] } )
      local status = bytes[pos + 2]
      attr_record.status = {value = status}
      attr_record.attr_id = {value = attr_id}
      
      -- success status
      if status == 0 then
        local data_type = bytes[pos + 3]
        local data_type_len = data_type_length_map[data_type]
        if data_type_len == nil then
      return nil, "no data_type_len specified for type "..(data_type or "nil")
        end
        local data = {}
        for i = 4,(4 + data_type_len) do
          table.insert(data, bytes[i])
        end
        local data_val = bytes_to_int(data)
        attr_record.data = {value = data_val}
        table.insert(zb_rx.body.zcl_body.attr_records, attr_record)
        -- On/Off Attribute
        if attr_id == 0x0000 then
          log.info_with({hub_logs=true}, "parsed onoff read attribute response")
        end
        pos = pos + 1 + data_type_len
      else
          pos = pos + 3
      end
    end
  -- Report attribute
  elseif not is_cluster_spcfc and cmd == 0x0A then
  	local attr_record = {}
    -- body is an attr_id, data_type, and value
    local attr_id = bytes_to_int( { bytes[19], bytes[20] } )
    local data_type = bytes[21]
    local data_type_len = data_type_length_map[data_type]
    if data_type_len == nil then
      return nil, "no data_type_len specified for type "..tostring(data_type)
    end
    local data = {}
    for i = 1,data_type_len do
      table.insert(data, bytes[21 + i])
    end
    local data_val = bytes_to_int(data)
    attr_record.attr_id = {value = attr_id}
    attr_record.data = {value = data_val}
    table.insert(zb_rx.body.zcl_body.attr_records, attr_record)

    -- On/Off Attribute
    if attr_id == 0x0000 then
      log.info_with({hub_logs=true}, "parsed onoff report attribute")
    end
  else
      -- Could handle default response if we care
      -- Don't care about other messages
      return nil, "zcl message type not handled "..tostring(cmd)
  end
  return zb_rx
end

--- Handler function for the raw zigbee channel message receive
---
--- This will be the default registered handler for the Zigbee message_channel receive callback.  It will parse the
--- raw serialized message into a ZigbeeMessageRx and then use the zigbee_message_dispatcher to find a handler that
--- can deal with it.
---
--- Handlers have various levels of specificity.  Global handlers are for global ZCL commands, and are specified with a
--- cluster, then command ID.  Cluster handlers are for cluster specific commands and are again defined by cluster, then
--- command id.  Attr handlers are used for an attribute report, or read response for a specific cluster, attribute ID.
--- and finally zdo handlers are for ZDO commands and are defined by the "cluster" of the command.
---
--- @param self Driver the driver context
--- @param message_channel message_channel the Zigbee message_channel with a message ready to be read
function ZigbeeDriver:zigbee_message_handler(message_channel)
  local buf_lib = require "st.buf"
  local device_uuid, data = message_channel:receive()
  -- local buf = buf_lib.Reader(data)
  -- local zb_rx = messages.ZigbeeMessageRx.deserialize(buf, {additional_zcl_profiles = self.additional_zcl_profiles})
  local zb_rx, err = parse_zigbee_channel_message(data)
  local device = self:get_device_info(device_uuid)
  if zb_rx ~= nil then
    device.log.info_with({ hub_logs = true }, string.format("received Zigbee message: %s", utils.stringify_table(zb_rx)))
    device.thread:queue_event(
      self.zigbee_message_dispatcher.dispatch, self.zigbee_message_dispatcher, self, device, zb_rx,
      self.default_handler_opts and self.default_handler_opts.native_capability_attrs_enabled
    )
  else 
  	device.log.info_with( {hub_logs=true}, "Failed to parse zigbee message: " .. tostring(err))
  end
end

--- Add a number of child handlers that override the top level driver behavior
---
--- Each handler set can contain a `handlers` field that follow exactly the same
--- pattern as the base driver format. It must also contain a
--- `zigbee_can_handle(driver, device, zb_rx)` function that returns true if the
--- corresponding handlers should be considered.
---
--- This will recursively follow the `sub_drivers` and build a structure that will
--- correctly find and execute a handler that matches.  It should be noted that a child handler
--- will always be preferred over a handler at the same level, but that if multiple child
--- handlers report that they can handle a message, it will be sent to each handler that reports
--- it can handle the message.
---
--- @param driver Driver the executing zigbee driver (or sub handler set)
function ZigbeeDriver.populate_zigbee_dispatcher_from_sub_drivers(driver)
  for _, sub_driver in ipairs(driver.sub_drivers) do
    local zigbee_handlers = {}
    if Driver.should_lazy_load_sub_driver(sub_driver) then
      zigbee_handlers = {}
    else
      zigbee_handlers = sub_driver.zigbee_handlers or {}
    end
    sub_driver.zigbee_message_dispatcher =
      ZigbeeMessageDispatcher(sub_driver.NAME, sub_driver.can_handle, zigbee_handlers)
    driver.zigbee_message_dispatcher:register_child_dispatcher(sub_driver.zigbee_message_dispatcher)

    ZigbeeDriver.populate_zigbee_dispatcher_from_sub_drivers(sub_driver)
  end
end

function ZigbeeDriver:add_hub_to_zigbee_group(group_id)
  self.zigbee_channel:add_hub_to_group(group_id)
end

function ZigbeeDriver:build_child_device(raw_device_table)
  local zigbee_child_device = require "st.zigbee.child"
  return zigbee_child_device.ZigbeeChildDevice(self, raw_device_table)
end

--- Build a Zigbee driver from the specified template
---
--- This can be used to, given a template, build a Zigbee driver that can be run to support devices.  The name field is
--- used for logging and other debugging purposes.  The driver should also include a set of
--- capability_handlers and zigbee_handlers to handle messages for the corresponding message types.  It is recommended
--- that you use the call syntax on the ZigbeeDriver to execute this (e.g. ZigbeeDriver("my_driver", {}) )
---
--- @param cls table the class to be instantiated (ZigbeeDriver)
--- @param name string the name of this driver
--- @param driver_template table a template providing information on the driver and it's handlers
--- @return Driver the constructed Zigbee driver
function ZigbeeDriver.init(cls, name, driver_template)
  local out_driver = driver_template or {}
  math.randomseed(os.time())

  out_driver.zigbee_channel = out_driver.zigbee_channel or socket.zigbee()
  out_driver.zigbee_handlers = out_driver.zigbee_handlers or {}

  out_driver.zigbee_message_dispatcher = ZigbeeMessageDispatcher(name, function(...) return true end, out_driver.zigbee_handlers)

  -- Add device lifecycle handler functions
  out_driver.lifecycle_handlers = out_driver.lifecycle_handlers or {}

  utils.merge(
      out_driver.lifecycle_handlers,
      {
        doConfigure = device_management.configure,
        driverSwitched = Driver.default_capability_match_driverSwitched_handler,
      }
  )

  out_driver.capability_handlers = out_driver.capability_handlers or {}
  -- use default refresh if explicit handler not set
  utils.merge(
      out_driver.capability_handlers,
      {
        refresh = {
          refresh = device_management.refresh
        }
      }
  )

  out_driver = Driver.init(cls, name, out_driver)
  out_driver:_register_channel_handler(out_driver.zigbee_channel, out_driver.zigbee_message_handler, "zigbee")
  ZigbeeDriver.populate_zigbee_dispatcher_from_sub_drivers(out_driver)
  log.trace_with({ hub_logs = true }, string.format("Setup driver %s with Zigbee handlers:\n%s", out_driver.NAME, out_driver.zigbee_message_dispatcher))
  ------------------------------------------------------------------------------------
  -- Set up local state
  ------------------------------------------------------------------------------------
  out_driver.health_check = out_driver.health_check == nil and true or out_driver.health_check
  if (out_driver.health_check) then
    log.warn("The Zigbee Driver \"health check\" feature is being deprecated.  If your driver depends on this functionality please replace it in your driver.  To remove this warning set `health_check = false` on your driver template.")
    device_management.init_device_health(out_driver)
  end

  return out_driver
end

setmetatable(ZigbeeDriver, {
  __index = Driver,
  __call = ZigbeeDriver.init
})

return ZigbeeDriver
