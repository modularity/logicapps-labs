# Microsoft Forms - Required Fields Template

Use this template when creating your "Vehicle Loan Application" form in Microsoft Forms.

## Form Configuration

**Form Title**: Vehicle Loan Application
**Form Description**: Please complete all fields to submit your vehicle loan application.

**Settings**:
- ✅ Require sign-in
- ✅ One response per person
- ✅ Record name (for audit trail)

## Required Fields

### 1. Personal Information

**Full Name**
- Type: Text
- Required: Yes
- Description: "Enter your full legal name as it appears on your ID"

**Date of Birth**
- Type: Date
- Required: Yes  
- Description: "For age verification and risk assessment"

**Social Security Number**
- Type: Text
- Required: Yes
- Description: "For credit check and identity verification (format: XXX-XX-XXXX)"

**Email Address**
- Type: Text
- Required: Yes
- Validation: Email format
- Description: "Primary contact for loan notifications"

**Phone Number**
- Type: Text
- Required: Yes
- Description: "Secondary contact method (format: (XXX) XXX-XXXX)"

### 2. Employment Information

**Current Employer**
- Type: Text
- Required: Yes
- Description: "Name of your current employer"

**Annual Salary**
- Type: Number
- Required: Yes
- Description: "Your annual gross salary in USD"

**Years in Current Role**
- Type: Number
- Required: Yes
- Description: "Number of years with current employer"

### 3. Loan Information

**Requested Loan Amount**
- Type: Number
- Required: Yes
- Description: "Amount you wish to borrow (USD)"

### 4. Vehicle Information

**Vehicle Make**
- Type: Choice (Dropdown)
- Required: Yes
- Options: 
  - Ford
  - Toyota
  - Honda
  - BMW
  - Mercedes-Benz
  - Audi
  - Volkswagen
  - Chevrolet
  - Nissan
  - Hyundai
  - Other
- Description: "Select the vehicle manufacturer"

**Vehicle Model**
- Type: Text
- Required: Yes
- Description: "Specific vehicle model (e.g., Camry, F-150, X5)"

**Vehicle Year**
- Type: Number
- Required: Yes
- Description: "Model year of the vehicle"

**Vehicle Price**
- Type: Number
- Required: Yes
- Description: "Purchase price of the vehicle (USD)"

## After Creating the Form

1. **Get Form ID**: After publishing, copy the Form ID from the sharing URL
2. **Test Submission**: Submit a test application to verify all fields work
3. **Note Form URL**: Copy both the short URL and Form ID for configuration

## Form ID Location

The Form ID can be found in the sharing URL:
- Short URL: `https://forms.microsoft.com/r/[FORM_ID]`
- Example: `https://forms.microsoft.com/r/S9HTy9dcR0`
- Form ID: `S9HTy9dcR0`

This Form ID will be used in the Logic Apps connection configuration.