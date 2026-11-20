# LAB-VET-01 | Financial Fraud Intelligence

### Investigação financeira com Neo4j, análise relacional e Machine Learning

> **O grafo não acusa: ele organiza conexões para que a investigação faça as perguntas certas.**

**Status:** experimento de modelagem, investigação e comparação preditiva concluído; organização do repositório e revisão de publicação pendentes.
**Natureza:** laboratório independente, educacional e experimental com dados sintéticos públicos.
**Tecnologias:** Python, pandas, XGBoost, scikit-learn, Neo4j, Cypher, Jupyter Notebook.

---

## 1. Resumo executivo

O **LAB-VET-01** investiga se características históricas dos relacionamentos entre contas financeiras podem acrescentar valor a um modelo supervisionado de detecção de fraudes.

O laboratório combina três frentes:

1. **Machine Learning:** construção de um baseline com XGBoost e avaliação sob restrições de capacidade de investigação.
2. **Graph Intelligence:** representação de contas e transações em Neo4j, consultas Cypher e exploração visual das conexões.
3. **Engenharia de features temporais:** criação de indicadores históricos de destinatários sem acesso a transações do mesmo intervalo temporal ou de períodos futuros.

**Resultado principal:** três features relacionais históricas geraram melhorias pontuais na validação, mas **não produziram superioridade consistente no teste reservado**. No teste, os dois modelos capturaram exatamente as mesmas fraudes nos limites de 250 a 1.250 alertas. No limiar de probabilidade de 0,5, o baseline apresentou maior recall, enquanto o enriquecido produziu menos falsos positivos.

O experimento demonstra uma abordagem de avaliação responsável: **não se presume que grafos melhoram qualquer modelo; o ganho precisa ser medido**.

## 2. Problema de negócio

Fraudes financeiras são eventos raros em relação ao volume de transações. Um sistema antifraude precisa equilibrar:

- **Recall:** fraudes identificadas entre todas as fraudes existentes.
- **Precision:** proporção de alertas que efetivamente correspondem a fraudes rotuladas.
- **Falsos positivos:** investigações desnecessárias e possíveis impactos na experiência do cliente.
- **Capacidade operacional:** quantidade de alertas que uma equipe consegue analisar.
- **Disponibilidade temporal:** informações que realmente existiam no momento da decisão.

A pergunta central da PoC foi:

> **Features derivadas do histórico relacional dos destinatários melhoram a detecção de fraudes em comparação com um XGBoost baseado em atributos transacionais?**

A hipótese foi testada, e não tratada como uma premissa verdadeira.

## 3. Dados utilizados

Foi utilizado o **PaySim**, conjunto de dados sintéticos de transações financeiras amplamente empregado em experimentos de detecção de fraudes.

| Indicador | Valor |
|---|---:|
| Transações totais | 6.362.620 |
| Fraudes rotuladas | 8.213 |
| Taxa global de fraude | ~0,1291% |
| Valores ausentes no dataset original | 0 |
| Registros duplicados identificados | 0 |

**Campos principais:** `step`, `type`, `amount`, `nameOrig`, `nameDest`, `oldbalanceOrg`, `newbalanceOrig`, `oldbalanceDest`, `newbalanceDest`, `isFraud`, `isFlaggedFraud`.

As fraudes rotuladas no conjunto aparecem nas categorias `TRANSFER` e `CASH_OUT`. O campo `step` foi utilizado como referência temporal. Como não existe ordenação confiável entre operações do mesmo step, as features históricas excluem **todo o step corrente**.

**Nota de interpretação:** o campo `nameDest` representa a contraparte informada no dataset. Para operações como `CASH_IN` e `CASH_OUT`, isso não deve ser interpretado automaticamente como um crédito bancário efetivamente recebido. O grafo reproduz a estrutura dos campos, não toda a semântica contábil da operação.

### Divisão cronológica

| Partição | Critério | Transações | Fraudes |
|---|---|---:|---:|
| Treino | `step <= 300` | 4.073.650 | 3.401 |
| Validação | `300 < step <= 400` | 1.713.380 | 1.076 |
| Teste reservado | `step > 400` | 575.590 | 3.736 |

O teste foi mantido fora da escolha inicial de features e da comparação dos modelos na validação.

**Atenção à mudança de distribuição:** a taxa de fraude na validação foi aproximadamente **0,063%** e no teste, aproximadamente **0,649%**. Essa diferença é relevante para a interpretação das métricas e limita a extrapolação direta para produção.

## 4. Arquitetura experimental

