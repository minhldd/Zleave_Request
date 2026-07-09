@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Leave Audit Log View'

define view entity ZI_LEAVE_AUDIT_LOG
  as select from zleave_audit_log as L
{
  key L.log_id      as LogId,
      L.request_id  as RequestId,
      L.employee_id as EmployeeId,
      L.action      as Action,

      case L.action
        when 'MGR_APPROVE'  then 3
        when 'HR_APPROVE'   then 3
        when 'MGR_REJECT'   then 1
        when 'HR_REJECT'    then 1
        when 'DELETE'       then 1
        when 'CREATE'       then 2
        else 0
      end as ActionCriticality,

      L.action_by   as ActionBy,
      L.action_at   as ActionAt,
      L.old_status  as OldStatus,
      L.new_status  as NewStatus,
      L.comments     as Comments
}
