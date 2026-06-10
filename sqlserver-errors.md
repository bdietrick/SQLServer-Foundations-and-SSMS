# SQL Server Error Logs

```sql
EXEC xp_readerrorlog;
```

```sql
BEGIN TRY
    -- your statements
	print 'executing script'
	GO
	
	RAISERROR (N'This is message %s %d.', -- Message text.
		10, -- Severity,
		1, -- State,
		N'number', -- First argument.
		5); -- Second argument.
	-- The message text returned is: This is message number 5.
	GO	
	  
END TRY
BEGIN CATCH
    SELECT
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_SEVERITY() AS ErrorSeverity,
        ERROR_STATE() AS ErrorState,
        ERROR_PROCEDURE() AS ErrorProcedure,
        ERROR_LINE() AS ErrorLine,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
```


# SQL Server Extended Events Templates (SQL Server 2016)

This page provides three ready-to-run Extended Events templates for support diagnostics:

1. Errors (severity >= 16)
2. Deadlocks
3. Slow queries

SQL Server 2016 note: Extended Events is the preferred replacement for SQL Trace/Profiler for ongoing diagnostics with lower overhead.

## Prerequisites

1. Ensure folder `C:\XE` exists and SQL Server service account can write to it.
2. Run scripts with an account that has permission to create server-level XE sessions.
3. Use a non-production file path in training labs if needed.

---

## Template 1: Capture Runtime Errors (Severity >= 16)

### Create and start session

```sql
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'XE_Errors_Sev16Plus')
	DROP EVENT SESSION [XE_Errors_Sev16Plus] ON SERVER;
GO

CREATE EVENT SESSION [XE_Errors_Sev16Plus]
ON SERVER
ADD EVENT sqlserver.error_reported
(
	ACTION
	(
		sqlserver.client_app_name,
		sqlserver.client_hostname,
		sqlserver.database_name,
		sqlserver.sql_text,
		sqlserver.username,
		sqlserver.session_id
	)
	WHERE ([severity] >= 16)
)
ADD TARGET package0.event_file
(
	SET filename = N'C:\XE\XE_Errors_Sev16Plus.xel',
		max_file_size = 100,
		max_rollover_files = 5
)
WITH
(
	EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
	MAX_DISPATCH_LATENCY = 5 SECONDS,
	STARTUP_STATE = ON
);
GO

ALTER EVENT SESSION [XE_Errors_Sev16Plus] ON SERVER STATE = START;
GO
```

### Read captured events

```sql
SELECT
	event_name = xed.event_data.value('(event/@name)[1]', 'nvarchar(128)'),
	utc_time = xed.event_data.value('(event/@timestamp)[1]', 'datetime2'),
	severity = xed.event_data.value('(event/data[@name="severity"]/value)[1]', 'int'),
	error_number = xed.event_data.value('(event/data[@name="error_number"]/value)[1]', 'int'),
	error_message = xed.event_data.value('(event/data[@name="message"]/value)[1]', 'nvarchar(max)'),
	database_name = xed.event_data.value('(event/action[@name="database_name"]/value)[1]', 'sysname'),
	session_id = xed.event_data.value('(event/action[@name="session_id"]/value)[1]', 'int'),
	username = xed.event_data.value('(event/action[@name="username"]/value)[1]', 'nvarchar(256)'),
	client_app = xed.event_data.value('(event/action[@name="client_app_name"]/value)[1]', 'nvarchar(256)'),
	sql_text = xed.event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)')
FROM
(
	SELECT CONVERT(XML, event_data) AS event_data
	FROM sys.fn_xe_file_target_read_file
	(
		'C:\XE\XE_Errors_Sev16Plus*.xel',
		NULL,
		NULL,
		NULL
	)
) AS xed
ORDER BY utc_time DESC;
```

---

## Template 2: Capture Deadlocks

### Create and start session

```sql
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'XE_Deadlocks')
	DROP EVENT SESSION [XE_Deadlocks] ON SERVER;
GO

CREATE EVENT SESSION [XE_Deadlocks]
ON SERVER
ADD EVENT sqlserver.xml_deadlock_report
ADD TARGET package0.event_file
(
	SET filename = N'C:\XE\XE_Deadlocks.xel',
		max_file_size = 100,
		max_rollover_files = 10
)
WITH
(
	EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
	MAX_DISPATCH_LATENCY = 5 SECONDS,
	STARTUP_STATE = ON
);
GO

ALTER EVENT SESSION [XE_Deadlocks] ON SERVER STATE = START;
GO
```

