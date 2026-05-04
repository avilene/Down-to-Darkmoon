local addonName, addon = ...

local Calendar = {
  active = false,
}
addon.Calendar = Calendar

--- While on the faire grounds, BestMap is a floor uiMap whose parent is the Darkmoon overview (407).
local DARKMOON_OVERVIEW_UIMAP = 407

local function textMentionsDarkmoon(s)
  if not s or s == "" then
    return false
  end
  local l = string.lower(s)
  return string.find(l, "darkmoon", 1, true) ~= nil
end

local function holidayLooksLikeDarkmoon(info)
  if not info then
    return false
  end
  return textMentionsDarkmoon(info.name) or textMentionsDarkmoon(info.description)
end

local function compareCalendar(a, b)
  if not a or not b then
    return nil
  end
  if C_DateAndTime.CompareCalendarTime then
    return C_DateAndTime.CompareCalendarTime(a, b)
  end
  if a.year ~= b.year then
    return a.year < b.year and -1 or 1
  end
  if a.month ~= b.month then
    return a.month < b.month and -1 or 1
  end
  if a.monthDay ~= b.monthDay then
    return a.monthDay < b.monthDay and -1 or 1
  end
  local ah = (a.hour or 0) * 60 + (a.minute or 0)
  local bh = (b.hour or 0) * 60 + (b.minute or 0)
  if ah ~= bh then
    return ah < bh and -1 or 1
  end
  return 0
end

--- Calendar day as YYYYMMDD for simple inclusive range checks.
local function dateKey(ct)
  if not ct then
    return 0
  end
  return (ct.year or 0) * 10000 + (ct.month or 0) * 100 + (ct.monthDay or 0)
end

local function nowWithinTimestampRange(now, startT, endT)
  if not startT or not endT then
    return nil
  end
  local geStart = compareCalendar(now, startT)
  local leEnd = compareCalendar(endT, now)
  if geStart == nil or leEnd == nil then
    return nil
  end
  return (geStart >= 0) and (leEnd >= 0)
end

--- Inclusive calendar-date range (ignores clock), handles multi-day Darkmoon week reliably.
local function nowWithinDateRange(now, startT, endT)
  if not startT or not endT then
    return false
  end
  local nk = dateKey(now)
  local sk = dateKey(startT)
  local ek = dateKey(endT)
  return nk >= sk and nk <= ek
end

local function sameCalendarDay(now, y, m, d)
  return now.year == y and now.month == m and now.monthDay == d
end

function Calendar:IsActiveFromHolidayInfo(now, info, monthInfo, dayIndex)
  if not info or not now or not monthInfo then
    return false
  end

  local ts = nowWithinTimestampRange(now, info.startTime, info.endTime)
  if ts == true then
    return true
  end

  if info.startTime and info.endTime then
    if nowWithinDateRange(now, info.startTime, info.endTime) then
      return true
    end
  end

  local y = monthInfo.year
  local m = monthInfo.month
  if y and m and sameCalendarDay(now, y, m, dayIndex) then
    return true
  end

  return false
end

--- Some clients expose Darkmoon only under day events (not GetHolidayInfo).
local function scanDayEventsForDarkmoon(now)
  if not C_Calendar.GetNumDayEvents or not C_Calendar.GetDayEvent then
    return false
  end
  for _, offset in ipairs({ 0, 1 }) do
    local ok, monthInfo = pcall(function()
      return C_Calendar.GetMonthInfo(offset)
    end)
    if ok and monthInfo and monthInfo.numDays and monthInfo.year and monthInfo.month then
      for day = 1, monthInfo.numDays do
        local n = C_Calendar.GetNumDayEvents(offset, day)
        if n and n > 0 then
          for idx = 1, n do
            local okEv, ev = pcall(C_Calendar.GetDayEvent, offset, day, idx)
            if okEv and ev then
              local title
              if type(ev) == "table" then
                title = ev.title
              elseif type(ev) == "string" then
                title = ev
              end
              if title and textMentionsDarkmoon(title) and sameCalendarDay(now, monthInfo.year, monthInfo.month, day) then
                return true
              end
            end
          end
        end
      end
    end
  end
  return false
end

local function playerAtDarkmoonIsland()
  local mapId = C_Map.GetBestMapForUnit("player")
  if not mapId then
    return false
  end
  if mapId == DARKMOON_OVERVIEW_UIMAP then
    return true
  end
  if C_Map and C_Map.GetMapInfo then
    local ok, info = pcall(C_Map.GetMapInfo, mapId)
    if ok and type(info) == "table" and info.parentMapID == DARKMOON_OVERVIEW_UIMAP then
      return true
    end
  end
  return false
end

function Calendar:RefreshActiveState()
  local function done()
    self._hasRefreshedStateOnce = true
  end

  if playerAtDarkmoonIsland() then
    self.active = true
    done()
    return
  end

  self.active = false
  if not C_Calendar or not C_DateAndTime.GetCurrentCalendarTime then
    done()
    return
  end

  local now = C_DateAndTime.GetCurrentCalendarTime()
  if not now then
    done()
    return
  end

  if C_Calendar.GetHolidayInfo then
    for _, offset in ipairs({ 0, 1 }) do
      local ok, monthInfo = pcall(function()
        return C_Calendar.GetMonthInfo(offset)
      end)
      if ok and monthInfo and monthInfo.numDays and monthInfo.year and monthInfo.month then
        for day = 1, monthInfo.numDays do
          for idx = 1, 32 do
            local info = C_Calendar.GetHolidayInfo(offset, day, idx)
            if not info then
              break
            end
            if holidayLooksLikeDarkmoon(info) then
              if self:IsActiveFromHolidayInfo(now, info, monthInfo, day) then
                self.active = true
                done()
                return
              end
            end
          end
        end
      end
    end
  end

  if scanDayEventsForDarkmoon(now) then
    self.active = true
    done()
    return
  end

  done()
