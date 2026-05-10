local addonName, addon = ...

local Calendar = {
  active = false,
}
addon.Calendar = Calendar

--- While on the faire grounds, BestMap is a floor uiMap whose parent is the Darkmoon overview (407).
local DARKMOON_OVERVIEW_UIMAP = 407

--- `CalendarHolidayInfo.texture` and `CalendarDayEvent.iconTexture` are **fileID** (locale-independent).
--- Retail Darkmoon calendar uses 235446–235451 (faction / variant); not the generic ticket icon.
local DARKMOON_CALENDAR_FILE_IDS = {
  [235446] = true,
  [235447] = true,
  [235448] = true,
  [235449] = true,
  [235450] = true,
  [235451] = true,
}

local function calendarFileIdIsDarkmoon(id)
  return type(id) == "number" and id > 0 and DARKMOON_CALENDAR_FILE_IDS[id] == true
end

local function rememberDarkmoonCalendarFileId(id)
  if type(id) == "number" and id > 0 then
    DARKMOON_CALENDAR_FILE_IDS[id] = true
  end
end

--- Substrings from localized calendar titles/descriptions (fallback when texture id is missing or changes).
--- enUS uses "Darkmoon"; deDE uses "Dunkelmond", etc.
--- Match on string.lower for Latin scripts; also search the raw string for CJK/Cyrillic tokens.
local DARKMOON_TITLE_TOKENS = {
  "darkmoon",
  "dunkelmond", -- deDE (e.g. Dunkelmond-Jahrmarkt)
  "sombrelune", -- frFR
  "negraluna", -- es/pt (Negraluna / Luna Negra)
  "lunargenta", -- esES Lunargenta
  "luna negra", -- es Feria de la Luna Negra
  "lunacupa", -- itIT Fiera di Lunacupa
  "новолун", -- ruRU (Ярмарка Новолуния, …)
  "暗月", -- zhCN/zhTW
  "다크문", -- koKR
}

local function textMentionsDarkmoon(s)
  if not s or s == "" then
    return false
  end
  local l = string.lower(s)
  for i = 1, #DARKMOON_TITLE_TOKENS do
    local token = DARKMOON_TITLE_TOKENS[i]
    if string.find(l, token, 1, true) ~= nil or string.find(s, token, 1, true) ~= nil then
      return true
    end
  end
  return false
end

local function calendarEntryLooksLikeDarkmoon(name, description, holidayTexture, dayIconTexture)
  if calendarFileIdIsDarkmoon(holidayTexture) or calendarFileIdIsDarkmoon(dayIconTexture) then
    return true
  end
  if textMentionsDarkmoon(name) or textMentionsDarkmoon(description) then
    --- Learn file IDs for this session — next refreshes match by id even if strings change or checks reorder.
    rememberDarkmoonCalendarFileId(holidayTexture)
    rememberDarkmoonCalendarFileId(dayIconTexture)
    return true
  end
  return false
end

local function holidayLooksLikeDarkmoon(info)
  if not info then
    return false
  end
  return calendarEntryLooksLikeDarkmoon(info.name, info.description, info.texture, nil)
end

local function compareCalendarFallback(a, b)
  if not a or not b then
    return nil
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

--- Prefer Blizzard compare when both sides are full CalendarTime tables; saved/minimal tables may omit
--- `weekday` etc. and CompareCalendarTime errors on Retail 12.x — fall back to date/time ordering.
local function compareCalendar(a, b)
  if not a or not b then
    return nil
  end
  if C_DateAndTime.CompareCalendarTime then
    local ok, cmp = pcall(C_DateAndTime.CompareCalendarTime, a, b)
    if ok and type(cmp) == "number" then
      return cmp
    end
  end
  return compareCalendarFallback(a, b)
end

--- Calendar day as YYYYMMDD for simple inclusive range checks.
local function dateKey(ct)
  if not ct then
    return 0
  end
  return (ct.year or 0) * 10000 + (ct.month or 0) * 100 + (ct.monthDay or 0)
end

--- Incomplete CalendarTime (e.g. before calendar sync) can yield monthDay 0; then dateKey(now) sorts
--- before the real day and a past Faire start can be mistaken for "in the future".
local function calendarDateValid(ct)
  if not ct then
    return false
  end
  local y, m, d = ct.year, ct.month, ct.monthDay
  return type(y) == "number" and y > 0
    and type(m) == "number" and m >= 1 and m <= 12
    and type(d) == "number" and d >= 1 and d <= 31
