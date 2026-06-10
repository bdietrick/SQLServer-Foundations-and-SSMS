------------------------------------------------------------
-- DATABASE CREATION (RERUN SAFE)
------------------------------------------------------------
IF DB_ID('PharmaMES') IS NOT NULL
BEGIN
    ALTER DATABASE PharmaMES SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PharmaMES;
END;
GO

CREATE DATABASE PharmaMES;
GO
USE PharmaMES;
GO

------------------------------------------------------------
-- LOOKUP TABLES
------------------------------------------------------------

CREATE TABLE Operators (
    OperatorID VARCHAR(10) PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    Role NVARCHAR(50) NOT NULL,
    CreatedOn DATETIME2 NOT NULL
);

CREATE TABLE Rooms (
    RoomCode VARCHAR(10) PRIMARY KEY,
    Description NVARCHAR(100) NOT NULL,
    CreatedOn DATETIME2 NOT NULL
);

CREATE TABLE Equipment (
    EquipmentID VARCHAR(20) PRIMARY KEY,
    EquipmentName NVARCHAR(100) NOT NULL,
    Area VARCHAR(20) NOT NULL,
    CommissionedOn DATETIME2 NOT NULL,
    Status VARCHAR(20) NOT NULL
);

------------------------------------------------------------
-- CORE BATCH AND MATERIAL TABLES
------------------------------------------------------------

CREATE TABLE BatchHeader (
    BatchID INT PRIMARY KEY,
    ProductCode VARCHAR(20) NOT NULL,
    BatchNumber VARCHAR(30) NOT NULL,
    PlannedQty INT NOT NULL,
    StartTime DATETIME2 NOT NULL,
    EndTime DATETIME2 NULL,
    Status VARCHAR(20) NOT NULL
);

CREATE TABLE MaterialLots (
    MaterialLotID VARCHAR(20) PRIMARY KEY,
    MaterialCode VARCHAR(20) NOT NULL,
    Supplier NVARCHAR(100) NOT NULL,
    LotNumber VARCHAR(50) NOT NULL,
    ExpiryDate DATE NOT NULL,
    COAStatus VARCHAR(20) NOT NULL,
    ReceivedOn DATETIME2 NOT NULL
);

CREATE TABLE MaterialConsumption (
    ConsumptionID INT PRIMARY KEY,
    BatchID INT NOT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    MaterialLotID VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES MaterialLots(MaterialLotID),
    QtyUsed DECIMAL(10,2) NOT NULL,
    ConsumedOn DATETIME2 NOT NULL
);

------------------------------------------------------------
-- BPM PROCESS TABLES
-- Steps: Batch creation, Material verification, Weigh & dispense,
-- Blending, Granulation, Compression, Coating, Packaging,
-- IPC checks, Deviations, QA release
------------------------------------------------------------

CREATE TABLE MaterialVerification (
    VerificationID INT PRIMARY KEY,
    BatchID INT NOT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    MaterialLotID VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES MaterialLots(MaterialLotID),
    VerifiedBy VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    VerifiedOn DATETIME2 NOT NULL,
    Result VARCHAR(20) NOT NULL,
    Notes NVARCHAR(200) NULL
);

CREATE TABLE WeighDispense (
    DispenseID INT PRIMARY KEY,
    BatchID INT NOT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    MaterialLotID VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES MaterialLots(MaterialLotID),
    WeighedBy VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    DispensedQty DECIMAL(10,2) NOT NULL,
    Unit VARCHAR(20) NOT NULL,
    WeighDispenseTime DATETIME2 NOT NULL,
    Result VARCHAR(20) NOT NULL
);

CREATE TABLE Blending (
    BlendID INT PRIMARY KEY,
    BatchID INT NOT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    EquipmentID VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES Equipment(EquipmentID),
    OperatorID VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    StartTime DATETIME2 NOT NULL,
    EndTime DATETIME2 NOT NULL,
    RPM INT NOT NULL,
    Result VARCHAR(20) NOT NULL
);

CREATE TABLE Granulation (
    GranulationID INT PRIMARY KEY,
    BatchID INT NOT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    EquipmentID VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES Equipment(EquipmentID),
    OperatorID VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    StartTime DATETIME2 NOT NULL,
    EndTime DATETIME2 NOT NULL,
    MoisturePct DECIMAL(5,2) NOT NULL,
    Result VARCHAR(20) NOT NULL
);

CREATE TABLE Compression (
    CompressionID INT PRIMARY KEY,
    BatchID INT NOT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    EquipmentID VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES Equipment(EquipmentID),
    OperatorID VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    StartTime DATETIME2 NOT NULL,
    EndTime DATETIME2 NOT NULL,
    AvgWeightMg DECIMAL(10,2) NOT NULL,
    Result VARCHAR(20) NOT NULL
);

CREATE TABLE Coating (
    CoatingID INT PRIMARY KEY,
    BatchID INT NOT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    EquipmentID VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES Equipment(EquipmentID),
    OperatorID VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    StartTime DATETIME2 NOT NULL,
    EndTime DATETIME2 NOT NULL,
    CoatingGainPct DECIMAL(5,2) NOT NULL,
    Result VARCHAR(20) NOT NULL
);

CREATE TABLE Packaging (
    PackagingID INT PRIMARY KEY,
    BatchID INT NOT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    EquipmentID VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES Equipment(EquipmentID),
    OperatorID VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    StartTime DATETIME2 NOT NULL,
    EndTime DATETIME2 NOT NULL,
    PacksProduced INT NOT NULL,
    Result VARCHAR(20) NOT NULL
);

