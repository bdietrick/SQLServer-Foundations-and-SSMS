# Module 2 Student Activities

Module: Storage, Memory, and Transaction Log Internals
Audience: SQL Server 2016 Foundations students (support-oriented)
Duration target: 8 hours (blended lecture + activity)

## How to Use This Activity Pack
- Use these activities during Module 2 delivery as checkpoints, pair work, and guided lab tasks.
- Keep students in SSMS for all query-based tasks.
- Have students write short evidence-based answers after each activity.
- SQL Server 2016 note: server-scoped DMVs in this pack require `VIEW SERVER STATE`.

## Activity Map by Segment
- Segment 1 (Storage fundamentals): Activities 1-3
- Segment 2 (Allocation and files): Activities 4-5
- Segment 3 (Memory internals): Activities 6-7
- Segment 4 (Transaction log and WAL): Activities 8-9
- Segment 5 (Integrated troubleshooting): Activity 10 + exit ticket

## Shared Setup (Run Once)
Use this setup at the beginning of activities that require query execution.

```sql
USE master;
GO

IF DB_ID(N'Module2TrainingDemo') IS NOT NULL
BEGIN
    ALTER DATABASE Module2TrainingDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Module2TrainingDemo;
END;
GO

CREATE DATABASE Module2TrainingDemo;
GO

USE Module2TrainingDemo;
GO

CREATE TABLE dbo.StorageDemo
(
    StorageDemoID int IDENTITY(1,1) NOT NULL,
    CustomerCode char(6) NOT NULL,
    Notes varchar(200) NOT NULL,
    Amount decimal(10,2) NOT NULL,
    CreatedAt datetime2(0) NOT NULL,
    CONSTRAINT PK_StorageDemo PRIMARY KEY CLUSTERED (StorageDemoID)
);
GO

INSERT INTO dbo.StorageDemo (CustomerCode, Notes, Amount, CreatedAt)
VALUES
    ('C00001', 'Initial order created for storage demo.', 125.00, '2026-06-01 09:00:00'),
    ('C00002', 'Second order adds another row to the clustered index.', 210.50, '2026-06-01 09:15:00'),
    ('C00003', 'Third row gives the table enough content for space checks.', 98.99, '2026-06-01 09:30:00'),
    ('C00004', 'Fourth row supports transaction and rollback examples.', 415.75, '2026-06-01 09:45:00'),
    ('C00005', 'Fifth row supports buffer cache inspection.', 302.10, '2026-06-01 10:00:00');
GO
```

Production-safety note: Setup is for training only. Use non-production databases for destructive setup scripts.

---

## Activity 1 - Storage Layer Sorting Drill (15 minutes)

### Goal
Classify symptoms by the correct storage layer: object, file, page/extent, or log.

### Student task
For each scenario, select the most likely first layer to inspect:
- "Table row count grew 10%, backup size grew 60%"
- "Inserts failing with file-full message"
- "Frequent update workload got slower after schema change"
- "Rollback took much longer than expected"

### Deliverable
A one-line layer choice for each scenario and one reason.

### Expected takeaway
Support engineers should route investigations to the right layer before choosing tools.

---

## Activity 2 - Storage Math Quick Check (10 minutes)

### Goal
Build fluency with page/extent math used in incident triage.

### Student task
Answer without calculator first, then verify:
- How many pages in 1 MB?
- How many extents in 1 GB?
- If an object has 4096 pages, how many extents is that?
- If 32 extents are allocated, how many KB is that?

### Answer key
- 1 MB = 128 pages
- 1 GB = 16384 extents
- 4096 pages = 512 extents
- 32 extents = 2048 KB

### Expected takeaway
Students should quickly estimate storage growth impact from page or extent counts.

---

## Activity 3 - File Role Identification (20 minutes)

### Goal
Distinguish data file pressure from log file pressure.

### Student task
Run:

```sql
USE Module2TrainingDemo;
GO

SELECT
    file_id,
    name AS logical_name,
    type_desc,
    size * 8 / 1024 AS size_mb,
    growth,
    is_percent_growth,
    physical_name
FROM sys.database_files
ORDER BY file_id;
GO
```

Then answer:
- Which row is the data file and why?
- Which row is the log file and why?
- If a write fails due to log capacity, which row do you inspect first?

Production-safety note: This catalog view is safe in production because it is metadata-only.

