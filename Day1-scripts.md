
## Slide 40 - Demo Script 1: Identify the Instance

**On-slide content**
```sql
SELECT
    @@SERVERNAME AS server_name,
    @@SERVICENAME AS service_name,
    @@VERSION AS version_string;
```

---

## Slide 41 - Demo Script 2: Review Databases

**On-slide content**
```sql
SELECT
    name,
    database_id,
    state_desc,
    recovery_model_desc
FROM sys.databases
ORDER BY name;
```


---

## Slide 42 - Demo Script 3: Inspect Instance Properties

**On-slide content**
```sql
SELECT
    SERVERPROPERTY('MachineName') AS machine_name,
    SERVERPROPERTY('ServerName') AS server_name,
    SERVERPROPERTY('InstanceName') AS instance_name,
    SERVERPROPERTY('Edition') AS edition,
    SERVERPROPERTY('ProductVersion') AS product_version,
    SERVERPROPERTY('ProductLevel') AS product_level;
```

ge.

---

## Slide 43 - Demo Script 4: Create the Demo Database

**On-slide content**
```sql
IF DB_ID('CourseDemo_Module1') IS NOT NULL
BEGIN
    ALTER DATABASE CourseDemo_Module1 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CourseDemo_Module1;
END;
GO

CREATE DATABASE CourseDemo_Module1;
GO

USE CourseDemo_Module1;
GO

CREATE TABLE dbo.SupportTickets
(
    TicketId int IDENTITY(1,1) PRIMARY KEY,
    SystemName nvarchar(50) NOT NULL,
    IssueType nvarchar(50) NOT NULL,
    PriorityLevel varchar(10) NOT NULL,
    OpenedBy nvarchar(50) NOT NULL,
    OpenedDate datetime2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
```


---

## Slide 44 - Demo Script 5: Populate and Query the Dataset

**On-slide content**
```sql
INSERT INTO dbo.SupportTickets (SystemName, IssueType, PriorityLevel, OpenedBy)
VALUES
('SQLLAB01', 'Login Failure', 'High', 'Alex'),
('SQLLAB01\\HR', 'Named Instance Not Found', 'Medium', 'Jordan'),
('SQLLAB02', 'Service Will Not Start', 'High', 'Sam'),
('SQLLAB03', 'Port Blocked', 'Medium', 'Taylor'),
('SQLLAB04', 'Agent Job Failed', 'Low', 'Morgan');
GO

SELECT TOP (5)
    TicketId,
    SystemName,
    IssueType,
    PriorityLevel,
    OpenedBy,
    OpenedDate
FROM dbo.SupportTickets
ORDER BY TicketId;
```



---

## Slide 45 - Demo Script 6: Database-Level Example

**On-slide content**
```sql
SELECT
    name,
    compatibility_level,
    collation_name
FROM sys.databases
WHERE name = 'CourseDemo_Module1';
```


---

## Slide 46 - Student Handout: Key Terms

**On-slide content**
- SQL Server platform
- Database Engine
- SQL Server Agent
- Service account
- Instance
- Default instance
- Named instance
- SQL Browser
- TCP/IP
- Windows Authentication
- SQL Authentication



---

## Slide 47 - Student Handout: Quick Reference Table

**On-slide content**
| Topic | Quick reference |
|---|---|
| Default instance | Commonly connects as `ServerName` |
| Named instance | Commonly connects as `ServerName\\InstanceName` |
| Default TCP port | Usually 1433 |
| SQL Browser | Helps map named instance to port |
| Protocols | Shared Memory, TCP/IP, Named Pipes |
| First connectivity checks | Service, name, port, protocol, auth |



---

## Slide 48 - Lab Introduction

**On-slide content**
- Goal: identify instance behavior and reason through connectivity issues
- Work in SSMS
- Use provided scripts
- Record observations, not just outputs



---

## Slide 49 - Lab Tasks

**On-slide content**
- Connect to the assigned instance
- Run the environment verification script
- Determine default vs. named instance behavior
- Create the demo database
- Review `sys.databases`
- Evaluate support scenarios
- Document instance-level vs. database-level facts


---

## Slide 50 - Lab Script: Environment Verification

**On-slide content**
```sql
SELECT
    @@SERVERNAME AS server_name,
    @@SERVICENAME AS service_name,
    SERVERPROPERTY('Edition') AS edition,
    SERVERPROPERTY('ProductVersion') AS product_version;
```



---

## Slide 51 - Lab Script: Scenario Table Setup

**On-slide content**
```sql
IF DB_ID('CourseDemo_Module1') IS NOT NULL
BEGIN
    ALTER DATABASE CourseDemo_Module1 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CourseDemo_Module1;
END;
GO

CREATE DATABASE CourseDemo_Module1;
GO

USE CourseDemo_Module1;
GO

CREATE TABLE dbo.InstanceScenarios
(
    ScenarioId int IDENTITY(1,1) PRIMARY KEY,
    ScenarioName nvarchar(100) NOT NULL,
    ConnectionExample nvarchar(100) NOT NULL,
    LikelyCause nvarchar(200) NOT NULL
);
GO

INSERT INTO dbo.InstanceScenarios (ScenarioName, ConnectionExample, LikelyCause)
VALUES
('Default instance connection', 'SQLLAB01', 'Engine reachable on expected endpoint'),
('Named instance connection', 'SQLLAB01\\HR', 'Client may need SQL Browser or a fixed port'),
('Explicit port connection', 'SQLLAB01,51433', 'Used when named instance discovery is bypassed'),
('Authentication issue', 'SQLLAB02', 'Login mode or permissions mismatch'),
('Network path issue', 'SQLLAB03\\OPS', 'Firewall, protocol, or Browser problem');
GO
```



---

## Slide 52 - Lab Script: Review Scenarios

**On-slide content**
```sql
USE CourseDemo_Module1;
GO

SELECT TOP (10)
    ScenarioId,
    ScenarioName,
    ConnectionExample,
    LikelyCause
FROM dbo.InstanceScenarios
ORDER BY ScenarioId;
```



---