end

--- True iff `startCt` is strictly after `nowCt` on the calendar (date first, then clock on same day).
local function startStrictlyAfterNow(startCt, nowCt)
  if not calendarDateValid(startCt) or not calendarDateValid(nowCt) then
    return false
  end
  local ks, kn = dateKey(startCt), dateKey(nowCt)
  if ks > kn then
    return true
  end
  if ks < kn then
    return false
  end
  local c = compareCalendar(startCt, nowCt)
  return c ~= nil and c > 0
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

--- True once this holiday occurrence is fully over (past the last calendar day, or past end clock on end day).
--- Do not use raw CompareCalendar(now, endTime) alone — Retail CompareCalendarTime can mis-order mixed tables and
--- mark `ended` while `now` is still before the listed end *date* (e.g. June 7 vs June 13).
local function isHolidayOccurrenceEnded(now, info)
  if not info or not info.endTime then
    return false
  end
  if not calendarDateValid(now) or not calendarDateValid(info.endTime) then
    return false
  end
  local nk, ek = dateKey(now), dateKey(info.endTime)
  if nk > ek then
    return true
  end
  if nk < ek then
    return false
  end
  return compareCalendar(now, info.endTime) > 0
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
              if type(ev) == "table" then
                if
                  calendarEntryLooksLikeDarkmoon(ev.title, "", nil, ev.iconTexture)
                  and sameCalendarDay(now, monthInfo.year, monthInfo.month, day)
                then
                  return true
                end
              elseif type(ev) == "string" then
                if
                  textMentionsDarkmoon(ev)
                  and sameCalendarDay(now, monthInfo.year, monthInfo.month, day)
                then
                  return true
                end
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
  if not now or not calendarDateValid(now) then
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
    if event == "CALENDAR_UPDATE_EVENT_LIST" then
      --- Let the inactive banner repaint once holiday data exists (don’t leave a stale date behind _inactiveBootFrozen).
      addon._inactiveBootFrozen = false
    end
    self:ScheduleRefresh(event == "PLAYER_ENTERING_WORLD" and 0.5 or 0)
  end)

  C_Timer.After(1.5, function()
    if C_Calendar and C_Calendar.OpenCalendar then
      C_Calendar.OpenCalendar()
    end
    self:ScheduleRefresh(1)
  end)
end

--- Darkmoon is roughly every ~4 weeks; the next week often isn’t listed yet—approximate from a known start.
local NEXT_DARKMOON_START_OFFSET_WEEKS = 4
local NEXT_DARKMOON_START_OFFSET_DAYS = NEXT_DARKMOON_START_OFFSET_WEEKS * 7

--- Returned/stored next start must be strictly after `now` and within this many days. Discovery scans the
--- full calendar first without this cap so we pick the real earliest occurrence (e.g. June 7), then apply
--- this limit only at the end—avoiding a bogus later month when an earlier start was wrongly filtered out.
local NEXT_FAIRE_MAX_DAYS_AHEAD = 35

local function calendarTimePlusDays(nowCt, days)
  if not calendarDateValid(nowCt) or not C_DateAndTime.AdjustTimeByDays then
    return nil
  end
  local ok, t = pcall(C_DateAndTime.AdjustTimeByDays, nowCt, days)
  if not ok or not t or not calendarDateValid(t) then
    return nil
  end
  return t
end

--- True if `startCt` is strictly after `nowCt` and not after `nowCt + maxDays` (end of horizon inclusive).
--- Uses calendar-date keys first; CompareCalendarTime vs `limit` alone can wrongly fail the gate when `weekday`
--- fields differ (wouldPick=Y but compute nil).
local function startWithinDaysAhead(startCt, nowCt, maxDays)
  if not startStrictlyAfterNow(startCt, nowCt) then
    return false
  end
  local limit = calendarTimePlusDays(nowCt, maxDays)
  if not limit or not calendarDateValid(limit) then
    return false
  end
  local sk, lk = dateKey(startCt), dateKey(limit)
  if sk > lk then
    return false
  end
  if sk < lk then
    return true
  end
  local c = compareCalendarFallback(startCt, limit)
  return c ~= nil and c <= 0
end