### Expected takeaway
`ROWS` vs `LOG` distinction should become immediate and operational.

---

## Activity 4 - Reserved vs Used Space Investigation (25 minutes)

### Goal
Explain why reserved and used space differ.

### Student task
Run:

```sql
USE Module2TrainingDemo;
GO

SELECT
    t.name AS table_name,
    i.name AS index_name,
    SUM(a.total_pages) * 8 AS reserved_kb,
    SUM(a.used_pages) * 8 AS used_kb,
    SUM(a.data_pages) * 8 AS data_kb
FROM sys.tables AS t
INNER JOIN sys.indexes AS i
    ON t.object_id = i.object_id
INNER JOIN sys.partitions AS p
    ON i.object_id = p.object_id
    AND i.index_id = p.index_id
INNER JOIN sys.allocation_units AS a
    ON a.container_id = CASE
        WHEN a.type IN (1, 3) THEN p.hobt_id
        ELSE p.partition_id
    END
WHERE t.name = N'StorageDemo'
GROUP BY t.name, i.name, i.index_id
ORDER BY i.index_id;
GO

EXEC sys.sp_spaceused @objname = N'dbo.StorageDemo';
GO
```

Then explain in 3-4 lines:
- Why can `reserved_kb` be larger than `used_kb`?
- Why do these outputs relate but not match formatting exactly?

Production-safety note: These are documented metadata views/procedures and safe for production read-only analysis.

### Expected takeaway
Students should separate allocation state from visible row payload.

---

## Activity 5 - Allocation Map Reasoning Exercise (15 minutes)

### Goal
Use GAM/SGAM/PFS/IAM concepts without memorizing internals.

### Student task
Given this statement, mark it true/false and fix false statements:
- "PFS tracks which table owns an extent."
- "IAM helps map object ownership to extents."
- "GAM and SGAM both relate to extent availability state."
- "If file free space exists, every table can grow without new allocation."

### Expected takeaway
Students should reason about ownership, free space, and allocation bookkeeping correctly.

---

## Activity 6 - Buffer Pool Observation (20 minutes)

### Goal
Connect table reads to cached pages.

### Student task
Run:

```sql
USE Module2TrainingDemo;
GO

SELECT TOP (5)
    StorageDemoID,
    CustomerCode,
    Amount
FROM dbo.StorageDemo
ORDER BY StorageDemoID;
GO

SELECT
    OBJECT_NAME(p.object_id, bd.database_id) AS object_name,
    COUNT(*) AS cached_pages,
    COUNT(*) * 8 AS cached_kb
FROM sys.dm_os_buffer_descriptors AS bd
INNER JOIN sys.allocation_units AS a
    ON bd.allocation_unit_id = a.allocation_unit_id
INNER JOIN sys.partitions AS p
    ON a.container_id = CASE
        WHEN a.type IN (1, 3) THEN p.hobt_id
        ELSE p.partition_id
    END
WHERE bd.database_id = DB_ID(N'Module2TrainingDemo')
  AND OBJECT_NAME(p.object_id, bd.database_id) = N'StorageDemo'
GROUP BY p.object_id, bd.database_id;
GO
```

Then answer:
- Why run the table query before the DMV query?
- What do cached pages mean operationally?
- Why does this not replace durable storage files?

Production-safety note: `sys.dm_os_buffer_descriptors` is documented and requires `VIEW SERVER STATE`; scope queries narrowly in production.

### Expected takeaway
Students should correctly describe buffer pool as a performance cache, not a durability layer.

---

## Activity 7 - Plan Cache vs Buffer Pool Classification (20 minutes)

### Goal
Separate data-page caching from plan reuse.

### Student task
Run:

```sql
USE Module2TrainingDemo;
GO

SELECT TOP (5)
    StorageDemoID,
    CustomerCode,
    Amount
FROM dbo.StorageDemo
ORDER BY StorageDemoID;
GO

SELECT TOP (10)
    cp.usecounts,
    cp.objtype,
    cp.cacheobjtype,
    LEFT(st.text, 200) AS sample_sql_text
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS st
WHERE st.dbid = DB_ID(N'Module2TrainingDemo')
  AND st.text LIKE N'%StorageDemo%'
ORDER BY cp.usecounts DESC;
GO
```

Write two statements:
- One statement that describes buffer-pool evidence.
- One statement that describes plan-cache evidence.

