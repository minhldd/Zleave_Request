@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Leave Request'
@Metadata.allowExtensions: true

define root view entity ZC_LEAVE_REQUEST
  provider contract transactional_query
  as projection on ZI_LEAVE_REQUEST as LeaveRequest
{
  @UI.hidden: true
  key UUID,

  /*----------------------------------------------------------------
   * List Report columns
   *----------------------------------------------------------------*/
  @UI.lineItem: [{ position: 10, label: 'Request ID' }]
  @UI.identification: [{ position: 10, label: 'Request ID' }]
  RequestId,

  @UI.lineItem: [{ position: 20, label: 'Employee ID' }]
  @UI.identification: [{ position: 20, label: 'Employee ID' }]
  EmployeeId,

  /*----------------------------------------------------------------
   * Approver – cho phép Employee CHỌN Manager khi tạo đơn
   *----------------------------------------------------------------*/
  @UI.lineItem: [{ position: 30, label: 'Approver' }]
  @UI.identification: [{ position: 30, label: 'Approver (Choose Manager)' }]
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZI_MANAGER_VH', element: 'ManagerUser' }
  }]
  ApproverId,

  /*----------------------------------------------------------------
   * ✅ THÊM: HR Approver – hiển thị sau khi Manager duyệt
   *----------------------------------------------------------------*/
  @UI.lineItem: [{ position: 35, label: 'HR Approver' }]
  @UI.identification: [{ position: 35, label: 'HR Approver' }]
  HrApproverId,

  @UI.lineItem: [{ position: 40, label: 'Leave Type' }]
  @UI.identification: [{ position: 40, label: 'Leave Type' }]
  /*----------------------------------------------------------------
   * Value Help: trỏ vào ZI_LEAVE_TYPE (không cần ZVI_... nữa)
   *----------------------------------------------------------------*/
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZI_LEAVE_TYPE', element: 'LeaveType' }
  }]
  LeaveType,

  @UI.lineItem: [{ position: 50, label: 'Start Date' }]
  @UI.identification: [{ position: 50, label: 'Start Date' }]
  StartDate,

  /*----------------------------------------------------------------
   * Start Session – Buổi nghỉ của ngày bắt đầu (chỉ áp dụng khi Half Day)
   *----------------------------------------------------------------*/
  @UI.identification: [{ position: 51, label: 'Start Session (M=Morning, A=Afternoon, blank = full day)' }]
  StartSession,

  @UI.lineItem: [{ position: 60, label: 'End Date' }]
  @UI.identification: [{ position: 60, label: 'End Date' }]
  EndDate,

  /*----------------------------------------------------------------
   * End Session – Buổi nghỉ của ngày kết thúc (chỉ áp dụng khi Half Day)
   *----------------------------------------------------------------*/
  @UI.identification: [{ position: 61, label: 'End Session (M=Morning, A=Afternoon, blank = full day)' }]
  EndSession,

  @UI.lineItem: [{ position: 70, label: 'Total Days' }]
  @UI.identification: [{ position: 70, label: 'Total Days' }]
  TotalDays,

  @UI.lineItem: [{
    position:    80,
    label:       'Status',
    criticality: 'StatusCriticality'
  }]
  @UI.identification: [{ position: 80, label: 'Status' }]
  Status,

  @UI.hidden: true
  StatusCriticality,

  @UI.identification: [{ position: 90, label: 'Reason' }]
  Reason,

  @UI.identification: [{ position: 110, label: 'Attachment' }]
  Attachment,

  @UI.hidden: true
  MimeType,

  @UI.hidden: true
  FileName,

  /*----------------------------------------------------------------
   * Action Buttons – gắn vào CreatedBy trên List Report
   * Manager: Approve / Reject  → chỉ sáng khi Status = SUBMITTED
   * HR:      HR Approve / HR Reject → chỉ sáng khi Status = MGR_APPROVED
   *----------------------------------------------------------------*/
  @UI.lineItem: [
    { type: #FOR_ACTION, dataAction: 'approveResult',
      label: 'Mgr Approve', position: 120 },
    { type: #FOR_ACTION, dataAction: 'rejectResult',
      label: 'Reject',      position: 130 },
    { type: #FOR_ACTION, dataAction: 'hrApproveResult',
      label: 'HR Approve',  position: 140 },
    { type: #FOR_ACTION, dataAction: 'hrRejectResult',
      label: 'HR Reject',   position: 150 }
  ]
  CreatedBy,

  @UI.identification: [{ position: 100, label: 'Approval Comment' }]
  ApprovalComment,

  /*----------------------------------------------------------------
   * ✅ THÊM: HR Comment – hiện trên Object Page sau khi HR duyệt/từ chối
   *----------------------------------------------------------------*/
  @UI.identification: [{ position: 101, label: 'HR Comment' }]
  HrComment,

  @UI.hidden: true
  CreatedAt,
  @UI.hidden: true
  LastChangedBy,
  @UI.hidden: true
  LastChangedAt
}