--- `fromStart` + interval, only if that moment is strictly after `now`.
local function nextStartFromScheduledOffset(fromStart, now)
  if not fromStart or not calendarDateValid(fromStart) or not C_DateAndTime.AdjustTimeByDays then
    return nil
  end
  local ok, shifted = pcall(C_DateAndTime.AdjustTimeByDays, fromStart, NEXT_DARKMOON_START_OFFSET_DAYS)
  if not ok or not shifted or not calendarDateValid(shifted) then
    return nil
  end
  if not startStrictlyAfterNow(shifted, now) then
    return nil
  end
  return shifted
end

local function earlierCalendarTime(a, b)
  if not a then
    return b
  end
  if not b then
    return a
  end
  local ka, kb = dateKey(a), dateKey(b)
  if ka < kb then
    return a
  end
  if ka > kb then
    return b
  end
  local c = compareCalendarFallback(a, b)
  if c == nil or c == 0 then
    return a
  end
  return c < 0 and a or b
end

--- Later of two valid calendar instants (max start among FAire rows).
local function laterCalendarTime(a, b)
  if not a then
    return b
  end
  if not b then
    return a
  end
  local ka, kb = dateKey(a), dateKey(b)
  if ka > kb then
    return a
  end
  if ka < kb then
    return b
  end
  local c = compareCalendarFallback(a, b)
  if c == nil or c == 0 then
    return a
  end
  return c > 0 and a or b
end

local function storedNextFaireFromCalendarTime(ct)
  if not ct or not calendarDateValid(ct) then
    return nil
  end
  return {
    year = ct.year,
    month = ct.month,
    monthDay = ct.monthDay,
    hour = type(ct.hour) == "number" and ct.hour or 0,
    minute = type(ct.minute) == "number" and ct.minute or 0,
  }
end

local function calendarTimeFromStoredNextFaire(t)
  if type(t) ~= "table" then
    return nil
  end
  local ct = {
    year = t.year,
    month = t.month,
    monthDay = t.monthDay,
    hour = type(t.hour) == "number" and t.hour or 0,
    minute = type(t.minute) == "number" and t.minute or 0,
  }
  if not calendarDateValid(ct) then
    return nil
  end
  return ct
end

--- Invalidate saved next-start once the realm calendar reaches that day (opening week has begun or passed).
local function shouldRollNextFaireCache(nowCt, cachedStartCt)
  if not calendarDateValid(nowCt) or not calendarDateValid(cachedStartCt) then
    return true
  end
  return dateKey(nowCt) >= dateKey(cachedStartCt)
end

--- Full calendar scan + extrapolation (expensive); prefer reading `DownToDarkmoonDB.nextFaireStart` via GetNextDarkmoonStartAfterNow.
local function computeNextDarkmoonStartAfterNow()
  if not C_Calendar or not C_Calendar.GetMonthInfo or not C_Calendar.GetHolidayInfo then
    return nil
  end
  --- Populate holiday data before scanning (needed on fresh login / empty cache).
  if C_Calendar.OpenCalendar then
    pcall(C_Calendar.OpenCalendar)
  end
  local now = C_DateAndTime.GetCurrentCalendarTime()
  if not calendarDateValid(now) then
    return nil
  end

  local bestCalendarFuture = nil
  --- Latest `startTime` among occurrences that have fully ended (`now` after `endTime`).
  local latestEndedStart = nil
  --- When the Faire is active, `startTime` of that holiday row (used instead of a second calendar pass).
  local activeWeekStart = nil
  for offset = 0, 8 do
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
          if holidayLooksLikeDarkmoon(info) and info.startTime and calendarDateValid(info.startTime) then
            local activeNow = Calendar:IsActiveFromHolidayInfo(now, info, monthInfo, day)
            local occurrenceOver = isHolidayOccurrenceEnded(now, info)
            if activeNow then
              if not activeWeekStart or laterCalendarTime(info.startTime, activeWeekStart) == info.startTime then
                activeWeekStart = info.startTime
              end
            end
            if occurrenceOver then
              if not latestEndedStart or laterCalendarTime(info.startTime, latestEndedStart) == info.startTime then
                latestEndedStart = info.startTime
              end
            end
            if not activeNow and not occurrenceOver and startStrictlyAfterNow(info.startTime, now) then
              if not bestCalendarFuture or earlierCalendarTime(info.startTime, bestCalendarFuture) == info.startTime then
                bestCalendarFuture = info.startTime
              end
            end
          end
        end
      end
    end
  end

  local anchorStart = activeWeekStart or latestEndedStart
  local fromScheduled = nextStartFromScheduledOffset(anchorStart, now)
  --- Prefer `GetHolidayInfo` starts. Extrapolation is anchor+28d and can hit arbitrary calendar days (e.g.
  --- May 3 + 28 = May 31) that are *earlier* than the real next Faire Sunday (June 7) — taking `earlier` of
  --- (calendar, extrap) wrongly preferred that bogus date over the API row.
  local candidate = bestCalendarFuture or fromScheduled
  local within = candidate and startWithinDaysAhead(candidate, now, NEXT_FAIRE_MAX_DAYS_AHEAD)
  if candidate and within then
    return candidate
  end
  addon:LogDebug(
    "calendar",
    "computeNext nil | bestCal=%s fromSched=%s cand=%s within35=%s",
    bestCalendarFuture and Calendar:FormatCalendarDate(bestCalendarFuture) or "nil",
    fromScheduled and Calendar:FormatCalendarDate(fromScheduled) or "nil",
    candidate and Calendar:FormatCalendarDate(candidate) or "nil",
    tostring(within)
  )
  return nil
