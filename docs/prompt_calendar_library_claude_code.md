# TAREFA: Biblioteca de Dimensão Calendário para Power BI (Power Query / M)

<papel>
Você é um engenheiro sênior de Power BI e Power Query (M), com experiência em modelagem dimensional e em bibliotecas reutilizáveis. Você prioriza correção sobre esperteza e declara explicitamente tudo o que não conseguiu verificar.
</papel>

<regras_inegociaveis>
Leia antes de qualquer ação. Estas regras prevalecem sobre qualquer outra instrução deste documento.

1. CORREÇÃO ACIMA DE TUDO. Ordem de prioridade: Correção > Confiabilidade > Simplicidade de uso > Manutenibilidade > Performance > Quantidade de colunas.
2. HONESTIDADE SOBRE VERIFICAÇÃO. Você NÃO tem um motor de Power Query neste ambiente. NUNCA afirme que o código M "foi testado" ou "funciona" se ele não foi executado. Separe sempre: (a) verificado por execução, (b) verificado por parser/sintaxe, (c) verificado apenas por revisão, (d) depende de execução no Power BI Desktop pelo usuário.
3. 100% OFFLINE. O código M final NUNCA usa `Web.Contents`, APIs, arquivos externos, bancos ou outras consultas. Feriados são calculados pelo próprio código.
4. FATOS JURÍDICOS COM FONTE. Toda regra de feriado DEVE ter fonte citada no documento `documentation/holidays.md` (lei, decreto, portaria, BOE, OPM). Se não conseguir confirmar uma regra, marque como `[a confirmar]` e pergunte; NUNCA invente.
5. ESCOPO NO REPOSITÓRIO. Trabalhe na branch `feature/calendar-library-v1`. NÃO apague, mova ou altere arquivos existentes fora do escopo desta tarefa. NÃO faça push, merge ou alteração de licença sem aprovação explícita.
6. SEM EXCESSO. Faça apenas o especificado. Não adicione colunas, recursos ou abstrações além deste documento. Se achar que algo falta, proponha no checkpoint; não implemente por conta própria.
7. PARE NOS CHECKPOINTS. Há dois pontos de parada obrigatórios (seção 11). Não avance sem aprovação.
</regras_inegociaveis>

---

## 1. Contexto

Repositório de referência (já clonado no diretório atual; se não estiver, clone):
`https://github.com/nelsongeraidine/calendar_periods_time_tables_power_bi`

Use o repositório apenas para entender estilo, nomenclatura e organização. NÃO replique as tabelas de períodos nem as tabelas de tempo existentes. O objetivo é uma dimensão calendário nova, mais robusta e documentada.

## 2. Objetivo e experiência do usuário final

Entregar 3 arquivos `.pq` independentes (Brasil, EUA, Espanha). O usuário final:

1. abre o arquivo no GitHub e copia o código;
2. no Power BI Desktop: Obter Dados → Consulta Nula → Editor Avançado;
3. cola o código, altera somente `StartDate` (se quiser) e clica em Concluído;
4. carrega a tabela e a marca como tabela de datas.

O topo de cada arquivo DEVE ter exatamente esta estrutura de configuração:

```powerquery
let
    // =====================================================
    // CONFIGURAÇÃO DO CALENDÁRIO
    // Altere somente esta data
    // =====================================================
    StartDate = #date(2020, 1, 1),

    // =====================================================
    // CONFIGURAÇÃO AVANÇADA (opcional; normalmente não altere)
    // =====================================================
    FutureYears          = 1,     // anos completos gerados após o ano atual
    UtcOffsetHours       = -3,    // fuso usado para definir "hoje" (ver seção 7)
    FiscalYearStartMonth = 1,     // 1 = ano fiscal igual ao ano-calendário
    AsOfDateOverride     = null,  // ex.: #date(2026, 9, 22) para testes; null = hoje
```

Valores padrão de `UtcOffsetHours`: pt-BR = -3; en-US = -5; es-ES = 1.

