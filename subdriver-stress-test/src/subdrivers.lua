local config = require "config"
local log = require "log"
local utils = require "st.utils"
local capabilities = require "st.capabilities"

local function generate_subdriver(name, can_handle)
	assert(type(can_handle) == "function")

	local subdriver = {
	  NAME = name,
	  capability_handlers = require("capability_handlers"),
	  can_handle = can_handle
	}
	return subdriver
end

local subdrivers = {}

if config.CAN_HANDLE_DISTRIBUTION == "UNIFORM" then
	for i=1,config.NUM_DEVICES do
		local can_handle = function(opts, driver, device)
			local device_num = string.match(device.device_network_id, string.format("%s (%%d)", config.CAN_HANDLE_DISTRIBUTION))
			return i == tonumber(device_num or 0)
		end
		table.insert(subdrivers, i, generate_subdriver(string.format("Subdriver %s", i), can_handle))
	end
elseif config.CAN_HANDLE_DISTRIBUTION == "LAST_ONLY" then
	local first_false = config.NUM_DEVICES - 1
	for i=1,first_false do
		local can_handle = function(opts, driver, device)
			return false
		end
		table.insert(subdrivers, i, generate_subdriver(string.format("Subdriver %s", i), can_handle))
	end
	local can_handle = function(opts, driver, device)
		return true
	end
	table.insert(subdrivers, config.NUM_DEVICES, generate_subdriver(string.format("Subdriver %s", config.NUM_DEVICES), can_handle))
elseif config.CAN_HANDLE_DISTRIBUTION == "FIRST_ONLY" then
	local can_handle = function(opts, driver, device)
		return true
	end
	table.insert(subdrivers, 1, generate_subdriver(string.format("Subdriver %s", 1), can_handle))
	for i=2,config.NUM_DEVICES do
		local can_handle = function(opts, driver, device)
			return false
		end
		table.insert(subdrivers, i, generate_subdriver(string.format("Subdriver %s", i), can_handle))
	end
elseif config.CAN_HANDLE_DISTRIBUTION == "NONE" then
	-- no subdrivers...
end

return subdrivers