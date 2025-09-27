-- AI Loan Agent Database Setup Script
-- This script creates the required database tables and sample data for the AI Loan Agent Logic Apps sample

-- =============================================================================
-- CustomersBankHistory Table
-- Stores customer banking history and account information
-- =============================================================================

IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='CustomersBankHistory' AND xtype='U')
BEGIN
    CREATE TABLE [dbo].[CustomersBankHistory] (
        [CustomerID] INT IDENTITY(1,1) PRIMARY KEY,
        [SSN] NVARCHAR(11) NOT NULL,
        [CustomerName] NVARCHAR(100) NOT NULL,
        [AccountBalance] DECIMAL(18,2) NOT NULL,
        [AccountType] NVARCHAR(20) NOT NULL,
        [YearsAsCustomer] INT NOT NULL,
        [OverdraftHistory] INT NOT NULL,
        [AverageMonthlyCredits] DECIMAL(18,2) NOT NULL,
        [AverageMonthlyDebits] DECIMAL(18,2) NOT NULL,
        [LastActivityDate] DATETIME NOT NULL,
        CONSTRAINT [CK_CustomersBankHistory_AccountBalance] CHECK ([AccountBalance] >= 0),
        CONSTRAINT [CK_CustomersBankHistory_YearsAsCustomer] CHECK ([YearsAsCustomer] >= 0),
        CONSTRAINT [CK_CustomersBankHistory_OverdraftHistory] CHECK ([OverdraftHistory] >= 0),
        INDEX [IX_CustomersBankHistory_SSN] NONCLUSTERED ([SSN])
    );
    
    PRINT 'Created CustomersBankHistory table';
END
ELSE
BEGIN
    PRINT 'CustomersBankHistory table already exists';
END

-- =============================================================================
-- AutoLoanSpecialVehicles Table
-- Stores information about special vehicles that require additional approval
-- =============================================================================

IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='AutoLoanSpecialVehicles' AND xtype='U')
BEGIN
    CREATE TABLE [dbo].[AutoLoanSpecialVehicles] (
        [VehicleID] INT IDENTITY(1,1) PRIMARY KEY,
        [Make] NVARCHAR(50) NOT NULL,
        [Model] NVARCHAR(50) NOT NULL,
        [Category] NVARCHAR(20) NOT NULL, -- 'Luxury', 'Custom', 'Limited'
        [RequiresHumanApproval] BIT NOT NULL DEFAULT 1,
        [MinCreditScore] INT NULL,
        [MaxLoanAmount] DECIMAL(18,2) NULL,
        CONSTRAINT [CK_AutoLoanSpecialVehicles_Category] CHECK ([Category] IN ('Luxury', 'Custom', 'Limited')),
        CONSTRAINT [CK_AutoLoanSpecialVehicles_MinCreditScore] CHECK ([MinCreditScore] IS NULL OR ([MinCreditScore] >= 300 AND [MinCreditScore] <= 850)),
        CONSTRAINT [CK_AutoLoanSpecialVehicles_MaxLoanAmount] CHECK ([MaxLoanAmount] IS NULL OR [MaxLoanAmount] > 0),
        INDEX [IX_AutoLoanSpecialVehicles_Make_Model] NONCLUSTERED ([Make], [Model]),
        INDEX [IX_AutoLoanSpecialVehicles_Category] NONCLUSTERED ([Category])
    );
    
    PRINT 'Created AutoLoanSpecialVehicles table';
END
ELSE
BEGIN
    PRINT 'AutoLoanSpecialVehicles table already exists';
END

-- =============================================================================
-- Sample Data for CustomersBankHistory
-- =============================================================================

