# Dimensão Calendário para Power BI (Power Query / M)

Data de Atualização: 22-09-2026_Versão 1.01

Três tabelas de calendário prontas para uso em Power BI, uma por idioma/localidade: **pt-BR**, **en-US**, **es-ES**. 100% offline (nenhuma chamada externa, nenhuma API, nenhum arquivo); feriados calculados pelo próprio código.

## Como usar

1. Abra o arquivo desejado em `powerquery_code/` (`calendar_pt-BR.pq`, `calendar_en-US.pq` ou `calendar_es-ES.pq`) e copie todo o conteúdo.
2. No Power BI Desktop: **Obter Dados → Consulta Nula** (Blank Query).
3. Abra o **Editor Avançado** (Home → Advanced Editor) e cole o código, substituindo o que já estiver lá.
4. Se quiser, altere só a linha `StartDate = #date(2020, 1, 1)` para a data de início desejada. Clique em **Concluído**.
5. Renomeie a consulta (ex.: `Calendario`) e clique em **Fechar e Aplicar**.
6. No modelo, clique com o botão direito na tabela → **Marcar como tabela de datas** → selecione a coluna `Date`.

Isso é tudo — não precisa de build, Python, nem instalar nada.

## Configuração avançada (topo de cada arquivo)

| Parâmetro | Padrão | O que faz |
|---|---|---|
| `StartDate` | `2020-01-01` | Primeira data da tabela. É o único parâmetro pensado para ser alterado. |
| `FutureYears` | `1` | Quantos anos completos gerar além do ano atual. |
| `UtcOffsetHours` | -3 (pt-BR) / -5 (en-US) / +1 (es-ES) | Fuso usado para calcular "hoje" (`AsOfDate`), já que `DateTime.LocalNow()` no serviço do Power BI usa o horário do servidor (UTC), não o seu. |
| `AsOfDateOverride` | `null` | Defina uma data fixa (ex.: `#date(2026,9,22)`) para testes; `null` usa a data de hoje. |

Se `StartDate` ficar depois de `EndDate` calculado, a consulta falha com um erro explícito em vez de devolver tabela vazia.

## Colunas geradas (resumo)

Nomes de coluna são **idênticos nos 3 arquivos** (em inglês), para que qualquer medida DAX funcione com qualquer versão trocando só a tabela. Só os valores (nomes de mês, dia, feriado etc.) mudam por idioma.

- **Data/Ano**: `Date`, `DateKey`, `DayOfMonth`, `DayOfYear`, `Year`, `YearStart`, `YearEnd`, `IsLeapYear`
- **Semestre/Trimestre/Mês**: `SemesterNumber/Name`, `QuarterNumber/Name`, `MonthNumber/Name/NameShort`, mais as combinações `Year*` para ordenação (`YearMonth`, `YearQuarter`, `YearSemester` + versões numéricas)
- **Semana**: `DayOfWeekNumber/Name`, `IsWeekend`, `WeekNumber/Start/End` (convenção local) e `ISOWeekNumber`, `ISOYear`, `ISOYearWeek` (padrão ISO 8601 — pt-BR/en-US começam domingo, es-ES começa segunda por já seguir ISO)
- **Estação**: `SeasonNumber`, `Season` (definição meteorológica: meses completos; hemisfério sul no pt-BR, hemisfério norte no en-US/es-ES)
- **Feriados**: `IsHoliday`, `HolidayName`, `HolidayType`, `IsOptionalDay`, `IsNationalHoliday`, `IsObservedHoliday`
- **Dia útil**: `IsBusinessDay`, `BusinessDayOfMonth`, `BusinessDayOfYear`
- **Marcos**: `IsMonthStart/End`, `IsQuarterStart/End`, `IsYearStart/End`
- **Relativos a hoje**: `AsOfDate`, `IsToday`, `IsCurrentMonth`, `IsCurrentYear`

### Ordenar colunas de texto no Power BI ("Classificar por coluna")

Depois de carregar, para cada coluna de texto abaixo, selecione-a → aba **Estrutura da Tabela/Column tools** → **Classificar por Coluna**:

