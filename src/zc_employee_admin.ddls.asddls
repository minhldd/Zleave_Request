@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Employee Admin Projection'
@Metadata.allowExtensions: true

@UI: {
  headerInfo: {
    typeName: 'Employee',
    typeNamePlural: 'Employees',
    title: { type: #STANDARD, value: 'FullName' }
  }
}

define root view entity ZC_EMPLOYEE_ADMIN
  provider contract transactional_query
  as projection on ZI_EMPLOYEE_ADMIN as Employee
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
    { position: 10, label: 'Employee ID' },
    { type: #FOR_ACTION, dataAction: 'deactivate', label: 'Deactivate', position: 200 },
    { type: #FOR_ACTION, dataAction: 'activate',   label: 'Activate',   position: 210 }
  ]
  @UI.identification: [{ position: 10, label: 'Employee ID' }]
  key EmployeeId,

  @UI.lineItem: [{ position: 20, label: 'SAP User' }]
  @UI.identification: [{ position: 20, label: 'SAP Username (SU01)' }]
  SapUser,

  @UI.lineItem: [{ position: 30, label: 'Full Name' }]
  @UI.identification: [{ position: 30, label: 'Full Name' }]
  FullName,

  @UI.lineItem: [{ position: 40, label: 'Department' }]
  @UI.identification: [{ position: 40, label: 'Department' }]
  Department,

  @UI.lineItem: [{ position: 50, label: 'Position' }]
  @UI.identification: [{ position: 50, label: 'Position Title' }]
  PositionTitle,

  @UI.identification: [{ position: 60, label: 'Email' }]
  Email,

  @UI.identification: [{ position: 70, label: 'Manager (SAP User)' }]
  ManagerUser,

  @UI.lineItem: [{ position: 80, label: 'Active' }]
  @UI.identification: [{ position: 80, label: 'Active' }]
  IsActive,

  @UI.lineItem: [{ position: 90, label: 'Is Manager' }]
  @UI.identification: [{ position: 90, label: 'Is Manager' }]
  IsManager,

  @UI.lineItem: [{ position: 100, label: 'Is HR' }]
  @UI.identification: [{ position: 100, label: 'Is HR' }]
  IsHr,

  @UI.lineItem: [{ position: 110, label: 'Is Admin' }]
  @UI.identification: [{ position: 110, label: 'Is Admin' }]
  IsAdmin,

  @UI.lineItem: [{ position: 120, label: 'Created By' }]
  @UI.identification: [{ position: 120, label: 'Created By' }]
  CreatedBy,

  @UI.lineItem: [{ position: 130, label: 'Created At' }]
  @UI.identification: [{ position: 130, label: 'Created At' }]
  CreatedAt
}