```text
                  Dataset sintético PaySim
                           |
                    Python / pandas
                           |
            +--------------+--------------+
            |                             |
      Análise temporal              Amostra de treino
            |                             |
     Features históricas                 Neo4j
            |                             |
     +------+------+              Contas e transações
     |             |                      |
 XGBoost       XGBoost             Consultas Cypher
 baseline      enriquecido         Investigação visual
     |             |                      |
     +------+------+----------------------+
            |
   Avaliação, documentação e conclusões
```

A exploração com Neo4j e a preparação tabular das features são componentes complementares. **As três features utilizadas no XGBoost enriquecido foram calculadas em pandas**, não por algoritmos Neo4j GDS. Portanto, o resultado preditivo não constitui prova de vantagem exclusiva de um banco de grafos.

## 5. Modelo de grafo no Neo4j

Foi adotado o modelo orientado a eventos:

```cypher
(:Account)-[:SENT]->(:Transaction)-[:RECEIVED_BY]->(:Account)
```

### Entidades e relacionamentos

| Elemento | Função |
|---|---|
| `Account` | Representar uma conta identificada por `account_id` |
| `Transaction` | Representar uma operação por `tx_id`, `step`, `type` e `amount` |
| `SENT` | Ligar a conta de origem à transação |
| `RECEIVED_BY` | Ligar a transação à conta de destino informada |

Exemplo de restrições:

```cypher
CREATE CONSTRAINT account_id_unique IF NOT EXISTS
FOR (a:Account) REQUIRE a.account_id IS UNIQUE;

CREATE CONSTRAINT transaction_id_unique IF NOT EXISTS
FOR (t:Transaction) REQUIRE t.tx_id IS UNIQUE;
```

Exemplo de investigação de um destino com múltiplas origens:

```cypher
MATCH (origem:Account)-[:SENT]->(t:Transaction)
      -[:RECEIVED_BY]->(destino:Account)
RETURN destino.account_id AS destino,
       count(t) AS transacoes,
       count(DISTINCT origem) AS origens_distintas,
       sum(t.amount) AS volume
ORDER BY transacoes DESC
LIMIT 10;
```

**Proteção contra vazamento:** o rótulo `isFraud` não foi incluído como atributo preditivo dos nós transacionais do grafo.

### Escopo efetivamente carregado

A exploração registrada no laboratório utilizou **100.000 transações carregadas no Neo4j**, com **151.551 contas** e **200.000 relacionamentos transacionais** (`SENT` e `RECEIVED_BY`).

Nesse recorte, as contas de origem e destino não apresentaram sobreposição de papéis, o que limitou a identificação de cadeias `A → B → C`. Não se deve generalizar essa característica para todo o PaySim ou para redes financeiras reais.

Uma conta de destino investigada concentrava **78 operações**, provenientes de **78 origens distintas**, mas nenhuma dessas operações estava rotulada como fraude no recorte. Isso reforçou a distinção entre **concentração relacional** e **evidência de fraude**.

## 6. Baseline de Machine Learning

O baseline utilizou `XGBClassifier` com:

```python
XGBClassifier(
    n_estimators=200,
    max_depth=5,
    learning_rate=0.05,
    subsample=0.8,
    colsample_bytree=0.8,
    objective="binary:logistic",
    eval_metric="aucpr",
    tree_method="hist",
    random_state=42,
    n_jobs=-1,
)
```

**Features originais:** `amount`, `oldbalanceOrg`, `oldbalanceDest`, `step` e codificação one-hot de `type`.

Os saldos após a transação (`newbalanceOrig`, `newbalanceDest`), o indicador `isFlaggedFraud` e o próprio rótulo `isFraud` foram excluídos das variáveis preditoras.

### Baseline na validação, limiar 0,5

| Métrica | Resultado |
|---|---:|
| Precision | 0,9138 |
| Recall | 0,4136 |
| F1-score | 0,5694 |
| Average Precision | 0,6598 |
| Verdadeiros positivos | 445 |
| Falsos negativos | 631 |
| Falsos positivos | 42 |

## 7. Hipóteses relacionais e investigação

Na amostra de 100.000 transações foram identificadas **116 fraudes rotuladas**: 59 `CASH_OUT` e 57 `TRANSFER`.

Uma primeira análise contou a frequência total dos destinatários na amostra. Contudo, esse indicador incorporava transações posteriores à operação avaliada e, portanto, **não poderia ser usado diretamente em predição**.

A investigação foi reformulada com contagens históricas que consideram somente steps anteriores. Nesse recorte:

| Tipo | Classe | Média de transações anteriores do destino | Mediana |
|---|---|---:|---:|
| CASH_OUT | Legítima | 3,30 | 1 |
| CASH_OUT | Fraude | 1,19 | 0 |
| TRANSFER | Legítima | 4,59 | 1 |
| TRANSFER | Fraude | 0,00 | 0 |

