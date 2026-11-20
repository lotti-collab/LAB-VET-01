// LAB-VET-01 — 01_constraints.cypher
// Execute uma vez antes da ingestão, no banco de dados do laboratório.
// As constraints também criam índices para os identificadores.

CREATE CONSTRAINT account_id_unique IF NOT EXISTS
FOR (a:Account) REQUIRE a.account_id IS UNIQUE;

CREATE CONSTRAINT transaction_id_unique IF NOT EXISTS
FOR (t:Transaction) REQUIRE t.tx_id IS UNIQUE;

// Conferência
SHOW CONSTRAINTS;
