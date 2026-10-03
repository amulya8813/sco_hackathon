--------------------------------------------------------------------------------
-- Supply Chain Ontology — Knowledge Graph: Schema Creation
-- 10_create_graph_schema.sql
--------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS SCO_HACKATHON.SCO_GRAPH
  COMMENT = 'Governed supply-chain knowledge graph — relational node and edge views over SCO_SILVER';
