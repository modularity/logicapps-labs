-- Create managed identity user for Logic App
-- Run this with Azure AD authentication
-- UPDATE: Replace 'my-loan-agent-logicapp' with your actual Logic App name

USE [my-loan-agent-db]  -- UPDATE: Replace with your database name
GO

-- Create contained database user for Logic App managed identity
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'my-loan-agent-logicapp')
BEGIN
    CREATE USER [my-loan-agent-logicapp] FROM EXTERNAL PROVIDER;
    PRINT 'Created user: my-loan-agent-logicapp'
END
ELSE
BEGIN
    PRINT 'User my-loan-agent-logicapp already exists'
END

-- Grant necessary permissions
ALTER ROLE db_datareader ADD MEMBER [my-loan-agent-logicapp];
ALTER ROLE db_datawriter ADD MEMBER [my-loan-agent-logicapp];

-- Grant execute permissions for stored procedures
GRANT EXECUTE TO [my-loan-agent-logicapp];

-- Verify the user and permissions
SELECT 
    dp.name AS principal_name,
    dp.type_desc AS principal_type,
    dp.authentication_type_desc AS authentication_type,
    r.name AS role_name
FROM sys.database_principals dp 
LEFT JOIN sys.database_role_members rm ON dp.principal_id = rm.member_principal_id
LEFT JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
WHERE dp.name = 'my-loan-agent-logicapp'  -- UPDATE: Replace with your Logic App name
ORDER BY dp.name, r.name;

PRINT 'Managed identity user setup completed successfully!';