Regras derivadas:
- `EndDate = Date.EndOfYear(AsOfDate) + FutureYears anos` (ou seja, 31/12 de `Year(AsOfDate) + FutureYears`).
- Se `StartDate > EndDate`, a consulta DEVE falhar com erro explícito e mensagem clara (`error Error.Record(...)`), nunca retornar tabela vazia.

## 3. Arquitetura

Os 3 arquivos finais são autocontidos para o usuário, mas NÃO devem ser mantidos como 3 cópias editadas à mão.

- `src/`: núcleo comum (template) + um bloco por localidade (nomes, feriados, convenções de semana).
- `build/build.py`: gera os 3 arquivos finais em `powerquery_code/` a partir de `src/`. Cada arquivo gerado começa com o comentário `// ARQUIVO GERADO AUTOMATICAMENTE A PARTIR DE src/. NÃO EDITE DIRETAMENTE.`, seguido da versão da biblioteca.
- Proponha o mecanismo exato (placeholders, concatenação) no Checkpoint 1.

Estrutura alvo (adapte ao repositório existente se houver organização melhor, justificando no Checkpoint 1):

```text
/
├── README.md
├── CHANGELOG.md
├── LICENSE                     (somente após aprovação; ver seção 10)
├── powerquery_code/            (arquivos finais que o usuário copia)
│   ├── calendar_pt-BR.pq
│   ├── calendar_en-US.pq
│   └── calendar_es-ES.pq
├── src/                        (fonte única)
├── build/build.py
├── documentation/
│   ├── calendar-columns.md
│   ├── holidays.md
│   └── usage.md
└── tests/
    ├── oracle/                 (implementação de referência em Python)
    ├── golden/                 (valores esperados em CSV)
    ├── calendar_pt-BR_tests.pq
    ├── calendar_en-US_tests.pq
    ├── calendar_es-ES_tests.pq
    └── calendar_health_check.pq
```

### Diretrizes de código M

- Nomes de colunas em INGLÊS e IDÊNTICOS nas 3 versões (medidas DAX funcionam em qualquer versão). Somente os VALORES são localizados.
- Nomes de meses e dias vêm de listas fixas no bloco de localidade, NÃO de `Date.ToText` com cultura (evita variação de maiúsculas e abreviações entre versões do motor). Primeira letra maiúscula nas 3 línguas.
- Calcule feriados por ANO (lista pequena, com `List.Buffer`) e cruze com as datas; NUNCA recalcule a Páscoa linha a linha.
- Índices de dia útil com `Table.Group` por mês/ano + índice dentro do grupo; NUNCA contagem filtrada linha a linha (O(n²)).
- Declare o tipo de cada coluna na criação (`Int64.Type`, `type date`, `type text`, `type logical`). Zero colunas do tipo `any` no resultado final.
- Ausência de valor = `null`, nunca string vazia.
- Comentários por seção; sem nomes genéricos (`x`, `temp`, `Custom1`).

## 4. Especificação de colunas

Somente estas colunas. Tipos: I = `Int64.Type`, D = `date`, T = `text`, L = `logical`.

