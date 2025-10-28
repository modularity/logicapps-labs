-- Complete AI Loan Agent Database Setup Script
-- This script creates tables, sample data, AND sets up managed identity access
-- Run this script in Azure Portal Query Editor as Azure AD admin

-- =============================================================================
-- PART 1: Database Tables and Sample Data
-- =============================================================================

-- Create CustomersBankHistory Table
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
        [CreditScore] INT NOT NULL,
        [RiskCategory] NVARCHAR(20) NOT NULL
    );
    PRINT 'Created CustomersBankHistory table';
END
ELSE
BEGIN
    PRINT 'CustomersBankHistory table already exists';
END

-- Create AutoLoanSpecialVehicles Table  
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='AutoLoanSpecialVehicles' AND xtype='U')
BEGIN
    CREATE TABLE [dbo].[AutoLoanSpecialVehicles] (
        [VehicleID] INT IDENTITY(1,1) PRIMARY KEY,
        [Make] NVARCHAR(50) NOT NULL,
        [Model] NVARCHAR(50) NOT NULL,
        [Year] INT NOT NULL,
        [Category] NVARCHAR(30) NOT NULL,
        [BasePrice] DECIMAL(18,2) NOT NULL,
        [RequiresSpecialApproval] BIT NOT NULL DEFAULT 1,
        [Description] NVARCHAR(200) NULL
    );
    PRINT 'Created AutoLoanSpecialVehicles table';
END
ELSE
BEGIN
    PRINT 'AutoLoanSpecialVehicles table already exists';
END

-- Insert Sample Customer Data
IF NOT EXISTS (SELECT 1 FROM CustomersBankHistory WHERE SSN = '555-12-3456')
BEGIN
    INSERT INTO [dbo].[CustomersBankHistory] VALUES
    ('555-12-3456', 'Sarah Johnson', 45000.00, 'Checking', 8, 0, 5200.00, 3800.00, '2024-09-20', 780, 'Low'),
    ('555-98-7654', 'Michael Chen', 125000.00, 'Premium', 12, 1, 12500.00, 8900.00, '2024-09-22', 720, 'Medium'),
    ('555-11-2233', 'Jennifer Martinez', 2800.00, 'Basic', 2, 5, 2400.00, 2600.00, '2024-09-15', 580, 'High'),
    ('555-44-5566', 'David Wilson', 185000.00, 'VIP', 15, 0, 22000.00, 16500.00, '2024-09-25', 810, 'Low'),
    ('555-77-8899', 'Robert Thompson', 78000.00, 'Premium', 25, 2, 8500.00, 6200.00, '2024-09-18', 750, 'Low'),
    ('555-33-4455', 'Alex Rodriguez', 18500.00, 'Checking', 3, 1, 4200.00, 3900.00, '2024-09-21', 690, 'Medium');
    PRINT 'Inserted customer sample data';
END
ELSE
BEGIN
    PRINT 'Customer sample data already exists';
END

-- Insert Special Vehicle Data
IF NOT EXISTS (SELECT 1 FROM AutoLoanSpecialVehicles WHERE Make = 'Ferrari')
BEGIN
    INSERT INTO [dbo].[AutoLoanSpecialVehicles] VALUES
    ('Ferrari', '488 GTB', 2024, 'Luxury Sports', 330000.00, 1, 'High-performance luxury sports car requiring special underwriting'),
    ('Lamborghini', 'Huracán', 2024, 'Luxury Sports', 285000.00, 1, 'Exotic sports car with special financing requirements'),
    ('Rolls-Royce', 'Phantom', 2024, 'Ultra Luxury', 550000.00, 1, 'Ultra-luxury sedan requiring executive approval'),
    ('McLaren', '720S', 2024, 'Luxury Sports', 315000.00, 1, 'High-performance vehicle with specialized insurance needs'),
    ('Bentley', 'Continental GT', 2024, 'Luxury Grand Touring', 275000.00, 1, 'Luxury grand touring vehicle requiring enhanced due diligence'),
    ('Aston Martin', 'DB12', 2024, 'Luxury Sports', 245000.00, 1, 'British luxury sports car with premium financing'),
    ('Porsche', '911 Turbo S', 2024, 'Performance Sports', 220000.00, 1, 'High-performance sports car requiring specialized assessment'),
    ('Mercedes-AMG', 'GT 63 S', 2024, 'Performance Luxury', 185000.00, 1, 'High-performance luxury coupe with advanced features'),
    ('BMW', 'M8 Competition', 2024, 'Performance Luxury', 165000.00, 1, 'High-performance luxury vehicle requiring additional verification');
    PRINT 'Inserted special vehicles data';
END
ELSE
BEGIN
    PRINT 'Special vehicles data already exists';
END

-- =============================================================================
-- PART 2: Managed Identity Setup for Logic App Runtime Access
-- =============================================================================

PRINT 'Setting up managed identity access for Logic App...';

-- Create contained database user for Logic App managed identity
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'your-logic-app-name')
BEGIN
    CREATE USER [your-logic-app-name] FROM EXTERNAL PROVIDER;
    PRINT 'Created managed identity user: your-logic-app-name';
END
ELSE
BEGIN
    PRINT 'Managed identity user your-logic-app-name already exists';
END

-- Grant necessary permissions for Logic App to read data
ALTER ROLE db_datareader ADD MEMBER [your-logic-app-name];
PRINT 'Granted db_datareader role to your-logic-app-name';

-- Grant execute permissions for any stored procedures (if needed)
GRANT EXECUTE TO [your-logic-app-name];
PRINT 'Granted execute permissions to your-logic-app-name';

-- Verify the setup
PRINT 'Verifying database setup...';

-- Verification queries commented out to avoid table output in deployment logs
-- Uncomment for manual troubleshooting if needed:

-- Check table creation
-- SELECT 
--     'CustomersBankHistory' as TableName,
--     COUNT(*) as RecordCount
-- FROM CustomersBankHistory
-- UNION ALL
-- SELECT 
--     'AutoLoanSpecialVehicles' as TableName,
--     COUNT(*) as RecordCount  
-- FROM AutoLoanSpecialVehicles;

-- Check managed identity user and permissions
-- SELECT 
--     dp.name AS principal_name,
--     dp.type_desc AS principal_type,
--     dp.authentication_type_desc AS authentication_type,
--     r.name AS role_name
-- FROM sys.database_principals dp 
-- LEFT JOIN sys.database_role_members rm ON dp.principal_id = rm.member_principal_id
-- LEFT JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
-- WHERE dp.name = 'your-logic-app-name'
-- ORDER BY dp.name, r.name;

PRINT 'Database setup complete! Tables created and managed identity configured.';

PRINT '=== Database Setup Complete ===';
PRINT 'Tables created with sample data';
PRINT 'Logic App managed identity configured for data access';
PRINT 'You can now test the Logic App workflows';