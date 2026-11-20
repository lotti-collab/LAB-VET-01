# LAB-VET-01 — Consultas Cypher

Execute `01_constraints.cypher` antes da ingestão. O arquivo `02_ingestao.cypher` contém uma consulta **parametrizada** para uso no driver Python: exige `$transacoes` com `tx_id`, `nameOrig`, `nameDest`, `step`, `type` e `amount`. Não deve ser executado diretamente sem o parâmetro. Execute as consultas de `03_investigacao.cypher` **uma por vez** no Neo4j Browser.

Modelo: `(:Account)-[:SENT]->(:Transaction)-[:RECEIVED_BY]->(:Account)`.

O grafo registra a direção dos campos de origem/destino do PaySim; ela não equivale necessariamente a liquidação financeira real, especialmente em `CASH_IN` e `CASH_OUT`. O dataset é sintético. O laboratório carregou 100 mil transações no Neo4j, enquanto os experimentos de ML utilizaram recortes maiores. As consultas não contêm rótulos de fraude nem provam, isoladamente, comportamento fraudulento.

**Publicação:** revise dados, capturas de tela, saídas de notebooks, arquivos de configuração e histórico Git antes de publicar. Nunca versionar `.env`, senhas ou dados privados.
