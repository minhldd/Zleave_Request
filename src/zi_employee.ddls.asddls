@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Employee Interface View (Custom)'
@Search.searchable: true

/*
 * ZI_EMPLOYEE
 * Đọc từ ZEMPLOYEE (custom table)
 * Logic đơn giản: 1 table, không cần JOIN phức tạp
 */
define view entity ZI_EMPLOYEE
  as select from zemployee_table as Emp
{
  @Search.defaultSearchElement: true
  key Emp.emp_id    as EmployeeId,

  @Search.defaultSearchElement: true
      Emp.sap_user       as SapUserName,

  @Search.defaultSearchElement: true
      Emp.full_name      as FullName,

      Emp.email          as Email,
      Emp.department     as Department,
      Emp.position_title as PositionTitle,
      Emp.manager_user   as ManagerSapUser,
      Emp.is_active      as IsActive,
      Emp.is_manager     as IsManager,
      Emp.is_hr          as IsHR,
      Emp.is_admin       as IsAdmin
}
where
  Emp.is_active = 'X' // Chỉ lấy nhân viên đang hoạt động
