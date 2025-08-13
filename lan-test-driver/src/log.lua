local original_log
if _envlibrequire ~= nil then
  original_log = _envlibrequire("log")
else
  original_log = require("stdout_log")
end

local hubcore_enabled_log = {}

hubcore_enabled_log.info = function(...)
  original_log.info_with({hub_logs = false}, ...)
end

hubcore_enabled_log.warn = function(...)
  original_log.warn_with({hub_logs = true}, ...)
end

hubcore_enabled_log.error = function(...)
  original_log.error_with({hub_logs = true}, ...)
end

--- Force logging Debug at Info to avoid needing to increase verbosity in hubcore for
--- diagnostic purposes
hubcore_enabled_log.debug = function(...)
  hubcore_enabled_log.info(table.concat({"[DEBUG->INFO] ", ...}))
end

--- Force logging Trace at Info to avoid needing to increase verbosity in hubcore for
--- diagnostic purposes
hubcore_enabled_log.trace = function(...)
  hubcore_enabled_log.info(table.concat({"[TRACE->INFO] ", ...}))
end

hubcore_enabled_log.info_with = original_log.info_with
hubcore_enabled_log.warn_with = original_log.warn_with
hubcore_enabled_log.error_with = original_log.error_with
hubcore_enabled_log.debug_with = original_log.debug_with
hubcore_enabled_log.trace_with = original_log.trace_with

return hubcore_enabled_log