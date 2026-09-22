// =====================================================================
// DIMENSÃO CALENDÁRIO — pt-BR (Brasil)
// Cole este código inteiro em: Poder BI Desktop > Obter Dados >
// Consulta Nula > Editor Avançado > colar > Concluído.
// Depois: marque a tabela como "Tabela de data" usando a coluna [Date].
// =====================================================================
let
    // =====================================================
    // CONFIGURAÇÃO — altere somente esta data se precisar
    // =====================================================
    StartDate = #date(2020, 1, 1),

    // =====================================================
    // CONFIGURAÇÃO AVANÇADA (opcional; normalmente não altere)
    // =====================================================
    FutureYears       = 1,     // anos completos gerados após o ano atual
    UtcOffsetHours    = -3,    // fuso horário de Brasília, usado para definir "hoje"
    AsOfDateOverride  = null,  // ex.: #date(2026,9,22) para testar; null = usar hoje

    // =====================================================
    // DATA DE REFERÊNCIA ("hoje") E LIMITES DO CALENDÁRIO
    // =====================================================
    // DateTime.LocalNow() no serviço do Power BI usa o horário do servidor
    // (UTC), o que erra "hoje" à noite no Brasil. Por isso ajustamos o fuso
    // manualmente em vez de usar a hora local da máquina.
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

    VerificacaoIntervalo =
        if StartDate > EndDate then
            error Error.Record(
                "Calendar.IntervaloInvalido",
                "StartDate é posterior a EndDate. Verifique a data de início.",
                [StartDate = StartDate, EndDate = EndDate]
            )
        else
            true,

    // =====================================================
    // NOMES LOCALIZADOS (listas fixas; não usam Date.ToText com cultura,
    // para não variar maiúsculas/abreviações entre versões do motor)
    // =====================================================
    NomesMes = {
        "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
        "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
    },
    NomesMesAbrev = {"Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"},
    // Índice 0 = Domingo, ..., 6 = Sábado (independe do dia inicial da semana)
    NomesDiaSemana = {"Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado"},
    NomesDiaSemanaAbrev = {"Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"},
    // Índice 0 = Verão (hemisfério sul: dez-fev), 1 = Outono, 2 = Inverno, 3 = Primavera
    NomesEstacao = {"Verão", "Outono", "Inverno", "Primavera"},
    DiaInicioSemana = Day.Sunday,

    // =====================================================
    // PÁSCOA — algoritmo de Meeus/Jones/Butcher (calendário gregoriano)
    // Conferido manualmente contra 2000-04-23 e 2026-04-05: correto.
    // =====================================================
    fnPascoa = (ano as number) as date =>
        let
            a = Number.Mod(ano, 19),
            b = Number.IntegerDivide(ano, 100),
            c = Number.Mod(ano, 100),
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
            #date(ano, mes, dia),

    // =====================================================
    // FERIADOS — gerados por ano (nunca linha a linha)
    // HolidayType: "National" (fecha o expediente) ou "Optional" (ponto facultativo)
    // =====================================================
    fnFeriadosFixos = (ano as number) as list =>
        {
              {#date(ano, 1, 1),  "Confraternização Universal",  "National", false}
            , {#date(ano, 4, 21), "Tiradentes",                   "National", false}
            , {#date(ano, 5, 1),  "Dia do Trabalho",               "National", false}
            , {#date(ano, 9, 7),  "Independência do Brasil",       "National", false}
            , {#date(ano, 10, 12),"Nossa Senhora Aparecida",       "National", false}
            , {#date(ano, 11, 2), "Finados",                       "National", false}
            , {#date(ano, 11, 15),"Proclamação da República",      "National", false}
            , {#date(ano, 12, 25),"Natal",                         "National", false}
        }
        & (
            if ano >= 2024 then
                {{#date(ano, 11, 20), "Dia Nacional de Zumbi e da Consciência Negra", "National", false}}
            else
                {}
          ),

    fnFeriadosMoveis = (ano as number) as list =>
        let
            pascoa = fnPascoa(ano)
        in
            {
                  {Date.AddDays(pascoa, -48), "Carnaval (segunda-feira)", "Optional", false}
                , {Date.AddDays(pascoa, -47), "Carnaval (terça-feira)",   "Optional", false}
                , {Date.AddDays(pascoa, -46), "Quarta-feira de Cinzas",   "Optional", false}
                , {Date.AddDays(pascoa, -2),  "Sexta-feira Santa",        "National", false}
                , {Date.AddDays(pascoa, 60),  "Corpus Christi",           "Optional", false}
                , {#date(ano, 12, 24),        "Véspera de Natal",         "Optional", false}
                , {#date(ano, 12, 31),        "Véspera de Ano-Novo",      "Optional", false}
            },

    // Gera um ano a mais em cada ponta por segurança (não afeta o resultado:
    // linhas fora de [StartDate, EndDate] simplesmente não casam no join)
    AnosParaFeriados = List.Buffer({Date.Year(StartDate) - 1 .. Date.Year(EndDate) + 1}),
    LinhasFeriados = List.Combine(List.Transform(AnosParaFeriados, each fnFeriadosFixos(_) & fnFeriadosMoveis(_))),
    TabelaFeriadosBruta = #table(
        type table [Date = date, HolidayName = text, HolidayType = text, IsObservedHoliday = logical],
        LinhasFeriados
    ),

    // Duas regras na mesma data (ex.: Tiradentes = Sexta-feira Santa em 2000):
    // concatena nomes, mantém o tipo mais restritivo, nunca duplica a linha
    TabelaFeriados = Table.Buffer(
        Table.Group(
            TabelaFeriadosBruta, {"Date"},
            {
                  {"HolidayName", each Text.Combine(_[HolidayName], " / "), type text}
                , {"HolidayType", each
                        let naoOpcionais = List.Select(_[HolidayType], each _ <> "Optional")
                        in if List.Count(naoOpcionais) > 0 then naoOpcionais{0} else "Optional",
                   type text}
                , {"IsObservedHoliday", each List.Contains(_[IsObservedHoliday], true), type logical}
            }
        )
    ),

    // =====================================================
    // TABELA BASE DE DATAS
    // =====================================================
    ListaDatas = List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1, 0, 0, 0)),
    TabelaBase = Table.TransformColumnTypes(
        Table.FromList(ListaDatas, Splitter.SplitByNothing(), {"Date"}),
        {{"Date", type date}}
    ),

    // ----- Data -----
    add_DateKey  = Table.AddColumn(TabelaBase, "DateKey", each Date.Year([Date]) * 10000 + Date.Month([Date]) * 100 + Date.Day([Date]), Int64.Type),
    add_DayOfMonth = Table.AddColumn(add_DateKey, "DayOfMonth", each Date.Day([Date]), Int64.Type),
    add_DayOfYear  = Table.AddColumn(add_DayOfMonth, "DayOfYear", each Date.DayOfYear([Date]), Int64.Type),

    // ----- Ano -----
    add_Year      = Table.AddColumn(add_DayOfYear, "Year", each Date.Year([Date]), Int64.Type),
    add_YearStart = Table.AddColumn(add_Year, "YearStart", each Date.StartOfYear([Date]), type date),
    add_YearEnd   = Table.AddColumn(add_YearStart, "YearEnd", each Date.EndOfYear([Date]), type date),
    add_IsLeapYear = Table.AddColumn(add_YearEnd, "IsLeapYear", each Date.DaysInMonth(#date([Year], 2, 1)) = 29, type logical),

    // ----- Mês -----
    add_MonthNumber = Table.AddColumn(add_IsLeapYear, "MonthNumber", each Date.Month([Date]), Int64.Type),
    add_MonthName   = Table.AddColumn(add_MonthNumber, "MonthName", each NomesMes{[MonthNumber] - 1}, type text),
    add_MonthNameShort = Table.AddColumn(add_MonthName, "MonthNameShort", each NomesMesAbrev{[MonthNumber] - 1}, type text),
    add_MonthYear   = Table.AddColumn(add_MonthNameShort, "MonthYear", each [MonthName] & "/" & Text.From([Year]), type text),
    add_MonthYearShort = Table.AddColumn(add_MonthYear, "MonthYearShort", each [MonthNameShort] & "/" & Text.From([Year]), type text),
    add_YearMonth   = Table.AddColumn(add_MonthYearShort, "YearMonth", each Text.From([Year]) & "-" & Text.PadStart(Text.From([MonthNumber]), 2, "0"), type text),
    add_YearMonthNumber = Table.AddColumn(add_YearMonth, "YearMonthNumber", each [Year] * 100 + [MonthNumber], Int64.Type),
    add_MonthStart  = Table.AddColumn(add_YearMonthNumber, "MonthStart", each Date.StartOfMonth([Date]), type date),
    add_MonthEnd    = Table.AddColumn(add_MonthStart, "MonthEnd", each Date.EndOfMonth([Date]), type date),

    // ----- Semestre -----
    add_SemesterNumber = Table.AddColumn(add_MonthEnd, "SemesterNumber", each if [MonthNumber] <= 6 then 1 else 2, Int64.Type),
    add_SemesterName   = Table.AddColumn(add_SemesterNumber, "SemesterName", each (if [SemesterNumber] = 1 then "1º" else "2º") & " Semestre", type text),
    add_YearSemesterNumber = Table.AddColumn(add_SemesterName, "YearSemesterNumber", each [Year] * 10 + [SemesterNumber], Int64.Type),
    add_YearSemester   = Table.AddColumn(add_YearSemesterNumber, "YearSemester", each Text.From([Year]) & "-S" & Text.From([SemesterNumber]), type text),

    // ----- Trimestre -----
    add_QuarterNumber = Table.AddColumn(add_YearSemester, "QuarterNumber", each Date.QuarterOfYear([Date]), Int64.Type),
    add_QuarterName   = Table.AddColumn(add_QuarterNumber, "QuarterName", each "T" & Text.From([QuarterNumber]), type text),
    add_YearQuarterNumber = Table.AddColumn(add_QuarterName, "YearQuarterNumber", each [Year] * 10 + [QuarterNumber], Int64.Type),
    add_YearQuarter   = Table.AddColumn(add_YearQuarterNumber, "YearQuarter", each Text.From([Year]) & "-" & [QuarterName], type text),
    add_QuarterStart  = Table.AddColumn(add_YearQuarter, "QuarterStart", each Date.StartOfQuarter([Date]), type date),
    add_QuarterEnd    = Table.AddColumn(add_QuarterStart, "QuarterEnd", each Date.EndOfQuarter([Date]), type date),

    // ----- Dia da semana -----
    add_DayOfWeekName = Table.AddColumn(add_QuarterEnd, "DayOfWeekName", each NomesDiaSemana{Date.DayOfWeek([Date], Day.Sunday)}, type text),
    add_DayOfWeekNameShort = Table.AddColumn(add_DayOfWeekName, "DayOfWeekNameShort", each NomesDiaSemanaAbrev{Date.DayOfWeek([Date], Day.Sunday)}, type text),
    add_IsWeekend = Table.AddColumn(add_DayOfWeekNameShort, "IsWeekend", each Date.DayOfWeek([Date], Day.Sunday) = 0 or Date.DayOfWeek([Date], Day.Sunday) = 6, type logical),
    add_DayOfWeekNumber = Table.AddColumn(add_IsWeekend, "DayOfWeekNumber", each Date.DayOfWeek([Date], DiaInicioSemana) + 1, Int64.Type),

    // ----- Semana local -----
    add_WeekNumber = Table.AddColumn(add_DayOfWeekNumber, "WeekNumber", each Date.WeekOfYear([Date], DiaInicioSemana), Int64.Type),
    add_WeekStart  = Table.AddColumn(add_WeekNumber, "WeekStart", each Date.StartOfWeek([Date], DiaInicioSemana), type date),
    add_WeekEnd    = Table.AddColumn(add_WeekStart, "WeekEnd", each Date.EndOfWeek([Date], DiaInicioSemana), type date),

    // ----- Semana ISO 8601 (independe do dia inicial da localidade) -----
    // Semana 1 = a que contém a primeira quinta-feira do ano; ISOYear pode
    // divergir de Year na virada do ano (conferido contra 2026-12-31 -> 2026-W53
    // e 2027-01-01 -> 2026-W53)
    add_ISOWeekNumber = Table.AddColumn(
        add_WeekEnd, "ISOWeekNumber",
        each let
            quintaDaSemana = Date.AddDays([Date], 3 - Date.DayOfWeek([Date], Day.Monday)),
            inicioAnoISO = #date(Date.Year(quintaDaSemana), 1, 1),
            diffDias = Duration.Days(quintaDaSemana - inicioAnoISO)
        in
            Number.IntegerDivide(diffDias, 7, 0) + 1,
        Int64.Type
    ),
    add_ISOYear = Table.AddColumn(add_ISOWeekNumber, "ISOYear", each Date.Year(Date.AddDays([Date], 3 - Date.DayOfWeek([Date], Day.Monday))), Int64.Type),
    add_ISOYearWeekNumber = Table.AddColumn(add_ISOYear, "ISOYearWeekNumber", each [ISOYear] * 100 + [ISOWeekNumber], Int64.Type),
    add_ISOYearWeek = Table.AddColumn(add_ISOYearWeekNumber, "ISOYearWeek", each Text.From([ISOYear]) & "-W" & Text.PadStart(Text.From([ISOWeekNumber]), 2, "0"), type text),

    // ----- Estação (definição meteorológica; hemisfério sul) -----
    add_SeasonNumber = Table.AddColumn(
        add_ISOYearWeek, "SeasonNumber",
        each if [MonthNumber] = 12 or [MonthNumber] <= 2 then 1
             else if [MonthNumber] <= 5 then 2
             else if [MonthNumber] <= 8 then 3
             else 4,
        Int64.Type
    ),
    add_Season = Table.AddColumn(add_SeasonNumber, "Season", each NomesEstacao{[SeasonNumber] - 1}, type text),

    // ----- Feriados (junta com a tabela de feriados) -----
    add_JuncaoFeriados = Table.NestedJoin(add_Season, {"Date"}, TabelaFeriados, {"Date"}, "InfoFeriado", JoinKind.LeftOuter),
    add_ExpandeFeriados = Table.ExpandTableColumn(add_JuncaoFeriados, "InfoFeriado", {"HolidayName", "HolidayType", "IsObservedHoliday"}, {"HolidayName", "HolidayType", "IsObservedHoliday"}),
    add_LimpaObservado = Table.TransformColumns(add_ExpandeFeriados, {{"IsObservedHoliday", each if _ = null then false else _, type logical}}),
    add_IsHoliday = Table.AddColumn(add_LimpaObservado, "IsHoliday", each [HolidayType] <> null and [HolidayType] <> "Optional", type logical),
    add_IsOptionalDay = Table.AddColumn(add_IsHoliday, "IsOptionalDay", each [HolidayType] = "Optional", type logical),
    add_IsNationalHoliday = Table.AddColumn(add_IsOptionalDay, "IsNationalHoliday", each [HolidayType] = "National", type logical),

    // ----- Dia útil -----
    // Ponto facultativo conta como dia útil por padrão (documentado no README).
    // Use [IsOptionalDay] em DAX se precisar tratá-lo como não útil.
    add_IsBusinessDay = Table.AddColumn(add_IsNationalHoliday, "IsBusinessDay", each not [IsWeekend] and not [IsHoliday], type logical),

    // Índice de dia útil calculado por grupo (mês/ano), nunca linha a linha
    // contra a tabela inteira — evita O(n²)
    GrupoMes = Table.Group(
        add_IsBusinessDay, {"YearMonthNumber"},
        {
            {"Sub", each
                let
                    ordenado   = Table.Sort(_, {{"Date", Order.Ascending}}),
                    uteis      = Table.AddIndexColumn(Table.SelectRows(ordenado, each [IsBusinessDay]), "BusinessDayOfMonth", 1, 1, Int64.Type),
                    naoUteis   = Table.AddColumn(Table.SelectRows(ordenado, each not [IsBusinessDay]), "BusinessDayOfMonth", each null, Int64.Type)
                in
                    Table.Combine({uteis, naoUteis}),
             type table}
        }
    ),
    ExpandidoMes = Table.Combine(GrupoMes[Sub]),

    GrupoAno = Table.Group(
        ExpandidoMes, {"Year"},
        {
            {"Sub", each
                let
                    ordenado   = Table.Sort(_, {{"Date", Order.Ascending}}),
                    uteis      = Table.AddIndexColumn(Table.SelectRows(ordenado, each [IsBusinessDay]), "BusinessDayOfYear", 1, 1, Int64.Type),
                    naoUteis   = Table.AddColumn(Table.SelectRows(ordenado, each not [IsBusinessDay]), "BusinessDayOfYear", each null, Int64.Type)
                in
                    Table.Combine({uteis, naoUteis}),
             type table}
        }
    ),
    ExpandidoAno = Table.Sort(Table.Combine(GrupoAno[Sub]), {{"Date", Order.Ascending}}),

    // ----- Marcos -----
    add_IsMonthStart = Table.AddColumn(ExpandidoAno, "IsMonthStart", each [Date] = [MonthStart], type logical),
    add_IsMonthEnd   = Table.AddColumn(add_IsMonthStart, "IsMonthEnd", each [Date] = [MonthEnd], type logical),
    add_IsQuarterStart = Table.AddColumn(add_IsMonthEnd, "IsQuarterStart", each [Date] = [QuarterStart], type logical),
    add_IsQuarterEnd   = Table.AddColumn(add_IsQuarterStart, "IsQuarterEnd", each [Date] = [QuarterEnd], type logical),
    add_IsYearStart  = Table.AddColumn(add_IsQuarterEnd, "IsYearStart", each [Date] = [YearStart], type logical),
    add_IsYearEnd    = Table.AddColumn(add_IsYearStart, "IsYearEnd", each [Date] = [YearEnd], type logical),

    // ----- Colunas relativas a hoje -----
    add_AsOfDate = Table.AddColumn(add_IsYearEnd, "AsOfDate", each AsOfDate, type date),
    add_IsToday  = Table.AddColumn(add_AsOfDate, "IsToday", each [Date] = [AsOfDate], type logical),
    add_IsCurrentMonth = Table.AddColumn(add_IsToday, "IsCurrentMonth", each [Year] = Date.Year([AsOfDate]) and [MonthNumber] = Date.Month([AsOfDate]), type logical),
    add_IsCurrentYear  = Table.AddColumn(add_IsCurrentMonth, "IsCurrentYear", each [Year] = Date.Year([AsOfDate]), type logical),

    // ----- Ordem final das colunas -----
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
