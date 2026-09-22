// =====================================================================
// CALENDAR DIMENSION — en-US (United States)
// Paste this whole code in: Power BI Desktop > Get Data >
// Blank Query > Advanced Editor > paste > Done.
// Then: mark the table as "Date table" using the [Date] column.
// =====================================================================
let
    // =====================================================
    // CONFIGURATION — change only this date if needed
    // =====================================================
    StartDate = #date(2020, 1, 1),

    // =====================================================
    // ADVANCED CONFIGURATION (optional; usually leave as is)
    // =====================================================
    FutureYears       = 1,     // full years generated after the current year
    UtcOffsetHours    = -5,    // US Eastern-ish default, used to define "today"
    AsOfDateOverride  = null,  // e.g. #date(2026,9,22) for testing; null = today

    // =====================================================
    // REFERENCE DATE ("today") AND CALENDAR BOUNDARIES
    // =====================================================
    // DateTime.LocalNow() in the Power BI Service uses the server's clock
    // (UTC), which shifts "today" at night. We adjust the offset manually
    // instead of relying on the local machine's time zone.
    AsOfDate =
        if AsOfDateOverride <> null then
            AsOfDateOverride
        else
            Date.From(
                DateTimeZone.RemoveZone(
                    DateTimeZone.SwitchZone(DateTimeZone.UtcNow(), UtcOffsetHours)
                )
            ),

    EndDate = Date.EndOfYear(#date(Date.Year(AsOfDate) + FutureYears, 12, 31)),

    RangeCheck =
        if StartDate > EndDate then
            error Error.Record(
                "Calendar.InvalidRange",
                "StartDate is later than EndDate. Check the start date.",
                [StartDate = StartDate, EndDate = EndDate]
            )
        else
            true,

    // =====================================================
    // LOCALIZED NAMES (fixed lists; not Date.ToText with culture, to avoid
    // capitalization/abbreviation drift across engine versions)
    // =====================================================
    MonthNames = {
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    },
    MonthNamesShort = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"},
    // Index 0 = Sunday, ..., 6 = Saturday (independent of week start)
    WeekdayNames = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"},
    WeekdayNamesShort = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"},
    // Index 0 = Winter (Dec-Feb), 1 = Spring, 2 = Summer, 3 = Fall
    SeasonNames = {"Winter", "Spring", "Summer", "Fall"},
    WeekStartDay = Day.Sunday,

    // =====================================================
    // EASTER — Meeus/Jones/Butcher algorithm (Gregorian calendar)
    // Manually checked against 2000-04-23 and 2026-04-05: correct.
    // Kept even though no US federal holiday depends on it today, so the
    // three locale files share the same building blocks.
    // =====================================================
    fnEaster = (year as number) as date =>
        let
            a = Number.Mod(year, 19),
            b = Number.IntegerDivide(year, 100),
            c = Number.Mod(year, 100),
            d = Number.IntegerDivide(b, 4),
            e = Number.Mod(b, 4),
            f = Number.IntegerDivide(b + 8, 25),
            g = Number.IntegerDivide(b - f + 1, 3),
            h = Number.Mod(19 * a + b - d - g + 15, 30),
            i = Number.IntegerDivide(c, 4),
            k = Number.Mod(c, 4),
            l = Number.Mod(32 + 2 * e + 2 * i - h - k, 7),
            m = Number.IntegerDivide(a + 11 * h + 22 * l, 451),
            month = Number.IntegerDivide(h + l - 7 * m + 114, 31),
            day = Number.Mod(h + l - 7 * m + 114, 31) + 1
        in
            #date(year, month, day),

    // =====================================================
    // HOLIDAY HELPERS — nth weekday of month / last weekday of month
    // weekday: 0 = Sunday .. 6 = Saturday
    // =====================================================
    fnNthWeekday = (year as number, month as number, weekday as number, n as number) as date =>
        let
            firstOfMonth = #date(year, month, 1),
            firstWeekday = Date.DayOfWeek(firstOfMonth, Day.Sunday),
            offset = Number.Mod(weekday - firstWeekday, 7),
            firstOccurrence = Date.AddDays(firstOfMonth, offset)
        in
            Date.AddDays(firstOccurrence, (n - 1) * 7),

    fnLastWeekday = (year as number, month as number, weekday as number) as date =>
        let
            lastOfMonth = Date.EndOfMonth(#date(year, month, 1)),
            lastWeekday = Date.DayOfWeek(lastOfMonth, Day.Sunday),
            offset = Number.Mod(lastWeekday - weekday, 7)
        in
            Date.AddDays(lastOfMonth, -offset),

    // Observance rule (5 U.S.C. 6103): Saturday -> observed previous Friday;
    // Sunday -> observed following Monday. Applied only to fixed-date holidays.
    fnObserved = (date as date) as date =>
        let dw = Date.DayOfWeek(date, Day.Sunday)
        in if dw = 6 then Date.AddDays(date, -1)
           else if dw = 0 then Date.AddDays(date, 1)
           else date,

    // Builds the actual-date row, plus an "(Observed)" row when the actual
    // date falls on a weekend (e.g. New Year's Day on Saturday is observed
    // on the preceding Friday, Dec 31 of the previous year).
    fnWithObservance = (date as date, name as text) as list =>
        let dw = Date.DayOfWeek(date, Day.Sunday)
        in if dw = 0 or dw = 6 then
                {
                    {date, name, "Federal", false},
                    {fnObserved(date), name & " (Observed)", "Federal", true}
                }
           else
                {{date, name, "Federal", false}},

    // =====================================================
    // FEDERAL HOLIDAYS — generated per year (never row by row)
    // HolidayType is always "Federal" here (5 U.S.C. 6103); there is no
    // "Optional" tier for US federal holidays.
    // =====================================================
    fnFixedHolidays = (year as number) as list =>
        List.Combine({
              fnWithObservance(#date(year, 1, 1), "New Year's Day")
            , fnWithObservance(#date(year, 7, 4), "Independence Day")
            , fnWithObservance(#date(year, 11, 11), "Veterans Day")
            , fnWithObservance(#date(year, 12, 25), "Christmas Day")
            , if year >= 2021 then fnWithObservance(#date(year, 6, 19), "Juneteenth National Independence Day") else {}
            , if year >= 1986 then {{fnNthWeekday(year, 1, 1, 3), "Martin Luther King Jr. Day", "Federal", false}} else {}
            , {{fnNthWeekday(year, 2, 1, 3), "Washington's Birthday", "Federal", false}}
            , {{fnLastWeekday(year, 5, 1), "Memorial Day", "Federal", false}}
            , {{fnNthWeekday(year, 9, 1, 1), "Labor Day", "Federal", false}}
            , {{fnNthWeekday(year, 10, 1, 2), "Columbus Day", "Federal", false}}
            , {{fnNthWeekday(year, 11, 4, 4), "Thanksgiving Day", "Federal", false}}
        }),

    // No moving (Easter-based) US federal holidays; kept for structural
    // symmetry with the other two locale files.
    fnMovingHolidays = (year as number) as list => {},

    // Generate one extra year on each end (harmless: rows outside
    // [StartDate, EndDate] simply don't match anything in the join)
    HolidayYears = List.Buffer({Date.Year(StartDate) - 1 .. Date.Year(EndDate) + 1}),
    HolidayRows = List.Combine(List.Transform(HolidayYears, each fnFixedHolidays(_) & fnMovingHolidays(_))),
    RawHolidays = #table(
        type table [Date = date, HolidayName = text, HolidayType = text, IsObservedHoliday = logical],
        HolidayRows
    ),

    // Two rules on the same date: concatenate names, keep the most
    // restrictive type, never duplicate the row
    Holidays = Table.Buffer(
        Table.Group(
            RawHolidays, {"Date"},
            {
                  {"HolidayName", each Text.Combine(_[HolidayName], " / "), type text}
                , {"HolidayType", each
                        let nonOptional = List.Select(_[HolidayType], each _ <> "Optional")
                        in if List.Count(nonOptional) > 0 then nonOptional{0} else "Optional",
                   type text}
                , {"IsObservedHoliday", each List.Contains(_[IsObservedHoliday], true), type logical}
            }
        )
    ),

    // =====================================================
    // BASE DATE TABLE
    // =====================================================
    DateList = List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1, 0, 0, 0)),
    BaseTable = Table.TransformColumnTypes(
        Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}),
        {{"Date", type date}}
    ),

    // ----- Date -----
    add_DateKey  = Table.AddColumn(BaseTable, "DateKey", each Date.Year([Date]) * 10000 + Date.Month([Date]) * 100 + Date.Day([Date]), Int64.Type),
    add_DayOfMonth = Table.AddColumn(add_DateKey, "DayOfMonth", each Date.Day([Date]), Int64.Type),
    add_DayOfYear  = Table.AddColumn(add_DayOfMonth, "DayOfYear", each Date.DayOfYear([Date]), Int64.Type),

    // ----- Year -----
    add_Year      = Table.AddColumn(add_DayOfYear, "Year", each Date.Year([Date]), Int64.Type),
    add_YearStart = Table.AddColumn(add_Year, "YearStart", each Date.StartOfYear([Date]), type date),
    add_YearEnd   = Table.AddColumn(add_YearStart, "YearEnd", each Date.EndOfYear([Date]), type date),
    add_IsLeapYear = Table.AddColumn(add_YearEnd, "IsLeapYear", each Date.DaysInMonth(#date([Year], 2, 1)) = 29, type logical),

    // ----- Month -----
    add_MonthNumber = Table.AddColumn(add_IsLeapYear, "MonthNumber", each Date.Month([Date]), Int64.Type),
    add_MonthName   = Table.AddColumn(add_MonthNumber, "MonthName", each MonthNames{[MonthNumber] - 1}, type text),
    add_MonthNameShort = Table.AddColumn(add_MonthName, "MonthNameShort", each MonthNamesShort{[MonthNumber] - 1}, type text),
    add_MonthYear   = Table.AddColumn(add_MonthNameShort, "MonthYear", each [MonthName] & "/" & Text.From([Year]), type text),
    add_MonthYearShort = Table.AddColumn(add_MonthYear, "MonthYearShort", each [MonthNameShort] & "/" & Text.From([Year]), type text),
    add_YearMonth   = Table.AddColumn(add_MonthYearShort, "YearMonth", each Text.From([Year]) & "-" & Text.PadStart(Text.From([MonthNumber]), 2, "0"), type text),
    add_YearMonthNumber = Table.AddColumn(add_YearMonth, "YearMonthNumber", each [Year] * 100 + [MonthNumber], Int64.Type),
    add_MonthStart  = Table.AddColumn(add_YearMonthNumber, "MonthStart", each Date.StartOfMonth([Date]), type date),
    add_MonthEnd    = Table.AddColumn(add_MonthStart, "MonthEnd", each Date.EndOfMonth([Date]), type date),

    // ----- Half year -----
    add_SemesterNumber = Table.AddColumn(add_MonthEnd, "SemesterNumber", each if [MonthNumber] <= 6 then 1 else 2, Int64.Type),
    add_SemesterName   = Table.AddColumn(add_SemesterNumber, "SemesterName", each "H" & Text.From([SemesterNumber]), type text),
    add_YearSemesterNumber = Table.AddColumn(add_SemesterName, "YearSemesterNumber", each [Year] * 10 + [SemesterNumber], Int64.Type),
    add_YearSemester   = Table.AddColumn(add_YearSemesterNumber, "YearSemester", each Text.From([Year]) & "-H" & Text.From([SemesterNumber]), type text),

    // ----- Quarter -----
    add_QuarterNumber = Table.AddColumn(add_YearSemester, "QuarterNumber", each Date.QuarterOfYear([Date]), Int64.Type),
    add_QuarterName   = Table.AddColumn(add_QuarterNumber, "QuarterName", each "Q" & Text.From([QuarterNumber]), type text),
    add_YearQuarterNumber = Table.AddColumn(add_QuarterName, "YearQuarterNumber", each [Year] * 10 + [QuarterNumber], Int64.Type),
    add_YearQuarter   = Table.AddColumn(add_YearQuarterNumber, "YearQuarter", each Text.From([Year]) & "-" & [QuarterName], type text),
    add_QuarterStart  = Table.AddColumn(add_YearQuarter, "QuarterStart", each Date.StartOfQuarter([Date]), type date),
    add_QuarterEnd    = Table.AddColumn(add_QuarterStart, "QuarterEnd", each Date.EndOfQuarter([Date]), type date),

    // ----- Day of week -----
    add_DayOfWeekName = Table.AddColumn(add_QuarterEnd, "DayOfWeekName", each WeekdayNames{Date.DayOfWeek([Date], Day.Sunday)}, type text),
    add_DayOfWeekNameShort = Table.AddColumn(add_DayOfWeekName, "DayOfWeekNameShort", each WeekdayNamesShort{Date.DayOfWeek([Date], Day.Sunday)}, type text),
    add_IsWeekend = Table.AddColumn(add_DayOfWeekNameShort, "IsWeekend", each Date.DayOfWeek([Date], Day.Sunday) = 0 or Date.DayOfWeek([Date], Day.Sunday) = 6, type logical),
    add_DayOfWeekNumber = Table.AddColumn(add_IsWeekend, "DayOfWeekNumber", each Date.DayOfWeek([Date], WeekStartDay) + 1, Int64.Type),

    // ----- Local week -----
    add_WeekNumber = Table.AddColumn(add_DayOfWeekNumber, "WeekNumber", each Date.WeekOfYear([Date], WeekStartDay), Int64.Type),
    add_WeekStart  = Table.AddColumn(add_WeekNumber, "WeekStart", each Date.StartOfWeek([Date], WeekStartDay), type date),
    add_WeekEnd    = Table.AddColumn(add_WeekStart, "WeekEnd", each Date.EndOfWeek([Date], WeekStartDay), type date),

    // ----- ISO 8601 week (independent of locale week start) -----
    // Week 1 = the week containing the year's first Thursday; ISOYear can
    // differ from Year at the year boundary (checked against 2026-12-31 ->
    // 2026-W53 and 2027-01-01 -> 2026-W53)
    add_ISOWeekNumber = Table.AddColumn(
        add_WeekEnd, "ISOWeekNumber",
        each let
            thursdayOfWeek = Date.AddDays([Date], 3 - Date.DayOfWeek([Date], Day.Monday)),
            isoYearStart = #date(Date.Year(thursdayOfWeek), 1, 1),
            dayDiff = Duration.Days(thursdayOfWeek - isoYearStart)
        in
            Number.IntegerDivide(dayDiff, 7, 0) + 1,
        Int64.Type
    ),
    add_ISOYear = Table.AddColumn(add_ISOWeekNumber, "ISOYear", each Date.Year(Date.AddDays([Date], 3 - Date.DayOfWeek([Date], Day.Monday))), Int64.Type),
    add_ISOYearWeekNumber = Table.AddColumn(add_ISOYear, "ISOYearWeekNumber", each [ISOYear] * 100 + [ISOWeekNumber], Int64.Type),
    add_ISOYearWeek = Table.AddColumn(add_ISOYearWeekNumber, "ISOYearWeek", each Text.From([ISOYear]) & "-W" & Text.PadStart(Text.From([ISOWeekNumber]), 2, "0"), type text),

    // ----- Season (meteorological definition; northern hemisphere) -----
    add_SeasonNumber = Table.AddColumn(
        add_ISOYearWeek, "SeasonNumber",
        each if [MonthNumber] = 12 or [MonthNumber] <= 2 then 1
             else if [MonthNumber] <= 5 then 2
             else if [MonthNumber] <= 8 then 3
             else 4,
        Int64.Type
    ),
    add_Season = Table.AddColumn(add_SeasonNumber, "Season", each SeasonNames{[SeasonNumber] - 1}, type text),

    // ----- Holidays (join with the holiday table) -----
    add_HolidayJoin = Table.NestedJoin(add_Season, {"Date"}, Holidays, {"Date"}, "HolidayInfo", JoinKind.LeftOuter),
    add_HolidayExpand = Table.ExpandTableColumn(add_HolidayJoin, "HolidayInfo", {"HolidayName", "HolidayType", "IsObservedHoliday"}, {"HolidayName", "HolidayType", "IsObservedHoliday"}),
    add_CleanObserved = Table.TransformColumns(add_HolidayExpand, {{"IsObservedHoliday", each if _ = null then false else _, type logical}}),
    add_IsHoliday = Table.AddColumn(add_CleanObserved, "IsHoliday", each [HolidayType] <> null and [HolidayType] <> "Optional", type logical),
    add_IsOptionalDay = Table.AddColumn(add_IsHoliday, "IsOptionalDay", each [HolidayType] = "Optional", type logical),
    add_IsNationalHoliday = Table.AddColumn(add_IsOptionalDay, "IsNationalHoliday", each [HolidayType] = "Federal", type logical),

    // ----- Business day -----
    add_IsBusinessDay = Table.AddColumn(add_IsNationalHoliday, "IsBusinessDay", each not [IsWeekend] and not [IsHoliday], type logical),

    // Business-day index computed per group (month/year), never row by row
    // against the whole table — avoids O(n^2)
    GroupByMonth = Table.Group(
        add_IsBusinessDay, {"YearMonthNumber"},
        {
            {"Sub", each
                let
                    sorted   = Table.Sort(_, {{"Date", Order.Ascending}}),
                    business = Table.AddIndexColumn(Table.SelectRows(sorted, each [IsBusinessDay]), "BusinessDayOfMonth", 1, 1, Int64.Type),
                    nonBusiness = Table.AddColumn(Table.SelectRows(sorted, each not [IsBusinessDay]), "BusinessDayOfMonth", each null, Int64.Type)
                in
                    Table.Combine({business, nonBusiness}),
             type table}
        }
    ),
    ExpandedByMonth = Table.Combine(GroupByMonth[Sub]),

    GroupByYear = Table.Group(
        ExpandedByMonth, {"Year"},
        {
            {"Sub", each
                let
                    sorted   = Table.Sort(_, {{"Date", Order.Ascending}}),
                    business = Table.AddIndexColumn(Table.SelectRows(sorted, each [IsBusinessDay]), "BusinessDayOfYear", 1, 1, Int64.Type),
                    nonBusiness = Table.AddColumn(Table.SelectRows(sorted, each not [IsBusinessDay]), "BusinessDayOfYear", each null, Int64.Type)
                in
                    Table.Combine({business, nonBusiness}),
             type table}
        }
    ),
    ExpandedByYear = Table.Sort(Table.Combine(GroupByYear[Sub]), {{"Date", Order.Ascending}}),

    // ----- Markers -----
    add_IsMonthStart = Table.AddColumn(ExpandedByYear, "IsMonthStart", each [Date] = [MonthStart], type logical),
    add_IsMonthEnd   = Table.AddColumn(add_IsMonthStart, "IsMonthEnd", each [Date] = [MonthEnd], type logical),
    add_IsQuarterStart = Table.AddColumn(add_IsMonthEnd, "IsQuarterStart", each [Date] = [QuarterStart], type logical),
    add_IsQuarterEnd   = Table.AddColumn(add_IsQuarterStart, "IsQuarterEnd", each [Date] = [QuarterEnd], type logical),
    add_IsYearStart  = Table.AddColumn(add_IsQuarterEnd, "IsYearStart", each [Date] = [YearStart], type logical),
    add_IsYearEnd    = Table.AddColumn(add_IsYearStart, "IsYearEnd", each [Date] = [YearEnd], type logical),

    // ----- Relative-to-today columns -----
    add_AsOfDate = Table.AddColumn(add_IsYearEnd, "AsOfDate", each AsOfDate, type date),
    add_IsToday  = Table.AddColumn(add_AsOfDate, "IsToday", each [Date] = [AsOfDate], type logical),
    add_IsCurrentMonth = Table.AddColumn(add_IsToday, "IsCurrentMonth", each [Year] = Date.Year([AsOfDate]) and [MonthNumber] = Date.Month([AsOfDate]), type logical),
    add_IsCurrentYear  = Table.AddColumn(add_IsCurrentMonth, "IsCurrentYear", each [Year] = Date.Year([AsOfDate]), type logical),

    // ----- Final column order -----
    Result = Table.ReorderColumns(
        add_IsCurrentYear,
        {
            "Date", "DateKey", "DayOfMonth", "DayOfYear",
            "Year", "YearStart", "YearEnd", "IsLeapYear",
            "SemesterNumber", "SemesterName", "YearSemesterNumber", "YearSemester",
            "QuarterNumber", "QuarterName", "YearQuarterNumber", "YearQuarter", "QuarterStart", "QuarterEnd",
            "MonthNumber", "MonthName", "MonthNameShort", "MonthYear", "MonthYearShort", "YearMonth", "YearMonthNumber", "MonthStart", "MonthEnd",
            "DayOfWeekNumber", "DayOfWeekName", "DayOfWeekNameShort", "IsWeekend",
            "WeekNumber", "WeekStart", "WeekEnd",
            "ISOWeekNumber", "ISOYear", "ISOYearWeek", "ISOYearWeekNumber",
            "SeasonNumber", "Season",
            "IsHoliday", "HolidayName", "HolidayType", "IsOptionalDay", "IsNationalHoliday", "IsObservedHoliday",
            "IsBusinessDay", "BusinessDayOfMonth", "BusinessDayOfYear",
            "IsMonthStart", "IsMonthEnd", "IsQuarterStart", "IsQuarterEnd", "IsYearStart", "IsYearEnd",
            "AsOfDate", "IsToday", "IsCurrentMonth", "IsCurrentYear"
        }
    )
in
    Result