| Grupo | Coluna | Tipo | Regra / exemplo (pt-BR, 22/09/2026) |
|---|---|---|---|
| Data | Date | D | 22/09/2026 |
| | DateKey | I | 20260922 (AAAAMMDD) |
| | DayOfMonth | I | 22 |
| | DayOfYear | I | 265 |
| Ano | Year | I | 2026 |
| | YearName | T | "2026" (texto, para segmentações) |
| | YearStart / YearEnd | D | 01/01/2026 / 31/12/2026 |
| | IsLeapYear | L | false |
| Semestre | SemesterNumber | I | 2 |
| | SemesterName | T | "2º Semestre" / "H2" / "2.º Semestre" |
| | YearSemester | T | "2026-S2" (sufixo localizado) |
| | YearSemesterNumber | I | 20262 |
| | SemesterStart / SemesterEnd | D | |
| Trimestre | QuarterNumber | I | 3 |
| | QuarterName | T | "T3" / "Q3" / "T3" |
| | YearQuarter | T | "2026-T3" |
| | YearQuarterNumber | I | 20263 |
| | QuarterStart / QuarterEnd | D | |
| Bimestre | BimesterNumber | I | 5 |
| | BimesterName | T | "5º Bimestre" (localizado) |
| | YearBimester | T | "2026-B5" |
| | YearBimesterNumber | I | 20265 |
| | BimesterStart / BimesterEnd | D | |
| Mês | MonthNumber | I | 9 |
| | MonthName | T | "Setembro" |
| | MonthShortName | T | "Set" |
| | MonthYear | T | "Setembro/2026" |
| | MonthYearShort | T | "Set/2026" |
| | YearMonth | T | "2026-09" |
| | YearMonthNumber | I | 202609 |
| | MonthStart / MonthEnd | D | |
| Quinzena | FortnightNumber | I | 1 ou 2 (dentro do mês; 1 = dias 1 a 15, 2 = dia 16 ao fim) |
| | FortnightName | T | "2ª Quinzena" (localizado) |
| | YearMonthFortnightNumber | I | 2026092 (ordenação) |
| | FortnightStart / FortnightEnd | D | |
| Semana local | WeekNumber | I | ver seção 5 |
| | WeekName | T | "S39" / "W39" / "S39" |
| | WeekStart / WeekEnd | D | conforme dia inicial da localidade |
| | DayOfWeekNumber | I | 1 a 7, começando no dia inicial da localidade |
| | DayOfWeekName / DayOfWeekShortName | T | "Terça-feira" / "Ter" |
| | IsWeekend | L | sábado ou domingo nas 3 versões |
| Semana ISO | ISOWeekNumber | I | 1 a 53 |
| | ISOYear | I | pode diferir de Year na virada do ano |
| | ISOYearWeek | T | "2026-W39" |
| | ISOYearWeekNumber | I | 202639 |
| Estação | SeasonNumber | I | ver seção 5 |
| | Season | T | "Primavera" |
| Fiscal | FiscalYear | I | ano em que o exercício fiscal TERMINA |
| | FiscalQuarter | I | 1 a 4 |
| | FiscalMonth | I | 1 a 12 |
| Feriados | IsHoliday | L | ver seção 6 |
| | HolidayName | T | null quando não há |
| | HolidayType | T | National, Federal, Optional, Other (Regional e Municipal reservados para extensão) |
| | IsNationalHoliday | L | |
| | IsOptionalDay | L | |
| | IsObservedHoliday | L | true só na data deslocada (EUA); false nas demais versões |
| Dia útil | IsBusinessDay | L | ver seção 6 |
| | BusinessDayOfMonth | I | 1, 2, 3...; null em dia não útil |
| | BusinessDayOfYear | I | idem, no ano |
| | IsFirstBusinessDayOfMonth / IsLastBusinessDayOfMonth | L | |
| Marcos | IsMonthStart, IsMonthEnd, IsQuarterStart, IsQuarterEnd, IsYearStart, IsYearEnd | L | |
| Relativos | AsOfDate | D | data de referência usada (constante) |
| | IsToday, IsCurrentMonth, IsCurrentQuarter, IsCurrentYear | L | |
| | RelativeDay | I | Date − AsOfDate em dias (0 = hoje, −1 = ontem) |
| | RelativeWeek | I | diferença em semanas ISO |
| | RelativeMonth, RelativeQuarter, RelativeYear | I | diferença em períodos-calendário |

Colunas de ordenação ("Classificar por coluna" no Power BI):
MonthName, MonthShortName → MonthNumber; MonthYear, MonthYearShort → YearMonthNumber; QuarterName → QuarterNumber; YearQuarter → YearQuarterNumber; SemesterName → SemesterNumber; YearSemester → YearSemesterNumber; BimesterName → BimesterNumber; YearBimester → YearBimesterNumber; FortnightName → FortnightNumber; DayOfWeekName, DayOfWeekShortName → DayOfWeekNumber; ISOYearWeek → ISOYearWeekNumber; WeekName → WeekNumber; Season → SeasonNumber.
Todo par DEVE ter relação 1 para 1 (exigência do Power BI).

## 5. Convenções de calendário

### Semanas

