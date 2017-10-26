#
#
#            Nim's Runtime Library
#        (c) Copyright 2015 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#


## This module contains routines and types for dealing with time.
## This module is available for the `JavaScript target
## <backends.html#the-javascript-target>`_. The proleptic Gregorian calendar is the only calendar supported.
##
## Examples:
##
## .. code-block:: nim
##
##  import times, os
##  let t = cpuTime()
##
##  sleep(100)   # replace this with something to be timed
##  echo "Time taken: ",cpuTime() - t
##
##  echo "My formatted time: ", format(now(), "d MMMM yyyy HH:mm")
##  echo "Using predefined formats: ", getClockStr(), " ", getDateStr()
##
##  echo "epochTime() float value: ", epochTime()
##  echo "getTime()   float value: ", toSeconds(getTime())
##  echo "cpuTime()   float value: ", cpuTime()
##  echo "An hour from now      : ", now() + 1.hours
##  echo "An hour from (UTC) now: ", getTime().inZone(Utc) + initInterval(0,0,0,1)

{.push debugger:off.} # the user does not want to trace a part
                      # of the standard library!

import
  strutils, parseutils

include "system/inclrtl"

when defined(JS):
  type
    TimeBase = float
    Time* = distinct TimeBase

elif defined(posix):
  when defined(linux) and defined(amd64):
    type
      TimeImpl {.importc: "time_t", header: "<time.h>".} = clong
      Time* = distinct TimeImpl ## Distinct type that represents a time
                                ## measured as number of seconds since the epoch.

      Timeval {.importc: "struct timeval",
                header: "<sys/select.h>".} = object ## struct timeval
        tv_sec: clong  ## Seconds.
        tv_usec: clong ## Microseconds.
  else:
    type
      TimeImpl {.importc: "time_t", header: "<time.h>".} = int
      Time* = distinct TimeImpl ## distinct type that represents a time
                                ## measured as number of seconds since the epoch

      Timeval {.importc: "struct timeval",
                header: "<sys/select.h>".} = object ## struct timeval
        tv_sec: int  ## Seconds.
        tv_usec: int ## Microseconds.

  # we cannot import posix.nim here, because posix.nim depends on times.nim.
  # Ok, we could, but I don't want circular dependencies.
  # And gettimeofday() is not defined in the posix module anyway. Sigh.

  proc posix_gettimeofday(tp: var Timeval, unused: pointer = nil) {.
    importc: "gettimeofday", header: "<sys/time.h>".}

  when not defined(freebsd) and not defined(netbsd) and not defined(openbsd):
    var timezone {.importc, header: "<time.h>".}: int
    proc tzset(): void {.importc, header: "<time.h>".}
    tzset()

elif defined(windows):
  import winlean

  # newest version of Visual C++ defines time_t to be of 64 bits
  type TimeImpl {.importc: "time_t", header: "<time.h>".} = int64
  # visual c's c runtime exposes these under a different name
  var
    timezone {.importc: "_timezone", header: "<time.h>".}: int

  type
    Time* = distinct TimeImpl

type
  Month* = enum ## Represents a month. Note that the enum starts at ``1``, so ``ord(month)`` will give
                ## the month number in the range ``[1..12]``.
    mJan = 1, mFeb, mMar, mApr, mMay, mJun, mJul, mAug, mSep, mOct, mNov, mDec

  WeekDay* = enum ## Represents a weekday.
    dMon, dTue, dWed, dThu, dFri, dSat, dSun

  MonthdayRange* = range[1..31]
  HourRange* = range[0..23]
  MinuteRange* = range[0..59]
  SecondRange* = range[0..60]
  YeardayRange* = range[0..365]

  TimeInfo* = object of RootObj ## Represents a time in different parts.
                                ## Although this type can represent leap
                                ## seconds, they are generally not supported
                                ## in this module. They are not ignored,
                                ## but the ``TimeInfo``'s returned by
                                ## procedures in this module will never have
                                ## a leap second.
    second*: SecondRange      ## The number of seconds after the minute,
                              ## normally in the range 0 to 59, but can
                              ## be up to 60 to allow for a leap second.
    minute*: MinuteRange      ## The number of minutes after the hour,
                              ## in the range 0 to 59.
    hour*: HourRange          ## The number of hours past midnight,
                              ## in the range 0 to 23.
    monthday*: MonthdayRange  ## The day of the month, in the range 1 to 31.
    month*: Month             ## The current month.
    year*: int                ## The current year, using astronomical year numbering
                              ## (meaning that before year 1 is year 0, then year -1 and so on).
    weekday*: WeekDay         ## The current day of the week.
    yearday*: YeardayRange    ## The number of days since January 1,
                              ## in the range 0 to 365.
    isDst*: bool              ## Determines whether DST is in effect.
                              ## Semantically, this adds another negative hour
                              ## offset to the time in addition to the timezone.
    timezone*: Timezone       # FIXME: add comment
    
    utcOffset*: int           ## The offset of the (non-DST) timezone in seconds
                              ## west of UTC. Note that the sign of this number
                              ## is the opposite of the one in a formatted
                              ## timezone string like ``+01:00`` (which would be
                              ## parsed into the timezone ``-3600``).

  TimeInterval* = object ## Represents a duration of time. Can be used to add and subtract
                         ## from a ``TimeInfo`` or ``Time``.
    milliseconds*: int ## The number of milliseconds
    seconds*: int     ## The number of seconds
    minutes*: int     ## The number of minutes
    hours*: int       ## The number of hours
    days*: int        ## The number of days
    months*: int      ## The number of months
    years*: int       ## The number of years

  Timezone* = object ## Timezone interface for supporting ``TimeInfo``'s of arbritary timezones.
                     ## The ``times`` module only supplies implementations for the systems local time and UTC.
    getZoned*: proc(self: Timezone, time: Time):
        TimeInfo {.nimcall, tags: [TimeEffect], raises: [], benign .}
      ## Convert a `Time` to a `TimeInfo` with correct `utcOffset` and `isDst`
    normalize*: proc(self: Timezone, ti: TimeInfo): TimeInfo {.nimcall, tags: [TimeEffect], raises: [], benign .}
      # FIXME: add better comment, improve name.
      # Assumes that ``ti`` is specified in this timezone, and returns a proper TimeInfo.
      # This includes setting the ``utcOffset`` and ``isDst`` (ignoring the old values),
      # but also other fields like weekday and yearday.
      # It also resolves ambigues dates, removes leap seconds etc...
    name*: string ## Name of the timezone. Used for checking equality.

{.deprecated: [TMonth: Month, TWeekDay: WeekDay, TTime: Time,
    TTimeInterval: TimeInterval, TTimeInfo: TimeInfo].}

