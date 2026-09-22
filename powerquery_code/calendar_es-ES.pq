// =====================================================================
// DIMENSIÓN CALENDARIO — es-ES (España)
// Pegue este código completo en: Power BI Desktop > Obtener datos >
// Consulta en blanco > Editor avanzado > pegar > Listo.
// Luego: marque la tabla como "Tabla de fechas" usando la columna [Date].
// =====================================================================
let
    // =====================================================
    // CONFIGURACIÓN — cambie solo esta fecha si lo necesita
    // =====================================================
    StartDate = #date(2020, 1, 1),

    // =====================================================
    // CONFIGURACIÓN AVANZADA (opcional; normalmente no cambiar)
    // =====================================================
    FutureYears       = 1,     // años completos generados después del año actual
    UtcOffsetHours    = 1,     // huso horario peninsular (CET), usado para definir "hoy"
    AsOfDateOverride  = null,  // ej.: #date(2026,9,22) para pruebas; null = hoy

    // =====================================================
    // FECHA DE REFERENCIA ("hoy") Y LÍMITES DEL CALENDARIO
    // =====================================================
    // DateTime.LocalNow() en el servicio de Power BI usa la hora del
    // servidor (UTC), lo que desplaza "hoy" por la noche. Por eso ajustamos
    // el huso manualmente en vez de usar la hora local de la máquina.
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

    ComprobacionRango =
        if StartDate > EndDate then
            error Error.Record(
                "Calendar.RangoInvalido",
                "StartDate es posterior a EndDate. Revise la fecha de inicio.",
                [StartDate = StartDate, EndDate = EndDate]
            )
        else
            true,

    // =====================================================
    // NOMBRES LOCALIZADOS (listas fijas; no usan Date.ToText con cultura,
    // para evitar variaciones de mayúsculas/abreviaturas entre motores)
    // =====================================================
    NombresMes = {
        "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
        "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
    },
    NombresMesAbrev = {"Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"},
    // Índice 0 = Domingo, ..., 6 = Sábado (independiente del inicio de semana)
    NombresDiaSemana = {"Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"},
    NombresDiaSemanaAbrev = {"Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"},
    // Índice 0 = Invierno (dic-feb), 1 = Primavera, 2 = Verano, 3 = Otoño
    NombresEstacion = {"Invierno", "Primavera", "Verano", "Otoño"},
    // España usa ISO 8601: la semana empieza en lunes
    DiaInicioSemana = Day.Monday,

    // =====================================================
    // PASCUA — algoritmo de Meeus/Jones/Butcher (calendario gregoriano)
    // Verificado manualmente contra 2000-04-23 y 2026-04-05: correcto.
    // =====================================================
    fnPascua = (anio as number) as date =>
        let
            a = Number.Mod(anio, 19),
            b = Number.IntegerDivide(anio, 100),
            c = Number.Mod(anio, 100),
            d = Number.IntegerDivide(b, 4),
            e = Number.Mod(b, 4),
            f = Number.IntegerDivide(b + 8, 25),
            g = Number.IntegerDivide(b - f + 1, 3),
            h = Number.Mod(19 * a + b - d - g + 15, 30),
            i = Number.IntegerDivide(c, 4),
            k = Number.Mod(c, 4),
            l = Number.Mod(32 + 2 * e + 2 * i - h - k, 7),
            m = Number.IntegerDivide(a + 11 * h + 22 * l, 451),
            mes = Number.IntegerDivide(h + l - 7 * m + 114, 31),
            dia = Number.Mod(h + l - 7 * m + 114, 31) + 1
        in
            #date(anio, mes, dia),

    // =====================================================
    // FIESTAS — generadas por año (nunca fila a fila)
    // HolidayType: siempre "National" (fiestas de ámbito nacional, Real
    // Decreto 2001/1983). Sin traslado a lunes cuando cae en domingo: el
    // calendario oficial anual del BOE decide eso por Comunidad Autónoma,
    // fuera del alcance de este archivo (ver README).
    // =====================================================
    fnFiestasFijas = (anio as number) as list =>
        {
              {#date(anio, 1, 1),  "Año Nuevo",                       "National", false}
            , {#date(anio, 1, 6),  "Epifanía del Señor",              "National", false}
            , {#date(anio, 5, 1),  "Fiesta del Trabajo",              "National", false}
            , {#date(anio, 8, 15), "Asunción de la Virgen",           "National", false}
            , {#date(anio, 10, 12),"Fiesta Nacional de España",       "National", false}
            , {#date(anio, 11, 1), "Todos los Santos",                "National", false}
            , {#date(anio, 12, 6), "Día de la Constitución Española", "National", false}
            , {#date(anio, 12, 8), "Inmaculada Concepción",           "National", false}
            , {#date(anio, 12, 25),"Natividad del Señor",             "National", false}
        },

    fnFiestasMoviles = (anio as number) as list =>
        {
            {Date.AddDays(fnPascua(anio), -2), "Viernes Santo", "National", false}
        },

    // Genera un año extra en cada extremo por seguridad (inofensivo: filas
    // fuera de [StartDate, EndDate] simplemente no coinciden en el join)
    AniosParaFiestas = List.Buffer({Date.Year(StartDate) - 1 .. Date.Year(EndDate) + 1}),
    FilasFiestas = List.Combine(List.Transform(AniosParaFiestas, each fnFiestasFijas(_) & fnFiestasMoviles(_))),
    FiestasBrutas = #table(
        type table [Date = date, HolidayName = text, HolidayType = text, IsObservedHoliday = logical],
        FilasFiestas
    ),

    // Dos reglas en la misma fecha: concatena nombres, mantiene el tipo más
    // restrictivo, nunca duplica la fila
    Fiestas = Table.Buffer(
        Table.Group(
            FiestasBrutas, {"Date"},
            {
                  {"HolidayName", each Text.Combine(_[HolidayName], " / "), type text}
                , {"HolidayType", each
                        let noOpcionales = List.Select(_[HolidayType], each _ <> "Optional")
                        in if List.Count(noOpcionales) > 0 then noOpcionales{0} else "Optional",
                   type text}
                , {"IsObservedHoliday", each List.Contains(_[IsObservedHoliday], true), type logical}
            }
        )
    ),

    // =====================================================
    // TABLA BASE DE FECHAS
    // =====================================================
    // "ComprobacionRango" se referencia aquí a propósito: en M los pasos son
    // perezosos, así que sin esta referencia la validación nunca se
    // evaluaría y el error de StartDate > EndDate nunca se dispararía.
    ListaFechas = if ComprobacionRango then List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1, 0, 0, 0)) else null,
    TablaBase = Table.TransformColumnTypes(
        Table.FromList(ListaFechas, Splitter.SplitByNothing(), {"Date"}),
        {{"Date", type date}}
    ),

    // ----- Fecha -----
    add_DateKey  = Table.AddColumn(TablaBase, "DateKey", each Date.Year([Date]) * 10000 + Date.Month([Date]) * 100 + Date.Day([Date]), Int64.Type),
    add_DayOfMonth = Table.AddColumn(add_DateKey, "DayOfMonth", each Date.Day([Date]), Int64.Type),
    add_DayOfYear  = Table.AddColumn(add_DayOfMonth, "DayOfYear", each Date.DayOfYear([Date]), Int64.Type),

    // ----- Año -----
    add_Year      = Table.AddColumn(add_DayOfYear, "Year", each Date.Year([Date]), Int64.Type),
    add_YearStart = Table.AddColumn(add_Year, "YearStart", each Date.StartOfYear([Date]), type date),
    add_YearEnd   = Table.AddColumn(add_YearStart, "YearEnd", each Date.EndOfYear([Date]), type date),
    add_IsLeapYear = Table.AddColumn(add_YearEnd, "IsLeapYear", each Date.DaysInMonth(#date([Year], 2, 1)) = 29, type logical),

    // ----- Mes -----
    add_MonthNumber = Table.AddColumn(add_IsLeapYear, "MonthNumber", each Date.Month([Date]), Int64.Type),
    add_MonthName   = Table.AddColumn(add_MonthNumber, "MonthName", each NombresMes{[MonthNumber] - 1}, type text),
    add_MonthNameShort = Table.AddColumn(add_MonthName, "MonthNameShort", each NombresMesAbrev{[MonthNumber] - 1}, type text),
    add_MonthYear   = Table.AddColumn(add_MonthNameShort, "MonthYear", each [MonthName] & "/" & Text.From([Year]), type text),
    add_MonthYearShort = Table.AddColumn(add_MonthYear, "MonthYearShort", each [MonthNameShort] & "/" & Text.From([Year]), type text),
    add_YearMonth   = Table.AddColumn(add_MonthYearShort, "YearMonth", each Text.From([Year]) & "-" & Text.PadStart(Text.From([MonthNumber]), 2, "0"), type text),
    add_YearMonthNumber = Table.AddColumn(add_YearMonth, "YearMonthNumber", each [Year] * 100 + [MonthNumber], Int64.Type),
    add_MonthStart  = Table.AddColumn(add_YearMonthNumber, "MonthStart", each Date.StartOfMonth([Date]), type date),
    add_MonthEnd    = Table.AddColumn(add_MonthStart, "MonthEnd", each Date.EndOfMonth([Date]), type date),

    // ----- Semestre -----
    add_SemesterNumber = Table.AddColumn(add_MonthEnd, "SemesterNumber", each if [MonthNumber] <= 6 then 1 else 2, Int64.Type),
    add_SemesterName   = Table.AddColumn(add_SemesterNumber, "SemesterName", each (if [SemesterNumber] = 1 then "1.º" else "2.º") & " Semestre", type text),
    add_YearSemesterNumber = Table.AddColumn(add_SemesterName, "YearSemesterNumber", each [Year] * 10 + [SemesterNumber], Int64.Type),
    add_YearSemester   = Table.AddColumn(add_YearSemesterNumber, "YearSemester", each Text.From([Year]) & "-S" & Text.From([SemesterNumber]), type text),

    // ----- Trimestre -----
    add_QuarterNumber = Table.AddColumn(add_YearSemester, "QuarterNumber", each Date.QuarterOfYear([Date]), Int64.Type),
    add_QuarterName   = Table.AddColumn(add_QuarterNumber, "QuarterName", each "T" & Text.From([QuarterNumber]), type text),
    add_YearQuarterNumber = Table.AddColumn(add_QuarterName, "YearQuarterNumber", each [Year] * 10 + [QuarterNumber], Int64.Type),
    add_YearQuarter   = Table.AddColumn(add_YearQuarterNumber, "YearQuarter", each Text.From([Year]) & "-" & [QuarterName], type text),
    add_QuarterStart  = Table.AddColumn(add_YearQuarter, "QuarterStart", each Date.StartOfQuarter([Date]), type date),
    add_QuarterEnd    = Table.AddColumn(add_QuarterStart, "QuarterEnd", each Date.EndOfQuarter([Date]), type date),

    // ----- Día de la semana -----
    add_DayOfWeekName = Table.AddColumn(add_QuarterEnd, "DayOfWeekName", each NombresDiaSemana{Date.DayOfWeek([Date], Day.Sunday)}, type text),
    add_DayOfWeekNameShort = Table.AddColumn(add_DayOfWeekName, "DayOfWeekNameShort", each NombresDiaSemanaAbrev{Date.DayOfWeek([Date], Day.Sunday)}, type text),
    add_IsWeekend = Table.AddColumn(add_DayOfWeekNameShort, "IsWeekend", each Date.DayOfWeek([Date], Day.Sunday) = 0 or Date.DayOfWeek([Date], Day.Sunday) = 6, type logical),
    add_DayOfWeekNumber = Table.AddColumn(add_IsWeekend, "DayOfWeekNumber", each Date.DayOfWeek([Date], DiaInicioSemana) + 1, Int64.Type),

    // ----- Semana local (España: igual a la semana ISO) -----
    add_WeekNumber = Table.AddColumn(add_DayOfWeekNumber, "WeekNumber", each Date.WeekOfYear([Date], DiaInicioSemana), Int64.Type),
    add_WeekStart  = Table.AddColumn(add_WeekNumber, "WeekStart", each Date.StartOfWeek([Date], DiaInicioSemana), type date),
    add_WeekEnd    = Table.AddColumn(add_WeekStart, "WeekEnd", each Date.EndOfWeek([Date], DiaInicioSemana), type date),

    // ----- Semana ISO 8601 -----
    // Semana 1 = la que contiene el primer jueves del año; ISOYear puede
    // diferir de Year en el cambio de año (verificado contra 2026-12-31 ->
    // 2026-W53 y 2027-01-01 -> 2026-W53)
    add_ISOWeekNumber = Table.AddColumn(
        add_WeekEnd, "ISOWeekNumber",
        each let
            juevesDeLaSemana = Date.AddDays([Date], 3 - Date.DayOfWeek([Date], Day.Monday)),
            inicioAnioISO = #date(Date.Year(juevesDeLaSemana), 1, 1),
            difDias = Duration.Days(juevesDeLaSemana - inicioAnioISO)
        in
            Number.IntegerDivide(difDias, 7, 0) + 1,
        Int64.Type
    ),
    add_ISOYear = Table.AddColumn(add_ISOWeekNumber, "ISOYear", each Date.Year(Date.AddDays([Date], 3 - Date.DayOfWeek([Date], Day.Monday))), Int64.Type),
    add_ISOYearWeekNumber = Table.AddColumn(add_ISOYear, "ISOYearWeekNumber", each [ISOYear] * 100 + [ISOWeekNumber], Int64.Type),
    add_ISOYearWeek = Table.AddColumn(add_ISOYearWeekNumber, "ISOYearWeek", each Text.From([ISOYear]) & "-W" & Text.PadStart(Text.From([ISOWeekNumber]), 2, "0"), type text),

    // ----- Estación (definición meteorológica; hemisferio norte) -----
    add_SeasonNumber = Table.AddColumn(
        add_ISOYearWeek, "SeasonNumber",
        each if [MonthNumber] = 12 or [MonthNumber] <= 2 then 1
             else if [MonthNumber] <= 5 then 2
             else if [MonthNumber] <= 8 then 3
             else 4,
        Int64.Type
    ),
    add_Season = Table.AddColumn(add_SeasonNumber, "Season", each NombresEstacion{[SeasonNumber] - 1}, type text),

    // ----- Fiestas (une con la tabla de fiestas) -----
    add_UnionFiestas = Table.NestedJoin(add_Season, {"Date"}, Fiestas, {"Date"}, "InfoFiesta", JoinKind.LeftOuter),
    add_ExpandeFiestas = Table.ExpandTableColumn(add_UnionFiestas, "InfoFiesta", {"HolidayName", "HolidayType", "IsObservedHoliday"}, {"HolidayName", "HolidayType", "IsObservedHoliday"}),
    add_LimpiaObservado = Table.TransformColumns(add_ExpandeFiestas, {{"IsObservedHoliday", each if _ = null then false else _, type logical}}),
    add_IsHoliday = Table.AddColumn(add_LimpiaObservado, "IsHoliday", each [HolidayType] <> null and [HolidayType] <> "Optional", type logical),
    add_IsOptionalDay = Table.AddColumn(add_IsHoliday, "IsOptionalDay", each [HolidayType] = "Optional", type logical),
    add_IsNationalHoliday = Table.AddColumn(add_IsOptionalDay, "IsNationalHoliday", each [HolidayType] = "National", type logical),

    // ----- Día laborable -----
    add_IsBusinessDay = Table.AddColumn(add_IsNationalHoliday, "IsBusinessDay", each not [IsWeekend] and not [IsHoliday], type logical),

    // Índice de día laborable calculado por grupo (mes/año), nunca fila a
    // fila contra toda la tabla — evita O(n²)
    GrupoMes = Table.Group(
        add_IsBusinessDay, {"YearMonthNumber"},
        {
            {"Sub", each
                let
                    ordenado   = Table.Sort(_, {{"Date", Order.Ascending}}),
                    laborables = Table.AddIndexColumn(Table.SelectRows(ordenado, each [IsBusinessDay]), "BusinessDayOfMonth", 1, 1, Int64.Type),
                    noLaborables = Table.AddColumn(Table.SelectRows(ordenado, each not [IsBusinessDay]), "BusinessDayOfMonth", each null, Int64.Type)
                in
                    Table.Combine({laborables, noLaborables}),
             type table}
        }
    ),
    ExpandidoMes = Table.Combine(GrupoMes[Sub]),

    GrupoAnio = Table.Group(
        ExpandidoMes, {"Year"},
        {
            {"Sub", each
                let
                    ordenado   = Table.Sort(_, {{"Date", Order.Ascending}}),
                    laborables = Table.AddIndexColumn(Table.SelectRows(ordenado, each [IsBusinessDay]), "BusinessDayOfYear", 1, 1, Int64.Type),
                    noLaborables = Table.AddColumn(Table.SelectRows(ordenado, each not [IsBusinessDay]), "BusinessDayOfYear", each null, Int64.Type)
                in
                    Table.Combine({laborables, noLaborables}),
             type table}
        }
    ),
    ExpandidoAnio = Table.Sort(Table.Combine(GrupoAnio[Sub]), {{"Date", Order.Ascending}}),

    // ----- Hitos -----
    add_IsMonthStart = Table.AddColumn(ExpandidoAnio, "IsMonthStart", each [Date] = [MonthStart], type logical),
    add_IsMonthEnd   = Table.AddColumn(add_IsMonthStart, "IsMonthEnd", each [Date] = [MonthEnd], type logical),
    add_IsQuarterStart = Table.AddColumn(add_IsMonthEnd, "IsQuarterStart", each [Date] = [QuarterStart], type logical),
    add_IsQuarterEnd   = Table.AddColumn(add_IsQuarterStart, "IsQuarterEnd", each [Date] = [QuarterEnd], type logical),
    add_IsYearStart  = Table.AddColumn(add_IsQuarterEnd, "IsYearStart", each [Date] = [YearStart], type logical),
    add_IsYearEnd    = Table.AddColumn(add_IsYearStart, "IsYearEnd", each [Date] = [YearEnd], type logical),

    // ----- Columnas relativas a hoy -----
    add_AsOfDate = Table.AddColumn(add_IsYearEnd, "AsOfDate", each AsOfDate, type date),
    add_IsToday  = Table.AddColumn(add_AsOfDate, "IsToday", each [Date] = [AsOfDate], type logical),
    add_IsCurrentMonth = Table.AddColumn(add_IsToday, "IsCurrentMonth", each [Year] = Date.Year([AsOfDate]) and [MonthNumber] = Date.Month([AsOfDate]), type logical),
    add_IsCurrentYear  = Table.AddColumn(add_IsCurrentMonth, "IsCurrentYear", each [Year] = Date.Year([AsOfDate]), type logical),

    // ----- Orden final de columnas -----
    Resultado = Table.ReorderColumns(
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
    Resultado
