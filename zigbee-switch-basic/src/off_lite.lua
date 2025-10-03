return function(driver, device, cmd)
	-- Generate zigbee tx message
	-- Make a table that can be accessed in the same way as the full message structure in a normal driver
	local zb_mess = {}
	zb_mess.address_header = {
	  src_addr = {value = 0x0000},
	  src_endpoint = {value = 0x01},
	  dest_addr = {value = tonumber(device.device_network_id, 16)},
	  dest_endpoint = {value = 1},
	  profile = {value = 0x0104},
	  cluster = {value = 0x0006}
	}
	zb_mess.tx_options = {value = 0x0000}

  zb_mess._serialize = function(aname) 
    -- frame ctrl, seq num, command
    return "\x01\x00\x00"
  end
  zb_mess.body = {}
	driver.zigbee_channel:send(device.id, zb_mess)
end