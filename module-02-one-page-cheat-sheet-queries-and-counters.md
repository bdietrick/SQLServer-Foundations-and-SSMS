# Module 2 One-Page Cheat Sheet: Key Queries and Counters

Scope: SQL Server 2016 Foundations (storage, memory, transaction log)
Audience: Support engineers and beginner DBAs

## Fast Storage Math
- 1 page = 8 KB
- 1 extent = 8 pages = 64 KB
- 1 MB = 128 pages = 16 extents
- 1 GB = 131072 pages = 16384 extents

## 1) File Layout and Growth (Data vs Log)
Use first when incidents mention "database full" or write failures.

```sql
USE <YourDatabaseName>;
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

How to read quickly
- `type_desc = ROWS` -> data file
- `type_desc = LOG` -> transaction log file

Production-safety note: Metadata-only view; safe for production diagnostics.

## 2) Object Reserved vs Used Space
Use when table growth and file growth do not match expectations.

```sql
USE <YourDatabaseName>;
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
GROUP BY t.name, i.name, i.index_id
ORDER BY t.name, i.index_id;
GO
```

Quick interpretation
- `reserved_kb >= used_kb >= data_kb` is common
- Reserved space is not the same as active row payload

Production-safety note: Documented metadata views; safe for read-only use.

## 3) Quick Space Summary per Object
Use for fast handoff-friendly output.

```sql
USE <YourDatabaseName>;
GO

EXEC sys.sp_spaceused @objname = N'dbo.<YourTableName>';
GO
```

Quick interpretation
- Good for concise summary
- Pairs well with Query 2 for deeper detail

Production-safety note: Documented procedure; safe for read-only diagnostics.

## 4) Buffer Pool Evidence for a Specific Object
Use to show data pages currently cached in memory.

```sql
USE <YourDatabaseName>;
GO

SELECT TOP (5)
    *
FROM dbo.<YourTableName>
ORDER BY 1;
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
WHERE bd.database_id = DB_ID(N'<YourDatabaseName>')
  AND OBJECT_NAME(p.object_id, bd.database_id) = N'<YourTableName>'
GROUP BY p.object_id, bd.database_id;
GO
```

Quick interpretation
- `cached_pages` > 0 means object pages are resident in buffer pool
- Cache improves reads but does not replace file durability

Production-safety note: Requires `VIEW SERVER STATE`; scope narrowly in production.

## 5) Plan Cache Evidence for Repeated Queries
Use to discuss compilation reuse vs data-page caching.

```sql
USE <YourDatabaseName>;
GO

SELECT TOP (10)
    cp.usecounts,
    cp.objtype,
    cp.cacheobjtype,
    LEFT(st.text, 200) AS sample_sql_text
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS st
WHERE st.dbid = DB_ID(N'<YourDatabaseName>')
ORDER BY cp.usecounts DESC;
GO
```

Quick interpretation
- Higher `usecounts` can indicate plan reuse
- Plan cache stores execution plans, not table data

Production-safety note: Requires `VIEW SERVER STATE`; avoid broad scans on busy servers.

## 6) Key Buffer Manager Counters (Checkpoint vs Lazy Writer)
Use when discussing recovery-focused writes vs memory-pressure writes.

```sql
SELECT
    counter_name,
    cntr_value
FROM sys.dm_os_performance_counters
WHERE object_name LIKE N'%Buffer Manager%'
  AND counter_name IN (N'Checkpoint pages/sec', N'Lazy writes/sec', N'Page life expectancy');
GO
```

Counter meanings
- `Checkpoint pages/sec`: data pages flushed for recovery progress
- `Lazy writes/sec`: buffers freed under memory pressure
- `Page life expectancy`: rough indicator of cache retention duration

Production-safety note: Documented DMV; filter to specific counters.

## 7) Log Reuse State (Before Any Shrink Decision)
Use when log file keeps growing or does not appear to free internally.

```sql
USE master;
GO

SELECT
    name,
    recovery_model_desc,
    log_reuse_wait,
    log_reuse_wait_desc
FROM sys.databases
WHERE name = N'<YourDatabaseName>';
GO
```

Quick interpretation
- `log_reuse_wait_desc` explains why log space may not yet be reusable
- Reuse eligibility is not the same as physical file shrink

Production-safety note: Metadata-only view; safe for production diagnostics.

## 8) Optional: Current Request Snapshot
Use for quick in-flight visibility during active incidents.

```sql
SELECT
    session_id,
    status,
    command,
    wait_type,
    wait_time,
    blocking_session_id,
    database_id,
    cpu_time,
    logical_reads,
    reads,
    writes
FROM sys.dm_exec_requests
WHERE session_id > 50
ORDER BY cpu_time DESC;
GO
```

Production-safety note: Requires `VIEW SERVER STATE`; documented DMV for live diagnostics.

## First-Response Order (Recommended)
1. Confirm file type pressure (Query 1)
2. Check object space context (Query 2 or 3)
3. Check memory evidence if performance-related (Query 4, 5, 6)
4. Check log reuse state before shrink decisions (Query 7)
5. Check active requests if behavior is in-flight (Query 8)

## Common Pitfalls
- Treating data-file growth and log-file growth as the same issue
- Assuming in-memory pages remove dependency on data files
- Confusing checkpoint activity with lazy writer activity
- Shrinking log before checking `log_reuse_wait_desc`
