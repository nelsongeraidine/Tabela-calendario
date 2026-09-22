# TODO — Dimensão Calendário

Data de Atualização: 22-09-2026_Versão 2.00

Escopo simplificado em 22-09-2026 (ver `PRD.md`). O plano de fases do `docs/prompt_calendar_library_claude_code.md` (build.py, oráculo, golden files) não foi seguido; abaixo está o que foi feito de fato.

## Concluído

- [x] Análise do repositório de referência (`calendar_periods_time_tables_power_bi`) — estilo, nomenclatura, licença.
- [x] Escrever `powerquery_code/calendar_pt-BR.pq` (56 colunas, feriados nacionais + facultativos, Páscoa, semana ISO, dia útil).
- [x] Escrever `powerquery_code/calendar_en-US.pq` (feriados federais 5 U.S.C. §6103 com regra de observância, MLK/Washington/Memorial/Labor/Columbus/Thanksgiving via nth-weekday).
- [x] Escrever `powerquery_code/calendar_es-ES.pq` (10 fiestas nacionales, semana ISO nativa, sem traslado a lunes).
- [x] Validar sintaxe dos 3 arquivos com `@microsoft/powerquery-parser` (real, via Node) — passou.
- [x] Verificar manualmente Páscoa (2000-04-23, 2026-04-05) e semana ISO (virada 2026/2027) contra datas de referência.
- [x] Confirmar ausência de `Web.Contents`/acesso externo nos 3 arquivos (grep).
- [x] `README.md` com instruções de uso, colunas, feriados, verificação e limitações.
- [x] `LICENSE` (MIT).
- [x] `git init` + branch `feature/calendar-library-v1`.

## Pendente (não pedido, mas útil se quiser evoluir depois)

- [ ] Carregar de fato no Power BI Desktop e conferir visualmente (não testado nesta sessão).
- [ ] Conferir fontes legais dos feriados contra publicação oficial (Lei, 5 U.S.C., BOE) em vez de conhecimento geral.
- [ ] Criar o repositório remoto no GitHub e fazer o primeiro push (usuário vai criar o repo; Claude sobe quando o link/remote existir).
- [ ] Se algum dia quiser o pacote completo original (build.py, testes, 90+ colunas): retomar `docs/prompt_calendar_library_claude_code.md`.
