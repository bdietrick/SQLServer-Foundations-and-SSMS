------------------------------------------------------------
-- DETECTION QUERIES FOR COMMON DATA ISSUES
------------------------------------------------------------

-- Q1: Completed batch missing QA release.
SELECT b.BatchID, b.BatchNumber, b.Status, b.EndTime
FROM BatchHeader b
LEFT JOIN QARelease q ON q.BatchID = b.BatchID
WHERE b.Status = 'Completed'
  AND q.BatchID IS NULL;

-- Q2: Weigh/dispense timestamp earlier than corresponding material verification.
SELECT wd.BatchID,
       wd.MaterialLotID,
       wd.WeighDispenseTime,
       mv.VerifiedOn
FROM WeighDispense wd
JOIN MaterialVerification mv
  ON mv.BatchID = wd.BatchID
 AND mv.MaterialLotID = wd.MaterialLotID
WHERE wd.WeighDispenseTime < mv.VerifiedOn;

-- Q3: Expired lots consumed by a batch.
SELECT mc.BatchID,
       mc.MaterialLotID,
       ml.ExpiryDate,
       mc.ConsumedOn
FROM MaterialConsumption mc
JOIN MaterialLots ml ON ml.MaterialLotID = mc.MaterialLotID
WHERE mc.ConsumedOn > DATEADD(DAY, 1, CAST(ml.ExpiryDate AS DATETIME2));

-- Q4: Batch released while at least one IPC result failed.
SELECT q.BatchID,
       q.ReleasedOn,
       i.TestName,
       i.ResultValue,
       i.Spec
FROM QARelease q
JOIN IPCResults i ON i.BatchID = q.BatchID
WHERE i.PassFlag = 0
  AND q.Decision = 'Released';

-- Q5: Batch released with an open critical deviation.
SELECT q.BatchID,
       q.ReleasedOn,
       d.DeviationID,
       d.Description,
       d.Status,
       d.Severity
FROM QARelease q
JOIN Deviations d ON d.BatchID = q.BatchID
WHERE q.Decision = 'Released'
  AND d.Severity = 'Critical'
  AND d.Status = 'Open';


------------------------------------------------------------
-- CONSOLIDATED BPM COMPLETENESS REPORT
-- One row per batch with PASS/FAIL for each required BPM step
------------------------------------------------------------

SELECT
    b.BatchID,
    b.BatchNumber,
    b.Status,
    CASE WHEN b.StartTime IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS BatchCreation,
    CASE WHEN mv.BatchID IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS MaterialVerification,
    CASE WHEN wd.BatchID IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS WeighDispense,
    CASE WHEN bl.BatchID IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS Blending,
    CASE WHEN gr.BatchID IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS Granulation,
    CASE WHEN cp.BatchID IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS Compression,
    CASE WHEN ct.BatchID IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS Coating,
    CASE WHEN pk.BatchID IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS Packaging,
    CASE WHEN ipc.BatchID IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS IPCChecks,
    CASE WHEN dev.BatchID IS NOT NULL OR b.Status = 'Completed' THEN 'PASS' ELSE 'FAIL' END AS Deviations,
    CASE WHEN qa.BatchID IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS QARelease,
    CASE
        WHEN b.Status = 'Completed'
             AND mv.BatchID IS NOT NULL
             AND wd.BatchID IS NOT NULL
             AND bl.BatchID IS NOT NULL
             AND gr.BatchID IS NOT NULL
             AND cp.BatchID IS NOT NULL
             AND ct.BatchID IS NOT NULL
             AND pk.BatchID IS NOT NULL
             AND ipc.BatchID IS NOT NULL
             AND qa.BatchID IS NOT NULL
        THEN 'PASS'
        WHEN b.Status <> 'Completed'
             AND mv.BatchID IS NOT NULL
             AND wd.BatchID IS NOT NULL
        THEN 'PASS'
        ELSE 'FAIL'
    END AS OverallBPMCompleteness
FROM BatchHeader b
LEFT JOIN (SELECT DISTINCT BatchID FROM MaterialVerification) mv ON mv.BatchID = b.BatchID
LEFT JOIN (SELECT DISTINCT BatchID FROM WeighDispense) wd ON wd.BatchID = b.BatchID
LEFT JOIN (SELECT DISTINCT BatchID FROM Blending) bl ON bl.BatchID = b.BatchID
LEFT JOIN (SELECT DISTINCT BatchID FROM Granulation) gr ON gr.BatchID = b.BatchID
LEFT JOIN (SELECT DISTINCT BatchID FROM Compression) cp ON cp.BatchID = b.BatchID
LEFT JOIN (SELECT DISTINCT BatchID FROM Coating) ct ON ct.BatchID = b.BatchID
LEFT JOIN (SELECT DISTINCT BatchID FROM Packaging) pk ON pk.BatchID = b.BatchID
LEFT JOIN (SELECT DISTINCT BatchID FROM IPCResults) ipc ON ipc.BatchID = b.BatchID
LEFT JOIN (SELECT DISTINCT BatchID FROM Deviations) dev ON dev.BatchID = b.BatchID
LEFT JOIN (SELECT DISTINCT BatchID FROM QARelease) qa ON qa.BatchID = b.BatchID
ORDER BY b.BatchID;
