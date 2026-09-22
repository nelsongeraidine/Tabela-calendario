# PRD — Dimensão Calendário (Power BI / Power Query M)

Data de Atualização: 22-09-2026_Versão 2.00

**Escopo revisado em 22-09-2026**: o plano original (`docs/prompt_calendar_library_claude_code.md`) previa build.py, oráculo Python, golden files 2000–2040 e ~90 colunas. Após feedback do usuário ("não entendo nada, só quero as tabelas prontas para colar"), o escopo foi reduzido drasticamente. Este PRD descreve o que foi **de fato** entregue.

## Objetivo

3 arquivos `.pq` independentes e autocontidos (pt-BR, en-US, es-ES), prontos para copiar e colar no Editor Avançado do Power Query. 100% offline, feriados calculados algoritmicamente, ~56 colunas úteis (não a lista completa de 90+ da especificação original).

## Público-alvo

Usuário único (Nelson), engenheiro de telecom que usa Power BI no dia a dia e quer uma dimensão calendário pronta, sem processo de build.

## Entregáveis

- `powerquery_code/calendar_{pt-BR,en-US,es-ES}.pq` — arquivos finais, escritos e mantidos diretamente (sem build.py).
- `README.md` — como usar, colunas, feriados incluídos, o que foi verificado e como, limitações conhecidas.
- `LICENSE` (MIT).
- `docs/prompt_calendar_library_claude_code.md` — especificação original ampla, mantida só como referência histórica.

## Fora de escopo (cortado do plano original)

`build/build.py`, `src/` (template + blocos por localidade), `tests/oracle/` (Python), `tests/golden/` (CSV 2000–2040), consultas de teste M, health check, `CHANGELOG.md` com SemVer, colunas fiscais/quinzena/bimestre, feriados estaduais/municipais (Brasil), estaduais e Inauguration Day (EUA), feriados regionais/traslados autonômicos (Espanha).

## Verificação (honestidade sobre o que foi checado)

- Sintaxe M: verificada por execução real do parser oficial `@microsoft/powerquery-parser` — passou nos 3 arquivos.
- Fórmula da Páscoa e da semana ISO: verificadas manualmente contra as datas de referência do prompt original (2000-04-23, 2026-04-05, virada 2026/2027) — bateram.
- Regras de feriado (leis citadas): verificadas por revisão de conhecimento geral, não por consulta a fonte legal ao vivo nesta sessão. Recomenda-se conferência antes de uso em produção jurídica/RH.
- Não executado: carga real no Power BI Desktop.

## Controle de mudança de escopo

Qualquer pedido que amplie ou altere este PRD deve ser sinalizado antes da implementação (ver `CLAUDE.md`, Regras de comportamento, item 5), com atualização deste arquivo (data + versão) antes de prosseguir.
