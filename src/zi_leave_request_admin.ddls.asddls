@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Leave Request Admin View (All Requests)'
define view entity ZI_LEAVE_REQUEST_ADMIN
  as select from zleave_request as LR
  association [0..1] to ZI_EMPLOYEE as _Employee
    on $projection.EmployeeId = _Employee.EmployeeId
{
  key LR.mykey              as UUID,
      LR.request_id         as RequestId,
      LR.employee_id        as EmployeeId,
      LR.created_by         as CreatedBy,
      LR.approver_id        as ApproverId,
      LR.leave_type         as LeaveType,
      LR.start_date         as StartDate,
      LR.end_date           as EndDate,
      LR.total_days         as TotalDays,
      LR.reason             as Reason,
      LR.status             as Status,
      case LR.status
        when 'SUBMITTED' then 2
        when 'APPROVED'  then 3
        when 'REJECTED'  then 1
        else 0
      end                   as StatusCriticality,
      LR.approval_comment   as ApprovalComment,
      LR.hr_comment         as HrApprovalComment,
      @Semantics.largeObject: {
      mimeType:   'MimeType',
      fileName:   'FileName',
      acceptableMimeTypes: [ 'application/pdf',
                         'image/png',
                         'image/jpeg',
                         'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                         'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ],
      contentDispositionPreference: #ATTACHMENT
      }
      LR.attachment         as Attachment,

      @Semantics.mimeType: true
      LR.mime_type          as MimeType,

      LR.file_name          as FileName,
      LR.created_at         as CreatedAt,
      LR.last_changed_by    as LastChangedBy,
      LR.last_changed_at    as LastChangedAt,
      _Employee
}