Production-safety note: `sys.dm_exec_cached_plans` and `sys.dm_exec_sql_text` are documented and require `VIEW SERVER STATE`; avoid broad scans in busy production systems.

### Expected takeaway
Students should avoid saying "memory cache" without specifying which cache.

---

## Activity 8 - Checkpoint vs Lazy Writer Counter Interpretation (20 minutes)

### Goal
Interpret selected Buffer Manager counters correctly.

### Student task
Run:

```sql
USE Module2TrainingDemo;
GO

SELECT
    counter_name,
    cntr_value
FROM sys.dm_os_performance_counters
WHERE object_name LIKE N'%Buffer Manager%'
  AND counter_name IN (N'Checkpoint pages/sec', N'Lazy writes/sec', N'Page life expectancy');
GO

CHECKPOINT;
GO

SELECT
    counter_name,
    cntr_value
FROM sys.dm_os_performance_counters
WHERE object_name LIKE N'%Buffer Manager%'
  AND counter_name IN (N'Checkpoint pages/sec', N'Lazy writes/sec', N'Page life expectancy');
GO
```

Then answer:
- Which counter is checkpoint-related?
- Why can low `Lazy writes/sec` still be healthy?

Production-safety note: `sys.dm_os_performance_counters` is documented; filter to specific counters to reduce noise.

### Expected takeaway
Students should link checkpoint to recovery behavior and lazy writer to reusable buffer pressure.

---

## Activity 9 - Explicit Transaction and Rollback Visibility (30 minutes)

### Goal
Observe transaction visibility and rollback semantics.

### Student task
Use two SSMS windows.

Window 1:

```sql
USE Module2TrainingDemo;
GO

BEGIN TRANSACTION;

UPDATE dbo.StorageDemo
SET Amount = Amount + 25.00
WHERE StorageDemoID IN (3, 4, 5);

SELECT
    StorageDemoID,
    CustomerCode,
    Amount
FROM dbo.StorageDemo
WHERE StorageDemoID IN (3, 4, 5)
ORDER BY StorageDemoID;
```

Window 2 (while Window 1 transaction is still open):

```sql
USE Module2TrainingDemo;
GO

SELECT
    StorageDemoID,
    CustomerCode,
    Amount
FROM dbo.StorageDemo
WHERE StorageDemoID IN (3, 4, 5)
ORDER BY StorageDemoID;
GO
```

Back in Window 1:

```sql
ROLLBACK TRANSACTION;

SELECT
    StorageDemoID,
    CustomerCode,
    Amount
FROM dbo.StorageDemo
WHERE StorageDemoID IN (3, 4, 5)
ORDER BY StorageDemoID;
GO
```

Then rerun Window 2 query.

### Deliverable
A short compare/contrast of what Window 1 vs Window 2 saw before and after rollback.

### Expected takeaway
Rollback is active undo work, and visibility differs by session context.

---

## Activity 10 - Log Reuse Diagnosis Drill (20 minutes)

### Goal
Read log reuse state before proposing corrective actions.

### Student task
Run:

```sql
USE master;
GO

SELECT
    name,
    recovery_model_desc,
    log_reuse_wait,
    log_reuse_wait_desc
FROM sys.databases
WHERE name = N'Module2TrainingDemo';
GO
```

Then answer:
- What does `log_reuse_wait_desc` tell you?
- Why is this about reuse eligibility, not immediate shrink?
- What is your next check before deciding to shrink?

Production-safety note: `sys.databases` is a safe metadata view for production diagnostics.

### Expected takeaway
Students should diagnose reuse blockers before recommending file-size changes.

---

## Exit Ticket (10 minutes)

Each student submits concise answers:
1. What is one page and one extent size in SQL Server?
2. State one difference between buffer pool and plan cache.
3. State one difference between checkpoint and lazy writer.
4. Explain write-ahead logging in one sentence.
5. Why can a log stay large even after transactions complete?

## Instructor Scoring Rubric (Quick)
- Correct technical statement: 2 points each prompt
- Mostly correct but vague: 1 point
- Incorrect/confused layer mapping: 0 points
- Suggested pass indicator: 7/10 or higher

## Optional Challenge Activities
- Insert 500 more rows and re-run Activity 4 to observe reserved/used change.
- Run Activity 6 twice after repeated reads and compare cached page counts.
- Create a mock incident timeline and ask students to choose first three diagnostic queries in order.
