@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Leave Quota Overview'
@Metadata.allowExtensions: true

define view entity ZC_LEAVE_QUOTA_ADMIN
  as select from ZI_LEAVE_QUOTA_ADMIN
{
  @UI.lineItem: [{ position: 10, label: 'Employee ID' }]
  @UI.identification: [{ position: 10 }]
  key EmployeeId,

  @UI.lineItem: [{ position: 20, label: 'Leave Type' }]
  @UI.identification: [{ position: 20 }]
  key LeaveTypeId,

  @UI.lineItem: [{ position: 30, label: 'Year' }]
  key QuotaYear,

  @UI.lineItem: [{ position: 40, label: 'Full Name' }]
  FullName,

  @UI.lineItem: [{ position: 50, label: 'Department' }]
  Department,

  @UI.lineItem: [{ position: 60, label: 'Leave Type Name' }]
  LeaveTypeName,

  @UI.lineItem: [{ position: 70, label: 'Total Days' }]
  TotalDays,

  @UI.lineItem: [{
    position:    80,
    label:       'Used Days',
    criticality: 'RemCriticality'
  }]
  UsedDays,

  @UI.lineItem: [{
    position:    90,
    label:       'Remaining Days',
    criticality: 'RemCriticality'
  }]
  RemainingDays,

  @UI.hidden: true
  RemCriticality,

  ValidFrom,
  ValidTo,
  LastUpdatedBy,
  LastUpdatedAt
}
