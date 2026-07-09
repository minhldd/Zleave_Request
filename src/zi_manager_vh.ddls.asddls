@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Manager Value Help'
define view entity ZI_MANAGER_VH
  as select from zemployee_table
{
  key sap_user    as ManagerUser,
      full_name   as ManagerName
}
where
  is_manager = 'X'
