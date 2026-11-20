// LAB-VET-01 — 02_ingestao.cypher
// Consulta parametrizada para execução pelo driver Python Neo4j.
// NÃO cole este script isoladamente no Neo4j Browser sem fornecer $transacoes.
// No laboratório, o Python executou em lotes com MERGE para permitir reexecução.
// Cada item da lista $transacoes deve conter:
// tx_id, nameOrig, nameDest, step, type, amount.
// NÃO envie isFraud ou dados confidenciais ao grafo.

UNWIND $transacoes AS tx
MERGE (origem:Account {account_id: tx.nameOrig})
MERGE (destino:Account {account_id: tx.nameDest})
MERGE (t:Transaction {tx_id: tx.tx_id})
SET t.step = toInteger(tx.step),
    t.type = tx.type,
    t.amount = toFloat(tx.amount)
MERGE (origem)-[:SENT]->(t)
MERGE (t)-[:RECEIVED_BY]->(destino);

// Exemplo de execução no Python (trecho ilustrativo, NÃO Cypher):
// with driver.session() as session:
//     session.execute_write(lambda tx: tx.run(query_ingestao, transacoes=lote).consume())
// Gere tx_id estável antes da ingestão (no laboratório: TX_ + índice original).