`MonthName`/`MonthNameShort` → `MonthNumber` · `MonthYear`/`MonthYearShort` → `YearMonthNumber` · `YearMonth` → `YearMonthNumber` · `QuarterName` → `QuarterNumber` · `YearQuarter` → `YearQuarterNumber` · `SemesterName` → `SemesterNumber` · `YearSemester` → `YearSemesterNumber` · `DayOfWeekName`/`DayOfWeekNameShort` → `DayOfWeekNumber` · `ISOYearWeek` → `ISOYearWeekNumber` · `Season` → `SeasonNumber`

## Feriados incluídos

**pt-BR**: Confraternização Universal, Carnaval (segunda/terça, facultativo), Quarta-feira de Cinzas (facultativo), Sexta-feira Santa, Tiradentes, Dia do Trabalho, Corpus Christi (facultativo), Independência, Nossa Senhora Aparecida, Finados, Proclamação da República, Consciência Negra (só a partir de 2024 — Lei 14.759/2023), Véspera de Natal (facultativo), Natal, Véspera de Ano-Novo (facultativo).

**en-US**: os 11 feriados federais (5 U.S.C. § 6103) — New Year's Day, MLK Day (a partir de 1986), Washington's Birthday, Memorial Day, Juneteenth (a partir de 2021), Independence Day, Labor Day, Columbus Day, Veterans Day, Thanksgiving, Christmas — com regra de observância (sábado → sexta anterior; domingo → segunda seguinte), incluindo o caso de Ano Novo em sábado observado em 31/12 do ano anterior.

**es-ES**: as 10 fiestas de ámbito nacional (Real Decreto 2001/1983) — Año Nuevo, Epifanía, Viernes Santo, Fiesta del Trabajo, Asunción, Fiesta Nacional, Todos los Santos, Constitución, Inmaculada Concepción, Natividad. **Sem traslado a lunes** quando cai em domingo — o calendário oficial anual publicado no BOE decide isso por Comunidade Autônoma, o que está fora do escopo deste arquivo genérico.

`IsOptionalDay = true` conta como dia útil por padrão (`IsBusinessDay` não desconta pontos facultativos). Se precisar tratá-los como não úteis (ex.: Carnaval para o setor bancário), filtre por `[IsOptionalDay]` em DAX.

## O que foi verificado, e como

Sem motor Power Query disponível neste ambiente para executar as consultas de ponta a ponta. O que foi feito:

- **Sintaxe**: os 3 arquivos passaram no parser oficial `@microsoft/powerquery-parser` (Microsoft), sem erro.
- **Páscoa** (algoritmo de Meeus/Jones/Butcher): conferida manualmente, passo a passo, contra duas datas conhecidas — 2000-04-23 e 2026-04-05. Bateu nas duas.
- **Semana ISO 8601**: fórmula conferida manualmente contra a virada 2026/2027 (2026-12-31 → 2026-W53; 2027-01-01 → 2026-W53). Bateu.
- **Regras de feriado**: verificadas por revisão de conhecimento geral, **não** por consulta a fonte legal em tempo real nesta sessão (sem acesso a IN/Lei/BOE consultado agora). As leis citadas (ex.: Lei 6.802/1980, Lei 14.759/2023, 5 U.S.C. § 6103, Real Decreto 2001/1983) são as normalmente citadas para essas datas, mas **recomendo conferir a fonte oficial antes de usar em produção jurídica/RH**, especialmente para Espanha, onde o calendário muda todo ano por Comunidade Autônoma.
- **Não testado**: carga real no Power BI Desktop, comportamento em produção com muitos anos de intervalo, comportamento em horário de verão nos EUA/Espanha (M não tem base de fusos horários — `UtcOffsetHours` é fixo e pode errar em até 1h durante DST).

## Limitações conhecidas

- Feriados estaduais/municipais (Brasil), estaduais e Inauguration Day (EUA), e feriados regionais/traslados autonômicos (Espanha) **não** estão incluídos — só o núcleo nacional/federal.
- `UtcOffsetHours` é um deslocamento fixo, não uma zona horária real: pode errar em até 1 hora durante o horário de verão nos EUA e na Espanha.
- Colunas relativas (`AsOfDate`, `IsToday` etc.) e `EndDate` mudam a cada atualização do modelo.

## Estrutura do repositório

```
powerquery_code/     3 arquivos .pq prontos para copiar e colar
docs/                especificação técnica completa original (referência)
README.md            este arquivo
CLAUDE.md, PRD.md, todo.md   documentação de processo para trabalho futuro no projeto
```
