@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Leave Quota Admin View - All Employees'

define view entity ZI_LEAVE_QUOTA_ADMIN
  as select from zquota as Q
    inner join zemployee_table as E
      on  E.emp_id    = Q.employee_id
      and E.is_active = 'X'
    inner join zleave_type as LT
      on LT.leave_type_id = Q.leave_type_id
{
  key Q.employee_id         as EmployeeId,
  key Q.leave_type_id       as LeaveTypeId,
  key Q.quota_year          as QuotaYear,

      E.full_name           as FullName,
      E.department          as Department,
      LT.leave_type_name    as LeaveTypeName,

      Q.total_days          as TotalDays,
      Q.used_days           as UsedDays,
      Q.remaining_days      as RemainingDays,

      Q.valid_from          as ValidFrom,
      Q.valid_to            as ValidTo,

      case
        when Q.remaining_days = 0
          then 1
        when Q.used_days > 0
          then 2
        else 3
      end                   as RemCriticality,

      Q.last_updated_by     as LastUpdatedBy,
      Q.last_updated_at     as LastUpdatedAt
}
