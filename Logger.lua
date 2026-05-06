local _, addon = ...

local Logger = {}
addon.Logger = Logger

local function formatMessage(fmtOrMsg, ...)
  if select("#", ...) == 0 then
    return tostring(fmtOrMsg)
  end
  local ok, out = pcall(string.format, tostring(fmtOrMsg), ...)
  if ok then
    return out
  end
  return tostring(fmtOrMsg)
end

function Logger:IsChannelEnabled(channel)
  local db = addon.GetDB and addon:GetDB()
  if type(db) ~= "table" then
    return false
  end
  return db.debug == true
end

function Logger:Log(channel, level, fmtOrMsg, ...)
  if not self:IsChannelEnabled(channel) then
    return
  end
  local msg = formatMessage(fmtOrMsg, ...)
  local chan = tostring(channel or "core"):upper()
  local lvl = tostring(level or "DEBUG"):upper()
  print(("|cff73d7ff[DTD %s/%s]|r %s"):format(chan, lvl, msg))
end

function Logger:Debug(channel, fmtOrMsg, ...)
  self:Log(channel, "DEBUG", fmtOrMsg, ...)
end

function Logger:Info(channel, fmtOrMsg, ...)
  self:Log(channel, "INFO", fmtOrMsg, ...)
end

function Logger:Warn(channel, fmtOrMsg, ...)
  self:Log(channel, "WARN", fmtOrMsg, ...)
end
