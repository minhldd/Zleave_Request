@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Leave Type Admin View'

define root view entity ZI_LEAVE_TYPE_ADMIN
  as select from zleave_type as LT
{
  key LT.leave_type_id      as LeaveTypeId,
      LT.leave_type_name    as LeaveTypeName,
      LT.max_day            as MaxDaysPerYear,
      LT.is_paid            as IsPaid,
      LT.requires_approval  as RequiresApproval,
      LT.is_active          as IsActive
}