Todas as **57 transferências fraudulentas** do recorte foram direcionadas a destinatários sem histórico anterior. Porém, **3.537 transferências legítimas** também tinham essa condição. Uma regra isolada de “destinatário sem histórico” geraria **3.594 alertas para 57 fraudes**, com precisão de aproximadamente **1,59%**.

**Conclusão exploratória:** ausência de histórico pode ser uma informação relevante, mas não é, isoladamente, uma regra operacional satisfatória nem evidência de fraude.

## 8. Engenharia de features sem vazamento temporal

Foram construídas três variáveis:

| Feature | Significado |
|---|---|
| `destino_tx_anteriores` | Quantidade de transações do destinatário em steps anteriores |
| `destino_volume_anterior` | Soma dos valores de transações associadas ao destinatário em steps anteriores |
| `destino_sem_historico` | Indicador binário de ausência de operações anteriores |

### Regra temporal

Para cada par `(nameDest, step)`, primeiro calcula-se o total de transações e o volume no step. Em seguida, calcula-se a soma acumulada por destinatário **subtraindo o total do step atual**.

```python
agregado = (
    base.groupby(["nameDest", "step"])
        .agg(qtd_step=("amount", "size"),
             volume_step=("amount", "sum"))
        .reset_index()
        .sort_values(["nameDest", "step"])
)

g = agregado.groupby("nameDest", sort=False)

agregado["destino_tx_anteriores"] = (
    g["qtd_step"].cumsum() - agregado["qtd_step"]
)
agregado["destino_volume_anterior"] = (
    g["volume_step"].cumsum() - agregado["volume_step"]
)
```

As features foram calculadas cronologicamente para treino e validação. Na avaliação final, o histórico foi estendido ao teste, sempre sem incorporar transações do próprio step ou steps futuros. **Rótulos de fraude não participam do cálculo**.

A preparação produziu **4.073.650 linhas de treino** e **1.713.380 de validação**, com **zero valores ausentes** nas três novas features. No treino, aproximadamente **44%** das transações tinham destinatário sem histórico.

## 9. Comparação na validação

O XGBoost enriquecido manteve os hiperparâmetros do baseline e acrescentou apenas as três features históricas.

### Métricas no limiar 0,5

| Métrica | Baseline | Enriquecido |
|---|---:|---:|
| Precision | 0,9138 | **0,9514** |
| Recall | **0,4136** | 0,4006 |
| F1-score | **0,5694** | 0,5638 |
| Average Precision | 0,6598 | **0,6647** |

### Capacidade operacional: Top K

| Alertas | TP baseline | TP enriquecido | Diferença |
|---:|---:|---:|---:|
| 250 | 249 | 250 | +1 |
| 500 | 445 | 446 | +1 |
| 750 | 590 | 566 | −24 |
| 1.000 | 658 | 639 | −19 |
| 1.250 | 698 | 729 | +31 |

O ganho foi **heterogêneo**: o enriquecido superou o baseline em alguns limites de alertas e perdeu em outros. O **Top 500** foi mantido como referência operacional principal para evitar escolher o cenário mais favorável após observar os resultados.

## 10. Avaliação no teste reservado

O teste compreendeu **575.590 transações**, incluindo **3.736 fraudes rotuladas**. Ambos os modelos foram avaliados sem novo ajuste de hiperparâmetros após a análise de validação.

### Métricas no limiar 0,5

| Métrica | Baseline | Enriquecido |
|---|---:|---:|
| Precision (recalculada da matriz de confusão) | 99,56% | 99,81% |
| Recall (recalculado) | 42,45% | 41,30% |
| F1-score (aproximado) | 59,5% | 58,4% |
| Average Precision (valor exibido, arredondado) | 0,85 | 0,85 |
| Verdadeiros positivos | **1.586** | 1.543 |
| Falsos positivos | 7 | **3** |
| Falsos negativos | **2.150** | 2.193 |
| Verdadeiros negativos | 571.847 | 571.851 |

O enriquecido reduziu **4 falsos positivos**, mas deixou de identificar **43 fraudes adicionais** no limiar 0,5.

### Top K no teste

| Alertas | TP baseline | TP enriquecido | FP de cada modelo |
|---:|---:|---:|---:|
| 250 | 250 | 250 | 0 |
| 500 | 500 | 500 | 0 |
| 750 | 750 | 750 | 0 |
| 1.000 | 1.000 | 1.000 | 0 |
| 1.250 | 1.250 | 1.250 | 0 |

**No Top 500, ambos capturaram 500 fraudes e nenhum falso positivo.** Isso representa aproximadamente **13,38% das 3.736 fraudes do teste**. Precisão perfeita nesse subconjunto **não significa detecção completa**.

O resultado do teste deve ser interpretado com cautela diante da mudança acentuada na taxa de fraude em relação à validação.

## 11. Decisão técnica

