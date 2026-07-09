@AbapCatalog.sqlViewName: 'ZVI_LEAVE'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Leave Type Interdace View'
@Metadata.ignorePropagatedAnnotations: true
define view ZI_LEAVE_TYPE as select from zleave_type
{
  key leave_type_id  as LeaveType,
  leave_type_name         as LeaveName,
  is_paid               as IsPaid,
  max_day           as MaxDays
}