const

  EuropeanWeekdayToUs: array[WeekDay, int8] = [1'i8,2'i8,3'i8,4'i8,5'i8,6'i8,0'i8]

  UsWeekdayToEuropean = [dSun, dMon, dTue, dWed, dThu, dFri, dSat]

  secondsInMin = 60
  secondsInHour = 60*60
  secondsInDay = 60*60*24
  minutesInHour = 60

# Forward declares
proc getZonedUtc(self: Timezone, time: Time): TimeInfo {.nimcall, tags: [TimeEffect], raises: [], benign .}
proc normalizeUtc(self: Timezone, ti: TimeInfo): TimeInfo {.nimcall, tags: [TimeEffect], raises: [], benign .}
proc getZonedLocal(self: Timezone, t: Time): TimeInfo {.nimcall, tags: [TimeEffect], raises: [], benign .}
proc normalizeLocal(self: Timezone, ti: TimeInfo): TimeInfo {.nimcall, tags: [TimeEffect], raises: [], benign .}
proc getDayOfYear*(monthday: MonthdayRange, month: Month, year: int): YeardayRange
proc toTime*(timeInfo: TimeInfo): Time {.tags: [TimeEffect], raises: [], benign.}
  ## Converts a broken-down time structure to
  ## calendar time representation. The function ignores the specified
  ## contents of the structure members `weekday` and `yearday` and recomputes
  ## them from the other information in the broken-down time structure.

proc `-`*(a, b: Time): int64 {.
  rtl, extern: "ntDiffTime", tags: [], raises: [], noSideEffect, benign.}
  ## Computes the difference of two calendar times. Result is in seconds.
  ##
  ## .. code-block:: nim
  ##     let a = fromSeconds(1_000_000_000)
  ##     let b = fromSeconds(1_500_000_000)
  ##     echo initInterval(seconds=int(b - a))
  ##     # (milliseconds: 0, seconds: 20, minutes: 53, hours: 0, days: 5787, months: 0, years: 0)

proc `<`*(a, b: Time): bool {.
  rtl, extern: "ntLtTime", tags: [], raises: [], noSideEffect.} =
  ## Returns true iff ``a < b``, that is iff a happened before b.
  when defined(js):
    result = TimeBase(a) < TimeBase(b)
  else:
    result = a - b < 0

proc `<=` * (a, b: Time): bool {.
  rtl, extern: "ntLeTime", tags: [], raises: [], noSideEffect.}=
  ## Returns true iff ``a <= b``.
  when defined(js):
    result = TimeBase(a) <= TimeBase(b)
  else:
    result = a - b <= 0

proc `==`*(a, b: Time): bool {.
  rtl, extern: "ntEqTime", tags: [], raises: [], noSideEffect.} =
  ## Returns true if ``a == b``, that is if both times represent the same point in time.
  when defined(js):
    result = TimeBase(a) == TimeBase(b)
  else:
    result = a - b == 0

proc inZone*(time: Time, zone: Timezone): TimeInfo {.tags: [TimeEffect], raises: [], benign.} =
  # FIXME: add comment
  result = zone.getZoned(zone, time)
  
proc inZone*(d: TimeInfo, zone: Timezone): TimeInfo  {.tags: [TimeEffect], raises: [], benign.} =
  # FIXME: add comment  
  if d.timezone != zone:
    result = d.toTime.inZone(zone)
  else:
    result = d

proc normalize(d: TimeInfo, zone: Timezone): TimeInfo =
  result = zone.normalize(zone, d)

proc `==`*(zone1, zone2: Timezone): bool =
  # FIXME: add comment
  zone1.name == zone2.name

proc `$`*(zone: Timezone): string =
  zone.name

when defined(JS):
    proc newDate(value: cstring): Time {.importc: "new Date".}
    proc getDay(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getFullYear(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getHours(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getMilliseconds(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getMinutes(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getMonth(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getSeconds(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getTime(t: Time): int {.tags: [], raises: [], noSideEffect, benign, importcpp.}
    proc getTimezoneOffset(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getDate(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getUTCDate(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getUTCFullYear(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getUTCHours(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getUTCMilliseconds(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getUTCMinutes(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getUTCMonth(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getUTCSeconds(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getUTCDay(t: Time): int {.tags: [], raises: [], benign, importcpp.}
    proc getYear(t: Time): int {.tags: [], raises: [], benign, importcpp.}

    proc getZonedUtc(t: Time): TimeInfo =
        result.second = t.getUTCSeconds()
        result.minute = t.getUTCMinutes()
        result.hour = t.getUTCHours()
        result.monthday = t.getUTCDate()
        result.month = Month(t.getUTCMonth() + 1)
        result.year = t.getUTCFullYear()
        result.weekday = UsWeekdayToEuropean[t.getUTCDay()]
        result.yearday = getDayOfYear(result.monthday, result.month, result.year)

    proc getZonedLocal(t: Time): TimeInfo =
        result.second = t.getSeconds()
        result.minute = t.getMinutes()
        result.hour = t.getHours()
        result.monthday = t.getDate()
        result.month = Month(t.getMonth() + 1)
        result.year = t.getFullYear()
        result.weekday = UsWeekdayToEuropean[t.getDay()]
        result.timezone = t.getTimezoneOffset() # Wrong - includes dst
        result.yearday = getDayOfYear(result.monthday, result.month, result.year)
    
    proc normalizeLocal(ti: TimeInfo): TimeInfo =
        newDate(ti.format("yyyy-MM-ddTHH:mm:ss")).inZone(Local)

else:
  when defined(freebsd) or defined(netbsd) or defined(openbsd) or
      defined(macosx):
    type
      StructTM {.importc: "struct tm".} = object
        second {.importc: "tm_sec".},
          minute {.importc: "tm_min".},
          hour {.importc: "tm_hour".},
          monthday {.importc: "tm_mday".},
          month {.importc: "tm_mon".},
          year {.importc: "tm_year".},
          weekday {.importc: "tm_wday".},
          yearday {.importc: "tm_yday".},
          isdst {.importc: "tm_isdst".}: cint
        gmtoff {.importc: "tm_gmtoff".}: clong
  else:
    type
      StructTM {.importc: "struct tm".} = object
        second {.importc: "tm_sec".},
          minute {.importc: "tm_min".},
          hour {.importc: "tm_hour".},
          monthday {.importc: "tm_mday".},
          month {.importc: "tm_mon".},
          year {.importc: "tm_year".},
          weekday {.importc: "tm_wday".},
          yearday {.importc: "tm_yday".},
          isdst {.importc: "tm_isdst".}: cint
        when defined(linux) and defined(amd64):
          gmtoff {.importc: "tm_gmtoff".}: clong
          zone {.importc: "tm_zone".}: cstring
  type
    TimeInfoPtr = ptr StructTM

  proc gmtime(timer: ptr Time): TimeInfoPtr {.importc: "gmtime", header: "<time.h>", tags: [].}
  proc localtime(timer: ptr Time): TimeInfoPtr {. importc: "localtime", header: "<time.h>", tags: [].}
  proc mktime(t: StructTM): Time {. importc: "mktime", header: "<time.h>", tags: [].}

  proc tmToTimeInfo(tm: StructTM): TimeInfo =
    TimeInfo(
      second: int(tm.second),
      minute:int(tm.minute),
      hour: int(tm.hour),
      monthday: int(tm.monthday),
      month: Month(tm.month + 1),
      year: tm.year + 1900'i32,
      weekday: UsWeekdayToEuropean[int(tm.weekday)],
      yearday: int(tm.yearday)
    )

  proc timeInfoToTM(t: TimeInfo): StructTM =
    result.second = t.second
    result.minute = t.minute
    result.hour = t.hour
    result.monthday = t.monthday
    result.month = ord(t.month) - 1
    result.year = cint(t.year - 1900)
    result.weekday = EuropeanWeekdayToUs[t.weekday]
    result.yearday = t.yearday
    # `-1` for `isdst` means that it's unknown,
    # which means that `mktime` will fill in the
    # value for us, without modifying the time.
    result.isdst = -1

  proc getZonedUtc(self: Timezone, time: Time): TimeInfo =
    var a = time
    let lt = gmtime(addr(a))
    assert(not lt.isNil)
    result = tmToTimeInfo(lt[])
    result.timezone = self

  proc getZonedLocal(self: Timezone, t: Time): TimeInfo =
    var a = t
    let lt = localtime(addr(a))
    assert(not lt.isNil)
    result = tmToTimeInfo(lt[])
    # Since timezone is not set for `result` yet, we can
    # calculate the utc offset by comparing `result.toTime` with
    # the original timestamp.
    result.utcOffset = (t - result.toTime).int
    result.isDst = lt.isdst > 0
    result.timezone = self

  proc normalizeLocal(self: Timezone, ti: TimeInfo): TimeInfo =
    let localTimestamp = mktime(timeInfoToTM(ti))
    return localTimestamp.inZone(self)

proc normalizeUtc(self: Timezone, ti: TimeInfo): TimeInfo =
  var tiUtc = ti
  tiUtc.utcOffset = 0
  tiUtc.isDst = false
  return ti.toTime.inZone(self)

let Utc* = Timezone(getZoned: getZonedUtc, normalize: normalizeUtc, name: "UTC") ## Represents the UTC timezone.

let Local* = Timezone(getZoned: getZonedLocal, normalize: normalizeLocal, name: "LOCAL") ## Represents the systems local timezone.

proc getTime*(): Time {.tags: [TimeEffect], benign.}
  ## Gets the current calendar time as a UNIX epoch value (number of seconds
  ## elapsed since 1970) with integer precission. Use epochTime for higher
  ## resolution.

proc now*(): TimeInfo {.tags: [TimeEffect], benign.} =
  ## Get the current time as a  ``TimeInfo`` in the local timezone.
  ##
  ## Shorthand for ``getTime().inZone(Local)``.
  getTime().inZone(Local)

proc fromSeconds*(since1970: float): Time {.tags: [], raises: [], benign.}
  ## Takes a float which contains the number of seconds since the unix epoch and
  ## returns a time object.

proc fromSeconds*(since1970: int64): Time {.tags: [], raises: [], benign.} =
  ## Takes an int which contains the number of seconds since the unix epoch and
  ## returns a time object.
  fromSeconds(float(since1970))

proc toSeconds*(time: Time): float {.tags: [], raises: [], benign.}
  ## Returns the time in seconds since the unix epoch.

proc initInterval*(milliseconds, seconds, minutes, hours, days, months,
                   years: int = 0): TimeInterval =
  ## Creates a new ``TimeInterval``.
  ##
  ## You can also use the convenience procedures called ``milliseconds``,
  ## ``seconds``, ``minutes``, ``hours``, ``days``, ``months``, and ``years``.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##     let day = initInterval(hours=24)
  ##     let tomorrow = getTime() + day
  ##     echo(tomorrow)
  var carryO = 0
  result.milliseconds = `mod`(milliseconds, 1000)
  carryO = `div`(milliseconds, 1000)
  result.seconds = `mod`(carryO + seconds, 60)
  carryO = `div`(carryO + seconds, 60)
  result.minutes = `mod`(carryO + minutes, 60)
  carryO = `div`(carryO + minutes, 60)
  result.hours = `mod`(carryO + hours, 24)
  carryO = `div`(carryO + hours, 24)
  result.days = carryO + days

  result.months = `mod`(months, 12)
  carryO = `div`(months, 12)
  result.years = carryO + years

proc `+`*(ti1, ti2: TimeInterval): TimeInterval =
  ## Adds two ``TimeInterval`` objects together.
  var carryO = 0
  result.milliseconds = `mod`(ti1.milliseconds + ti2.milliseconds, 1000)
  carryO = `div`(ti1.milliseconds + ti2.milliseconds, 1000)
  result.seconds = `mod`(carryO + ti1.seconds + ti2.seconds, 60)
  carryO = `div`(carryO + ti1.seconds + ti2.seconds, 60)
  result.minutes = `mod`(carryO + ti1.minutes + ti2.minutes, 60)
  carryO = `div`(carryO + ti1.minutes + ti2.minutes, 60)
  result.hours = `mod`(carryO + ti1.hours + ti2.hours, 24)
  carryO = `div`(carryO + ti1.hours + ti2.hours, 24)
  result.days = carryO + ti1.days + ti2.days

  result.months = `mod`(ti1.months + ti2.months, 12)
  carryO = `div`(ti1.months + ti2.months, 12)
  result.years = carryO + ti1.years + ti2.years

proc `-`*(ti: TimeInterval): TimeInterval =
  ## Reverses a time interval
  ##
  ## .. code-block:: nim
  ##
  ##     let day = -initInterval(hours=24)
  ##     echo day  # -> (milliseconds: 0, seconds: 0, minutes: 0, hours: 0, days: -1, months: 0, years: 0)
  result = TimeInterval(
    milliseconds: -ti.milliseconds,
    seconds: -ti.seconds,
    minutes: -ti.minutes,
    hours: -ti.hours,
    days: -ti.days,
    months: -ti.months,
    years: -ti.years
  )

proc `-`*(ti1, ti2: TimeInterval): TimeInterval =
  ## Subtracts TimeInterval ``ti1`` from ``ti2``.
  ##
  ## Time components are compared one-by-one, see output:
  ##
  ## .. code-block:: nim
  ##     let a = fromSeconds(1_000_000_000)
  ##     let b = fromSeconds(1_500_000_000)
  ##     echo b.toTimeInterval - a.toTimeInterval
  ##     # (milliseconds: 0, seconds: -40, minutes: -6, hours: 1, days: -2, months: -2, years: 16)
  result = ti1 + (-ti2)

proc isLeapYear*(year: int): bool =
  ## Returns true if ``year`` is a leap year.

  if year mod 400 == 0:
    return true
  elif year mod 100 == 0:
    return false
  elif year mod 4 == 0:
    return true
  else:
    return false

proc getDaysInMonth*(month: Month, year: int): int =
  ## Get the number of days in a ``month`` of a ``year``.

  # http://www.dispersiondesign.com/articles/time/number_of_days_in_a_month
  case month
  of mFeb: result = if isLeapYear(year): 29 else: 28
  of mApr, mJun, mSep, mNov: result = 30
  else: result = 31

proc getDaysInYear*(year: int): int =
  ## Get the number of days in a ``year``
  result = 365 + (if isLeapYear(year): 1 else: 0)

proc toSeconds(a: TimeInfo, interval: TimeInterval): float =
  ## Calculates how many seconds the interval is worth by adding up
  ## all the fields.

  var anew = a
  var newinterv = interval
  result = 0

  newinterv.months += interval.years * 12
  var curMonth = anew.month
  if newinterv.months < 0:   # subtracting
    for mth in countDown(-1 * newinterv.months, 1):
      result -= float(getDaysInMonth(curMonth, anew.year) * 24 * 60 * 60)
      if curMonth == mJan:
        curMonth = mDec
        anew.year.dec()
      else:
        curMonth.dec()
  else:  # adding
    for mth in 1 .. newinterv.months:
      result += float(getDaysInMonth(curMonth, anew.year) * 24 * 60 * 60)
      if curMonth == mDec:
        curMonth = mJan
        anew.year.inc()
      else:
        curMonth.inc()
  result += float(newinterv.days * 24 * 60 * 60)
  result += float(newinterv.hours * 60 * 60)
  result += float(newinterv.minutes * 60)
  result += float(newinterv.seconds)
  result += newinterv.milliseconds / 1000

proc `+`*(a: TimeInfo, interval: TimeInterval): TimeInfo =
  ## Adds ``interval`` time from TimeInfo ``a``. Components from ``interval`` are added
  ## in the order of their size, i.e first the ``years`` component, then the ``months``
  ## component and so on. The returned ``TimeInfo`` will have the same timezone as the input.
  let t = toSeconds(toTime(a))
  let secs = toSeconds(a, interval)
  return fromSeconds(t + secs).inZone(a.timezone)

proc `-`*(a: TimeInfo, interval: TimeInterval): TimeInfo =
  ## Subtract ``interval`` time from TimeInfo ``a``. Components from ``interval`` are subtracted
  ## in the order of their size, i.e first the ``years`` component, then the ``months``
  ## component and so on. The returned ``TimeInfo`` will have the same timezone as the input.
  a + (-interval)

proc getDateStr*(): string {.rtl, extern: "nt$1", tags: [TimeEffect].} =
  ## Gets the current date as a string of the format ``YYYY-MM-DD``.
  var ti = now()
  result = $ti.year & '-' & intToStr(ord(ti.month), 2) &
    '-' & intToStr(ti.monthday, 2)

proc getClockStr*(): string {.rtl, extern: "nt$1", tags: [TimeEffect].} =
  ## Gets the current clock time as a string of the format ``HH:MM:SS``.
  var ti = now()
  result = intToStr(ti.hour, 2) & ':' & intToStr(ti.minute, 2) &
    ':' & intToStr(ti.second, 2)

proc `$`*(day: WeekDay): string =
  ## Stringify operator for ``WeekDay``.
  const lookup: array[WeekDay, string] = ["Monday", "Tuesday", "Wednesday",
     "Thursday", "Friday", "Saturday", "Sunday"]
  return lookup[day]

proc `$`*(m: Month): string =
  ## Stringify operator for ``Month``.
  const lookup: array[Month, string] = ["January", "February", "March",
      "April", "May", "June", "July", "August", "September", "October",
      "November", "December"]
  return lookup[m]

proc milliseconds*(ms: int): TimeInterval {.inline.} =
  ## TimeInterval of `ms` milliseconds
  ##
  ## Note: not all time procedures have millisecond resolution
  initInterval(`mod`(ms,1000), `div`(ms,1000))

proc seconds*(s: int): TimeInterval {.inline.} =
  ## TimeInterval of `s` seconds
  ##
  ## ``echo getTime() + 5.second``
  initInterval(0,`mod`(s,60), `div`(s,60))

proc minutes*(m: int): TimeInterval {.inline.} =
  ## TimeInterval of `m` minutes
  ##
  ## ``echo getTime() + 5.minutes``
  initInterval(0,0,`mod`(m,60), `div`(m,60))

proc hours*(h: int): TimeInterval {.inline.} =
  ## TimeInterval of `h` hours
  ##
  ## ``echo getTime() + 2.hours``
  initInterval(0,0,0,`mod`(h,24),`div`(h,24))

proc days*(d: int): TimeInterval {.inline.} =
  ## TimeInterval of `d` days
  ##
  ## ``echo getTime() + 2.days``
  initInterval(0,0,0,0,d)

proc months*(m: int): TimeInterval {.inline.} =
  ## TimeInterval of `m` months
  ##
  ## ``echo getTime() + 2.months``
  initInterval(0,0,0,0,0,`mod`(m,12),`div`(m,12))

proc years*(y: int): TimeInterval {.inline.} =
  ## TimeInterval of `y` years
  ##
  ## ``echo getTime() + 2.years``
  initInterval(0,0,0,0,0,0,y)

proc `+=`*(t: var Time, ti: TimeInterval) =
  ## Modifies `t` by adding the interval `ti`.
  t = toTime(t.inZone(Local) + ti)

proc `+`*(t: Time, ti: TimeInterval): Time =
  ## Adds the interval `ti` to Time `t`
  ## by converting to a ``TimeInfo`` in the local timezone,
  ## adding the interval, and converting back to ``Time``.
  ##
  ## ``echo getTime() + 1.day``
  result = toTime(t.inZone(Local) + ti)

proc `-=`*(t: var Time, ti: TimeInterval) =
  ## Modifies `t` by subtracting the interval `ti`.
  t = toTime(t.inZone(Local) - ti)

proc `-`*(t: Time, ti: TimeInterval): Time =
  ## Subtracts the interval `ti` from Time `t`.
  ##
  ## ``echo getTime() - 1.day``
  result = toTime(t.inZone(Local) - ti)

proc formatToken(info: TimeInfo, token: string, buf: var string) =
  ## Helper of the format proc to parse individual tokens.
  ##
  ## Pass the found token in the user input string, and the buffer where the
  ## final string is being built. This has to be a var value because certain
  ## formatting tokens require modifying the previous characters.
  case token
  of "d":
    buf.add($info.monthday)
  of "dd":
    if info.monthday < 10:
      buf.add("0")
    buf.add($info.monthday)
  of "ddd":
    buf.add(($info.weekday)[0 .. 2])
  of "dddd":
    buf.add($info.weekday)
  of "h":
    buf.add($(if info.hour > 12: info.hour - 12 else: info.hour))
  of "hh":
    let amerHour = if info.hour > 12: info.hour - 12 else: info.hour
    if amerHour < 10:
      buf.add('0')
    buf.add($amerHour)
  of "H":
    buf.add($info.hour)
  of "HH":
    if info.hour < 10:
      buf.add('0')
    buf.add($info.hour)
  of "m":
    buf.add($info.minute)
  of "mm":
    if info.minute < 10:
      buf.add('0')
    buf.add($info.minute)
  of "M":
    buf.add($ord(info.month))
  of "MM":
    if info.month < mOct:
      buf.add('0')
    buf.add($ord(info.month))
  of "MMM":
    buf.add(($info.month)[0..2])
  of "MMMM":
    buf.add($info.month)
  of "s":
    buf.add($info.second)
  of "ss":
    if info.second < 10:
      buf.add('0')
    buf.add($info.second)
  of "t":
    if info.hour >= 12:
      buf.add('P')
    else: buf.add('A')
  of "tt":
    if info.hour >= 12:
      buf.add("PM")
    else: buf.add("AM")
  of "y":
    var fr = ($info.year).len()-1
    if fr < 0: fr = 0
    buf.add(($info.year)[fr .. ($info.year).len()-1])
  of "yy":
    var fr = ($info.year).len()-2
    if fr < 0: fr = 0
    var fyear = ($info.year)[fr .. ($info.year).len()-1]
    if fyear.len != 2: fyear = repeat('0', 2-fyear.len()) & fyear
    buf.add(fyear)
  of "yyy":
    var fr = ($info.year).len()-3
    if fr < 0: fr = 0
    var fyear = ($info.year)[fr .. ($info.year).len()-1]
    if fyear.len != 3: fyear = repeat('0', 3-fyear.len()) & fyear
    buf.add(fyear)
  of "yyyy":
    var fr = ($info.year).len()-4
    if fr < 0: fr = 0
    var fyear = ($info.year)[fr .. ($info.year).len()-1]
    if fyear.len != 4: fyear = repeat('0', 4-fyear.len()) & fyear
    buf.add(fyear)
  of "yyyyy":
    var fr = ($info.year).len()-5
    if fr < 0: fr = 0
    var fyear = ($info.year)[fr .. ($info.year).len()-1]
    if fyear.len != 5: fyear = repeat('0', 5-fyear.len()) & fyear
    buf.add(fyear)
  of "z":
    let
      nonDstTz = info.utcOffset
      hours = abs(nonDstTz) div secondsInHour
    if nonDstTz <= 0: buf.add('+')
    else: buf.add('-')
    buf.add($hours)
  of "zz":
    let
      nonDstTz = info.utcOffset
      hours = abs(nonDstTz) div secondsInHour
    if nonDstTz <= 0: buf.add('+')
    else: buf.add('-')
    if hours < 10: buf.add('0')
    buf.add($hours)
  of "zzz":
    let
      nonDstTz = info.utcOffset
      hours = abs(nonDstTz) div secondsInHour
      minutes = (abs(nonDstTz) div secondsInMin) mod minutesInHour
    if nonDstTz <= 0: buf.add('+')
    else: buf.add('-')
    if hours < 10: buf.add('0')
    buf.add($hours)
    buf.add(':')
    if minutes < 10: buf.add('0')
    buf.add($minutes)
  of "":
    discard
  else:
    raise newException(ValueError, "Invalid format string: " & token)


proc format*(info: TimeInfo, f: string): string =
  ## This procedure formats `info` as specified by `f`. The following format
  ## specifiers are available:
  ##
  ## ==========  =================================================================================  ================================================
  ## Specifier   Description                                                                        Example
  ## ==========  =================================================================================  ================================================
  ##    d        Numeric value of the day of the month, it will be one or two digits long.          ``1/04/2012 -> 1``, ``21/04/2012 -> 21``
  ##    dd       Same as above, but always two digits.                                              ``1/04/2012 -> 01``, ``21/04/2012 -> 21``
  ##    ddd      Three letter string which indicates the day of the week.                           ``Saturday -> Sat``, ``Monday -> Mon``
  ##    dddd     Full string for the day of the week.                                               ``Saturday -> Saturday``, ``Monday -> Monday``
  ##    h        The hours in one digit if possible. Ranging from 0-12.                             ``5pm -> 5``, ``2am -> 2``
  ##    hh       The hours in two digits always. If the hour is one digit 0 is prepended.           ``5pm -> 05``, ``11am -> 11``
  ##    H        The hours in one digit if possible, randing from 0-24.                             ``5pm -> 17``, ``2am -> 2``
  ##    HH       The hours in two digits always. 0 is prepended if the hour is one digit.           ``5pm -> 17``, ``2am -> 02``
  ##    m        The minutes in 1 digit if possible.                                                ``5:30 -> 30``, ``2:01 -> 1``
  ##    mm       Same as above but always 2 digits, 0 is prepended if the minute is one digit.      ``5:30 -> 30``, ``2:01 -> 01``
  ##    M        The month in one digit if possible.                                                ``September -> 9``, ``December -> 12``
  ##    MM       The month in two digits always. 0 is prepended.                                    ``September -> 09``, ``December -> 12``
  ##    MMM      Abbreviated three-letter form of the month.                                        ``September -> Sep``, ``December -> Dec``
  ##    MMMM     Full month string, properly capitalized.                                           ``September -> September``
  ##    s        Seconds as one digit if possible.                                                  ``00:00:06 -> 6``
  ##    ss       Same as above but always two digits. 0 is prepended.                               ``00:00:06 -> 06``
  ##    t        ``A`` when time is in the AM. ``P`` when time is in the PM.
  ##    tt       Same as above, but ``AM`` and ``PM`` instead of ``A`` and ``P`` respectively.
  ##    y(yyyy)  This displays the year to different digits. You most likely only want 2 or 4 'y's
  ##    yy       Displays the year to two digits.                                                   ``2012 -> 12``
  ##    yyyy     Displays the year to four digits.                                                  ``2012 -> 2012``
  ##    z        Displays the timezone offset from UTC.                                             ``GMT+7 -> +7``, ``GMT-5 -> -5``
  ##    zz       Same as above but with leading 0.                                                  ``GMT+7 -> +07``, ``GMT-5 -> -05``
  ##    zzz      Same as above but with ``:mm`` where *mm* represents minutes.                      ``GMT+7 -> +07:00``, ``GMT-5 -> -05:00``
  ## ==========  =================================================================================  ================================================
  ##
  ## Other strings can be inserted by putting them in ``''``. For example
  ## ``hh'->'mm`` will give ``01->56``.  The following characters can be
  ## inserted without quoting them: ``:`` ``-`` ``(`` ``)`` ``/`` ``[`` ``]``
  ## ``,``. However you don't need to necessarily separate format specifiers, a
  ## unambiguous format string like ``yyyyMMddhhmmss`` is valid too.

  result = ""
  var i = 0
  var currentF = ""
  while true:
    case f[i]
    of ' ', '-', '/', ':', '\'', '\0', '(', ')', '[', ']', ',':
      formatToken(info, currentF, result)

      currentF = ""
      if f[i] == '\0': break

      if f[i] == '\'':
        inc(i) # Skip '
        while f[i] != '\'' and f.len-1 > i:
          result.add(f[i])
          inc(i)
      else: result.add(f[i])

    else:
      # Check if the letter being added matches previous accumulated buffer.
      if currentF.len < 1 or currentF[high(currentF)] == f[i]:
        currentF.add(f[i])
      else:
        formatToken(info, currentF, result)
        dec(i) # Move position back to re-process the character separately.
        currentF = ""

    inc(i)

proc `$`*(timeInfo: TimeInfo): string {.tags: [], raises: [], benign.} =
  ## Converts a `TimeInfo` object to a string representation.
  ## It uses the format ``yyyy-MM-dd'T'HH-mm-sszzz``.
  try:
    result = format(timeInfo, "yyyy-MM-dd'T'HH:mm:sszzz") # todo: optimize this
  except ValueError: assert false # cannot happen because format string is valid

proc `$`*(time: Time): string {.tags: [TimeEffect], raises: [], benign.} =
  ## converts a `Time` value to a string representation. It will use the local
  ## time zone and use the format ``yyyy-MM-dd'T'HH-mm-sszzz``.
  $time.inZone(Local)

{.pop.}

proc parseToken(info: var TimeInfo; token, value: string; j: var int) =
  ## Helper of the parse proc to parse individual tokens.
  var sv: int
  case token
  of "d":
    var pd = parseInt(value[j..j+1], sv)
    info.monthday = sv
    j += pd
  of "dd":
    info.monthday = value[j..j+1].parseInt()
    j += 2
  of "ddd":
    case value[j..j+2].toLowerAscii()
    of "sun": info.weekday = dSun
    of "mon": info.weekday = dMon
    of "tue": info.weekday = dTue
    of "wed": info.weekday = dWed
    of "thu": info.weekday = dThu
    of "fri": info.weekday = dFri
    of "sat": info.weekday = dSat
    else:
      raise newException(ValueError,
        "Couldn't parse day of week (ddd), got: " & value[j..j+2])
    j += 3
  of "dddd":
    if value.len >= j+6 and value[j..j+5].cmpIgnoreCase("sunday") == 0:
      info.weekday = dSun
      j += 6
    elif value.len >= j+6 and value[j..j+5].cmpIgnoreCase("monday") == 0:
      info.weekday = dMon
      j += 6
    elif value.len >= j+7 and value[j..j+6].cmpIgnoreCase("tuesday") == 0:
      info.weekday = dTue
      j += 7
    elif value.len >= j+9 and value[j..j+8].cmpIgnoreCase("wednesday") == 0:
      info.weekday = dWed
      j += 9
    elif value.len >= j+8 and value[j..j+7].cmpIgnoreCase("thursday") == 0:
      info.weekday = dThu
      j += 8
    elif value.len >= j+6 and value[j..j+5].cmpIgnoreCase("friday") == 0:
      info.weekday = dFri
      j += 6
    elif value.len >= j+8 and value[j..j+7].cmpIgnoreCase("saturday") == 0:
      info.weekday = dSat
      j += 8
    else:
      raise newException(ValueError,
        "Couldn't parse day of week (dddd), got: " & value)
  of "h", "H":
    var pd = parseInt(value[j..j+1], sv)
    info.hour = sv
    j += pd
  of "hh", "HH":
    info.hour = value[j..j+1].parseInt()
    j += 2
  of "m":
    var pd = parseInt(value[j..j+1], sv)
    info.minute = sv
    j += pd
  of "mm":
    info.minute = value[j..j+1].parseInt()
    j += 2
  of "M":
    var pd = parseInt(value[j..j+1], sv)
    info.month = sv.Month
    j += pd
  of "MM":
    var month = value[j..j+1].parseInt()
    j += 2
    info.month = month.Month
  of "MMM":
    case value[j..j+2].toLowerAscii():
    of "jan": info.month =  mJan
    of "feb": info.month =  mFeb
    of "mar": info.month =  mMar
    of "apr": info.month =  mApr
    of "may": info.month =  mMay
    of "jun": info.month =  mJun
    of "jul": info.month =  mJul
    of "aug": info.month =  mAug
    of "sep": info.month =  mSep
    of "oct": info.month =  mOct
    of "nov": info.month =  mNov
    of "dec": info.month =  mDec
    else:
      raise newException(ValueError,
        "Couldn't parse month (MMM), got: " & value)
    j += 3
  of "MMMM":
    if value.len >= j+7 and value[j..j+6].cmpIgnoreCase("january") == 0:
      info.month =  mJan
      j += 7
    elif value.len >= j+8 and value[j..j+7].cmpIgnoreCase("february") == 0:
      info.month =  mFeb
      j += 8
    elif value.len >= j+5 and value[j..j+4].cmpIgnoreCase("march") == 0:
      info.month =  mMar
      j += 5
    elif value.len >= j+5 and value[j..j+4].cmpIgnoreCase("april") == 0:
      info.month =  mApr
      j += 5
    elif value.len >= j+3 and value[j..j+2].cmpIgnoreCase("may") == 0:
      info.month =  mMay
      j += 3
    elif value.len >= j+4 and value[j..j+3].cmpIgnoreCase("june") == 0:
      info.month =  mJun
      j += 4
    elif value.len >= j+4 and value[j..j+3].cmpIgnoreCase("july") == 0:
      info.month =  mJul
      j += 4
    elif value.len >= j+6 and value[j..j+5].cmpIgnoreCase("august") == 0:
      info.month =  mAug
      j += 6
    elif value.len >= j+9 and value[j..j+8].cmpIgnoreCase("september") == 0:
      info.month =  mSep
      j += 9
    elif value.len >= j+7 and value[j..j+6].cmpIgnoreCase("october") == 0:
      info.month =  mOct
      j += 7
    elif value.len >= j+8 and value[j..j+7].cmpIgnoreCase("november") == 0:
      info.month =  mNov
      j += 8
    elif value.len >= j+8 and value[j..j+7].cmpIgnoreCase("december") == 0:
      info.month =  mDec
      j += 8
    else:
      raise newException(ValueError,
        "Couldn't parse month (MMMM), got: " & value)
  of "s":
    var pd = parseInt(value[j..j+1], sv)
    info.second = sv
    j += pd
  of "ss":
    info.second = value[j..j+1].parseInt()
    j += 2
  of "t":
    if value[j] == 'P' and info.hour > 0 and info.hour < 12:
      info.hour += 12
    j += 1
  of "tt":
    if value[j..j+1] == "PM" and info.hour > 0 and info.hour < 12:
      info.hour += 12
    j += 2
  of "yy":
    # Assumes current century
    var year = value[j..j+1].parseInt()
    var thisCen = now().year div 100
    info.year = thisCen*100 + year
    j += 2
  of "yyyy":
    info.year = value[j..j+3].parseInt()
    j += 4
  of "z":
    info.isDst = false
    if value[j] == '+':
      info.utcOffset = 0 - parseInt($value[j+1]) * secondsInHour
    elif value[j] == '-':
      info.utcOffset = parseInt($value[j+1]) * secondsInHour
    elif value[j] == 'Z':
      info.utcOffset = 0
      j += 1
      return
    else:
      raise newException(ValueError,
        "Couldn't parse timezone offset (z), got: " & value[j])
    j += 2
  of "zz":
    info.isDst = false
    if value[j] == '+':
      info.utcOffset = 0 - value[j+1..j+2].parseInt() * secondsInHour
    elif value[j] == '-':
      info.utcOffset = value[j+1..j+2].parseInt() * secondsInHour
    elif value[j] == 'Z':
      info.utcOffset = 0
      j += 1
      return
    else:
      raise newException(ValueError,
        "Couldn't parse timezone offset (zz), got: " & value[j])
    j += 3
  of "zzz":
    info.isDst = false
    var factor = 0
    if value[j] == '+': factor = -1
    elif value[j] == '-': factor = 1
    elif value[j] == 'Z':
      info.utcOffset = 0
      j += 1
      return
    else:
      raise newException(ValueError,
        "Couldn't parse timezone offset (zzz), got: " & value[j])
    info.utcOffset = factor * value[j+1..j+2].parseInt() * secondsInHour
    j += 4
    info.utcOffset += factor * value[j..j+1].parseInt() * 60
    j += 2
  else:
    # Ignore the token and move forward in the value string by the same length
    j += token.len

proc parse*(value, layout: string, zone: Timezone = Local): TimeInfo =
  ## This procedure parses a date/time string using the standard format
  ## identifiers as listed below. The procedure defaults information not provided
  ## in the format string from the running program (month, year, etc).
  ##
  ## The return value will always be in the `zone` timezone. If no UTC offset was
  ## parsed, then the input will be assumed to be specified in the `zone` timezone
  ## already, so no timezone conversion will be done in that case.
  ##
  ## ==========  =================================================================================  ================================================
  ## Specifier   Description                                                                        Example
  ## ==========  =================================================================================  ================================================
  ##    d        Numeric value of the day of the month, it will be one or two digits long.          ``1/04/2012 -> 1``, ``21/04/2012 -> 21``
  ##    dd       Same as above, but always two digits.                                              ``1/04/2012 -> 01``, ``21/04/2012 -> 21``
  ##    ddd      Three letter string which indicates the day of the week.                           ``Saturday -> Sat``, ``Monday -> Mon``
  ##    dddd     Full string for the day of the week.                                               ``Saturday -> Saturday``, ``Monday -> Monday``
  ##    h        The hours in one digit if possible. Ranging from 0-12.                             ``5pm -> 5``, ``2am -> 2``
  ##    hh       The hours in two digits always. If the hour is one digit 0 is prepended.           ``5pm -> 05``, ``11am -> 11``
  ##    H        The hours in one digit if possible, randing from 0-24.                             ``5pm -> 17``, ``2am -> 2``
  ##    HH       The hours in two digits always. 0 is prepended if the hour is one digit.           ``5pm -> 17``, ``2am -> 02``
  ##    m        The minutes in 1 digit if possible.                                                ``5:30 -> 30``, ``2:01 -> 1``
  ##    mm       Same as above but always 2 digits, 0 is prepended if the minute is one digit.      ``5:30 -> 30``, ``2:01 -> 01``
  ##    M        The month in one digit if possible.                                                ``September -> 9``, ``December -> 12``
  ##    MM       The month in two digits always. 0 is prepended.                                    ``September -> 09``, ``December -> 12``
  ##    MMM      Abbreviated three-letter form of the month.                                        ``September -> Sep``, ``December -> Dec``
  ##    MMMM     Full month string, properly capitalized.                                           ``September -> September``
  ##    s        Seconds as one digit if possible.                                                  ``00:00:06 -> 6``
  ##    ss       Same as above but always two digits. 0 is prepended.                               ``00:00:06 -> 06``
  ##    t        ``A`` when time is in the AM. ``P`` when time is in the PM.
  ##    tt       Same as above, but ``AM`` and ``PM`` instead of ``A`` and ``P`` respectively.
  ##    yy       Displays the year to two digits.                                                   ``2012 -> 12``
  ##    yyyy     Displays the year to four digits.                                                  ``2012 -> 2012``
  ##    z        Displays the timezone offset from UTC. ``Z`` is parsed as ``+0``                   ``GMT+7 -> +7``, ``GMT-5 -> -5``
  ##    zz       Same as above but with leading 0.                                                  ``GMT+7 -> +07``, ``GMT-5 -> -05``
  ##    zzz      Same as above but with ``:mm`` where *mm* represents minutes.                      ``GMT+7 -> +07:00``, ``GMT-5 -> -05:00``
  ## ==========  =================================================================================  ================================================
  ##
  ## Other strings can be inserted by putting them in ``''``. For example
  ## ``hh'->'mm`` will give ``01->56``.  The following characters can be
  ## inserted without quoting them: ``:`` ``-`` ``(`` ``)`` ``/`` ``[`` ``]``
  ## ``,``. However you don't need to necessarily separate format specifiers, a
  ## unambiguous format string like ``yyyyMMddhhmmss`` is valid too.
  var i = 0 # pointer for format string
  var j = 0 # pointer for value string
  var token = ""
  # Assumes current day of month, month and year, but time is reset to 00:00:00. Weekday will be reset after parsing.
  var info = now()
  info.hour = 0
  info.minute = 0
  info.second = 0
  info.isDst = true # using this is flag for checking whether a timezone has \
      # been read (because DST is always false when a tz is parsed)
  while true:
    case layout[i]
    of ' ', '-', '/', ':', '\'', '\0', '(', ')', '[', ']', ',':
      if token.len > 0:
        parseToken(info, token, value, j)
      # Reset token
      token = ""
      # Break if at end of line
      if layout[i] == '\0': break
      # Skip separator and everything between single quotes
      # These are literals in both the layout and the value string
      if layout[i] == '\'':
        inc(i)
        while layout[i] != '\'' and layout.len-1 > i:
          inc(i)
          inc(j)
        inc(i)
      else:
        inc(i)
        inc(j)
    else:
      # Check if the letter being added matches previous accumulated buffer.
      if token.len < 1 or token[high(token)] == layout[i]:
        token.add(layout[i])
        inc(i)
      else:
        parseToken(info, token, value, j)
        token = ""

  if info.isDst:
    # No timezone parsed - assume timezone is `zone`
    result = info.normalize(zone)
  else:
    # Otherwise convert to `zone`
    result = info.toTime.inZone(zone)

# Leap year calculations are adapted from:
# http://www.codeproject.com/Articles/7358/Ultra-fast-Algorithms-for-Working-with-Leap-Years
# The dayOfTheWeek procs are adapated from:
# http://stason.org/TULARC/society/calendars/2-5-What-day-of-the-week-was-2-August-1953.html

proc countLeapYears*(yearSpan: int): int =
  ## Returns the number of leap years spanned by a given number of years.
  ##
  ## **Note:** For leap years, start date is assumed to be 1 AD.
  ## counts the number of leap years up to January 1st of a given year.
  ## Keep in mind that if specified year is a leap year, the leap day
  ## has not happened before January 1st of that year.
  (yearSpan - 1) div 4 - (yearSpan - 1) div 100 + (yearSpan - 1) div 400

proc countDays*(yearSpan: int): int =
  ## Returns the number of days spanned by a given number of years.
  (yearSpan - 1) * 365 + countLeapYears(yearSpan)

proc countYears*(daySpan: int): int =
  ## Returns the number of years spanned by a given number of days.
  ((daySpan - countLeapYears(daySpan div 365)) div 365)

proc countYearsAndDays*(daySpan: int): tuple[years: int, days: int] =
  ## Returns the number of years spanned by a given number of days and the
  ## remainder as days.
  let days = daySpan - countLeapYears(daySpan div 365)
  result.years = days div 365
  result.days = days mod 365

proc getDayOfYear*(monthday: MonthdayRange, month: Month, year: int): YeardayRange =
  ## Returns the day of the year.
  ## Equivalent with ``initTimeInfo(day, month, year).yearday``.
  const daysUntilMonth : array[Month, int] = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
  const daysUntilMonthLeap : array[Month, int] = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]

  if isLeapYear(year):
    result = daysUntilMonth[month] + monthday - 1
  else:
    result = daysUntilMonthLeap[month] + monthday - 1

proc getDayOfWeek*(monthday: MonthdayRange, month: Month, year: int): WeekDay =
  ## Returns the day of the week enum from day, month and year.
  ## Equivalent with ``initTimeInfo(day, month, year).weekday``.
  let
    ordinalMonth = ord(month)
    a = (14 - ordinalMonth) div 12
    y = year - a
    m = ordinalMonth + (12*a) - 2
    d = (monthday + y + (y div 4) - (y div 100) + (y div 400) + (31*m) div 12) mod 7
  # The value of d is 0 for a Sunday, 1 for a Monday, 2 for a Tuesday, etc.
  # so we must correct for the WeekDay type.
  result = UsWeekdayToEuropean[d]

proc getDayOfWeekJulian*(day, month, year: int): WeekDay =
  ## Returns the day of the week enum from day, month and year,
  ## according to the Julian calendar.
  # Day & month start from one.
  let
    a = (14 - month) div 12
    y = year - a
    m = month + (12*a) - 2
    d = (5 + day + y + (y div 4) + (31*m) div 12) mod 7
  result = d.WeekDay

proc toTimeInterval*(t: Time): TimeInterval =
  ## Converts a Time to a TimeInterval.
  ##
  ## To be used when diffing times.
  ##
  ## .. code-block:: nim
  ##     let a = fromSeconds(1_000_000_000)
  ##     let b = fromSeconds(1_500_000_000)
  ##     echo a, " ", b  # real dates
  ##     echo a.toTimeInterval  # meaningless value, don't use it by itself
  ##     echo b.toTimeInterval - a.toTimeInterval
  ##     # (milliseconds: 0, seconds: -40, minutes: -6, hours: 1, days: -2, months: -2, years: 16)
  # Milliseconds not available from Time
  var tInfo = t.inZone(Local)
  initInterval(0, tInfo.second, tInfo.minute, tInfo.hour, tInfo.weekday.ord, tInfo.month.ord - 1, tInfo.year)

proc initTimeInfo*(monthday: MonthdayRange, month: Month, year: int,
                  hour: HourRange, minute: MinuteRange, second: SecondRange, zone: Timezone = Local): TimeInfo =
  ## Create a new ``TimeInfo`` in the specified timezone.
  doAssert monthday <= getDaysInMonth(month, year), "Invalid date: " & $month & " " & $monthday & ", " & $year
  let ti = TimeInfo(
    monthday:  monthday,
    year:  year,
    month:  month,
    hour:  hour,
    minute:  minute,
    second:  second
  )
  result = ti.normalize(zone)

proc initTimeInfo*(monthday: MonthdayRange, month: Month, year: int, zone: Timezone = Local): TimeInfo =
  ## Create a new ``TimeInfo`` in the specified timezone. The time component will be set to the first
  ## hour/minute/second of they day (in almost all cases 00:00:00).
  # TODO: Add a test for this. In Brazil, DST actives on 00:00:00, which means that the first time of
  # the day is actually 01:00:00.
  initTimeInfo(monthday, month, year, 0, 0, 0, zone)

# Deprecated procs

proc getLocalTime*(t: Time): TimeInfo {.tags: [TimeEffect], raises: [], benign, deprecated.} =
  ## Converts the calendar time `t` to broken-time representation,
  ## expressed relative to the user's specified time zone.
  t.inZone(Local)

proc getGMTime*(t: Time): TimeInfo {.tags: [TimeEffect], raises: [], benign, deprecated.} =
  ## Converts the calendar time `t` to broken-down time representation,
  ## expressed in Coordinated Universal Time (UTC).
  t.inZone(Utc)

proc getTimezone*(): int {.tags: [TimeEffect], raises: [], benign, deprecated.}
  ## returns the offset of the local (non-DST) timezone in seconds west of UTC.

proc timeInfoToTime*(timeInfo: TimeInfo): Time {.tags: [TimeEffect], benign, deprecated.} =
  ## Converts a broken-down time structure to
  ## calendar time representation. The function ignores the specified
  ## contents of the structure members `weekday` and `yearday` and recomputes
  ## them from the other information in the broken-down time structure.
  ##
  ## **Warning:** This procedure is deprecated since version 0.14.0.
  ## Use ``toTime`` instead.
  timeInfo.toTime  

proc getStartMilsecs*(): int {.deprecated, tags: [TimeEffect], benign.}
  ## get the milliseconds from the start of the program. **Deprecated since
  ## version 0.8.10.** Use ``epochTime`` or ``cpuTime`` instead.

proc miliseconds*(t: TimeInterval): int {.deprecated.} =
  t.milliseconds

proc timeToTimeInterval*(t: Time): TimeInterval {.deprecated.} =
  ## Converts a Time to a TimeInterval.
  ##
  ## **Warning:** This procedure is deprecated since version 0.14.0.
  ## Use ``toTimeInterval`` instead.
  # Milliseconds not available from Time
  t.toTimeInterval()

proc timeToTimeInfo*(t: Time): TimeInfo {.deprecated.} =
  ## Converts a Time to TimeInfo.
  ##
  ## **Warning:** This procedure is deprecated since version 0.14.0.
  ## Use ``inZone`` instead.
  const epochStartYear = 1970

  let
    secs = t.toSeconds().int
    daysSinceEpoch = secs div secondsInDay
    (yearsSinceEpoch, daysRemaining) = countYearsAndDays(daysSinceEpoch)
    daySeconds = secs mod secondsInDay

    y = yearsSinceEpoch + epochStartYear

  var
    mon = mJan
    days = daysRemaining
    daysInMonth = getDaysInMonth(mon, y)

  # calculate month and day remainder
  while days > daysInMonth and mon <= mDec:
    days -= daysInMonth
    mon.inc
    daysInMonth = getDaysInMonth(mon, y)

  let
    yd = daysRemaining
    m = mon  # month is zero indexed enum
    md = days
    # NB: month is zero indexed but dayOfWeek expects 1 indexed.
    wd = getDayOfWeek(days, mon, y).Weekday
    h = daySeconds div secondsInHour + 1
    mi = (daySeconds mod secondsInHour) div secondsInMin
    s = daySeconds mod secondsInMin
  result = TimeInfo(year: y, yearday: yd, month: m, monthday: md, weekday: wd, hour: h, minute: mi, second: s)

when not defined(JS):
  proc epochTime*(): float {.rtl, extern: "nt$1", tags: [TimeEffect].}
    ## gets time after the UNIX epoch (1970) in seconds. It is a float
    ## because sub-second resolution is likely to be supported (depending
    ## on the hardware/OS).

  proc cpuTime*(): float {.rtl, extern: "nt$1", tags: [TimeEffect].}
    ## gets time spent that the CPU spent to run the current process in
    ## seconds. This may be more useful for benchmarking than ``epochTime``.
    ## However, it may measure the real time instead (depending on the OS).
    ## The value of the result has no meaning.
    ## To generate useful timing values, take the difference between
    ## the results of two ``cpuTime`` calls:
    ##
    ## .. code-block:: nim
    ##   var t0 = cpuTime()
    ##   doWork()
    ##   echo "CPU time [s] ", cpuTime() - t0

when not defined(JS):
  type
    Clock {.importc: "clock_t".} = distinct int

  proc timec(timer: ptr Time): Time {.
    importc: "time", header: "<time.h>", tags: [].}

  proc getClock(): Clock {.importc: "clock", header: "<time.h>", tags: [TimeEffect].}
  proc difftime(a, b: Time): float {.importc: "difftime", header: "<time.h>",
    tags: [].}

  var
    clocksPerSec {.importc: "CLOCKS_PER_SEC", nodecl.}: int

  when not defined(useNimRtl):
    proc `-` (a, b: Time): int64 =
      return toBiggestInt(difftime(a, b))

  proc getStartMilsecs(): int =
    #echo "clocks per sec: ", clocksPerSec, "clock: ", int(getClock())
    #return getClock() div (clocksPerSec div 1000)
    when defined(macosx):
      result = toInt(toFloat(int(getClock())) / (toFloat(clocksPerSec) / 1000.0))
    else:
      result = int(getClock()) div (clocksPerSec div 1000)
    when false:
      var a: Timeval
      posix_gettimeofday(a)
      result = a.tv_sec * 1000'i64 + a.tv_usec div 1000'i64
      #echo "result: ", result

  proc getTime(): Time =
    timec(nil)

  proc toEpochday(year, month, day: int): int64 =
    # Based on http://howardhinnant.github.io/date_algorithms.html
    var (y, m, d) = (year, month, day)
    if m <= 2:
      y.dec

    let era = (if y >= 0: y else: y-399) div 400
    let yoe = y - era * 400
    let doy = (153 * (m + (if m > 2: -3 else: 9)) + 2) div 5 + d-1
    let doe = yoe * 365 + yoe div 4 - yoe div 100 + doy
    return era * 146097 + doe - 719468

  proc toTime(timeInfo: TimeInfo): Time =
    let epochDay = toEpochday(timeInfo.year, ord(timeInfo.month), timeInfo.monthday)
    result = Time(epochDay * secondsInDay)
    result.inc timeInfo.hour * secondsInHour
    result.inc timeInfo.minute * 60
    result.inc timeInfo.second
    # The code above ignores the UTC offset of `timeInfo`,
    # so we need to compensate for that here.
    result.inc timeInfo.utcOffset

  const
    epochDiff = 116444736000000000'i64
    rateDiff = 10000000'i64 # 100 nsecs

  proc unixTimeToWinTime*(t: Time): int64 =
    ## converts a UNIX `Time` (``time_t``) to a Windows file time
    result = int64(t) * rateDiff + epochDiff

  proc winTimeToUnixTime*(t: int64): Time =
    ## converts a Windows time to a UNIX `Time` (``time_t``)
    result = Time((t - epochDiff) div rateDiff)

  proc getTimezone(): int =
    when defined(freebsd) or defined(netbsd) or defined(openbsd):
      var a = timec(nil)
      let lt = localtime(addr(a))
      # BSD stores in `gmtoff` offset east of UTC in seconds,
      # but posix systems using west of UTC in seconds
      return -(lt.gmtoff)
    else:
      return timezone

  proc fromSeconds(since1970: float): Time = Time(since1970)

  proc toSeconds(time: Time): float = float(time)

  when not defined(useNimRtl):
    proc epochTime(): float =
      when defined(posix):
        var a: Timeval
        posix_gettimeofday(a)
        result = toFloat(a.tv_sec) + toFloat(a.tv_usec)*0.00_0001
      elif defined(windows):
        var f: winlean.FILETIME
        getSystemTimeAsFileTime(f)
        var i64 = rdFileTime(f) - epochDiff
        var secs = i64 div rateDiff
        var subsecs = i64 mod rateDiff
        result = toFloat(int(secs)) + toFloat(int(subsecs)) * 0.0000001
      else:
        {.error: "unknown OS".}

    proc cpuTime(): float =
      result = toFloat(int(getClock())) / toFloat(clocksPerSec)

elif defined(JS):
  proc newDate(): Time {.importc: "new Date".}
  proc internGetTime(): Time {.importc: "new Date", tags: [].}

  proc newDate(value: float): Time {.importc: "new Date".}
  proc newDate(value: cstring): Time {.importc: "new Date".}
  proc getTime(): Time =
    # Warning: This is something different in JS.
    return newDate()

  proc timeInfoToTime(timeInfo: TimeInfo): Time = toTime(timeInfo)

  proc toTime*(timeInfo: TimeInfo): Time = newDate($timeInfo)

  proc `-` (a, b: Time): int64 =
    return a.getTime() - b.getTime()

  var
    startMilsecs = getTime()

  proc getStartMilsecs(): int =
    ## get the milliseconds from the start of the program
    return int(getTime() - startMilsecs)

  proc fromSeconds(since1970: float): Time = result = newDate(since1970 * 1000)

  proc toSeconds(time: Time): float = result = time.getTime() / 1000

  proc getTimezone(): int = result = newDate().getTimezoneOffset() * 60

  proc epochTime*(): float {.tags: [TimeEffect].} = newDate().toSeconds()

when isMainModule:
  # this is testing non-exported function
  var
    t4 = fromSeconds(876124714).inZone(Utc) # Mon  6 Oct 08:58:34 BST 1997
    t4L = fromSeconds(876124714).inZone(Local)
  assert toSeconds(t4, initInterval(seconds=0)) == 0.0
  assert toSeconds(t4L, initInterval(milliseconds=1)) == toSeconds(t4, initInterval(milliseconds=1))
  assert toSeconds(t4L, initInterval(seconds=1)) == toSeconds(t4, initInterval(seconds=1))
  assert toSeconds(t4L, initInterval(minutes=1)) == toSeconds(t4, initInterval(minutes=1))
  assert toSeconds(t4L, initInterval(hours=1)) == toSeconds(t4, initInterval(hours=1))
  assert toSeconds(t4L, initInterval(days=1)) == toSeconds(t4, initInterval(days=1))
  assert toSeconds(t4L, initInterval(months=1)) == toSeconds(t4, initInterval(months=1))
  assert toSeconds(t4L, initInterval(years=1)) == toSeconds(t4, initInterval(years=1))

  # Further tests are in tests/stdlib/ttime.nim
  # koch test c stdlib