CREATE TABLE IPCResults (
    IPCID INT PRIMARY KEY,
    BatchID INT NOT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    Stage VARCHAR(30) NOT NULL,
    TestName VARCHAR(50) NOT NULL,
    SampleNumber INT NOT NULL,
    ResultValue DECIMAL(10,2) NOT NULL,
    Unit VARCHAR(20) NOT NULL,
    Spec VARCHAR(50) NOT NULL,
    PassFlag BIT NOT NULL,
    TestedOn DATETIME2 NOT NULL,
    TestedBy VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID)
);

CREATE TABLE Deviations (
    DeviationID INT PRIMARY KEY,
    BatchID INT NOT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    Description NVARCHAR(200) NOT NULL,
    Severity VARCHAR(20) NOT NULL,
    Opened DATETIME2 NOT NULL,
    Closed DATETIME2 NULL,
    Status VARCHAR(20) NOT NULL,
    OpenedBy VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    ClosedBy VARCHAR(10) NULL FOREIGN KEY REFERENCES Operators(OperatorID)
);

CREATE TABLE QARelease (
    ReleaseID INT PRIMARY KEY,
    BatchID INT NOT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    Decision VARCHAR(20) NOT NULL,
    ReleasedBy VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    ReleasedOn DATETIME2 NOT NULL,
    Comments NVARCHAR(200) NULL
);

CREATE TABLE SerializedUnits (
    SerialID INT PRIMARY KEY,
    BatchID INT NOT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    GTIN VARCHAR(20) NOT NULL,
    SerialNumber VARCHAR(50) NOT NULL,
    PackDate DATE NOT NULL,
    Status VARCHAR(20) NOT NULL,
    CreatedOn DATETIME2 NOT NULL
);

CREATE TABLE EquipmentLog (
    EquipLogID INT PRIMARY KEY,
    EquipmentID VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES Equipment(EquipmentID),
    BatchID INT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    Action VARCHAR(50) NOT NULL,
    OperatorID VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    LoggedAt DATETIME2 NOT NULL,
    Status VARCHAR(20) NOT NULL
);

CREATE TABLE EnvMonitoring (
    RecordID INT PRIMARY KEY,
    RoomCode VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Rooms(RoomCode),
    Parameter VARCHAR(50) NOT NULL,
    Value DECIMAL(10,2) NOT NULL,
    Unit VARCHAR(20) NOT NULL,
    RecordedAt DATETIME2 NOT NULL,
    Status VARCHAR(30) NOT NULL
);

CREATE TABLE BatchStepExecution (
    StepExecID INT PRIMARY KEY,
    BatchID INT NOT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    StepNumber INT NOT NULL,
    StepName NVARCHAR(100) NOT NULL,
    OperatorID VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    StartTime DATETIME2 NOT NULL,
    EndTime DATETIME2 NOT NULL,
    Result VARCHAR(20) NOT NULL
);

CREATE TABLE AuditTrail (
    AuditID INT PRIMARY KEY,
    UserID VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    Action VARCHAR(100) NOT NULL,
    ObjectType VARCHAR(50) NOT NULL,
    ObjectID VARCHAR(50) NOT NULL,
    LoggedAt DATETIME2 NOT NULL,
    Reason NVARCHAR(200) NULL
);

------------------------------------------------------------
-- REGULATED DATA CORRECTION PATTERN
-- Use append-only correction records plus controlled update procedure.
------------------------------------------------------------

CREATE TABLE DataCorrectionHeader (
    CorrectionID INT IDENTITY(1,1) PRIMARY KEY,
    CorrectionRef VARCHAR(30) NOT NULL UNIQUE,
    ChangeControlID VARCHAR(30) NOT NULL,
    DeviationID INT NULL,
    BatchID INT NULL FOREIGN KEY REFERENCES BatchHeader(BatchID),
    RequestedBy VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    ApprovedBy VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    ExecutedBy VARCHAR(10) NOT NULL FOREIGN KEY REFERENCES Operators(OperatorID),
    RequestedOn DATETIME2 NOT NULL,
    ApprovedOn DATETIME2 NOT NULL,
    ExecutedOn DATETIME2 NOT NULL,
    Reason NVARCHAR(500) NOT NULL,
    ImpactAssessment NVARCHAR(500) NOT NULL,
    SignatureMeaning NVARCHAR(100) NOT NULL,
    Status VARCHAR(20) NOT NULL
);

CREATE TABLE DataCorrectionDetail (
    DetailID INT IDENTITY(1,1) PRIMARY KEY,
    CorrectionID INT NOT NULL FOREIGN KEY REFERENCES DataCorrectionHeader(CorrectionID),
    TableName SYSNAME NOT NULL,
    RecordPK NVARCHAR(100) NOT NULL,
    ColumnName SYSNAME NOT NULL,
    OldValue NVARCHAR(4000) NULL,
    NewValue NVARCHAR(4000) NULL,
    ChangedOn DATETIME2 NOT NULL,
    ChangeType VARCHAR(20) NOT NULL
);
GO