### Read captured deadlock graphs

```sql
SELECT
	utc_time = xed.event_data.value('(event/@timestamp)[1]', 'datetime2'),
	deadlock_xml = xed.event_data.query('(event/data[@name="xml_report"]/value/deadlock)[1]')
FROM
(
	SELECT CONVERT(XML, event_data) AS event_data
	FROM sys.fn_xe_file_target_read_file
	(
		'C:\XE\XE_Deadlocks*.xel',
		NULL,
		NULL,
		NULL
	)
) AS xed
ORDER BY utc_time DESC;
```

---

## Template 3: Capture Slow Queries (Completed Statements)

This template captures completed statements over 2 seconds (`duration > 2000000` microseconds).

### Create and start session

```sql
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'XE_SlowQueries')
	DROP EVENT SESSION [XE_SlowQueries] ON SERVER;
GO

CREATE EVENT SESSION [XE_SlowQueries]
ON SERVER
ADD EVENT sqlserver.sql_statement_completed
(
	ACTION
	(
		sqlserver.client_app_name,
		sqlserver.client_hostname,
		sqlserver.database_name,
		sqlserver.sql_text,
		sqlserver.username,
		sqlserver.session_id
	)
	WHERE ([duration] > 2000000)
)
ADD TARGET package0.event_file
(
	SET filename = N'C:\XE\XE_SlowQueries.xel',
		max_file_size = 200,
		max_rollover_files = 8
)
WITH
(
	EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
	MAX_DISPATCH_LATENCY = 5 SECONDS,
	STARTUP_STATE = OFF
);
GO

ALTER EVENT SESSION [XE_SlowQueries] ON SERVER STATE = START;
GO
```

### Read captured slow statements

```sql
SELECT
	utc_time = xed.event_data.value('(event/@timestamp)[1]', 'datetime2'),
	duration_us = xed.event_data.value('(event/data[@name="duration"]/value)[1]', 'bigint'),
	duration_ms = xed.event_data.value('(event/data[@name="duration"]/value)[1]', 'bigint') / 1000.0,
	cpu_time_us = xed.event_data.value('(event/data[@name="cpu_time"]/value)[1]', 'bigint'),
	logical_reads = xed.event_data.value('(event/data[@name="logical_reads"]/value)[1]', 'bigint'),
	row_count = xed.event_data.value('(event/data[@name="row_count"]/value)[1]', 'bigint'),
	database_name = xed.event_data.value('(event/action[@name="database_name"]/value)[1]', 'sysname'),
	session_id = xed.event_data.value('(event/action[@name="session_id"]/value)[1]', 'int'),
	username = xed.event_data.value('(event/action[@name="username"]/value)[1]', 'nvarchar(256)'),
	client_app = xed.event_data.value('(event/action[@name="client_app_name"]/value)[1]', 'nvarchar(256)'),
	sql_text = xed.event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)')
FROM
(
	SELECT CONVERT(XML, event_data) AS event_data
	FROM sys.fn_xe_file_target_read_file
	(
		'C:\XE\XE_SlowQueries*.xel',
		NULL,
		NULL,
		NULL
	)
) AS xed
ORDER BY duration_us DESC;
```

---

## Stop or drop sessions

```sql
ALTER EVENT SESSION [XE_Errors_Sev16Plus] ON SERVER STATE = STOP;
ALTER EVENT SESSION [XE_Deadlocks] ON SERVER STATE = STOP;
ALTER EVENT SESSION [XE_SlowQueries] ON SERVER STATE = STOP;
GO

-- Optional cleanup
DROP EVENT SESSION [XE_Errors_Sev16Plus] ON SERVER;
DROP EVENT SESSION [XE_Deadlocks] ON SERVER;
DROP EVENT SESSION [XE_SlowQueries] ON SERVER;
GO
```

## Operational Notes

1. Keep filters tight to minimize overhead.
2. Prefer event file target over ring buffer for persistence.
3. In production, avoid unnecessary `sql_text` capture if sensitive data exposure is a concern.
4. Review and archive `.xel` files under retention policy.
5. For regulated environments, treat XE output as controlled diagnostic evidence.
