@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Leave Type Management'
@Metadata.allowExtensions: true

define root view entity ZC_LEAVE_TYPE_ADMIN
  provider contract transactional_query
  as projection on ZI_LEAVE_TYPE_ADMIN as LeaveType
{
  @UI.lineItem: [{ position: 10, label: 'Leave Type ID' }]
  @UI.identification: [{ position: 10, label: 'Leave Type ID' }]
  key LeaveTypeId,

  @UI.lineItem: [{ position: 20, label: 'Leave Type Name' }]
  @UI.identification: [{ position: 20, label: 'Leave Type Name' }]
  LeaveTypeName,

  @UI.lineItem: [{ position: 30, label: 'Max Days/Year' }]
  @UI.identification: [{ position: 30, label: 'Max Days Per Year' }]
  MaxDaysPerYear,

  @UI.lineItem: [{ position: 40, label: 'Requires Approval' }]
  @UI.identification: [{ position: 40, label: 'Requires Approval' }]
  RequiresApproval,

  @UI.lineItem: [{ position: 50, label: 'Active' }]
  @UI.identification: [{ position: 50, label: 'Active' }]
  IsActive
}