CREATE PROCEDURE dbo.usp_Fix_MaterialVerificationTimestamp_WithAudit
    @VerificationID INT,
    @NewVerifiedOn DATETIME2,
    @ChangeControlID VARCHAR(30),
    @BatchID INT,
    @RequestedBy VARCHAR(10),
    @ApprovedBy VARCHAR(10),
    @ExecutedBy VARCHAR(10),
    @Reason NVARCHAR(500),
    @ImpactAssessment NVARCHAR(500),
    @SignatureMeaning NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @OldVerifiedOn DATETIME2;
    DECLARE @CorrectionID INT;
    DECLARE @CorrectionRef VARCHAR(30);
    DECLARE @AuditID INT;

    SELECT @OldVerifiedOn = VerifiedOn
    FROM MaterialVerification
    WHERE VerificationID = @VerificationID;

    IF @OldVerifiedOn IS NULL
    BEGIN
        RAISERROR('MaterialVerification row not found for supplied VerificationID.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        SET @CorrectionRef = CONCAT('DCR-', FORMAT(SYSDATETIME(), 'yyyyMMddHHmmss'));

        INSERT INTO DataCorrectionHeader (
            CorrectionRef,
            ChangeControlID,
            DeviationID,
            BatchID,
            RequestedBy,
            ApprovedBy,
            ExecutedBy,
            RequestedOn,
            ApprovedOn,
            ExecutedOn,
            Reason,
            ImpactAssessment,
            SignatureMeaning,
            Status
        )
        VALUES (
            @CorrectionRef,
            @ChangeControlID,
            NULL,
            @BatchID,
            @RequestedBy,
            @ApprovedBy,
            @ExecutedBy,
            SYSDATETIME(),
            SYSDATETIME(),
            SYSDATETIME(),
            @Reason,
            @ImpactAssessment,
            @SignatureMeaning,
            'Executed'
        );

        SET @CorrectionID = SCOPE_IDENTITY();

        INSERT INTO DataCorrectionDetail (
            CorrectionID,
            TableName,
            RecordPK,
            ColumnName,
            OldValue,
            NewValue,
            ChangedOn,
            ChangeType
        )
        VALUES (
            @CorrectionID,
            'MaterialVerification',
            CAST(@VerificationID AS NVARCHAR(100)),
            'VerifiedOn',
            CONVERT(NVARCHAR(30), @OldVerifiedOn, 126),
            CONVERT(NVARCHAR(30), @NewVerifiedOn, 126),
            SYSDATETIME(),
            'UPDATE'
        );

        UPDATE MaterialVerification
        SET VerifiedOn = @NewVerifiedOn,
            Notes = CONCAT(COALESCE(Notes + ' | ', ''), 'Corrected under ', @CorrectionRef)
        WHERE VerificationID = @VerificationID;

        SELECT @AuditID = ISNULL(MAX(AuditID), 0) + 1
        FROM AuditTrail;

        INSERT INTO AuditTrail (AuditID, UserID, Action, ObjectType, ObjectID, LoggedAt, Reason)
        VALUES (
            @AuditID,
            @ExecutedBy,
            'DATA_CORRECTION_EXECUTED',
            'MaterialVerification',
            CAST(@VerificationID AS VARCHAR(50)),
            SYSDATETIME(),
            CONCAT('Applied ', @CorrectionRef, ' under ', @ChangeControlID)
        );

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        THROW;
    END CATCH;
END;
GO

------------------------------------------------------------
-- EXAMPLE FIX WITH AUDIT (for issue #2, VerificationID 91)
-- Keep commented for safe execution during training walkthrough.
------------------------------------------------------------

/*
EXEC dbo.usp_Fix_MaterialVerificationTimestamp_WithAudit
    @VerificationID = 91,
    @NewVerifiedOn = '2026-06-05T07:15:00',
    @ChangeControlID = 'CC-2026-0042',
    @BatchID = 1091,
    @RequestedBy = 'QA112',
    @ApprovedBy = 'QA210',
    @ExecutedBy = 'QA112',
    @Reason = 'Verification timestamp was after weigh and dispense. Correcting to restore process sequence.',
    @ImpactAssessment = 'No product quality impact. Documentation alignment correction only.',
    @SignatureMeaning = 'Reviewed and approved data correction.';

SELECT * FROM DataCorrectionHeader ORDER BY CorrectionID DESC;
SELECT * FROM DataCorrectionDetail ORDER BY DetailID DESC;
*/

------------------------------------------------------------
-- BASELINE SEED DATA (BPM-CONSISTENT)
-- Batches 1001 and 1002 are complete and contain all required process data.
-- Batch 1003 is in-process and intentionally not yet released.
------------------------------------------------------------

INSERT INTO Operators (OperatorID, FullName, Role, CreatedOn) VALUES
('OP221','Maria Sanchez','Manufacturing Tech','2026-05-01T08:00:00'),
('OP332','James Porter','Manufacturing Tech','2026-05-01T08:05:00'),
('QA112','Linda Chen','QA Specialist','2026-05-01T08:10:00'),
('QA210','Robert Miles','QA Reviewer','2026-05-01T08:15:00'),
('ENG01','Priya Patel','Maintenance Engineer','2026-05-01T08:20:00');

INSERT INTO Rooms (RoomCode, Description, CreatedOn) VALUES
('CR-A','Cleanroom A','2026-05-01T08:30:00'),
('CR-B','Cleanroom B','2026-05-01T08:30:00'),
('CR-C','Cleanroom C','2026-05-01T08:30:00'),
('WR-1','Weighing Room 1','2026-05-01T08:30:00'),
('PKG-1','Packaging Line 1','2026-05-01T08:30:00');

INSERT INTO Equipment (EquipmentID, EquipmentName, Area, CommissionedOn, Status) VALUES
('BLD-01','Main Blender','Granulation','2025-01-10T09:00:00','Active'),
('GRA-01','High Shear Granulator','Granulation','2025-01-12T09:00:00','Active'),
('CMP-01','Tablet Press 1','Compression','2025-01-14T09:00:00','Active'),
('COA-01','Auto Coater 1','Coating','2025-01-16T09:00:00','Active'),
('PKG-01','Primary Packaging Line','Packaging','2025-01-18T09:00:00','Active');

INSERT INTO MaterialLots (MaterialLotID, MaterialCode, Supplier, LotNumber, ExpiryDate, COAStatus, ReceivedOn) VALUES
('LOT-A001','API-IBU','PharmaChem Inc','API-2026-001','2027-01-31','Approved','2026-05-15T08:00:00'),
('LOT-B001','EXC-MCC','Excipients Co','MCC-2026-020','2027-03-31','Approved','2026-05-15T08:15:00'),
('LOT-C001','EXC-PVP','Binders Ltd','PVP-2026-014','2026-12-31','Approved','2026-05-15T08:30:00'),
('LOT-D001','COAT-HPMC','CoatTech','HPMC-2026-008','2027-06-30','Approved','2026-05-15T08:45:00'),
('LOT-E001','EXC-LACT','Lactose Labs','LAC-2026-011','2027-02-28','Approved','2026-05-15T09:00:00');

INSERT INTO BatchHeader (BatchID, ProductCode, BatchNumber, PlannedQty, StartTime, EndTime, Status) VALUES
(1001,'TAB-IBU-200','B2026-1001',120000,'2026-06-01T07:00:00','2026-06-01T17:30:00','Completed'),
(1002,'TAB-IBU-400','B2026-1002',100000,'2026-06-02T07:10:00','2026-06-02T18:00:00','Completed'),
(1003,'TAB-IBU-200','B2026-1003',90000,'2026-06-03T07:20:00',NULL,'InProcess');

-- Material verification (pre-weigh)
INSERT INTO MaterialVerification (VerificationID, BatchID, MaterialLotID, VerifiedBy, VerifiedOn, Result, Notes) VALUES
(1,1001,'LOT-A001','QA112','2026-06-01T07:05:00','Approved','COA and label match'),
(2,1001,'LOT-B001','QA112','2026-06-01T07:06:00','Approved','Seal intact'),
(3,1001,'LOT-C001','QA112','2026-06-01T07:07:00','Approved','Released by QA'),
(4,1001,'LOT-D001','QA112','2026-06-01T07:08:00','Approved','Coating lot verified'),
(5,1002,'LOT-A001','QA112','2026-06-02T07:15:00','Approved','COA and label match'),
(6,1002,'LOT-E001','QA112','2026-06-02T07:16:00','Approved','Seal intact'),
(7,1002,'LOT-C001','QA112','2026-06-02T07:17:00','Approved','Binder lot verified'),
(8,1002,'LOT-D001','QA112','2026-06-02T07:18:00','Approved','Coating lot verified'),
(9,1003,'LOT-A001','QA112','2026-06-03T07:25:00','Approved','COA and label match'),
(10,1003,'LOT-B001','QA112','2026-06-03T07:26:00','Approved','Seal intact');

-- Weigh and dispense (after material verification)
INSERT INTO WeighDispense (DispenseID, BatchID, MaterialLotID, WeighedBy, DispensedQty, Unit, WeighDispenseTime, Result) VALUES
(1,1001,'LOT-A001','OP221',24.00,'kg','2026-06-01T07:20:00','OK'),
(2,1001,'LOT-B001','OP221',55.00,'kg','2026-06-01T07:28:00','OK'),
(3,1001,'LOT-C001','OP332',6.00,'kg','2026-06-01T07:35:00','OK'),
(4,1001,'LOT-D001','OP332',2.00,'kg','2026-06-01T14:50:00','OK'),
(5,1002,'LOT-A001','OP221',20.00,'kg','2026-06-02T07:30:00','OK'),
(6,1002,'LOT-E001','OP221',48.00,'kg','2026-06-02T07:36:00','OK'),
(7,1002,'LOT-C001','OP332',5.50,'kg','2026-06-02T07:42:00','OK'),
(8,1002,'LOT-D001','OP332',1.80,'kg','2026-06-02T15:05:00','OK'),
(9,1003,'LOT-A001','OP221',18.00,'kg','2026-06-03T07:35:00','OK'),
(10,1003,'LOT-B001','OP332',42.00,'kg','2026-06-03T07:43:00','OK');

INSERT INTO MaterialConsumption (ConsumptionID, BatchID, MaterialLotID, QtyUsed, ConsumedOn) VALUES
(1,1001,'LOT-A001',24.00,'2026-06-01T07:40:00'),
(2,1001,'LOT-B001',55.00,'2026-06-01T07:41:00'),
(3,1001,'LOT-C001',6.00,'2026-06-01T07:42:00'),
(4,1001,'LOT-D001',2.00,'2026-06-01T15:00:00'),
(5,1002,'LOT-A001',20.00,'2026-06-02T07:50:00'),
(6,1002,'LOT-E001',48.00,'2026-06-02T07:51:00'),
(7,1002,'LOT-C001',5.50,'2026-06-02T07:52:00'),
(8,1002,'LOT-D001',1.80,'2026-06-02T15:15:00'),
(9,1003,'LOT-A001',18.00,'2026-06-03T07:55:00'),
(10,1003,'LOT-B001',42.00,'2026-06-03T07:56:00');

-- Process execution tables
INSERT INTO Blending (BlendID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, RPM, Result) VALUES
(1,1001,'BLD-01','OP221','2026-06-01T08:00:00','2026-06-01T09:00:00',80,'OK'),
(2,1002,'BLD-01','OP332','2026-06-02T08:10:00','2026-06-02T09:05:00',82,'OK'),
(3,1003,'BLD-01','OP221','2026-06-03T08:15:00','2026-06-03T09:10:00',81,'OK');

INSERT INTO Granulation (GranulationID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, MoisturePct, Result) VALUES
(1,1001,'GRA-01','OP332','2026-06-01T09:15:00','2026-06-01T10:25:00',2.30,'OK'),
(2,1002,'GRA-01','OP221','2026-06-02T09:20:00','2026-06-02T10:30:00',2.40,'OK'),
(3,1003,'GRA-01','OP332','2026-06-03T09:25:00','2026-06-03T10:35:00',2.35,'OK');

INSERT INTO Compression (CompressionID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, AvgWeightMg, Result) VALUES
(1,1001,'CMP-01','OP221','2026-06-01T10:45:00','2026-06-01T12:20:00',501.20,'OK'),
(2,1002,'CMP-01','OP332','2026-06-02T10:50:00','2026-06-02T12:35:00',649.50,'OK'),
(3,1003,'CMP-01','OP221','2026-06-03T10:55:00','2026-06-03T12:40:00',503.10,'OK');

INSERT INTO Coating (CoatingID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, CoatingGainPct, Result) VALUES
(1,1001,'COA-01','OP332','2026-06-01T13:00:00','2026-06-01T14:20:00',2.10,'OK'),
(2,1002,'COA-01','OP221','2026-06-02T13:15:00','2026-06-02T14:30:00',2.05,'OK');

INSERT INTO Packaging (PackagingID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, PacksProduced, Result) VALUES
(1,1001,'PKG-01','OP221','2026-06-01T14:40:00','2026-06-01T16:20:00',118000,'OK'),
(2,1002,'PKG-01','OP332','2026-06-02T14:45:00','2026-06-02T16:45:00',98000,'OK');

INSERT INTO IPCResults (IPCID, BatchID, Stage, TestName, SampleNumber, ResultValue, Unit, Spec, PassFlag, TestedOn, TestedBy) VALUES
(1,1001,'Granulation','Moisture',1,2.30,'%','<= 3.00',1,'2026-06-01T10:20:00','QA112'),
(2,1001,'Compression','TabletWeight',1,501.20,'mg','500 +/- 10',1,'2026-06-01T11:10:00','QA112'),
(3,1001,'Coating','AppearanceScore',1,9.00,'score','>= 8',1,'2026-06-01T14:10:00','QA210'),
(4,1002,'Granulation','Moisture',1,2.40,'%','<= 3.00',1,'2026-06-02T10:25:00','QA112'),
(5,1002,'Compression','TabletWeight',1,649.50,'mg','650 +/- 15',1,'2026-06-02T11:20:00','QA112'),
(6,1002,'Coating','AppearanceScore',1,8.80,'score','>= 8',1,'2026-06-02T14:15:00','QA210'),
(7,1003,'Granulation','Moisture',1,2.35,'%','<= 3.00',1,'2026-06-03T10:30:00','QA112'),
(8,1003,'Compression','TabletWeight',1,503.10,'mg','500 +/- 10',1,'2026-06-03T11:30:00','QA112');

INSERT INTO Deviations (DeviationID, BatchID, Description, Severity, Opened, Closed, Status, OpenedBy, ClosedBy) VALUES
(1,1002,'Minor tablet chipping observed at startup; adjusted feeder.','Minor','2026-06-02T11:05:00','2026-06-02T11:40:00','Closed','OP332','QA210');

INSERT INTO QARelease (ReleaseID, BatchID, Decision, ReleasedBy, ReleasedOn, Comments) VALUES
(1,1001,'Released','QA210','2026-06-01T17:20:00','All records reviewed and approved.'),
(2,1002,'Released','QA210','2026-06-02T17:55:00','Deviation closed before disposition.');

INSERT INTO SerializedUnits (SerialID, BatchID, GTIN, SerialNumber, PackDate, Status, CreatedOn) VALUES
(1,1001,'08912345670001','SN1001-000001','2026-06-01','Packed','2026-06-01T16:00:00'),
(2,1001,'08912345670001','SN1001-000002','2026-06-01','Packed','2026-06-01T16:00:01'),
(3,1002,'08912345670002','SN1002-000001','2026-06-02','Packed','2026-06-02T16:10:00'),
(4,1002,'08912345670002','SN1002-000002','2026-06-02','Packed','2026-06-02T16:10:01');

INSERT INTO EquipmentLog (EquipLogID, EquipmentID, BatchID, Action, OperatorID, LoggedAt, Status) VALUES
(1,'BLD-01',1001,'Pre-use check','ENG01','2026-06-01T07:50:00','Completed'),
(2,'CMP-01',1001,'In-process cleaning','ENG01','2026-06-01T12:30:00','Completed'),
(3,'PKG-01',1002,'Line clearance','ENG01','2026-06-02T14:35:00','Completed');

INSERT INTO EnvMonitoring (RecordID, RoomCode, Parameter, Value, Unit, RecordedAt, Status) VALUES
(1,'CR-A','Temperature',21.60,'C','2026-06-01T08:05:00','WithinRange'),
(2,'CR-A','Humidity',45.20,'%RH','2026-06-01T08:05:00','WithinRange'),
(3,'CR-B','Temperature',21.90,'C','2026-06-02T08:15:00','WithinRange'),
(4,'CR-C','DifferentialPressure',12.50,'Pa','2026-06-03T08:25:00','WithinRange');

INSERT INTO BatchStepExecution (StepExecID, BatchID, StepNumber, StepName, OperatorID, StartTime, EndTime, Result) VALUES
(1,1001,1,'Batch creation','OP221','2026-06-01T07:00:00','2026-06-01T07:01:00','OK'),
(2,1001,2,'Material verification','QA112','2026-06-01T07:05:00','2026-06-01T07:08:00','OK'),
(3,1001,3,'Weigh and dispense','OP221','2026-06-01T07:20:00','2026-06-01T07:35:00','OK'),
(4,1001,4,'Blending','OP221','2026-06-01T08:00:00','2026-06-01T09:00:00','OK'),
(5,1001,5,'Granulation','OP332','2026-06-01T09:15:00','2026-06-01T10:25:00','OK'),
(6,1001,6,'Compression','OP221','2026-06-01T10:45:00','2026-06-01T12:20:00','OK'),
(7,1001,7,'Coating','OP332','2026-06-01T13:00:00','2026-06-01T14:20:00','OK'),
(8,1001,8,'Packaging','OP221','2026-06-01T14:40:00','2026-06-01T16:20:00','OK'),
(9,1001,9,'IPC checks','QA112','2026-06-01T10:20:00','2026-06-01T14:10:00','OK'),
(10,1001,10,'QA release','QA210','2026-06-01T17:20:00','2026-06-01T17:25:00','OK'),
(11,1002,1,'Batch creation','OP332','2026-06-02T07:10:00','2026-06-02T07:11:00','OK'),
(12,1002,2,'Material verification','QA112','2026-06-02T07:15:00','2026-06-02T07:18:00','OK'),
(13,1002,3,'Weigh and dispense','OP221','2026-06-02T07:30:00','2026-06-02T07:42:00','OK'),
(14,1002,4,'Blending','OP332','2026-06-02T08:10:00','2026-06-02T09:05:00','OK'),
(15,1002,5,'Granulation','OP221','2026-06-02T09:20:00','2026-06-02T10:30:00','OK'),
(16,1002,6,'Compression','OP332','2026-06-02T10:50:00','2026-06-02T12:35:00','OK'),
(17,1002,7,'Coating','OP221','2026-06-02T13:15:00','2026-06-02T14:30:00','OK'),
(18,1002,8,'Packaging','OP332','2026-06-02T14:45:00','2026-06-02T16:45:00','OK'),
(19,1002,9,'IPC checks','QA112','2026-06-02T10:25:00','2026-06-02T14:15:00','OK'),
(20,1002,10,'QA release','QA210','2026-06-02T17:55:00','2026-06-02T18:00:00','OK'),
(21,1003,1,'Batch creation','OP221','2026-06-03T07:20:00','2026-06-03T07:21:00','OK'),
(22,1003,2,'Material verification','QA112','2026-06-03T07:25:00','2026-06-03T07:26:00','OK'),
(23,1003,3,'Weigh and dispense','OP332','2026-06-03T07:35:00','2026-06-03T07:43:00','OK'),
(24,1003,4,'Blending','OP221','2026-06-03T08:15:00','2026-06-03T09:10:00','OK'),
(25,1003,5,'Granulation','OP332','2026-06-03T09:25:00','2026-06-03T10:35:00','OK'),
(26,1003,6,'Compression','OP221','2026-06-03T10:55:00','2026-06-03T12:40:00','OK');

INSERT INTO AuditTrail (AuditID, UserID, Action, ObjectType, ObjectID, LoggedAt, Reason) VALUES
(1,'OP221','INSERT','BatchHeader','1001','2026-06-01T07:00:10','Batch order entered'),
(2,'QA112','INSERT','MaterialVerification','1','2026-06-01T07:05:30','Incoming lot verification'),
(3,'QA210','INSERT','QARelease','1','2026-06-01T17:20:10','Final release disposition');

------------------------------------------------------------
-- ADDITIONAL SEED DATA (MORE VOLUME, STILL RULE-COMPLIANT)
------------------------------------------------------------

INSERT INTO BatchHeader (BatchID, ProductCode, BatchNumber, PlannedQty, StartTime, EndTime, Status) VALUES
(1004,'TAB-IBU-400','B2026-1004',95000,'2026-06-04T07:05:00','2026-06-04T17:40:00','Completed');

INSERT INTO MaterialVerification (VerificationID, BatchID, MaterialLotID, VerifiedBy, VerifiedOn, Result, Notes) VALUES
(11,1004,'LOT-A001','QA112','2026-06-04T07:10:00','Approved','Primary API verified'),
(12,1004,'LOT-E001','QA112','2026-06-04T07:11:00','Approved','Excipient verified'),
(13,1004,'LOT-C001','QA112','2026-06-04T07:12:00','Approved','Binder verified'),
(14,1004,'LOT-D001','QA112','2026-06-04T07:13:00','Approved','Coating lot verified');

INSERT INTO WeighDispense (DispenseID, BatchID, MaterialLotID, WeighedBy, DispensedQty, Unit, WeighDispenseTime, Result) VALUES
(11,1004,'LOT-A001','OP221',19.00,'kg','2026-06-04T07:25:00','OK'),
(12,1004,'LOT-E001','OP332',45.00,'kg','2026-06-04T07:33:00','OK'),
(13,1004,'LOT-C001','OP332',5.20,'kg','2026-06-04T07:39:00','OK'),
(14,1004,'LOT-D001','OP221',1.70,'kg','2026-06-04T15:05:00','OK');

INSERT INTO MaterialConsumption (ConsumptionID, BatchID, MaterialLotID, QtyUsed, ConsumedOn) VALUES
(11,1004,'LOT-A001',19.00,'2026-06-04T07:50:00'),
(12,1004,'LOT-E001',45.00,'2026-06-04T07:51:00'),
(13,1004,'LOT-C001',5.20,'2026-06-04T07:52:00'),
(14,1004,'LOT-D001',1.70,'2026-06-04T15:15:00');

INSERT INTO Blending (BlendID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, RPM, Result) VALUES
(4,1004,'BLD-01','OP221','2026-06-04T08:05:00','2026-06-04T09:00:00',83,'OK');

INSERT INTO Granulation (GranulationID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, MoisturePct, Result) VALUES
(4,1004,'GRA-01','OP332','2026-06-04T09:15:00','2026-06-04T10:25:00',2.42,'OK');

INSERT INTO Compression (CompressionID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, AvgWeightMg, Result) VALUES
(4,1004,'CMP-01','OP221','2026-06-04T10:45:00','2026-06-04T12:30:00',651.20,'OK');

INSERT INTO Coating (CoatingID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, CoatingGainPct, Result) VALUES
(3,1004,'COA-01','OP332','2026-06-04T13:05:00','2026-06-04T14:25:00',2.00,'OK');

INSERT INTO Packaging (PackagingID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, PacksProduced, Result) VALUES
(3,1004,'PKG-01','OP221','2026-06-04T14:40:00','2026-06-04T16:35:00',93000,'OK');

INSERT INTO IPCResults (IPCID, BatchID, Stage, TestName, SampleNumber, ResultValue, Unit, Spec, PassFlag, TestedOn, TestedBy) VALUES
(9,1004,'Granulation','Moisture',1,2.42,'%','<= 3.00',1,'2026-06-04T10:20:00','QA112'),
(10,1004,'Compression','TabletWeight',1,651.20,'mg','650 +/- 15',1,'2026-06-04T11:20:00','QA112');

INSERT INTO QARelease (ReleaseID, BatchID, Decision, ReleasedBy, ReleasedOn, Comments) VALUES
(3,1004,'Released','QA210','2026-06-04T17:35:00','Batch completed with no open critical issues.');

INSERT INTO SerializedUnits (SerialID, BatchID, GTIN, SerialNumber, PackDate, Status, CreatedOn) VALUES
(5,1004,'08912345670002','SN1004-000001','2026-06-04','Packed','2026-06-04T15:55:00'),
(6,1004,'08912345670002','SN1004-000002','2026-06-04','Packed','2026-06-04T15:55:01');

------------------------------------------------------------
-- INTENTIONAL COMMON PHARMAMES DATA ISSUES (FOR TRAINING)
-- Issue 1: Completed batch missing QA release (Batch 1090)
-- Issue 2: Weigh/dispense recorded before material verification (Batch 1091)
-- Issue 3: Expired lot consumed (Batch 1092)
-- Issue 4: Failed IPC but batch released (Batch 1093)
-- Issue 5: Open critical deviation on a released batch (Batch 1094)
------------------------------------------------------------

INSERT INTO MaterialLots (MaterialLotID, MaterialCode, Supplier, LotNumber, ExpiryDate, COAStatus, ReceivedOn) VALUES
('LOT-XEXP','API-IBU','PharmaChem Inc','API-EXPIRED-001','2026-05-20','Approved','2026-05-01T09:00:00');

INSERT INTO BatchHeader (BatchID, ProductCode, BatchNumber, PlannedQty, StartTime, EndTime, Status) VALUES
(1090,'TAB-IBU-200','B2026-1090',30000,'2026-06-05T07:00:00','2026-06-05T13:00:00','Completed'),
(1091,'TAB-IBU-200','B2026-1091',28000,'2026-06-05T07:10:00','2026-06-05T13:05:00','Completed'),
(1092,'TAB-IBU-200','B2026-1092',26000,'2026-06-05T07:20:00','2026-06-05T13:10:00','Completed'),
(1093,'TAB-IBU-400','B2026-1093',24000,'2026-06-05T07:30:00','2026-06-05T13:15:00','Completed'),
(1094,'TAB-IBU-400','B2026-1094',22000,'2026-06-05T07:40:00','2026-06-05T13:20:00','Completed');

-- Issue 1 data
INSERT INTO MaterialVerification (VerificationID, BatchID, MaterialLotID, VerifiedBy, VerifiedOn, Result, Notes) VALUES
(90,1090,'LOT-A001','QA112','2026-06-05T07:05:00','Approved','Issue training batch');
INSERT INTO WeighDispense (DispenseID, BatchID, MaterialLotID, WeighedBy, DispensedQty, Unit, WeighDispenseTime, Result) VALUES
(90,1090,'LOT-A001','OP221',6.00,'kg','2026-06-05T07:20:00','OK');
INSERT INTO Blending (BlendID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, RPM, Result) VALUES
(90,1090,'BLD-01','OP221','2026-06-05T08:00:00','2026-06-05T08:45:00',80,'OK');
INSERT INTO Granulation (GranulationID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, MoisturePct, Result) VALUES
(90,1090,'GRA-01','OP332','2026-06-05T09:00:00','2026-06-05T09:40:00',2.20,'OK');
INSERT INTO Compression (CompressionID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, AvgWeightMg, Result) VALUES
(90,1090,'CMP-01','OP221','2026-06-05T09:50:00','2026-06-05T10:40:00',500.50,'OK');
INSERT INTO Coating (CoatingID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, CoatingGainPct, Result) VALUES
(90,1090,'COA-01','OP332','2026-06-05T10:50:00','2026-06-05T11:30:00',2.00,'OK');
INSERT INTO Packaging (PackagingID, BatchID, EquipmentID, OperatorID, StartTime, EndTime, PacksProduced, Result) VALUES
(90,1090,'PKG-01','OP221','2026-06-05T11:40:00','2026-06-05T12:30:00',29000,'OK');
INSERT INTO IPCResults (IPCID, BatchID, Stage, TestName, SampleNumber, ResultValue, Unit, Spec, PassFlag, TestedOn, TestedBy) VALUES
(90,1090,'Compression','TabletWeight',1,500.50,'mg','500 +/- 10',1,'2026-06-05T10:20:00','QA112');
-- No QARelease row for 1090 on purpose.

-- Issue 2 data
INSERT INTO MaterialVerification (VerificationID, BatchID, MaterialLotID, VerifiedBy, VerifiedOn, Result, Notes) VALUES
(91,1091,'LOT-A001','QA112','2026-06-05T07:30:00','Approved','Verification after weigh (intentional issue)');
INSERT INTO WeighDispense (DispenseID, BatchID, MaterialLotID, WeighedBy, DispensedQty, Unit, WeighDispenseTime, Result) VALUES
(91,1091,'LOT-A001','OP221',5.80,'kg','2026-06-05T07:22:00','OK');

-- Issue 3 data
INSERT INTO MaterialVerification (VerificationID, BatchID, MaterialLotID, VerifiedBy, VerifiedOn, Result, Notes) VALUES
(92,1092,'LOT-XEXP','QA112','2026-06-05T07:25:00','Approved','Expired lot intentionally verified');
INSERT INTO WeighDispense (DispenseID, BatchID, MaterialLotID, WeighedBy, DispensedQty, Unit, WeighDispenseTime, Result) VALUES
(92,1092,'LOT-XEXP','OP332',5.20,'kg','2026-06-05T07:35:00','OK');
INSERT INTO MaterialConsumption (ConsumptionID, BatchID, MaterialLotID, QtyUsed, ConsumedOn) VALUES
(92,1092,'LOT-XEXP',5.20,'2026-06-05T07:45:00');

-- Issue 4 data
INSERT INTO MaterialVerification (VerificationID, BatchID, MaterialLotID, VerifiedBy, VerifiedOn, Result, Notes) VALUES
(93,1093,'LOT-A001','QA112','2026-06-05T07:35:00','Approved','Issue training batch');
INSERT INTO WeighDispense (DispenseID, BatchID, MaterialLotID, WeighedBy, DispensedQty, Unit, WeighDispenseTime, Result) VALUES
(93,1093,'LOT-A001','OP221',5.00,'kg','2026-06-05T07:45:00','OK');
INSERT INTO IPCResults (IPCID, BatchID, Stage, TestName, SampleNumber, ResultValue, Unit, Spec, PassFlag, TestedOn, TestedBy) VALUES
(93,1093,'Compression','TabletWeight',1,530.00,'mg','500 +/- 10',0,'2026-06-05T10:00:00','QA112');
INSERT INTO QARelease (ReleaseID, BatchID, Decision, ReleasedBy, ReleasedOn, Comments) VALUES
(93,1093,'Released','QA210','2026-06-05T12:55:00','Intentional bad release for training.');

-- Issue 5 data
INSERT INTO MaterialVerification (VerificationID, BatchID, MaterialLotID, VerifiedBy, VerifiedOn, Result, Notes) VALUES
(94,1094,'LOT-A001','QA112','2026-06-05T07:45:00','Approved','Issue training batch');
INSERT INTO WeighDispense (DispenseID, BatchID, MaterialLotID, WeighedBy, DispensedQty, Unit, WeighDispenseTime, Result) VALUES
(94,1094,'LOT-A001','OP332',4.80,'kg','2026-06-05T07:55:00','OK');
INSERT INTO Deviations (DeviationID, BatchID, Description, Severity, Opened, Closed, Status, OpenedBy, ClosedBy) VALUES
(94,1094,'Coating pan speed excursion.','Critical','2026-06-05T10:10:00',NULL,'Open','OP332',NULL);
INSERT INTO QARelease (ReleaseID, BatchID, Decision, ReleasedBy, ReleasedOn, Comments) VALUES
(94,1094,'Released','QA210','2026-06-05T12:58:00','Intentional bad release with open critical deviation.');
