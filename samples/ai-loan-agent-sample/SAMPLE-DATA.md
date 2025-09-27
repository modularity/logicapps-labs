# AI Loan Agent - Sample Data Scenarios

This file contains sample form data for demonstrating the AI Loan Agent workflow through Microsoft Forms.

## How to Use This Data

1. **Access your Microsoft Forms**: Use the Form ID from your workflow configuration
2. **Copy and paste the data** from the scenarios below into your form
3. **Submit each scenario** to test different workflow paths
4. **Monitor Logic Apps runs** in Azure Portal to see the AI processing in action
5. **Check Teams notifications** for human review cases

## Form URL Construction

Your Form ID: `v4j5cvGGr0GRqy180BHbRzvuYcO0V-9Bq3SxP9NbF71UOVY2WDBINVRGVFRSWUUxUlJHWktTODU1Sy4u`

**Direct Form URL**: 
```
https://forms.microsoft.com/r/v4j5cvGGr0GRqy180BHbRzvuYcO0V-9Bq3SxP9NbF71UOVY2WDBINVRGVFRSWUUxUlJHWktTODU1Sy4u
```

---

## Test Scenario 1: Standard Auto-Approval ✅

**Expected Outcome**: Automatic approval with email notification

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

**Why this should auto-approve**:
- Stable employment (5 years)
- Good salary-to-loan ratio
- Standard vehicle (not luxury)
- Reasonable loan amount

---

## Test Scenario 2: High-End Vehicle Review ⚠️

**Expected Outcome**: Human review required via Teams notification

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

**Why this triggers review**:
- High-performance vehicle (BMW M5)
- Large loan amount
- Should trigger special vehicle check

---

## Test Scenario 3: High Risk Profile ⚠️

**Expected Outcome**: Human review due to risk factors

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

**Risk factors**:
- Low employment tenure (1.5 years)
- High debt-to-income ratio
- Startup employer (potentially unstable)
- Performance vehicle

---

## Test Scenario 4: Luxury Vehicle Alert 🚨

**Expected Outcome**: Special vehicle processing + human review

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

**Luxury factors**:
- Ultra-luxury vehicle (Mercedes S-Class AMG)
- Very high loan amount ($120K)
- Should trigger special vehicle workflow
- Requires human approval regardless of credit

---

## Test Scenario 5: Edge Case - Senior Applicant 👴

**Expected Outcome**: Standard processing with age consideration

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

**Edge case factors**:
- Senior applicant (68 years old)
- Very stable employment (25 years)
- Government job (stable income)
- Conservative vehicle choice

---

## Test Scenario 6: Young Professional 👨‍💼

**Expected Outcome**: Possible approval with verification

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

**Young professional factors**:
- Young age (26 years)
- High-tech employer
- Good salary for age
- Premium vehicle (Audi)

---

## Expected Workflow Behavior

### For Each Submission:

1. **Forms Trigger** → Logic App starts
2. **Get Response Details** → Extracts form data
3. **Credit Check API** → Simulated credit score lookup
4. **Background Check API** → Verifies applicant information
5. **Employment Verification API** → Confirms employment details
6. **Application Summary** → Compiles all data for AI agent
7. **AI Agent (GPT-4.1)** → Evaluates using company policy
8. **Special Vehicle Check** → Checks luxury vehicle database
9. **Decision Processing** → Auto-approve or escalate
10. **Notifications** → Email + Teams (if human review needed)
11. **Post-Processing** → Loan setup workflows

### Teams Notifications

Human review cases will send notifications to your configured Teams channel with:
- Applicant details
- Risk factors identified
- Recommended actions
- Approval/rejection buttons

### Email Notifications

All applicants receive email confirmations with:
- Application status
- Next steps
- Contact information for questions

---

## Monitoring Your Tests

### Azure Portal - Logic Apps Monitoring

1. Navigate to **Azure Portal** → **Resource Groups** → **[YOUR-RESOURCE-GROUP]**
2. Click on **[YOUR-LOGIC-APP]**
3. Go to **Workflows** → **LoanApprovalAgent**
4. Check **Runs history** for real-time execution
5. Click on any run to see detailed step-by-step execution

### Teams Channel Monitoring

Check your configured Teams channel for:
- Human review notifications
- Approval request cards
- Risk assessment summaries

### Email Verification

Monitor the email addresses used in test scenarios for:
- Application confirmations
- Approval/rejection notifications
- Next steps instructions

---

## Troubleshooting

### If Workflow Doesn't Trigger
- Verify Microsoft Forms connection is authorized
- Check form submission went through
- Confirm form ID matches workflow configuration

### If AI Agent Fails
- Check OpenAI connection and API key
- Verify GPT-4.1 deployment is available
- Review agent tool configurations

### If Teams Notifications Don't Work
- Verify Teams connection authorization
- Check Group ID and Channel ID configuration
- Confirm managed identity permissions

### If APIs Fail
- Check SQL connection string
- Verify API Management subscription keys
- Review external API endpoints

---

## Next Steps After Testing

1. **Analyze Results** → Review which scenarios worked as expected
2. **Adjust Policies** → Modify AI agent instructions if needed
3. **Fine-tune Thresholds** → Update risk assessment criteria
4. **Production Deployment** → Move to live Forms with real data
5. **User Training** → Train loan officers on Teams notifications
6. **Monitoring Setup** → Configure alerts for failed runs

---

## Additional Test Variations

You can create additional test cases by varying:

- **Credit Scores**: Modify the SSN to trigger different credit responses
- **Employment Types**: Try different employers (banks, startups, government)
- **Vehicle Categories**: Test electric vehicles, classics, motorcycles
- **Loan Amounts**: Test minimum/maximum thresholds
- **Geographic Factors**: Different states (if applicable to policy)

## Form Field Validation

Ensure your Microsoft Forms includes validation for:
- **SSN Format**: XXX-XX-XXXX pattern
- **Email Format**: Valid email addresses
- **Phone Format**: (XXX) XXX-XXXX pattern
- **Date Format**: MM/DD/YYYY for dates
- **Numeric Fields**: Salary and loan amounts as numbers only

This comprehensive test suite will help you validate all aspects of your AI Loan Agent workflow and ensure it handles various real-world scenarios appropriately.