| Versão | Dia inicial (WeekStart, DayOfWeekNumber = 1) | WeekNumber |
|---|---|---|
| pt-BR | Domingo | `Date.WeekOfYear(Date, Day.Sunday)`: semana parcial de 1º de janeiro é a semana 1 |
| en-US | Domingo | `Date.WeekOfYear(Date, Day.Sunday)` (convenção usual nos EUA) |
| es-ES | Segunda-feira | igual a ISOWeekNumber (a Espanha usa ISO 8601) |

ISO 8601 (as 3 versões): semana começa na segunda; a semana 1 é a que contém a primeira quinta-feira do ano; ISOYear é o ano da quinta-feira daquela semana. NUNCA assuma `ISOYear = Year`.

Documente as três definições no README com um exemplo de data em que divergem.

### Estações

Use a definição METEOROLÓGICA (meses completos), documentada como tal:
- pt-BR (hemisfério sul): Verão dez–fev (1), Outono mar–mai (2), Inverno jun–ago (3), Primavera set–nov (4).
- en-US e es-ES (hemisfério norte): Winter/Invierno dez–fev (1), Spring/Primavera mar–mai (2), Summer/Verano jun–ago (3), Fall/Otoño set–nov (4).

### Calendário fiscal

Com `FiscalYearStartMonth = 1`, FiscalYear = Year. Com outro valor (ex.: 4), o exercício de abril/2026 a março/2027 é FiscalYear 2027. FiscalMonth 1 = mês de início.

## 6. Feriados e dias úteis

### 6.1 Semântica comum (as 3 versões)

- Feriados são gerados para todos os anos de `Year(StartDate)` até `Year(EndDate) + 1` (o ano extra captura feriados observados que caem no ano anterior) e depois filtrados para o intervalo.
- Cada regra tem vigência (`ValidFrom`, `ValidTo`). Um feriado NUNCA aparece antes da lei que o criou.
- `IsHoliday = true` somente para dias de feriado que interrompem o expediente (tipos National, Federal ou Other). Pontos facultativos: `IsHoliday = false`, `IsOptionalDay = true`, `HolidayName` preenchido.
- `IsNationalHoliday = true` para HolidayType National (pt-BR, es-ES) e Federal (en-US).
- Duas regras na mesma data: `HolidayName` concatena com " / " e `HolidayType` assume o tipo mais restritivo (National/Federal > Other > Optional). NUNCA duplique a linha.
- Lista de EXCEÇÕES (overrides) no bloco de localidade: tabela `#table` com Date, Name, Type para fechamentos decretados que nenhuma regra prevê. Documente como adicionar novas linhas.
- `IsBusinessDay = not IsWeekend and not IsHoliday`. Pontos facultativos CONTAM como dia útil por padrão. Documente isso no README e explique como o usuário que precisa tratá-los como não úteis (ex.: Carnaval para o setor bancário) pode usar `IsOptionalDay` em DAX.

### 6.2 Páscoa

Algoritmo de Meeus/Jones/Butcher (calendário gregoriano), implementado como função interna. NUNCA use lista fixa de datas.

### 6.3 Brasil (pt-BR)

| Nome (HolidayName) | Regra | Tipo | Vigência / observação |
|---|---|---|---|
| Confraternização Universal | 01/01 | National | Lei 10.607/2002 |
| Carnaval (segunda-feira) | Páscoa − 48 | Optional | ponto facultativo federal |
| Carnaval (terça-feira) | Páscoa − 47 | Optional | ponto facultativo federal |
| Quarta-feira de Cinzas | Páscoa − 46 | Optional | facultativo até 14h |
| Sexta-feira Santa | Páscoa − 2 | National | ver nota abaixo |
| Tiradentes | 21/04 | National | |
| Dia do Trabalho | 01/05 | National | |
| Corpus Christi | Páscoa + 60 | Optional | ponto facultativo federal |
| Independência do Brasil | 07/09 | National | |
| Nossa Senhora Aparecida | 12/10 | National | Lei 6.802/1980 |
| Finados | 02/11 | National | |
| Proclamação da República | 15/11 | National | |
| Dia Nacional de Zumbi e da Consciência Negra | 20/11 | National | Lei 14.759/2023; somente a partir de 2024 |
| Véspera de Natal | 24/12 | Optional | facultativo após 14h |
| Natal | 25/12 | National | |
| Véspera de Ano-Novo | 31/12 | Optional | facultativo após 14h |

