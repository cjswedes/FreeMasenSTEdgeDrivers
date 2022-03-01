local cosock = require "cosock"
local log = require "log"
local api = cosock.asyncify "api"
local utils = require 'st.utils'

local function is_nil_or_empty_string(v)
  if type(v) == 'string' then
    return #v == 0
  end
  return true
end

local NEW_CLIENT = "new-client"
local CREDS_UPDATE = "credentials-update"

---Create a new client message table
---@param device_id string The device id for this client
---@param name string The target name provided by the preferences
---@return table
local function new_client_message(device_id, name)
  return {
    type = NEW_CLIENT,
    device_id = device_id,
    name = name,
  }
end

local function creds_update_message(ip, username, password)
  return {
    type = CREDS_UPDATE,
    ip = ip,
    username = username,
    password = password,
  }
end

local function check_states(ip, device_names, creds, event_tx)
  log.trace("check_states")
  if not (creds.xsrf and creds.cookie) then
    creds.cookie, creds.xsrf = assert(api.login(ip, creds.username, creds.password))
  end
  local sites = assert(api.get_sites(ip, creds.cookie, creds.xsrf))
  for _, client in ipairs(sites.data) do
    local current_state = device_names[client.name]
      or device_names[client.hostname]
      or device_names[client.mac]
    if current_state ~= nil then
      local now = cosock.socket.gettime()
      local diff = now - client.last_seen
      local next_state = diff < 60
      if current_state.state ~= next_state then
        log.debug("Sending device update ", current_state.id, next_state)
        event_tx:send({
          device_id = current_state.id,
          state = next_state
        })
        current_state.state = next_state
      end
    end
  end
end


local function spawn_presence_task(ip, device_names, username, password)
  log.trace("spawn_presence_task")
  local update_tx, update_rx = cosock.channel.new()
  local event_tx, event_rx = cosock.channel.new()
  cosock.spawn(function()
    local creds = {
      cookie = nil,
      xsrf = nil,
      username = username,
      password = password,
    }
    while true do
      log.debug("Waiting for message")
      local ready, msg, err
      ready, err = cosock.socket.select({update_rx}, {}, 5)
      if ready then
        msg, err = update_rx:receive()
      end
      if msg then
        log.debug("Got message", msg.type)
        if msg.type == NEW_CLIENT then
          device_names[msg.name] = {
            state = false,
            id = msg.device_id,
          }
        elseif msg.type == CREDS_UPDATE then
          creds.username = msg.username or username
          creds.password = msg.password or password
          creds.cookie = nil
          creds.xsrf = nil
          ip = msg.ip or ip
        else
          log.warn("unknown message type", utils.stringify_table(msg, "msg", true))
        end
      else
        log.debug("No message", err)
      end
      if err and err ~= "timeout" then
        log.error(string.format("Error receiving from update_rx: %q", err))
        goto continue
      end
      if is_nil_or_empty_string(ip)
      or is_nil_or_empty_string(creds.username)
      or is_nil_or_empty_string(creds.password) then
        log.warn("No ip/username/password")
        goto continue
      end
      local s, err = pcall(function()
        check_states(ip, device_names, creds, event_tx)
      end)
      if not s then
        log.error("Failed in presence pass", err)
      else
        log.info("Successfully checked sites")
      end
      ::continue::
    end
  end, "presence-task")
  return update_tx, event_rx
end


return {
  spawn_presence_task = spawn_presence_task,
  new_client_message = new_client_message,
  creds_update_message = creds_update_message,
  timeout_message = timeout_message,
}