end

--- Earliest next Faire **start** after `now`: uses saved `nextFaireStart` until the calendar date reaches that
--- start, then recomputes once and stores the new date (avoids scanning the calendar every UI refresh).
function Calendar:GetNextDarkmoonStartAfterNow()
  if not C_DateAndTime or not C_DateAndTime.GetCurrentCalendarTime then
    return nil
  end
  local now = C_DateAndTime.GetCurrentCalendarTime()
  if not calendarDateValid(now) then
    addon:LogDebug("calendar", "GetNextDarkmoonStartAfterNow: skipped (realm calendar time invalid).")
    return nil
  end

  local db = addon.GetDB and addon:GetDB()
  --- Use saved date only when present and valid; otherwise always compute (fetch) below.
  if type(db) == "table" and db.nextFaireStart ~= nil then
    local cachedCt = calendarTimeFromStoredNextFaire(db.nextFaireStart)
    if
      cachedCt
      and not shouldRollNextFaireCache(now, cachedCt)
      and startWithinDaysAhead(cachedCt, now, NEXT_FAIRE_MAX_DAYS_AHEAD)
    then
      addon:LogDebug(
        "calendar",
        "nextFaireStart: using cache %s (no DB write)",
        self:FormatCalendarDate(cachedCt) or "?"
      )
      return cachedCt
    end
    if cachedCt then
      addon:LogDebug(
        "calendar",
        "nextFaireStart: recomputing (cache not used). roll=%s within35=%s",
        tostring(shouldRollNextFaireCache(now, cachedCt)),
        tostring(startWithinDaysAhead(cachedCt, now, NEXT_FAIRE_MAX_DAYS_AHEAD))
      )
    else
      addon:LogDebug("calendar", "nextFaireStart: recomputing (stored value invalid or missing fields)")
    end
  end

  local computed = computeNextDarkmoonStartAfterNow()
  if type(db) == "table" then
    if computed then
      db.nextFaireStart = storedNextFaireFromCalendarTime(computed)
      addon:LogDebug(
        "calendar",
        "nextFaireStart: saved to DB | display=%s | y=%d m=%d d=%d h=%d min=%d",
        self:FormatCalendarDate(computed) or "?",
        computed.year,
        computed.month,
        computed.monthDay,
        computed.hour or 0,
        computed.minute or 0
      )
    else
      db.nextFaireStart = nil
      addon:LogDebug(
        "calendar",
        "nextFaireStart: cleared DB (compute returned nil — no candidate within %d days after now)",
        NEXT_FAIRE_MAX_DAYS_AHEAD
      )
    end
  end
  return computed
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