Nota sobre a Sexta-feira Santa: pela Lei 9.093/1995 ela é feriado religioso declarado por lei municipal, mas as portarias federais anuais a listam como feriado e a adoção é praticamente universal. Decisão: classificar como National e documentar esta nota em `holidays.md`.
Fora do escopo (documentar): Dia do Servidor Público (28/10, frequentemente transferido por portaria), feriados estaduais e municipais.

### 6.4 Estados Unidos (en-US)

Feriados federais conforme 5 U.S.C. 6103. `HolidayType = Federal`.

| HolidayName | Regra | Vigência |
|---|---|---|
| New Year's Day | Jan 1 | |
| Martin Luther King Jr. Day | 3ª segunda de janeiro | a partir de 1986 |
| Washington's Birthday | 3ª segunda de fevereiro | |
| Memorial Day | última segunda de maio | |
| Juneteenth National Independence Day | Jun 19 | a partir de 2021 |
| Independence Day | Jul 4 | |
| Labor Day | 1ª segunda de setembro | |
| Columbus Day | 2ª segunda de outubro | nome oficial na lei federal; mencionar Indigenous Peoples' Day apenas na documentação |
| Veterans Day | Nov 11 | |
| Thanksgiving Day | 4ª quinta de novembro | |
| Christmas Day | Dec 25 | |

Regra de observância (feriados de data fixa): sábado → sexta anterior; domingo → segunda seguinte.
- Na data deslocada: `HolidayName = "<nome> (Observed)"`, `IsObservedHoliday = true`, `IsHoliday = true`.
- Na data oficial (fim de semana): `HolidayName = "<nome>"`, `IsHoliday = true`.
- Caso obrigatório: New Year's Day em sábado é observado em 31/12 do ANO ANTERIOR (ex.: 01/01/2022 → 31/12/2021).

Exceções (overrides), tipo Other: fechamentos federais por ordem executiva ou luto oficial. Pesquise na OPM (opm.gov) e inclua SOMENTE os confirmados com fonte. Candidatos a verificar: 2018-12-05, 2018-12-24, 2019-12-24, 2020-12-24, 2024-12-24, 2025-01-09. Fora do escopo: Inauguration Day (só região de Washington DC) e feriados estaduais.

### 6.5 Espanha (es-ES)

Fiestas de ámbito nacional. `HolidayType = National`.

| HolidayName | Regra |
|---|---|
| Año Nuevo | 01/01 |
| Epifanía del Señor | 06/01 |
| Viernes Santo | Páscoa − 2 |
| Fiesta del Trabajo | 01/05 |
| Asunción de la Virgen | 15/08 |
| Fiesta Nacional de España | 12/10 |
| Todos los Santos | 01/11 |
| Día de la Constitución Española | 06/12 |
| Inmaculada Concepción | 08/12 |
| Natividad del Señor | 25/12 |

Verifique no BOE (Real Decreto 2001/1983, art. 45, e resoluções anuais) quais destes podem ser substituídos pelas Comunidades Autônomas e documente. O `holidays.md` e o README DEVEM avisar que o calendário oficial é publicado anualmente no BOE, que as Comunidades podem substituir ou trasladar feriados (ex.: de domingo para segunda) e que esta versão é uma aproximação algorítmica do núcleo nacional. Fora do escopo: Jueves Santo, Lunes de Pascua, 19/03, 25/07 e traslados autonômicos.

## 7. Data de referência e fuso horário

`DateTime.LocalNow()` no Power BI Service retorna o horário do servidor (UTC), o que desloca "hoje" à noite no Brasil. Use:

```powerquery
AsOfDate = if AsOfDateOverride <> null then AsOfDateOverride
           else Date.From(DateTimeZone.RemoveZone(
                    DateTimeZone.SwitchZone(DateTimeZone.UtcNow(), UtcOffsetHours))),
```

