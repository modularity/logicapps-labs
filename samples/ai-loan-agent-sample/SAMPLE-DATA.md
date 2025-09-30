# AI Loan Agent - Test Scenarios

This file contains test scenarios for validating the AI Loan Agent workflow. The deployment scripts populate the SQL database and mock APIs with specific data to support these test cases.

## How to Use These Test Scenarios

1. **Submit test data** through your Microsoft Forms using the scenarios below
2. **Monitor Logic Apps runs** in Azure Portal to see the AI processing
3. **Verify expected outcomes** match the AI agent's decisions
4. **Check Teams notifications** for human review cases
5. **Confirm email notifications** are sent with correct status

## Database & API Test Data

The deployment scripts populate these data sources:

**SQL Database Tables:**
- `CustomersBankHistory` - 8 sample customer records with banking history
- `AutoLoanSpecialVehicles` - 27 vehicle records (5 Custom, 9 Limited, 13 Luxury)

**Mock APIs (Azure API Management):**
- **Credit Check API** - Returns credit scores based on SSN patterns  
- **Employment Verification API** - Validates employer and salary information
- **Demographics API** - Provides demographic and risk assessment data
- **Risk Assessment API** - Calculates loan risk profiles

---

## Test Scenario 1: Standard Auto-Approval ✅

**Expected Outcome**: Automatic approval with email notification

**Test Data:**
```
Full Name: Sarah Johnson
Date of Birth: 05/15/1988
Social Security Number: 555-12-3456
Email Address: sarah.johnson@example.com
Phone Number: (555) 123-4567

Current Employer: Microsoft Corporation
Annual Salary: 85000
Years in Current Role: 5

Requested Loan Amount: 25000

Vehicle Make: Toyota
Vehicle Model: Camry
Vehicle Year: 2023
Vehicle Price: 28000
```

**Why this auto-approves:**
- SSN pattern `555-12-XXXX` triggers high credit score in Credit Check API
- `Microsoft Corporation` validates successfully in Employment API  
- Salary-to-loan ratio is favorable (85K salary, 25K loan)
- Toyota Camry is standard vehicle (not in special vehicles database)
- Customer may have positive banking history in SQL database

**AI Agent Decision Factors:**
- ✅ Credit score: High (based on SSN pattern)
- ✅ Employment: Stable (5 years, reputable employer)
- ✅ Debt-to-income: Low risk (29% ratio)
- ✅ Vehicle type: Standard (no special handling required)

---

## Test Scenario 2: Luxury Vehicle Review ⚠️

**Expected Outcome**: Human review required via Teams notification

**Test Data:**
```
Full Name: Michael Chen
Date of Birth: 03/22/1982
Social Security Number: 555-98-7654
Email Address: michael.chen@example.com
Phone Number: (555) 987-6543

Current Employer: Goldman Sachs
Annual Salary: 150000
Years in Current Role: 8

Requested Loan Amount: 75000

Vehicle Make: BMW
Vehicle Model: M5 Competition
Vehicle Year: 2024
Vehicle Price: 85000
```

**Why this triggers human review:**
- BMW M5 Competition is in the `AutoLoanSpecialVehicles` table as a **Luxury** vehicle
- SpecialVehicles child workflow detects high-performance vehicle
- AI agent policy requires human approval for luxury vehicles regardless of creditworthiness
- Large loan amount adds to review requirements

**AI Agent Decision Factors:**
- ✅ Credit score: High (555-98-XXXX pattern)
- ✅ Employment: Excellent (Goldman Sachs, 8 years)
- ✅ Debt-to-income: Good (50% ratio, high income)
- ⚠️ Vehicle type: **Luxury** (triggers mandatory human review)

**Teams Notification Content:**
- Customer profile and loan details
- Vehicle flagged as luxury/high-performance
- AI recommendation with reasoning
- Approve/Reject action buttons

---

## Test Scenario 3: High Risk Profile ⚠️

**Expected Outcome**: Human review due to multiple risk factors

**Test Data:**
```
Full Name: Jennifer Martinez
Date of Birth: 01/10/1995
Social Security Number: 555-11-2233
Email Address: jennifer.martinez@example.com
Phone Number: (555) 112-2334

Current Employer: Startup Innovations
Annual Salary: 45000
Years in Current Role: 1.5

Requested Loan Amount: 40000

Vehicle Make: Ford
Vehicle Model: Mustang GT
Vehicle Year: 2022
Vehicle Price: 45000
```

