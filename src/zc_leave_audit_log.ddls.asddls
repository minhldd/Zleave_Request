@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Leave Audit Log'
@Metadata.allowExtensions: true

define view entity ZC_LEAVE_AUDIT_LOG
  as select from ZI_LEAVE_AUDIT_LOG
{
  @UI.lineItem: [{ position: 10, label: 'Log ID' }]
  @UI.hidden: true
  key LogId,

  @UI.lineItem: [{ position: 10, label: 'Request ID' }]
  @UI.identification: [{ position: 10, label: 'Request ID' }]
  RequestId,

  @UI.lineItem: [{ position: 20, label: 'Employee ID' }]
  @UI.identification: [{ position: 20, label: 'Employee ID' }]
  EmployeeId,

  @UI.lineItem: [{
    position:    30,
    label:       'Action',
    criticality: 'ActionCriticality'
  }]
  @UI.identification: [{ position: 30, label: 'Action' }]
  Action,

  @UI.hidden: true
  ActionCriticality,

  @UI.lineItem: [{ position: 40, label: 'Action By' }]
  @UI.identification: [{ position: 40, label: 'Action By' }]
  ActionBy,

  @UI.lineItem: [{ position: 50, label: 'Action At' }]
  @UI.identification: [{ position: 50, label: 'Action At' }]
  ActionAt,

  @UI.identification: [{ position: 60, label: 'Old Status' }]
  OldStatus,

  @UI.identification: [{ position: 70, label: 'New Status' }]
  NewStatus,

  @UI.identification: [{ position: 80, label: 'Comment' }]
  Comments
}
