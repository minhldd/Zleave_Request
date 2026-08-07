@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Employee Admin View'

define root view entity ZI_EMPLOYEE_ADMIN
  as select from zemployee_table as E
{
  key E.emp_id          as EmployeeId,
      E.sap_user        as SapUser,
      E.full_name       as FullName,
      E.department      as Department,
      E.position_title  as PositionTitle,
      E.manager_user    as ManagerUser,
      E.is_active       as IsActive,
      cast( E.is_manager as abap_boolean ) as IsManager,
      cast( E.is_hr      as abap_boolean ) as IsHr,
      cast( E.is_admin   as abap_boolean ) as IsAdmin,
      E.created_by      as CreatedBy,
      E.created_at      as CreatedAt
}
