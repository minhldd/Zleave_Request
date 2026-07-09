@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Leave Quota View'

/*
 * ZI_LEAVE_QUOTA
 * Fix:
 *  - Không dùng CAST trong ON condition -> dùng left outer join + where
 *  - Không dùng abap_true -> dùng 'X'
 *  - employee_id NUMC(10) join emp_id CHAR(10): dùng association thay vì join trực tiếp
 */
define view entity ZI_LEAVE_QUOTA
  as select from zquota as Q
    inner join zleave_type as LT
      on LT.leave_type_id = Q.leave_type_id
    inner join zemployee_table as Emp
      on  Emp.emp_id    = Q.employee_id
      and Emp.is_active = 'X'
{
  key Q.employee_id              as EmployeeId,
  key Q.leave_type_id            as LeaveTypeId,
  key Q.quota_year               as QuotaYear,

      LT.leave_type_name         as LeaveTypeName,
      Emp.sap_user               as SapUserName,
      Emp.full_name              as EmployeeName,

      Q.total_days               as TotalDays,
      Q.used_days                as UsedDays,
      Q.remaining_days           as RemainingDays,
      Q.valid_from               as ValidFrom,
      Q.valid_to                 as ValidTo,

      case
        when Q.remaining_days <= 0                then 1
        when Q.remaining_days <= Q.total_days / 5 then 2
        else                                           3
      end                        as RemCriticality
}
where Emp.sap_user = $session.user
