# Microsoft Forms - Required Fields Template

This document provides the technical specification for creating the "Vehicle Loan Application" form in Microsoft Forms.

> **📋 Setup Instructions**: For step-by-step form creation instructions, see the main [README.md](README.md) → Step 2.1 Configure Microsoft Forms.

## Import File Available

**Quick Setup**: Use the included `Vehicle-Loan-Application-Form-Import.docx` file for fast form creation. This pre-structured document contains all required fields with proper formatting for Microsoft Forms import.

## Field Type Reference

After importing or creating the form manually, ensure these field types are configured correctly:

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

## Form Configuration Requirements

**Form Settings** (configured during setup):
- ✅ **Require sign-in**: "Only people in my organization can respond"
- ✅ **One response per person**: Limit to one response
- ✅ **Record name**: For audit trail and user identification

**Form Metadata**:
- **Title**: "Vehicle Loan Application"
- **Description**: "Please complete all fields to submit your vehicle loan application."
- **Form ID Format**: Extract from sharing URL `https://forms.microsoft.com/r/[FORM_ID]`