IF NOT EXISTS (SELECT * FROM [dbo].[CustomersBankHistory])
BEGIN
    INSERT INTO [dbo].[CustomersBankHistory] (
        [SSN], 
        [CustomerName], 
        [AccountBalance], 
        [AccountType], 
        [YearsAsCustomer], 
        [OverdraftHistory], 
        [AverageMonthlyCredits], 
        [AverageMonthlyDebits], 
        [LastActivityDate]
    ) VALUES
    -- SAMPLE-DATA.md Scenario 1: Standard Auto-Approval (Sarah Johnson)
    ('555-12-3456', 'Sarah Johnson', 35000.00, 'Checking', 5, 0, 7500.00, 5200.00, '2024-01-15'),
    
    -- SAMPLE-DATA.md Scenario 2: High-End Vehicle Review (Michael Chen)
    ('555-98-7654', 'Michael Chen', 75000.00, 'Premium', 8, 0, 15000.00, 10500.00, '2024-01-20'),
    
    -- SAMPLE-DATA.md Scenario 3: High Risk Profile (Jennifer Martinez)
    ('555-11-2233', 'Jennifer Martinez', 2800.00, 'Checking', 1, 3, 3200.00, 3800.00, '2024-01-10'),
    
    -- SAMPLE-DATA.md Scenario 4: Luxury Vehicle Alert (David Wilson)
    ('555-44-5566', 'David Wilson', 125000.00, 'Premium', 6, 0, 18500.00, 12000.00, '2024-01-22'),
    
    -- SAMPLE-DATA.md Scenario 5: Edge Case - Senior Applicant (Robert Thompson)
    ('555-77-8899', 'Robert Thompson', 85000.00, 'Premium', 25, 0, 9500.00, 6800.00, '2024-01-18'),
    
    -- SAMPLE-DATA.md Scenario 6: Young Professional (Alex Rodriguez)
    ('555-33-4455', 'Alex Rodriguez', 18500.00, 'Checking', 3, 1, 10500.00, 8200.00, '2024-01-12'),
    
    -- Additional existing customer for reference
    ('123-45-6789', 'John Doe', 15000.00, 'Checking', 5, 0, 5000.00, 3500.00, '2024-01-16'),
    
    -- Additional existing customer for reference
    ('987-65-4321', 'Jane Smith', 8500.00, 'Savings', 3, 1, 3000.00, 2800.00, '2024-01-14');
    
    PRINT 'Inserted sample data into CustomersBankHistory table';
END
ELSE
BEGIN
    PRINT 'CustomersBankHistory table already contains data';
END

-- =============================================================================
-- Sample Data for AutoLoanSpecialVehicles
-- =============================================================================

IF NOT EXISTS (SELECT * FROM [dbo].[AutoLoanSpecialVehicles])
BEGIN
    INSERT INTO [dbo].[AutoLoanSpecialVehicles] (
        [Make], 
        [Model], 
        [Category], 
        [RequiresHumanApproval], 
        [MinCreditScore], 
        [MaxLoanAmount]
    ) VALUES
    -- Luxury Sports Cars
    ('Ferrari', 'F8 Tributo', 'Luxury', 1, 750, 300000.00),
    ('Ferrari', '488 GTB', 'Luxury', 1, 750, 280000.00),
    ('Lamborghini', 'Huracan', 'Luxury', 1, 750, 250000.00),
    ('Lamborghini', 'Aventador', 'Luxury', 1, 780, 400000.00),
    ('McLaren', '720S', 'Luxury', 1, 750, 320000.00),
    ('McLaren', 'Artura', 'Luxury', 1, 750, 240000.00),
    ('Porsche', '911 Turbo S', 'Luxury', 1, 720, 220000.00),
    ('Aston Martin', 'DB11', 'Luxury', 1, 750, 230000.00),
    
    -- Ultra-Luxury Vehicles
    ('Rolls-Royce', 'Phantom', 'Luxury', 1, 800, 500000.00),
    ('Rolls-Royce', 'Cullinan', 'Luxury', 1, 800, 380000.00),
    ('Bentley', 'Mulsanne', 'Luxury', 1, 780, 350000.00),
    ('Bentley', 'Bentayga', 'Luxury', 1, 750, 250000.00),
    ('Maybach', 'S 680', 'Luxury', 1, 780, 200000.00),
    
    -- Limited Edition Supercars
    ('McLaren', 'P1', 'Limited', 1, 800, 1000000.00),
    ('Ferrari', 'LaFerrari', 'Limited', 1, 820, 1200000.00),
    ('Porsche', '918 Spyder', 'Limited', 1, 800, 900000.00),
    ('Bugatti', 'Chiron', 'Limited', 1, 850, 3000000.00),
    ('Koenigsegg', 'Regera', 'Limited', 1, 850, 2000000.00),
    ('Pagani', 'Huayra', 'Limited', 1, 850, 2500000.00),
    
    -- Custom/Modified Vehicles
    ('Tesla', 'Model S Plaid (Modified)', 'Custom', 1, 700, 150000.00),
    ('Ford', 'Mustang (Custom Build)', 'Custom', 1, 680, 80000.00),
    ('Chevrolet', 'Corvette (Track Spec)', 'Custom', 1, 700, 120000.00),
    ('Dodge', 'Challenger Hellcat (Modified)', 'Custom', 1, 680, 90000.00),
    
    -- Classic/Vintage Luxury
    ('Ferrari', '250 GTO (Classic)', 'Limited', 1, 850, 50000000.00),
    ('Porsche', '911 Carrera RS (Classic)', 'Limited', 1, 800, 500000.00),
    ('Jaguar', 'E-Type (Restored)', 'Custom', 1, 720, 150000.00),
    ('Mercedes-Benz', '300SL Gullwing (Classic)', 'Limited', 1, 850, 1500000.00);
    
    PRINT 'Inserted sample data into AutoLoanSpecialVehicles table';
