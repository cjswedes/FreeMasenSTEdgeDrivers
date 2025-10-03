-- Copyright 2022 SmartThings
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
local lite_enabled = true

local capabilities = require "st.capabilities"
local ZigbeeDriver 
if lite_enabled then
  ZigbeeDriver = require "zigbee_driver_patch"
else
  ZigbeeDriver = require "st.zigbee"
end
local clusters
if not lite_enabled then
  clusters = require "st.zigbee.zcl.clusters"
end

local function info_changed(self, device, event, args)
  device.log.info_with({hub_logs=true}, "info_changed")
end

local do_configure = function(self, device)
  device.log.info_with({hub_logs=true}, "do_configure")
end

local function component_to_endpoint(device, component_id)
  local ep_num = component_id:match("switch(%d)")
  return ep_num and tonumber(ep_num) or device.fingerprinted_endpoint_id
end

local function endpoint_to_component(device, ep)
  local switch_comp = string.format("switch%d", ep)
  if device.profile.components[switch_comp] ~= nil then
    return switch_comp
  else
    return "main"
  end
end

local function find_child(parent, ep_id)
  return parent:get_child_by_parent_assigned_key(string.format("%02X", ep_id))
end

local device_init = function(driver, device)
  device:set_component_to_endpoint_fn(component_to_endpoint)
  device:set_endpoint_to_component_fn(endpoint_to_component)

  device.log.info_with({hub_logs=true}, "device_init")
end

local function device_added(driver, device, event)
  device.log.info_with({hub_logs=true}, "device_added")
end

local zigbee_switch_driver_template = {
  zigbee_handlers = {
    attr = {
      [0x0006] = {
        [0x0000] = require("on_off_attr_handler")
      }
    }
  },
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = require("on"),
      [capabilities.switch.commands.off.NAME] = require("off"),
    }
  },
  current_config_version = 1,
  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    infoChanged = info_changed,
    doConfigure = do_configure,
  },
  health_check = false,
}
local zigbee_switch = ZigbeeDriver("zigbee_switch", zigbee_switch_driver_template)
zigbee_switch:run()