**Não foi demonstrada vantagem operacional robusta que justificasse substituir o baseline pelo modelo enriquecido neste experimento.**

Motivos:

- O ganho de Average Precision na validação foi pequeno.
- O desempenho no Top K de validação variou conforme a capacidade de alertas.
- No teste, ambos empataram em todos os limites de Top K avaliados.
- No limiar 0,5 do teste, o baseline identificou mais fraudes, embora o enriquecido tenha produzido menos falsos positivos.
- A mudança de distribuição entre validação e teste limita generalizações.

O baseline permanece a **referência recomendada para continuidade experimental**, não um modelo aprovado para produção.

## 12. O que o Neo4j acrescentou — e o que ainda não foi testado

### Implementado

- Modelo de grafo orientado a eventos.
- Ingestão parcial e incremental de transações.
- Restrições de unicidade e consultas Cypher.
- Investigação de destinatários, origens distintas, tipos de operação e volumes.
- Exploração visual de conexões e identificação de limitações estruturais do recorte.

### Não demonstrado neste experimento

- Ganho preditivo atribuível exclusivamente ao Neo4j.
- Melhorias decorrentes de algoritmos Neo4j GDS como Louvain, PageRank ou Betweenness.
- Identificação confiável de redes criminosas ou confirmação de fraude por centralidade.
- Desempenho operacional em ambiente bancário real.

### Evoluções futuras

- Comunidades e centralidades em grafos com relacionamentos adequados.
- Identificação de compartilhamento de dispositivos, IPs ou identidades, quando houver dados autorizados.
- Avaliação de drift temporal, custo financeiro e calibração de probabilidades.
- API investigativa com FastAPI, Neo4j e interface React.

Essas evoluções são **propostas**, não funcionalidades já entregues no LAB-VET-01.

## 13. Limitações

1. **Dataset sintético:** padrões do PaySim não equivalem necessariamente a fraudes reais.
2. **Mudança temporal de distribuição:** a taxa de fraude cresce substancialmente no teste.
3. **Granularidade do tempo:** não há ordenação confiável entre transações do mesmo `step`.
4. **Grafo parcial:** somente uma amostra de 100 mil transações foi carregada na etapa exploratória documentada.
5. **Features tabulares:** os indicadores relacionais usados no ML são agregações históricas, também calculáveis sem Neo4j.
6. **Ausência de avaliação econômica completa:** não foi estimado o custo monetário de falsos positivos e falsos negativos.
7. **Ausência de validação externa:** os resultados não foram replicados em outra instituição ou conjunto independente.
8. **Resultados de teste:** são avaliação final deste protocolo, não autorização para otimizações adicionais sobre o mesmo teste.

## 14. Estrutura planejada do repositório

> A estrutura abaixo é o **alvo de organização**; os arquivos de notebooks, scripts e imagens devem ser revisados e incluídos antes de declarar o projeto reproduzível.

```text
LAB-VET-01/
├── README.md
├── requirements.txt
├── .gitignore
├── notebooks/
│   ├── 01_analise_exploratoria.ipynb
│   ├── 02_modelo_baseline.ipynb
│   ├── 03_neo4j_investigacao.ipynb
│   ├── 04_features_historicas.ipynb
│   └── 05_comparacao_modelos.ipynb
├── cypher/
│   ├── 01_constraints.cypher
│   ├── 02_ingestao.cypher
│   └── 03_investigacao.cypher
├── images/
│   └── visualizacoes_neo4j/
└── docs/
    ├── metodologia.md
    ├── resultados.md
    └── limitacoes.md
```

### Reprodutibilidade

Para reproduzir o experimento, será necessário obter o PaySim por uma fonte pública autorizada, configurar o ambiente Python, executar os notebooks na ordem documentada e, para a etapa de investigação visual, configurar uma instância local do Neo4j.

**Este README registra o experimento e seus resultados, mas não substitui os notebooks, arquivos Cypher, dependências versionadas e instruções de execução que ainda serão organizados.**





## 15. Conclusão

O **LAB-VET-01** mostrou que a exploração de relacionamentos financeiros pode gerar hipóteses investigativas úteis, mas **a utilidade preditiva dessas hipóteses deve ser comprovada fora da amostra de treinamento**.

Neste experimento, o enriquecimento histórico não apresentou ganho consistente suficiente para recomendar a substituição do baseline. A principal contribuição é a metodologia integrada: **modelagem de grafos, investigação contextual, engenharia temporal sem vazamento e comparação operacional sob a mesma capacidade de alertas**.

> **O grafo não acusa: ele organiza conexões para que a investigação faça as perguntas certas.**

**LAB-VET-01 — Connecting Data. Revealing Decisions.**
** Alexandre Lotti
**<!LOTTI>