Documente: colunas relativas e `EndDate` mudam a cada atualização do modelo; en-US e es-ES usam deslocamento fixo e podem errar em até 1 hora durante o horário de verão (M não tem base de fusos horários).

## 8. Validação (sem motor M disponível)

Estratégia de teste diferencial obrigatória:

1. **Oráculo Python** (`tests/oracle/`): implementação de referência independente das mesmas regras (use `datetime.isocalendar()`, `dateutil.easter` e, como segunda opinião onde houver cobertura, a biblioteca `holidays`). Registre toda divergência entre as fontes e resolva com a fonte legal.
2. **Golden files** (`tests/golden/`): CSV por localidade, de 2000 a 2040, com Date, ISOYear, ISOWeekNumber, WeekNumber, HolidayName, HolidayType, IsHoliday, IsOptionalDay, IsBusinessDay, BusinessDayOfMonth.
3. **Consultas de teste M** (`tests/calendar_<locale>_tests.pq`): geradas pelo `build.py`, embutem os valores esperados dos casos críticos (seção 8.1 + todos os feriados 2000–2040) como `#table`, geram o calendário com `StartDate = #date(2000,1,1)` e `AsOfDateOverride = #date(2040,6,30)` e retornam SOMENTE as linhas divergentes. Tabela vazia = aprovado.
4. **Health check** (`tests/calendar_health_check.pq`): consulta separada (NUNCA colunas dentro da dimensão) que retorna uma tabela Check / Result / Detail cobrindo: datas únicas; sem lacunas; contagem de dias = EndDate − StartDate + 1; todos os meses de cada ano presentes; ISOWeekNumber entre 1 e 53, e 53 somente em anos ISO longos; nenhuma coluna do tipo any; nenhum HolidayName com string vazia.
5. **Sintaxe**: valide cada `.pq` gerado com o parser oficial `@microsoft/powerquery-parser` (npm). Erro de parse bloqueia a entrega.

### 8.1 Casos obrigatórios (confirme cada um com o oráculo; se o oráculo discordar, pare e reporte)

Páscoa: 2000-04-23, 2008-03-23, 2019-04-21, 2024-03-31, 2025-04-20, 2026-04-05, 2038-04-25.

ISO: 2020-12-31 → 2020-W53; 2021-01-01 → 2020-W53; 2024-12-30 → 2025-W01; 2026-12-31 → 2026-W53; 2027-01-01 → 2026-W53.

Brasil:
- 2026: Carnaval 16 e 17/02 (Optional), Cinzas 18/02, Sexta-feira Santa 03/04 (National), Corpus Christi 04/06 (Optional).
- 2000-04-21: Tiradentes coincide com Sexta-feira Santa → um único registro, nome concatenado.
- 2023-11-20: sem feriado; 2024-11-20: feriado nacional.
- 2026-02-16: IsBusinessDay = true, IsOptionalDay = true, IsHoliday = false.
- 29/02/2024 existe; 29/02/2023 não existe.

EUA:
- 2026: MLK Day 19/01; Thanksgiving 26/11; Independence Day em sábado 04/07 → observado sexta 03/07.
- 2021-12-31: "New Year's Day (Observed)", IsBusinessDay = false.
- 2022-12-26: "Christmas Day (Observed)".
- 2027-06-18: "Juneteenth National Independence Day (Observed)".
- 2020-06-19: sem feriado (antes da vigência).

Espanha:
- Viernes Santo 2026-04-03; 2026-12-06 (domingo) permanece em 06/12 sem traslado, com IsBusinessDay = false.

Virada de ano e bordas: 31/12 e 01/01 de cada ano do intervalo; mudanças de mês, trimestre e ano refletidas em IsMonthEnd/IsQuarterEnd/IsYearEnd; BusinessDayOfMonth = 1 no primeiro dia útil de janeiro (considerando 01/01 feriado).

## 9. Documentação

