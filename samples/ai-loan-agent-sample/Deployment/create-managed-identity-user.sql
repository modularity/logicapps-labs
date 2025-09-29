-- Create managed identity user for Logic App
-- Run this with Azure AD authentication
-- UPDATE: Replace 'your-logic-app-name' with your actual Logic App name

USE [your-database-name]  -- Replace with your actual database name
GO

-- Create contained database user for Logic App managed identity
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'your-logic-app-name')
BEGIN
    CREATE USER [your-logic-app-name] FROM EXTERNAL PROVIDER;
    PRINT 'Created user: your-logic-app-name'
END
ELSE
BEGIN
    PRINT 'User your-logic-app-name already exists'
END

-- Grant necessary permissions
ALTER ROLE db_datareader ADD MEMBER [your-logic-app-name];
ALTER ROLE db_datawriter ADD MEMBER [your-logic-app-name];

-- Grant execute permissions for stored procedures
GRANT EXECUTE TO [your-logic-app-name];

-- Verify the user and permissions
SELECT 
    dp.name AS principal_name,
    dp.type_desc AS principal_type,
    dp.authentication_type_desc AS authentication_type,
    r.name AS role_name
FROM sys.database_principals dp 
LEFT JOIN sys.database_role_members rm ON dp.principal_id = rm.member_principal_id
LEFT JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
WHERE dp.name = 'your-logic-app-name'  -- Replace with your Logic App name
ORDER BY dp.name, r.name;

PRINT 'Managed identity user setup completed successfully!';