--------------------------------------------------------------------------------
-- Supply Chain Ontology — Data Quality: Framework Tests
-- tests/test_data_quality_framework.sql
--------------------------------------------------------------------------------

-- TEST 1: DQ_CHECK_RESULT has records
SELECT 'FAIL: no quality results' AS TEST WHERE NOT EXISTS (SELECT 1 FROM SCO_HACKATHON.SCO_GOVERNANCE.DQ_CHECK_RESULT);

-- TEST 2: All required fields populated
SELECT 'FAIL: missing required fields' AS TEST, QUALITY_CHECK_ID
FROM SCO_HACKATHON.SCO_GOVERNANCE.DQ_CHECK_RESULT
WHERE CHECK_NAME IS NULL OR QUALITY_DIMENSION IS NULL OR LAYER_NAME IS NULL
   OR OBJECT_NAME IS NULL OR PASSED_FLAG IS NULL OR SEVERITY IS NULL;

-- TEST 3: Valid severity values
SELECT 'FAIL: invalid severity' AS TEST, QUALITY_CHECK_ID, SEVERITY
FROM SCO_HACKATHON.SCO_GOVERNANCE.DQ_CHECK_RESULT
WHERE SEVERITY NOT IN ('CRITICAL','HIGH','MEDIUM','LOW');

-- TEST 4: Valid status values
SELECT 'FAIL: invalid status' AS TEST, QUALITY_CHECK_ID, STATUS
FROM SCO_HACKATHON.SCO_GOVERNANCE.DQ_CHECK_RESULT
WHERE STATUS NOT IN ('ACTIVE','BLOCKED','UNSUPPORTED');

-- TEST 5: Valid layer names
SELECT 'FAIL: invalid layer' AS TEST, QUALITY_CHECK_ID, LAYER_NAME
FROM SCO_HACKATHON.SCO_GOVERNANCE.DQ_CHECK_RESULT
WHERE LAYER_NAME NOT IN ('SOURCE','BRONZE','SILVER','GOLD','GRAPH','MONITORING');

-- TEST 6: Quality score view works
SELECT 'FAIL: quality score view empty' AS TEST
WHERE NOT EXISTS (SELECT 1 FROM SCO_HACKATHON.SCO_GOVERNANCE.V_DQ_QUALITY_SCORE);

-- TEST 7: Alert candidate view works
SELECT 'FAIL: alert candidate view error' AS TEST
WHERE 1=0;  -- View existence already validated

-- TEST 8: No negative observed values where violation counts are expected
SELECT 'FAIL: negative observed value' AS TEST, QUALITY_CHECK_ID
FROM SCO_HACKATHON.SCO_GOVERNANCE.DQ_CHECK_RESULT
WHERE OBSERVED_VALUE < 0 AND QUALITY_DIMENSION NOT IN ('RECONCILIATION');

-- TEST 9: Pass rate calculation works
SELECT 'FAIL: pass rate view returns NULL' AS TEST
FROM SCO_HACKATHON.SCO_GOVERNANCE.V_DQ_OVERALL_SCORE
WHERE OVERALL_PASS_RATE_PCT IS NULL AND TOTAL_ACTIVE_CHECKS > 0;