**Why this triggers human review:**
- SSN pattern `555-11-XXXX` may return moderate credit score from Credit Check API
- Employment Verification API flags short tenure (1.5 years) as risk factor
- Demographics API identifies high debt-to-income ratio (89%)
- Risk Assessment API calculates elevated risk profile
- Ford Mustang GT may be flagged as performance vehicle in database

**AI Agent Decision Factors:**
- ⚠️ Credit score: Moderate (SSN pattern-based)
- ⚠️ Employment: Short tenure (startup, 1.5 years)
- ❌ Debt-to-income: High risk (89% ratio)
- ⚠️ Vehicle type: Performance (Mustang GT)
- ❌ Risk profile: Multiple red flags detected

---

## Test Scenario 4: Ultra-Luxury Vehicle 🚨

**Expected Outcome**: Special vehicle workflow + mandatory human approval

**Test Data:**
```
Full Name: David Wilson
Date of Birth: 08/30/1979
Social Security Number: 555-44-5566
Email Address: david.wilson@example.com
Phone Number: (555) 445-5667

Current Employer: Amazon Web Services
Annual Salary: 180000
Years in Current Role: 6

Requested Loan Amount: 120000

Vehicle Make: Mercedes-Benz
Vehicle Model: S-Class AMG S63
Vehicle Year: 2024
Vehicle Price: 150000
```

**Why this requires special handling:**
- Mercedes S-Class AMG S63 is in `AutoLoanSpecialVehicles` table as **Ultra-Luxury**
- SpecialVehicles workflow detects vehicle requiring enhanced documentation
- Vehicle price exceeds $100K threshold triggering additional policies
- AI agent policy mandates human approval for ultra-luxury regardless of credit

**AI Agent Decision Factors:**
- ✅ Credit score: Excellent (555-44-XXXX pattern)
- ✅ Employment: Outstanding (AWS, 6 years, high salary)
- ✅ Debt-to-income: Acceptable (67% ratio)
- 🚨 Vehicle type: **Ultra-Luxury** (special workflow required)
- 🚨 Loan amount: High value ($120K+)

---

## Test Scenario 5: Senior Applicant with Stable History 👴

**Expected Outcome**: Standard processing with age consideration

**Test Data:**
```
Full Name: Robert Thompson
Date of Birth: 12/05/1955
Social Security Number: 555-77-8899
Email Address: robert.thompson@example.com
Phone Number: (555) 778-8990

Current Employer: State Government
Annual Salary: 95000
Years in Current Role: 25

Requested Loan Amount: 35000

Vehicle Make: Honda
Vehicle Model: Accord
Vehicle Year: 2024
Vehicle Price: 38000
```

**Expected AI processing:**
- SSN pattern `555-77-XXXX` returns stable credit history from Credit Check API
- Employment API validates government employment as highly stable
- Demographics API considers age (68) but balances with long employment
- Honda Accord is standard vehicle (not in special vehicles database)
- May have excellent banking history in SQL database

**AI Agent Decision Factors:**
- ✅ Credit score: Excellent (long credit history)
- ✅ Employment: Maximum stability (government, 25 years)
- ✅ Debt-to-income: Conservative (37% ratio)
- ✅ Vehicle type: Standard, reliable choice
- ✅ Overall profile: Low risk despite age consideration

---

## Test Scenario 6: Young High Earner 👨‍💼

**Expected Outcome**: Likely approval with income verification

**Test Data:**
```
Full Name: Alex Rodriguez
Date of Birth: 06/18/1998
Social Security Number: 555-33-4455
Email Address: alex.rodriguez@example.com
Phone Number: (555) 334-4556

Current Employer: Google LLC
Annual Salary: 125000
Years in Current Role: 3

Requested Loan Amount: 45000

Vehicle Make: Audi
Vehicle Model: A4
Vehicle Year: 2024
Vehicle Price: 50000
```

**Expected AI processing:**
- SSN pattern `555-33-XXXX` may return moderate credit score (limited credit history)
- Employment API validates Google as premium employer with high compensation
- Demographics API balances young age with high income potential
- Risk Assessment API weighs income stability vs. limited history
- Audi A4 may be in special vehicles database as **Limited** category

**AI Agent Decision Factors:**
- ⚠️ Credit score: Moderate (young, limited history)
- ✅ Employment: Excellent (Google, tech sector, high salary)
- ✅ Debt-to-income: Good (36% ratio)
- ⚠️ Vehicle type: Premium (may require additional review)
- ✅ Income trajectory: Strong future earning potential

---

## Expected Workflow Behavior

### API Response Patterns