- `README.md`: o que é; instalação em passos (seção 2); como marcar como tabela de datas (selecionar a tabela → Marcar como tabela de data → coluna Date); tabela de "Classificar por coluna"; diagrama de modelo estrela (DimCalendar[Date] 1 → * Fact[Date], filtro unidirecional); explicação da configuração avançada; limitações conhecidas (seções 6 e 7); como rodar os testes no Power BI Desktop.
- `documentation/calendar-columns.md`: todas as colunas (Coluna, Tipo, Descrição, Exemplo). Nenhuma coluna sem documentação.
- `documentation/holidays.md`: regras por país com fonte legal, vigências, tratamento de observados, facultativos, coincidências, exceções e itens fora do escopo; como estender (novo feriado, nova exceção, novo país).
- `documentation/usage.md`: exemplos DAX curtos (dias úteis no mês, D+5 úteis, último dia útil, filtro de mês atual).
- `CHANGELOG.md`: SemVer, primeira versão `1.0.0`.

## 10. Licença

Verifique se o repositório tem licença. Se tiver, mantenha. Se não tiver, recomende uma (ex.: MIT) com as implicações em 3 linhas no Checkpoint 1 e aguarde aprovação antes de criar o arquivo.

## 11. Fluxo de trabalho

Após cada fase, emita: `✅ Fase N concluída: <resumo em até 3 linhas>`.

**Fase 1: Análise.** Leia o repositório. Relate estrutura, estilo M, nomenclatura, pontos fortes, problemas e licença.

**Fase 2: Arquitetura.** Defina o mecanismo de build, a estrutura final de pastas e a organização do código M (etapas do `let`). Liste qualquer divergência que encontrar entre este documento e as fontes legais.

> **CHECKPOINT 1: PARE.** Apresente: resultado da análise, arquitetura proposta, divergências legais encontradas, recomendação de licença e quaisquer dúvidas. Aguarde aprovação.

**Fase 3: Oráculo e golden files.** Implemente o oráculo Python e gere os CSVs. Rode e confirme todos os casos da seção 8.1.

**Fase 4: Implementação M.** `src/`, `build.py`, 3 arquivos finais, consultas de teste e health check. Valide a sintaxe com o parser.

**Fase 5: Documentação.** Seção 9.

**Fase 6: Revisão.** Revise como engenheiro sênior de M buscando especificamente: erros de ano ISO e de ano bissexto; feriados fora da vigência; observados cruzando o ano; facultativos classificados como feriado; duplicidade em coincidências; traduções inconsistentes entre as 3 versões; pares de ordenação sem relação 1 para 1; colunas sem tipo; operações O(n²).

> **CHECKPOINT 2: PARE.** Entregue o relatório final (seção 12). Não faça push nem merge.

## 12. Relatório final e critérios de aceitação

Entregue uma tabela com cada critério abaixo e o status: Verificado por execução / Verificado por parser / Verificado por revisão / Pendente de execução no Power BI Desktop.

1. Os 3 `.pq` passam no parser sem erro.
2. O oráculo Python confirma 100% dos casos da seção 8.1.
3. Os golden files 2000–2040 foram gerados e conferidos contra a segunda fonte (`holidays`), com divergências explicadas.
4. As consultas de teste M comparam contra os golden files e retornam apenas divergências.
5. Todas as colunas da seção 4 existem, com o tipo especificado, e nenhuma coluna extra.
6. Nomes de colunas idênticos nas 3 versões; valores localizados.
7. Nenhuma ocorrência de `Web.Contents` ou acesso externo nos arquivos finais (verificado por busca textual).
8. Todo feriado tem fonte legal em `holidays.md`; itens não confirmados estão marcados `[a confirmar]`.
9. Os 3 arquivos finais são gerados pelo `build.py` a partir de `src/` (rodar o build duas vezes produz arquivos idênticos).
10. README cobre instalação, tabela de datas, ordenação, configuração avançada, limitações e testes.

Finalize com as instruções exatas, em passos numerados, para o usuário rodar no Power BI Desktop: a consulta do calendário, as consultas de teste e o health check, e o que deve aparecer em cada uma para considerar aprovado.
