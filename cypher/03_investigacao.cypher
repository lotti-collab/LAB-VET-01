// LAB-VET-01 — 03_investigacao.cypher
// Consultas independentes: execute cada bloco separadamente no Neo4j Browser.
// Todas as consultas observam a amostra realmente carregada, não o dataset completo.

// 1. Integridade e dimensão do grafo
MATCH (a:Account)
WITH count(a) AS contas
MATCH (t:Transaction)
RETURN contas, count(t) AS transacoes;

// 2. Distribuição das transações por tipo
MATCH (t:Transaction)
RETURN t.type AS tipo,
       count(*) AS quantidade,
       round(sum(t.amount) * 100) / 100.0 AS volume_total,
       round(avg(t.amount) * 100) / 100.0 AS valor_medio
ORDER BY quantidade DESC;

// 3. Destinatários com maior recorrência na amostra
MATCH (origem:Account)-[:SENT]->(t:Transaction)-[:RECEIVED_BY]->(destino:Account)
RETURN destino.account_id AS destinatario,
       count(t) AS transacoes,
       count(DISTINCT origem) AS origens_distintas,
       round(sum(t.amount) * 100) / 100.0 AS volume_total
ORDER BY transacoes DESC, destinatario
LIMIT 20;

// 4. Perfil investigativo de um destinatário (exemplo do dataset sintético)
MATCH (origem:Account)-[:SENT]->(t:Transaction)-[:RECEIVED_BY]->
      (destino:Account {account_id: 'C985934102'})
RETURN t.type AS tipo,
       count(t) AS quantidade,
       count(DISTINCT origem) AS origens_distintas,
       round(sum(t.amount) * 100) / 100.0 AS volume_total,
       min(t.step) AS primeiro_step,
       max(t.step) AS ultimo_step
ORDER BY quantidade DESC;

// 5. Visualização do subgrafo de um destinatário
MATCH p=(origem:Account)-[:SENT]->(t:Transaction)-[:RECEIVED_BY]->
        (destino:Account {account_id: 'C985934102'})
RETURN p
LIMIT 100;

// 6. Remetentes de um destino que também enviaram a outros destinos
MATCH (destino1:Account {account_id: 'C985934102'})
      <-[:RECEIVED_BY]-(t1:Transaction)<-[:SENT]-(origem:Account)
MATCH (origem)-[:SENT]->(t2:Transaction)-[:RECEIVED_BY]->(destino2:Account)
WHERE destino2 <> destino1 AND t1 <> t2
RETURN origem.account_id AS remetente,
       destino2.account_id AS outro_destino,
       t1.type AS tipo_original,
       t2.type AS tipo_adicional,
       t1.step AS step_original,
       t2.step AS step_adicional
ORDER BY remetente
LIMIT 30;

// 7. Contas que exercem ambos os papéis na amostra
MATCH (a:Account)
WHERE EXISTS { MATCH (a)-[:SENT]->(:Transaction) }
  AND EXISTS { MATCH (:Transaction)-[:RECEIVED_BY]->(a) }
RETURN count(a) AS contas_com_ambos_papeis;

// Nota: a ausência de caminhos ou de registros NÃO comprova ausência de fraude.
// O rótulo isFraud é usado somente na avaliação retrospectiva em Python.
