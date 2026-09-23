# TODO — Dimensão Calendário

Data de Atualização: 23-09-2026_Versão 2.02

Escopo simplificado em 22-09-2026 (ver `PRD.md`). O plano de fases do `docs/prompt_calendar_library_claude_code.md` (build.py, oráculo, golden files) não foi seguido; abaixo está o que foi feito de fato.

## Concluído

- [x] Análise do repositório de referência (`calendar_periods_time_tables_power_bi`) — estilo, nomenclatura, licença.
- [x] Escrever `powerquery_code/calendar_pt-BR.pq` (59 colunas, feriados nacionais + facultativos, Páscoa, semana ISO, dia útil).
- [x] Escrever `powerquery_code/calendar_en-US.pq` (feriados federais 5 U.S.C. §6103 com regra de observância, MLK/Washington/Memorial/Labor/Columbus/Thanksgiving via nth-weekday).
- [x] Escrever `powerquery_code/calendar_es-ES.pq` (10 fiestas nacionales, semana ISO nativa, sem traslado a lunes).
- [x] Validar sintaxe dos 3 arquivos com `@microsoft/powerquery-parser` (real, via Node) — passou.
- [x] Verificar manualmente Páscoa (2000-04-23, 2008-03-23, 2019-04-21, 2026-04-05) e semana ISO (virada 2026/2027) contra datas de referência.
- [x] Confirmar ausência de `Web.Contents`/acesso externo nos 3 arquivos (grep).
- [x] Confirmar que as 59 colunas são idênticas em nome e ordem nos 3 arquivos, e que nenhuma coluna é `type any`.
- [x] `README.md` com instruções de uso, colunas, feriados, verificação e limitações.
- [x] `LICENSE` (MIT).
- [x] `git init` + branch `feature/calendar-library-v1` + branch `main`; remoto configurado e ambas as branches sincronizadas em https://github.com/nelsongeraidine/Tabela-calendario.
- [x] Corrigido bug real: a validação `StartDate > EndDate` nunca era avaliada (M é preguiçoso, nada referenciava a variável de checagem) — agora referenciada na construção da lista de datas, forçando o erro a disparar quando aplicável.
- [x] README: adicionadas `MonthYear`/`MonthYearShort` à lista de colunas que precisam de "Classificar por coluna" (senão ordenam alfabeticamente em vez de cronologicamente).
- [x] Teste real no Power BI Desktop confirmado pelo usuário: carga funcionou.
- [x] Esclarecido para o usuário: `EndDate` é ancorado em `AsOfDate` (hoje), não em `StartDate` — `FutureYears` conta a partir do ano corrente. Sem alteração de código (usuário optou por ajustar `FutureYears` manualmente se precisar).
- [x] Esclarecido para o usuário: nomes de coluna ficam em inglês nas 3 versões por design (portabilidade de medidas DAX entre localidades); só os valores são localizados. Sem alteração de código.
- [x] README: adicionado glossário completo das 59 colunas (tipo, descrição, exemplo), agrupado pelas mesmas seções do resumo.

## Pendente (não pedido, mas útil se quiser evoluir depois)

- [ ] Carregar de fato no Power BI Desktop e conferir visualmente (não testado nesta sessão).
- [ ] Conferir fontes legais dos feriados contra publicação oficial (Lei, 5 U.S.C., BOE) em vez de conhecimento geral.
- [ ] Se algum dia quiser o pacote completo original (build.py, testes, 90+ colunas): retomar `docs/prompt_calendar_library_claude_code.md`.