--- Dump every Darkmoon `GetHolidayInfo` row to chat for troubleshooting (`/dtdm caldebug`).
function Calendar:DumpDarkmoonCalendarDebug()
  if not C_Calendar or not C_Calendar.GetMonthInfo or not C_Calendar.GetHolidayInfo then
    print("|cffff5555[DTD calendar]|r C_Calendar API unavailable.")
    return
  end
  if C_Calendar.OpenCalendar then
    pcall(C_Calendar.OpenCalendar)
  end
  local now = C_DateAndTime.GetCurrentCalendarTime()
  if not calendarDateValid(now) then
    print("|cffff5555[DTD calendar]|r Realm calendar time invalid (try opening the calendar UI once).")
    return
  end

  print("|cff73d7ff[DTD calendar]|r ========== Darkmoon GetHolidayInfo scan ==========")
  print(("|cff73d7ff[DTD calendar]|r Now (realm): %s"):format(self:FormatCalendarDate(now) or "?"))

  local total = 0
  local futureLines = {}

  for offset = 0, 8 do
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
          if holidayLooksLikeDarkmoon(info) and info.startTime and calendarDateValid(info.startTime) then
            total = total + 1
            local activeNow = Calendar:IsActiveFromHolidayInfo(now, info, monthInfo, day)
            local occurrenceOver = isHolidayOccurrenceEnded(now, info)
            local futureStart = startStrictlyAfterNow(info.startTime, now)
            local wouldPick =
              not activeNow and not occurrenceOver and futureStart
            local startStr = self:FormatCalendarDate(info.startTime) or "?"
            local endStr = "(no end)"
            if info.endTime and calendarDateValid(info.endTime) then
              endStr = self:FormatCalendarDate(info.endTime) or "?"
            end
            local tex = type(info.texture) == "number" and info.texture or "?"

            local line = string.format(
              "off=%d %04d-%02d gridDay=%02d idx=%d | %s | start=%s end=%s | tex=%s | active=%s ended=%s futureStart=%s wouldPick=%s",
              offset,
              monthInfo.year,
              monthInfo.month,
              day,
              idx,
              info.name or "?",
              startStr,
              endStr,
              tostring(tex),
              activeNow and "Y" or "N",
              occurrenceOver and "Y" or "N",
              futureStart and "Y" or "N",
              wouldPick and "Y" or "N"
            )
            print("|cffaaaaaa[DTD]|r " .. line)

            if futureStart then
              futureLines[#futureLines + 1] = "|cff88ff88[future]|r " .. line
            end
          end
        end
      end
    end
  end

  print(("|cff73d7ff[DTD calendar]|r Total Darkmoon rows: %d"):format(total))

  if #futureLines > 0 then
    print("|cff73d7ff[DTD calendar]|r --- Starts strictly AFTER now ---")
    for _, l in ipairs(futureLines) do
      print(l)
    end
  else
    print("|cffff5555[DTD calendar]|r No rows with start strictly after now.")
  end

  local computed = computeNextDarkmoonStartAfterNow()
  local passesGate = computed and startWithinDaysAhead(computed, now, NEXT_FAIRE_MAX_DAYS_AHEAD)
  print(
    ("|cff73d7ff[DTD calendar]|r computeNext (fresh scan, ignores saved cache): %s"):format(
      computed and self:FormatCalendarDate(computed) or "nil"
    )
  )
  print(
    ("|cff73d7ff[DTD calendar]|r passes %d-day gate: %s"):format(
      NEXT_FAIRE_MAX_DAYS_AHEAD,
      computed and (passesGate and "yes" or "no") or "n/a"
    )
  )

  local db = addon.GetDB and addon:GetDB()
  if type(db) == "table" and db.nextFaireStart ~= nil then
    local stored = calendarTimeFromStoredNextFaire(db.nextFaireStart)
    print(
      ("|cff73d7ff[DTD calendar]|r Saved DownToDarkmoonDB.nextFaireStart: %s"):format(
        stored and self:FormatCalendarDate(stored) or "(invalid table)"
      )
    )
  else
    print("|cff73d7ff[DTD calendar]|r Saved DownToDarkmoonDB.nextFaireStart: (none)")
  end
end

--- Human-readable next Faire start, or nil if the calendar has no matching holiday yet.
function addon:GetNextDarkmoonFaireStartDateString()
  local ct = self.Calendar:GetNextDarkmoonStartAfterNow()
  return self.Calendar:FormatCalendarDate(ct)
end

--- Clears saved next-start and reloads from the calendar (minimap / slash “refresh” entry).
function addon:InvalidateNextFaireStartCache()
  local db = self:GetDB()
  if type(db) == "table" then
    db.nextFaireStart = nil
    self:LogDebug("calendar", "nextFaireStart: cleared DB (manual InvalidateNextFaireStartCache)")
  end
  if C_Calendar and C_Calendar.OpenCalendar then
    pcall(C_Calendar.OpenCalendar)
  end
  if self.Calendar and self.Calendar.ScheduleRefresh then
    self.Calendar:ScheduleRefresh(0.25)
  end
  if self.UI and self.UI.mainFrame and self.UI.mainFrame:IsShown() then
    self.UI:Refresh()
  end
  if self.Minimap and self.Minimap.RefreshTooltip then
    self.Minimap:RefreshTooltip()
  end
end

function addon:IsDarkmoonActive()
  return addon.Calendar.active == true
end
