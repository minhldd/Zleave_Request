@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Leave Type Management'
@Metadata.allowExtensions: true

define root view entity ZC_LEAVE_TYPE_ADMIN
  provider contract transactional_query
  as projection on ZI_LEAVE_TYPE_ADMIN as LeaveType
{
  @UI.facet: [
    {
      id:       'GeneralInfo',
      purpose:  #STANDARD,
      type:     #IDENTIFICATION_REFERENCE,
      label:    'General Information',
      position: 10
    }
  ]
  @UI.lineItem: [
    { position: 10, label: 'Leave Type ID' },
    { type: #FOR_ACTION, dataAction: 'deactivateLeaveType', label: 'Deactivate', position: 200 },
    { type: #FOR_ACTION, dataAction: 'activateLeaveType',   label: 'Activate',   position: 210 }
  ]
  @UI.identification: [{ position: 10, label: 'Leave Type ID' }]
  key LeaveTypeId,

  @UI.lineItem: [{ position: 20, label: 'Leave Type Name' }]
  @UI.identification: [{ position: 20, label: 'Leave Type Name' }]
  LeaveTypeName,

  @UI.lineItem: [{ position: 30, label: 'Max Days/Year' }]
  @UI.identification: [{ position: 30, label: 'Max Days Per Year' }]
  MaxDaysPerYear,

  @UI.lineItem: [{ position: 40, label: 'Type' }]
  @UI.identification: [{ position: 40, label: 'Type' }]
  IsPaid,

  @UI.lineItem: [{ position: 50, label: 'Requires Approval' }]
  @UI.identification: [{ position: 50, label: 'Requires Approval' }]
  RequiresApproval,
  
  @UI.lineItem: [{ position: 60, label: 'Active' }]
  @UI.identification: [{ position: 60, label: 'Active' }]
  IsActive
}