END
ELSE
BEGIN
    PRINT 'AutoLoanSpecialVehicles table already contains data';
END

-- =============================================================================
-- Data Validation and Summary
-- =============================================================================

PRINT '';
PRINT '=============================================================================';
PRINT 'Database Setup Complete';
PRINT '=============================================================================';

-- Display table counts
DECLARE @CustomerCount INT, @VehicleCount INT;
SELECT @CustomerCount = COUNT(*) FROM [dbo].[CustomersBankHistory];
SELECT @VehicleCount = COUNT(*) FROM [dbo].[AutoLoanSpecialVehicles];

PRINT 'CustomersBankHistory records: ' + CAST(@CustomerCount AS VARCHAR(10));
PRINT 'AutoLoanSpecialVehicles records: ' + CAST(@VehicleCount AS VARCHAR(10));

-- Display sample queries that the Logic App will use
PRINT '';
PRINT 'Sample queries that will be used by the Logic App:';
PRINT '';

PRINT '-- Query customer by SSN (example):';
PRINT 'SELECT * FROM [dbo].[CustomersBankHistory] WHERE SSN = ''123-45-6789'';';
PRINT '';

PRINT '-- Query special vehicles by make (example):';
PRINT 'SELECT * FROM [dbo].[AutoLoanSpecialVehicles] WHERE Make = ''Ferrari'';';
PRINT '';

PRINT '-- Check if vehicle requires human approval (example):';
PRINT 'SELECT RequiresHumanApproval, MinCreditScore, MaxLoanAmount';
PRINT 'FROM [dbo].[AutoLoanSpecialVehicles] ';
PRINT 'WHERE Make = ''McLaren'' AND Model = ''P1'';';
PRINT '';

-- Display some statistics
PRINT 'Database Statistics:';
PRINT '- Customer accounts by type:';
SELECT 
    AccountType, 
    COUNT(*) as Count, 
    AVG(AccountBalance) as AvgBalance,
    AVG(YearsAsCustomer) as AvgYearsAsCustomer
FROM [dbo].[CustomersBankHistory] 
GROUP BY AccountType;

PRINT '';
PRINT '- Special vehicles by category:';
SELECT 
    Category, 
    COUNT(*) as Count,
    AVG(CAST(MinCreditScore AS FLOAT)) as AvgMinCreditScore,
    AVG(MaxLoanAmount) as AvgMaxLoanAmount
FROM [dbo].[AutoLoanSpecialVehicles] 
GROUP BY Category;

PRINT '';
PRINT '=============================================================================';
PRINT 'Database setup completed successfully!';
PRINT 'You can now deploy and test the AI Loan Agent Logic Apps workflows.';
PRINT '=============================================================================';

-- Optional: Create views for common queries (uncomment if desired)
/*
-- View for high-value customers
IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'HighValueCustomers')
BEGIN
    EXEC('CREATE VIEW [dbo].[HighValueCustomers] AS
    SELECT 
        SSN,
        CustomerName,
        AccountBalance,
        YearsAsCustomer,
        OverdraftHistory,
        CASE 
            WHEN AccountBalance > 20000 AND YearsAsCustomer >= 5 AND OverdraftHistory = 0 THEN ''Premium''
            WHEN AccountBalance > 10000 AND YearsAsCustomer >= 3 AND OverdraftHistory <= 1 THEN ''Good''
            ELSE ''Standard''
        END as CustomerTier
    FROM [dbo].[CustomersBankHistory]
    WHERE AccountBalance > 5000;');
    
    PRINT 'Created HighValueCustomers view';
END

-- View for vehicles requiring human approval
IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'HumanApprovalVehicles')
BEGIN
    EXEC('CREATE VIEW [dbo].[HumanApprovalVehicles] AS
    SELECT 
        Make,
        Model,
        Category,
        MinCreditScore,
        MaxLoanAmount,
        CASE 
            WHEN Category = ''Limited'' THEN ''Always requires approval''
            WHEN MaxLoanAmount > 500000 THEN ''High value - requires approval''
            WHEN MinCreditScore > 750 THEN ''High credit requirement''
            ELSE ''Standard approval process''
        END as ApprovalReason
    FROM [dbo].[SpecialVehicles]
    WHERE RequiresHumanApproval = 1;');
    
    PRINT 'Created HumanApprovalVehicles view';
END
*/