**Credit Check API (based on SSN patterns):**
- `555-12-XXXX`: High credit score (750+)
- `555-98-XXXX`: High credit score (720+)
- `555-11-XXXX`: Moderate credit score (650-699)
- `555-44-XXXX`: Excellent credit score (800+)
- `555-77-XXXX`: Excellent credit score (780+)
- `555-33-XXXX`: Moderate credit score (680-720)

**Employment Verification API (employer validation):**
- Major corporations (Microsoft, Google, Amazon): ✅ Verified, stable
- Financial institutions (Goldman Sachs): ✅ Premium employers
- Government agencies: ✅ Maximum stability
- Startups: ⚠️ Flagged for review

**Special Vehicles Database (`AutoLoanSpecialVehicles` table):**
- **Custom**: Rare/collectible vehicles requiring specialist approval
- **Limited**: Premium vehicles needing enhanced documentation  
- **Luxury**: High-end vehicles requiring human review
- Standard vehicles (Toyota Camry, Honda Accord): No special handling

### AI Agent Decision Process

For each loan application, the AI agent:

1. **Gathers Data**: Credit, employment, demographics from APIs
2. **Queries Database**: Customer banking history, special vehicle lookup
3. **Applies Policy**: Loan-to-income ratios, vehicle restrictions, risk thresholds
4. **Makes Decision**: Auto-approve, auto-reject, or escalate for human review
5. **Triggers Actions**: Email notifications, Teams alerts, post-processing workflows

### Teams Notifications

Human review cases trigger Teams adaptive cards with:
- Complete applicant profile and loan details
- Risk factors and AI analysis
- Vehicle classification and special requirements
- Recommended action with reasoning
- Approve/Reject buttons with comment fields

### Email Notifications

All applicants receive status emails:
- **Auto-Approved**: Welcome email with next steps and loan officer contact
- **Auto-Rejected**: Explanation with improvement suggestions and appeal process
- **Under Review**: Acknowledgment with expected timeline and human contact info

## Monitoring & Validation

### Azure Portal - Logic Apps Monitoring

1. Navigate to **Azure Portal** → **Resource Groups** → **[your-resource-group]**
2. Click on your **Logic App** resource
3. Go to **Workflows** → **LoanApprovalAgent**
4. Check **Runs history** for real-time execution
5. Click on any run to see detailed step-by-step execution including:
   - API responses from Credit Check, Employment, Demographics
   - SQL query results from SpecialVehicles workflow
   - AI agent reasoning and decision process
   - Teams and email notification status

### Database Validation

Check the populated test data in your SQL database:
```sql
-- View customer banking history
SELECT * FROM CustomersBankHistory;

-- View special vehicles database
SELECT * FROM AutoLoanSpecialVehicles 
WHERE VehicleCategory IN ('Custom', 'Limited', 'Luxury');
```

### API Response Testing

Monitor API Management responses:
1. **Azure Portal** → **API Management** → **APIs**
2. Test individual APIs with sample SSNs to verify response patterns
3. Check subscription keys are working correctly

## Troubleshooting Test Scenarios

### If Workflow Doesn't Trigger
- Verify Microsoft Forms connection is authorized
- Check that form submission completed successfully
- Confirm Forms trigger is properly configured

### If AI Agent Decisions Don't Match Expected
- Review AI agent prompt and policy document
- Check API responses are returning expected data patterns
- Verify special vehicles database contains test data
- Review Azure OpenAI model deployment (GPT-4.1)

### If Teams Notifications Missing
- Verify Teams connection authorization in Azure Portal
- Check Group ID and Channel ID configuration
- Confirm Microsoft Graph permissions are granted

### If Wrong Email Notifications
- Check email addresses in test scenarios
- Verify Outlook connection authentication
- Review post-processing workflow logic

## Test Data Patterns Summary

| SSN Pattern | Credit Score | Employment Examples | Vehicle Examples | Expected Outcome |
|-------------|--------------|-------------------|------------------|------------------|
| `555-12-XXXX` | High (750+) | Microsoft, stable | Standard vehicles | Auto-Approve |
| `555-98-XXXX` | High (720+) | Goldman Sachs | Luxury vehicles | Human Review |
| `555-11-XXXX` | Moderate (650-699) | Startups | Performance vehicles | Human Review |
| `555-44-XXXX` | Excellent (800+) | Amazon/AWS | Ultra-luxury | Mandatory Review |
| `555-77-XXXX` | Excellent (780+) | Government | Standard vehicles | Auto-Approve |
| `555-33-XXXX` | Moderate (680-720) | Google/Tech | Premium vehicles | Likely Approve |

This test data design ensures comprehensive validation of all workflow paths and AI agent decision-making scenarios.