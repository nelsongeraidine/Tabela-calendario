# CLAUDE.md — Dimensão Calendário (Power BI / Power Query M)

Data de Atualização: 22-09-2026_Versão 2.00

## Visão geral

Três tabelas de dimensão calendário prontas para colar no Editor Avançado do Power Query (pt-BR, en-US, es-ES), 100% offline, com feriados calculados algoritmicamente. Sem build, sem dependência externa: arquivos `.pq` finais escritos e mantidos diretamente.

## Arquitetura em uma página

`powerquery_code/calendar_{pt-BR,en-US,es-ES}.pq`: 3 arquivos `.pq` autocontidos e independentes, editados diretamente (não gerados por script). Nomes de coluna idênticos nas 3 versões (inglês); só os valores (nomes de mês/dia/feriado) são localizados. Cada arquivo calcula sua própria tabela de feriados por ano (Páscoa via Meeus/Jones/Butcher) e junta com a tabela de datas via `Table.NestedJoin`. `docs/prompt_calendar_library_claude_code.md` guarda a especificação técnica ampla original (90+ colunas, build.py, oráculo Python, golden files) — mantida como referência histórica, mas **não é o escopo atual**: o escopo real e simplificado está no `README.md`.

## Escopo do projeto

Ver `README.md` para o que foi entregue, colunas geradas, feriados incluídos e o que foi/não foi verificado. `PRD.md` e `todo.md` têm o histórico do processo (mantidos por transparência, não são o guia do dia a dia).

## Regras de comportamento

1. Antes de qualquer mudança não-trivial (mais de um arquivo, ou que altere comportamento existente), propor um plano antes de executar.
2. Nunca adicionar bibliotecas externas, CDNs ou pacotes sem consultar antes.
3. Comentários em português nos arquivos de processo/documentação; nos 3 `.pq` finais, comentários no idioma do próprio arquivo (pt-BR/en-US/es-ES), para não confundir quem for usar a versão localizada.
4. Antes de criar arquivo novo além dos principais (`CLAUDE.md`, `PRD.md`, `todo.md`, `README.md`), justificar por que ele precisa existir.
5. Se um pedido conflitar com o `PRD.md`/`README.md`, avisar antes de implementar.
6. Toda atualização do projeto (código, docs, PRD) registra data e versão no topo do arquivo alterado: `Data de Atualização: DD-MM-YYYY_Versão X.XX`.

## Convenções de código

- M: nomes de coluna em inglês, idênticos nas 3 versões. Tipo declarado em toda coluna (zero `any`). `null` para ausência de valor, nunca string vazia. Feriados/Páscoa calculados por ano com `List.Buffer`/listas, nunca linha a linha; índices de dia útil via `Table.Group` por mês/ano, nunca O(n²) sobre a tabela inteira.
- Qualquer alteração em um dos 3 `.pq` que mexa em coluna/lógica compartilhada deve ser replicada nos outros 2 (mesma estrutura, valores localizados).

## Como rodar

1. Copie o conteúdo de `powerquery_code/calendar_<locale>.pq`.
2. No Power BI Desktop: Obter Dados → Consulta Nula → Editor Avançado → colar → Concluído.
3. Marque a tabela como "Tabela de datas" usando a coluna `Date`.
4. (Opcional, para quem for editar o M) validar sintaxe com `@microsoft/powerquery-parser` via Node antes de entregar uma mudança.