end

function Calendar:ScheduleRefresh(delay)
  if self._pendingTimer then
    self._pendingTimer:Cancel()
    self._pendingTimer = nil
  end
  self._pendingTimer = C_Timer.NewTimer(delay or 0.2, function()
    self._pendingTimer = nil
    self:RefreshActiveState()
    if addon.UI and addon.UI.mainFrame and addon.UI.mainFrame:IsShown() then
      addon.UI:Refresh()
    end
    if addon.Minimap and addon.Minimap.RefreshTooltip then
      addon.Minimap:RefreshTooltip()
    end
  end)
end

function Calendar:Init()
  if self._inited then
    return
  end
  self._inited = true

  local f = CreateFrame("Frame")
  f:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function(_, event)
    self:ScheduleRefresh(event == "PLAYER_ENTERING_WORLD" and 0.5 or 0)
  end)

  C_Timer.After(1.5, function()
    if C_Calendar and C_Calendar.OpenCalendar then
      C_Calendar.OpenCalendar()
    end
    self:ScheduleRefresh(1)
  end)
end

--- Calendar start time for the Darkmoon instance that is active **today** (nil if not found in API).
local function getActiveDarkmoonHolidayStartTime(now)
  if not now or not C_Calendar or not C_Calendar.GetHolidayInfo then
    return nil
  end
  for _, offset in ipairs({ 0, 1 }) do
    local ok, monthInfo = pcall(function()
      return C_Calendar.GetMonthInfo(offset)
    end)
    if ok and monthInfo and monthInfo.numDays and monthInfo.year and monthInfo.month then
      for day = 1, monthInfo.numDays do
        for idx = 1, 32 do
          local info = C_Calendar.GetHolidayInfo(offset, day, idx)
          if not info then
            break
          end
          if holidayLooksLikeDarkmoon(info) and info.startTime then
            if Calendar:IsActiveFromHolidayInfo(now, info, monthInfo, day) then
              return info.startTime
            end
          end
        end
      end
    end
  end
  return nil
end

--- While the Faire is up, the next occurrence isn’t in the calendar list yet; approximate as start + 5 weeks.
local NEXT_DARKMOON_START_OFFSET_WEEKS = 5
local NEXT_DARKMOON_START_OFFSET_DAYS = NEXT_DARKMOON_START_OFFSET_WEEKS * 7

--- Earliest Darkmoon Faire **start** after `now`, excluding the instance running **now**
--- (calendar APIs sometimes list the active faire with a start that still sorts after the clock).
function Calendar:GetNextDarkmoonStartAfterNow()
  if not C_DateAndTime or not C_DateAndTime.GetCurrentCalendarTime then
    return nil
  end
  if not C_Calendar or not C_Calendar.GetMonthInfo or not C_Calendar.GetHolidayInfo then
    return nil
  end
  local now = C_DateAndTime.GetCurrentCalendarTime()

  if addon:IsDarkmoonActive() then
    local startCt = getActiveDarkmoonHolidayStartTime(now)
    if startCt and C_DateAndTime.AdjustTimeByDays then
      local ok, shifted = pcall(C_DateAndTime.AdjustTimeByDays, startCt, NEXT_DARKMOON_START_OFFSET_DAYS)
      if ok and shifted then
        return shifted
      end
    end
  end

  local best = nil
  for offset = 0, 5 do
    local ok, monthInfo = pcall(function()
      return C_Calendar.GetMonthInfo(offset)
    end)
    if ok and monthInfo and monthInfo.numDays and monthInfo.year and monthInfo.month then
      for day = 1, monthInfo.numDays do
        for idx = 1, 32 do
          local info = C_Calendar.GetHolidayInfo(offset, day, idx)
          if not info then
            break
          end
          if holidayLooksLikeDarkmoon(info) and info.startTime then
            local activeNow = self:IsActiveFromHolidayInfo(now, info, monthInfo, day)
            if not activeNow and compareCalendar(info.startTime, now) > 0 then
              if not best or compareCalendar(info.startTime, best) < 0 then
                best = info.startTime
              end
            end
          end
        end
      end
    end
  end
  return best
end

function Calendar:FormatCalendarDate(ct)
  if not ct or not ct.year or not ct.month or not ct.monthDay then
    return nil
  end
  if C_DateAndTime and type(C_DateAndTime.FormatCalendarTime) == "function" then
    local ok, s = pcall(C_DateAndTime.FormatCalendarTime, ct)
    if ok and type(s) == "string" and s ~= "" then
      return s
    end
  end
  local months = {
    _G.MONTH_JANUARY,
    _G.MONTH_FEBRUARY,
    _G.MONTH_MARCH,
    _G.MONTH_APRIL,
    _G.MONTH_MAY,
    _G.MONTH_JUNE,
    _G.MONTH_JULY,
    _G.MONTH_AUGUST,
    _G.MONTH_SEPTEMBER,
    _G.MONTH_OCTOBER,
    _G.MONTH_NOVEMBER,
    _G.MONTH_DECEMBER,
  }
  local name = months[ct.month]
  if type(name) ~= "string" then
    name = tostring(ct.month)
  end
  return string.format("%s %d, %d", name, ct.monthDay, ct.year)
end

--- Human-readable next Faire start, or nil if the calendar has no matching holiday yet.
function addon:GetNextDarkmoonFaireStartDateString()
  local ct = self.Calendar:GetNextDarkmoonStartAfterNow()
  return self.Calendar:FormatCalendarDate(ct)
end

function addon:IsDarkmoonActive()
  return addon.Calendar.active == true
end
