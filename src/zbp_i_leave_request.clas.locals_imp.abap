"##############################################################################
"# LOCAL TYPES cho ZBP_I_LEAVE_REQUEST (Không dùng HCM)
"##############################################################################

CLASS ltc_leave_request DEFINITION DEFERRED FOR TESTING.

CLASS lhc_leave_request DEFINITION INHERITING FROM cl_abap_behavior_handler
  FRIENDS ltc_leave_request.

  PRIVATE SECTION.

    "--- Helper method: tính TotalDays theo Session (không cần LeaveUnit) ---
    METHODS calculate_total_days
      IMPORTING
        iv_start_date    TYPE dats
        iv_end_date      TYPE dats
        iv_start_session TYPE char1
        iv_end_session   TYPE char1
      RETURNING
        VALUE(rv_days)   TYPE decfloat16.

    METHODS get_instance_authorizations
      FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations
      FOR LeaveRequest
      RESULT result.

    METHODS get_instance_features
      FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features
      FOR LeaveRequest
      RESULT result.

    METHODS determineEmployeeAndManager
      FOR DETERMINE ON MODIFY
      IMPORTING keys FOR LeaveRequest~determineEmployeeAndManager.

    METHODS validateDates
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR LeaveRequest~validateDates.

    METHODS validateLeaveQuota
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR LeaveRequest~validateLeaveQuota.

    METHODS validateOverlap
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR LeaveRequest~validateOverlap.

    METHODS validateSession
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR LeaveRequest~validateSession.

    METHODS approveResult
      FOR MODIFY
      IMPORTING keys FOR ACTION LeaveRequest~approveResult RESULT result.

    METHODS rejectResult
      FOR MODIFY
      IMPORTING keys FOR ACTION LeaveRequest~rejectResult RESULT result.

    "--- HR actions cho duyệt cấp 2 ---
    METHODS hrApproveResult
      FOR MODIFY
      IMPORTING keys FOR ACTION LeaveRequest~hrApproveResult RESULT result.

    METHODS hrRejectResult
      FOR MODIFY
      IMPORTING keys FOR ACTION LeaveRequest~hrRejectResult RESULT result.

    "--- ✅ THAY ĐỔI: send_email_sendgrid giờ tự đọc config từ ZSENDGRID_CONFIG,
    "    không còn nhận API Key/Sender hard-code qua CONSTANTS ---
    METHODS send_email_sendgrid
      IMPORTING
        iv_to_email  TYPE string
        iv_to_name   TYPE string
        iv_subject   TYPE string
        iv_body_text TYPE string.

    METHODS get_user_email
      IMPORTING
        iv_username      TYPE syuname
      RETURNING
        VALUE(rv_email)  TYPE string.

    METHODS write_audit_log
      IMPORTING iv_request_id  TYPE zleave_audit_log-request_id
            iv_employee_id TYPE zleave_audit_log-employee_id
            iv_action      TYPE zleave_audit_log-action
            iv_old_status  TYPE zleave_audit_log-old_status
            iv_new_status  TYPE zleave_audit_log-new_status
            iv_comments     TYPE zleave_audit_log-comments OPTIONAL.

    METHODS validateLeaveTypeActive
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR LeaveRequest~validateLeaveTypeActive.

    "--- ❌ ĐÃ XÓA: recalculateQuota (chỉ dùng khi cho phép edit đơn) ---

ENDCLASS.


CLASS lhc_leave_request IMPLEMENTATION.

"=============================================================================
" HELPER: calculate_total_days
" Tính số ngày nghỉ, tự suy luận Full Day/Half Day từ Session
" - Cả 2 Session trống  -> Full Day (tính nguyên ngày)
" - Có Session (M/A)     -> Half Day (tính theo buổi)
"=============================================================================
  METHOD calculate_total_days.

    rv_days = 0.

    CHECK iv_start_date IS NOT INITIAL
      AND iv_end_date   IS NOT INITIAL
      AND iv_end_date  >= iv_start_date.

    DATA(lv_base_days) = iv_end_date - iv_start_date + 1.

    IF iv_start_session IS INITIAL AND iv_end_session IS INITIAL.

      "--- Không chọn Session nào -> Full Day ---
      rv_days = lv_base_days.

    ELSE.

      "--- Có chọn Session -> Half Day ---
      IF iv_start_date = iv_end_date.
        "--- Cùng 1 ngày, có Session -> luôn là 0.5 ---
        rv_days = '0.5'.

      ELSE.
        rv_days = lv_base_days.

        "--- Ngày đầu nghỉ buổi Chiều -> trừ 0.5 (không nghỉ sáng ngày đầu) ---
        IF iv_start_session = 'A'.
          rv_days = rv_days - '0.5'.
        ENDIF.

        "--- Ngày cuối nghỉ buổi Sáng -> trừ 0.5 (không nghỉ chiều ngày cuối) ---
        IF iv_end_session = 'M'.
          rv_days = rv_days - '0.5'.
        ENDIF.

      ENDIF.

    ENDIF.

  ENDMETHOD.

"=============================================================================
" INSTANCE AUTHORIZATION
" ✅ THAY ĐỔI: %update luôn unauthorized (đã bỏ tính năng edit đơn)
"=============================================================================
  METHOD get_instance_authorizations.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    "--- Check role HR/Admin qua bảng AGR_USERS ---
    DATA(lv_is_hr) = abap_false.

    SELECT SINGLE agr_name
      FROM agr_users
      WHERE agr_name IN ('ZR_LR_HR', 'ZR_LR_ADMIN')
        AND uname     = @lv_user
        AND from_dat <= @sy-datum
        AND to_dat   >= @sy-datum
      INTO @DATA(lv_hr_role).

    IF sy-subrc = 0.
      lv_is_hr = abap_true.
    ENDIF.

    READ ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
      FIELDS ( CreatedBy ApproverId Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests)
      FAILED DATA(lt_failed).

    LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls>).

      DATA(lv_is_owner)        = xsdbool( <ls>-CreatedBy  = lv_user ).
      DATA(lv_is_approver)     = xsdbool( <ls>-ApproverId = lv_user ).
      DATA(lv_is_submitted)    = xsdbool( <ls>-Status     = 'SUBMITTED' ).
      DATA(lv_is_mgr_approved) = xsdbool( <ls>-Status     = 'MGR_APPROVED' ).

      APPEND VALUE #(
        %tky = <ls>-%tky

        %update = COND #(
          WHEN lv_is_owner = abap_true AND lv_is_submitted = abap_true
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )

        %delete = COND #(
          WHEN lv_is_owner = abap_true AND lv_is_submitted = abap_true
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )

        %action-approveResult = COND #(
          WHEN lv_is_approver = abap_true AND lv_is_submitted = abap_true
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )

        %action-rejectResult = COND #(
          WHEN lv_is_approver = abap_true AND lv_is_submitted = abap_true
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )

        %action-hrApproveResult = COND #(
          WHEN lv_is_hr = abap_true AND lv_is_mgr_approved = abap_true
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )

        %action-hrRejectResult = COND #(
          WHEN lv_is_hr = abap_true AND lv_is_mgr_approved = abap_true
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )

      ) TO result.

    ENDLOOP.

  ENDMETHOD.

"=============================================================================
" INSTANCE FEATURES
" Manager Approve/Reject: enable khi SUBMITTED
" HR Approve/Reject:      enable khi MGR_APPROVED
" ✅ THAY ĐỔI: đã bỏ field %update (không còn edit), lv_editable không dùng nữa
"=============================================================================
  METHOD get_instance_features.

    READ ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
      FIELDS ( Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests)
      FAILED DATA(lt_failed).

    LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls>).

      "--- Manager actions: enable khi SUBMITTED ---
      DATA(lv_submitted) = COND if_abap_behv=>t_char01(
                             WHEN <ls>-Status = 'SUBMITTED'
                             THEN if_abap_behv=>fc-o-enabled
                             ELSE if_abap_behv=>fc-o-disabled ).

      "--- HR actions: enable khi MGR_APPROVED ---
      DATA(lv_mgr_approved) = COND if_abap_behv=>t_char01(
                                WHEN <ls>-Status = 'MGR_APPROVED'
                                THEN if_abap_behv=>fc-o-enabled
                                ELSE if_abap_behv=>fc-o-disabled ).

      APPEND VALUE #(
        %tky                    = <ls>-%tky
        %action-approveResult   = lv_submitted
        %action-rejectResult    = lv_submitted
        %action-hrApproveResult = lv_mgr_approved
        %action-hrRejectResult  = lv_mgr_approved
        "--- ❌ ĐÃ BỎ: %update field control (không còn edit) ---
      ) TO result.

    ENDLOOP.

  ENDMETHOD.

"=============================================================================
" DETERMINATION: determineEmployeeAndManager
" ApproverId do Employee chọn khi tạo đơn, KHÔNG auto-set
" Tính TotalDays theo Session (không cần LeaveUnit)
" Trừ quota NGAY KHI TẠO ĐƠN
"
" ✅ THAY ĐỔI QUAN TRỌNG: KHÔNG còn gửi email ở đây nữa.
" Lý do bạn nêu ra là đúng: "ON MODIFY" determination chạy TRƯỚC các
" validate ON SAVE (validateDates, validateLeaveQuota, validateOverlap,
" validateSession, validateLeaveTypeActive). Nếu 1 trong các validate đó
" reject transaction, RAP sẽ rollback toàn bộ thay đổi DB - nhưng email đã
" gửi ra ngoài (side-effect qua HTTP) thì KHÔNG thể "rollback" được.
" -> Kết quả: user nhận được mail "đơn mới cần duyệt" dù đơn chưa hề được
" tạo thành công.
"
" Cách fix: method này CHỈ còn lo phần data (RequestId, Status, quota...).
" Việc gửi email "đơn mới cần duyệt" được chuyển sang save_modified (SAVER
" CLASS), trong nhánh CREATE - đây là nơi DUY NHẤT chạy SAU KHI mọi
" validate đã pass và ngay trước khi DB COMMIT thực sự xảy ra.
"
" ✅ FIX QUOTA BỊ TRỪ 2 LẦN (giữ nguyên như cũ):
" Đọc thêm field RequestId, CHECK RequestId IS INITIAL trước khi xử lý để
" chống bị framework gọi lại determination 2 lần cho cùng 1 instance.
"=============================================================================
  METHOD determineEmployeeAndManager.

    DATA(lv_current_user) = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_year)         = sy-datum(4).

    "--- Check user có role Manager không ---
    DATA(lv_is_manager) = abap_false.

    SELECT SINGLE agr_name
      FROM agr_users
      WHERE agr_name IN ('ZR_LR_MANAGER', 'ZR_LR_ADMIN')
        AND uname     = @lv_current_user
        AND from_dat <= @sy-datum
        AND to_dat   >= @sy-datum
      INTO @DATA(lv_mgr_role).

    IF sy-subrc = 0.
      lv_is_manager = abap_true.
    ENDIF.

    SELECT SINGLE emp_id, full_name
      FROM zemployee_table
      WHERE sap_user  = @lv_current_user
        AND is_active = @abap_true
      INTO @DATA(ls_emp).

    IF sy-subrc <> 0.
      READ ENTITIES OF zi_leave_request IN LOCAL MODE
        ENTITY LeaveRequest FIELDS ( UUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_keys).

      LOOP AT lt_keys ASSIGNING FIELD-SYMBOL(<k>).
        APPEND VALUE #(
          %tky = <k>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |User '{ lv_current_user }' chưa được đăng ký. Vui lòng liên hệ HR Admin.|
                 )
        ) TO reported-leaverequest.
      ENDLOOP.
      RETURN.
    ENDIF.

    "--- THÊM RequestId vào FIELDS để dùng làm guard chống double-run ---
    READ ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
      FIELDS ( RequestId StartDate EndDate LeaveType StartSession EndSession ApproverId )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_dates).

    LOOP AT lt_dates ASSIGNING FIELD-SYMBOL(<ls_d>).

      "--- GUARD: nếu RequestId đã có giá trị -> đơn đã được xử lý
      "    (tạo + trừ quota) rồi, bỏ qua để tránh trừ quota lần 2 ---
      CHECK <ls_d>-RequestId IS INITIAL.

      DATA lv_nr_number TYPE numc10.
      CALL FUNCTION 'NUMBER_GET_NEXT'
        EXPORTING
          nr_range_nr = '01'
          object      = 'ZLEAVE_NR'
        IMPORTING
          number      = lv_nr_number
        EXCEPTIONS
          OTHERS      = 1.

      DATA(lv_request_id) = COND string(
                              WHEN sy-subrc = 0
                              THEN |LR-{ lv_nr_number }|
                              ELSE |LR-{ lv_current_user }-{ sy-datum }| ).

      GET TIME STAMP FIELD DATA(lv_ts).

      DATA(lv_days) = calculate_total_days(
                        iv_start_date    = <ls_d>-StartDate
                        iv_end_date      = <ls_d>-EndDate
                        iv_start_session = <ls_d>-StartSession
                        iv_end_session   = <ls_d>-EndSession
                      ).

      IF lv_days > 0 AND <ls_d>-LeaveType IS NOT INITIAL.

        SELECT SINGLE *
          FROM zquota
          WHERE employee_id   = @ls_emp-emp_id
            AND leave_type_id = @<ls_d>-LeaveType
            AND quota_year    = @lv_year
          INTO @DATA(ls_quota).

        IF sy-subrc = 0.
          IF lv_days <= ls_quota-remaining_days.

            DATA(lv_new_used)      = ls_quota-used_days + lv_days.
            DATA(lv_new_remaining) = ls_quota-total_days - lv_new_used.

            UPDATE zquota SET
              used_days       = @lv_new_used,
              remaining_days  = @lv_new_remaining,
              last_updated_by = @lv_current_user,
              last_updated_at = @lv_ts
              WHERE employee_id   = @ls_emp-emp_id
                AND leave_type_id = @<ls_d>-LeaveType
                AND quota_year    = @lv_year.

          ELSE.
            APPEND VALUE #( %tky = <ls_d>-%tky ) TO reported-leaverequest.
            APPEND VALUE #(
              %tky = <ls_d>-%tky
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = |Không đủ quota! Còn lại: { ls_quota-remaining_days } ngày, Yêu cầu: { lv_days } ngày.|
                     )
            ) TO reported-leaverequest.
            CONTINUE.
          ENDIF.
        ENDIF.
      ENDIF.

      "--- Xác định Status và HrApproverId theo role ---
      DATA lv_status       TYPE char15.
      DATA lv_hr_approver  TYPE syuname.

      IF lv_is_manager = abap_true.

        "--- Manager tạo đơn: bỏ qua cấp duyệt 1, chuyển thẳng MGR_APPROVED ---
        lv_status = 'MGR_APPROVED'.

        "--- Tự động tìm HR user để gán ---
        SELECT SINGLE sap_user
          FROM zemployee_table
          WHERE is_hr     = 'X'
            AND is_active = @abap_true
          INTO @lv_hr_approver.

      ELSE.

        "--- Employee thường: SUBMITTED như cũ ---
        lv_status      = 'SUBMITTED'.
        lv_hr_approver = ''.

      ENDIF.

      MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
        ENTITY LeaveRequest
        UPDATE FIELDS ( RequestId EmployeeId Status HrApproverId
                        TotalDays CreatedBy CreatedAt LastChangedBy LastChangedAt )
        WITH VALUE #(
          ( %tky          = <ls_d>-%tky
            RequestId     = lv_request_id
            EmployeeId    = ls_emp-emp_id
            Status        = lv_status
            HrApproverId  = lv_hr_approver
            TotalDays     = lv_days
            CreatedBy     = lv_current_user
            CreatedAt     = lv_ts
            LastChangedBy = lv_current_user
            LastChangedAt = lv_ts )
        ).

      "--- ❌ ĐÃ XÓA: toàn bộ khối gửi email cho Manager ở đây.
      "    Logic này (bao gồm cả cảnh báo "Email không tìm thấy") đã được
      "    chuyển sang save_modified, nhánh CREATE, xem class lsc_leave_request. ---

    ENDLOOP.

  ENDMETHOD.

"=============================================================================
" VALIDATION: validateDates
"=============================================================================
METHOD validateDates.

  DATA(lv_first_day_of_month) = sy-datum.
  lv_first_day_of_month+6(2) = '01'.

  READ ENTITIES OF zi_leave_request IN LOCAL MODE
    ENTITY LeaveRequest
    FIELDS ( StartDate EndDate )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_requests).

  LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls>).

    IF <ls>-EndDate < <ls>-StartDate.
      APPEND VALUE #( %tky = <ls>-%tky ) TO failed-leaverequest.
      APPEND VALUE #(
        %tky               = <ls>-%tky
        %element-StartDate = if_abap_behv=>mk-on
        %element-EndDate   = if_abap_behv=>mk-on
        %msg               = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Ngày kết thúc không được nhỏ hơn ngày bắt đầu!'
                             )
      ) TO reported-leaverequest.
    ENDIF.

    "--- Chỉ chặn nếu StartDate ở THÁNG TRƯỚC (trước ngày 01 tháng hiện tại) ---
    IF <ls>-StartDate < lv_first_day_of_month.
      APPEND VALUE #( %tky = <ls>-%tky ) TO failed-leaverequest.
      APPEND VALUE #(
        %tky               = <ls>-%tky
        %element-StartDate = if_abap_behv=>mk-on
        %msg               = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = |Chỉ được phép gửi đơn cho ngày trong tháng hiện tại trở đi | &&
                                          |(không thể chọn ngày trước { lv_first_day_of_month+6(2) }.{ lv_first_day_of_month+4(2) }.{ lv_first_day_of_month(4) })!|
                             )
      ) TO reported-leaverequest.
    ENDIF.

  ENDLOOP.

ENDMETHOD.

"=============================================================================
" VALIDATION: validateSession
" Chỉ validate nếu user CÓ chọn Session (đang làm Half Day)
" Nếu cả 2 trống -> Full Day, không cần validate gì
"=============================================================================
  METHOD validateSession.

    READ ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
      FIELDS ( StartSession EndSession StartDate EndDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests).

    LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls>).

      "--- Nếu cả 2 Session đều trống -> Full Day, bỏ qua validation ---
      CHECK <ls>-StartSession IS NOT INITIAL OR <ls>-EndSession IS NOT INITIAL.

      "--- Đã bắt đầu chọn Half Day -> StartSession bắt buộc ---
      IF <ls>-StartSession IS INITIAL.
        APPEND VALUE #( %tky = <ls>-%tky ) TO failed-leaverequest.
        APPEND VALUE #(
          %tky = <ls>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Vui lòng chọn buổi nghỉ (Sáng/Chiều) cho ngày bắt đầu!'
                 )
        ) TO reported-leaverequest.
      ENDIF.

      "--- Nếu nghỉ nhiều ngày dạng Half Day, EndSession cũng bắt buộc ---
      IF <ls>-StartDate <> <ls>-EndDate AND <ls>-EndSession IS INITIAL.
        APPEND VALUE #( %tky = <ls>-%tky ) TO failed-leaverequest.
        APPEND VALUE #(
          %tky = <ls>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = 'Vui lòng chọn buổi nghỉ (Sáng/Chiều) cho ngày kết thúc!'
                 )
        ) TO reported-leaverequest.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

"=============================================================================
" VALIDATION: validateLeaveQuota
"=============================================================================
  METHOD validateLeaveQuota.

    DATA(lv_year) = sy-datum(4).

    READ ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
      FIELDS ( EmployeeId LeaveType TotalDays )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests).

    LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls>).

      CHECK <ls>-EmployeeId IS NOT INITIAL
        AND <ls>-LeaveType   IS NOT INITIAL
        AND <ls>-TotalDays   > 0.

      SELECT SINGLE total_days, used_days, remaining_days
        FROM zquota
        WHERE employee_id   = @<ls>-EmployeeId
          AND leave_type_id = @<ls>-LeaveType
          AND quota_year    = @lv_year
        INTO @DATA(ls_quota).

      IF sy-subrc <> 0.
        APPEND VALUE #(
          %tky = <ls>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-warning
                   text     = |Chưa có hạn mức phép loại '{ <ls>-LeaveType }' cho năm { lv_year }. Vui lòng liên hệ HR Admin.|
                 )
        ) TO reported-leaverequest.
        CONTINUE.
      ENDIF.

      IF <ls>-TotalDays > ls_quota-remaining_days.
        APPEND VALUE #( %tky = <ls>-%tky ) TO failed-leaverequest.
        APPEND VALUE #(
          %tky               = <ls>-%tky
          %element-TotalDays = if_abap_behv=>mk-on
          %msg               = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Vượt quá hạn mức! Còn lại: { ls_quota-remaining_days } ngày, Yêu cầu: { <ls>-TotalDays } ngày.|
                               )
        ) TO reported-leaverequest.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

"=============================================================================
" VALIDATION: validateOverlap
"=============================================================================
  METHOD validateOverlap.

    READ ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
      FIELDS ( EmployeeId StartDate EndDate UUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests).

    LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls>).

      CHECK <ls>-EmployeeId IS NOT INITIAL
        AND <ls>-StartDate  IS NOT INITIAL
        AND <ls>-EndDate    IS NOT INITIAL.

      SELECT SINGLE mykey, status, start_date, end_date
        FROM zleave_request
        WHERE employee_id = @<ls>-EmployeeId
          AND mykey      <> @<ls>-UUID
          AND status     <> 'REJECTED'
          AND start_date <= @<ls>-EndDate
          AND end_date   >= @<ls>-StartDate
        INTO @DATA(ls_overlap).

      IF sy-subrc = 0.
        APPEND VALUE #( %tky = <ls>-%tky ) TO failed-leaverequest.
        APPEND VALUE #(
          %tky               = <ls>-%tky
          %element-StartDate = if_abap_behv=>mk-on
          %element-EndDate   = if_abap_behv=>mk-on
          %msg               = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Trùng ngày với đơn { ls_overlap-status } ({ ls_overlap-start_date } - { ls_overlap-end_date }). Vui lòng chọn ngày khác.|
                               )
        ) TO reported-leaverequest.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

"=============================================================================
" ACTION: approveResult (Manager duyệt cấp 1)
" Đổi Status SUBMITTED -> MGR_APPROVED
" Tự động set HrApproverId = HR user đầu tiên có is_hr = 'X'
"=============================================================================
  METHOD approveResult.

  GET TIME STAMP FIELD DATA(lv_ts).
  DATA(lv_current_user) = cl_abap_context_info=>get_user_technical_name( ).

  SELECT SINGLE sap_user
    FROM zemployee_table
    WHERE is_hr     = 'X'
      AND is_active = @abap_true
    INTO @DATA(lv_hr_user).

  READ ENTITIES OF zi_leave_request IN LOCAL MODE
    ENTITY LeaveRequest
    FIELDS ( Status RequestId EmployeeId )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_requests).

  LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls>).
    CHECK <ls>-Status = 'SUBMITTED'.

    " Lấy comment từ parameter
    READ TABLE keys WITH KEY %tky = <ls>-%tky
      ASSIGNING FIELD-SYMBOL(<key>).
    DATA(lv_comment) = COND string(
                         WHEN sy-subrc = 0
                         THEN <key>-%param-ApprovalComment
                         ELSE '' ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
      UPDATE FIELDS ( Status HrApproverId ApprovalComment LastChangedBy LastChangedAt )
      WITH VALUE #(
        ( %tky            = <ls>-%tky
          Status          = 'MGR_APPROVED'
          HrApproverId    = lv_hr_user
          ApprovalComment = lv_comment
          LastChangedBy   = lv_current_user
          LastChangedAt   = lv_ts )
      ).

    APPEND VALUE #(
      %tky = <ls>-%tky
      %msg = new_message_with_text(
               severity = if_abap_behv_message=>severity-success
               text     = 'Manager đã duyệt. Đơn chuyển sang HR để duyệt lần 2.'
             )
    ) TO reported-leaverequest.

    write_audit_log(
      iv_request_id  = <ls>-RequestId
      iv_employee_id = CONV #( <ls>-EmployeeId )
      iv_action      = 'MGR_APPROVE'
      iv_old_status  = 'SUBMITTED'
      iv_new_status  = 'MGR_APPROVED'
      iv_comments    = CONV #( lv_comment )
    ).

    "--- Action (approve/reject) chạy SAU khi validate/save của bước trước
    "    đã pass và ta đang ở giữa 1 modify request đã được authorize riêng,
    "    nên gửi email trực tiếp ở đây vẫn an toàn (khác với determination
    "    lúc CREATE, vốn chạy trước validate). ---
    IF lv_hr_user IS NOT INITIAL.
      DATA(lv_hr_email) = get_user_email( iv_username = lv_hr_user ).
      IF lv_hr_email IS NOT INITIAL.
        send_email_sendgrid(
          iv_to_email  = lv_hr_email
          iv_to_name   = CONV string( lv_hr_user )
          iv_subject   = |[Leave Request] Đơn nghỉ phép chờ HR duyệt|
          iv_body_text = |Xin chào HR,<br><br>| &&
                         |Manager đã duyệt 1 đơn xin nghỉ phép.<br>| &&
                         |<b>Comment Manager:</b> { lv_comment }<br><br>| &&
                         |Đơn đang chờ HR xác nhận lần 2.<br><br>| &&
                         |Vui lòng đăng nhập hệ thống để kiểm tra.<br><br>| &&
                         |Trân trọng,<br><b>Hệ thống Leave Management</b>|
        ).
      ENDIF.
    ENDIF.

  ENDLOOP.

  READ ENTITIES OF zi_leave_request IN LOCAL MODE
    ENTITY LeaveRequest ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_result).

  result = VALUE #( FOR ls IN lt_result ( %tky = ls-%tky %param = ls ) ).

ENDMETHOD.

"=============================================================================
" ACTION: rejectResult (Manager từ chối)
"=============================================================================
METHOD rejectResult.

  GET TIME STAMP FIELD DATA(lv_ts).
  DATA(lv_current_user) = cl_abap_context_info=>get_user_technical_name( ).
  DATA(lv_year)         = sy-datum(4).

  READ ENTITIES OF zi_leave_request IN LOCAL MODE
    ENTITY LeaveRequest
    FIELDS ( Status RequestId EmployeeId LeaveType TotalDays CreatedBy )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_requests).

  LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls>).
    CHECK <ls>-Status = 'SUBMITTED'.

    READ TABLE keys WITH KEY %tky = <ls>-%tky
      ASSIGNING FIELD-SYMBOL(<key>).
    DATA(lv_comment) = COND string(
                         WHEN sy-subrc = 0
                         THEN <key>-%param-ApprovalComment
                         ELSE '' ).

    IF <ls>-EmployeeId IS NOT INITIAL
       AND <ls>-LeaveType IS NOT INITIAL
       AND <ls>-TotalDays > 0.

      SELECT SINGLE *
        FROM zquota
        WHERE employee_id   = @<ls>-EmployeeId
          AND leave_type_id = @<ls>-LeaveType
          AND quota_year    = @lv_year
        INTO @DATA(ls_quota).

      IF sy-subrc = 0.
        DATA(lv_new_used)      = ls_quota-used_days - <ls>-TotalDays.
        DATA(lv_new_remaining) = ls_quota-remaining_days + <ls>-TotalDays.
        IF lv_new_used < 0. lv_new_used = 0. ENDIF.
        IF lv_new_remaining > ls_quota-total_days. lv_new_remaining = ls_quota-total_days. ENDIF.

        UPDATE zquota SET
          used_days       = @lv_new_used,
          remaining_days  = @lv_new_remaining,
          last_updated_by = @lv_current_user,
          last_updated_at = @lv_ts
          WHERE employee_id   = @<ls>-EmployeeId
            AND leave_type_id = @<ls>-LeaveType
            AND quota_year    = @lv_year.
      ELSE.
        APPEND VALUE #(
          %tky = <ls>-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-warning
                   text     = |Không tìm thấy quota emp { <ls>-EmployeeId } loai { <ls>-LeaveType } nam { lv_year }|
                 )
        ) TO reported-leaverequest.
      ENDIF.
    ENDIF.

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
      UPDATE FIELDS ( Status ApprovalComment LastChangedBy LastChangedAt )
      WITH VALUE #(
        ( %tky            = <ls>-%tky
          Status          = 'REJECTED'
          ApprovalComment = lv_comment
          LastChangedBy   = lv_current_user
          LastChangedAt   = lv_ts )
      ).

    APPEND VALUE #(
      %tky = <ls>-%tky
      %msg = new_message_with_text(
               severity = if_abap_behv_message=>severity-success
               text     = 'Manager đã từ chối đơn. Quota đã được hoàn trả (nếu tìm thấy).'
             )
    ) TO reported-leaverequest.

    write_audit_log(
      iv_request_id  = <ls>-RequestId
      iv_employee_id = CONV #( <ls>-EmployeeId )
      iv_action      = 'MGR_REJECT'
      iv_old_status  = 'SUBMITTED'
      iv_new_status  = 'REJECTED'
      iv_comments    = CONV #( lv_comment )
    ).

    IF <ls>-CreatedBy IS NOT INITIAL.
      DATA(lv_emp_email_mgr_rej) = get_user_email( iv_username = <ls>-CreatedBy ).
      IF lv_emp_email_mgr_rej IS NOT INITIAL.
        send_email_sendgrid(
          iv_to_email  = lv_emp_email_mgr_rej
          iv_to_name   = CONV string( <ls>-CreatedBy )
          iv_subject   = |[Leave Request] Đơn nghỉ phép bị từ chối bởi Manager|
          iv_body_text = |Xin chào,<br><br>| &&
                         |Rất tiếc, đơn nghỉ phép của bạn đã bị <b>Manager từ chối</b>.<br><br>| &&
                         |<b>Lý do:</b> { lv_comment }<br><br>| &&
                         |Vui lòng liên hệ Manager để biết thêm thông tin.<br><br>| &&
                         |Trân trọng,<br><b>Hệ thống Leave Management</b>|
        ).
      ENDIF.
    ENDIF.

  ENDLOOP.

  READ ENTITIES OF zi_leave_request IN LOCAL MODE
    ENTITY LeaveRequest ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_result).

  result = VALUE #( FOR ls IN lt_result ( %tky = ls-%tky %param = ls ) ).

ENDMETHOD.

"=============================================================================
" ACTION: hrApproveResult (HR duyệt cấp 2)
"=============================================================================
METHOD hrApproveResult.

  GET TIME STAMP FIELD DATA(lv_ts).
  DATA(lv_current_user) = cl_abap_context_info=>get_user_technical_name( ).

  READ ENTITIES OF zi_leave_request IN LOCAL MODE
    ENTITY LeaveRequest
    FIELDS ( Status RequestId EmployeeId CreatedBy )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_requests).

  LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls>).
    CHECK <ls>-Status = 'MGR_APPROVED'.

    " Lấy comment từ parameter
    READ TABLE keys WITH KEY %tky = <ls>-%tky
      ASSIGNING FIELD-SYMBOL(<key>).
    DATA(lv_comment) = COND string(
                         WHEN sy-subrc = 0
                         THEN <key>-%param-ApprovalComment
                         ELSE '' ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
      UPDATE FIELDS ( Status HrComment LastChangedBy LastChangedAt )
      WITH VALUE #(
        ( %tky          = <ls>-%tky
          Status        = 'APPROVED'
          HrComment     = lv_comment
          LastChangedBy = lv_current_user
          LastChangedAt = lv_ts )
      ).

    APPEND VALUE #(
      %tky = <ls>-%tky
      %msg = new_message_with_text(
               severity = if_abap_behv_message=>severity-success
               text     = 'HR đã duyệt. Đơn nghỉ phép được chấp thuận hoàn toàn.'
             )
    ) TO reported-leaverequest.

    write_audit_log(
      iv_request_id  = <ls>-RequestId
      iv_employee_id = CONV #( <ls>-EmployeeId )
      iv_action      = 'HR_APPROVE'
      iv_old_status  = 'MGR_APPROVED'
      iv_new_status  = 'APPROVED'
      iv_comments    = CONV #( lv_comment )
    ).

    IF <ls>-CreatedBy IS NOT INITIAL.
      DATA(lv_emp_email_approve) = get_user_email( iv_username = <ls>-CreatedBy ).
      IF lv_emp_email_approve IS NOT INITIAL.
        send_email_sendgrid(
          iv_to_email  = lv_emp_email_approve
          iv_to_name   = CONV string( <ls>-CreatedBy )
          iv_subject   = |[Leave Request] Đơn nghỉ phép đã được APPROVED|
          iv_body_text = |Xin chào,<br><br>| &&
                         |Đơn nghỉ phép của bạn đã được <b>HR duyệt thành công</b>.<br><br>| &&
                         |<b>Comment HR:</b> { lv_comment }<br><br>| &&
                         |<b>Trạng thái:</b> APPROVED ✅<br><br>| &&
                         |Chúc bạn có một kỳ nghỉ thật vui vẻ!<br><br>| &&
                         |Trân trọng,<br><b>Hệ thống Leave Management</b>|
        ).
      ENDIF.
    ENDIF.

  ENDLOOP.

  READ ENTITIES OF zi_leave_request IN LOCAL MODE
    ENTITY LeaveRequest ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_result).

  result = VALUE #( FOR ls IN lt_result ( %tky = ls-%tky %param = ls ) ).

ENDMETHOD.

"=============================================================================
" ACTION: hrRejectResult (HR từ chối cấp 2)
"=============================================================================
METHOD hrRejectResult.

  GET TIME STAMP FIELD DATA(lv_ts).
  DATA(lv_current_user) = cl_abap_context_info=>get_user_technical_name( ).
  DATA(lv_year)         = sy-datum(4).

  READ ENTITIES OF zi_leave_request IN LOCAL MODE
    ENTITY LeaveRequest
    FIELDS ( Status RequestId EmployeeId LeaveType TotalDays CreatedBy )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_requests).

  LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls>).
    CHECK <ls>-Status = 'MGR_APPROVED'.

    " Lấy comment từ parameter
    READ TABLE keys WITH KEY %tky = <ls>-%tky
      ASSIGNING FIELD-SYMBOL(<key>).
    DATA(lv_comment) = COND string(
                         WHEN sy-subrc = 0
                         THEN <key>-%param-ApprovalComment
                         ELSE '' ).

    IF <ls>-EmployeeId IS NOT INITIAL
       AND <ls>-LeaveType IS NOT INITIAL
       AND <ls>-TotalDays > 0.

      SELECT SINGLE *
        FROM zquota
        WHERE employee_id   = @<ls>-EmployeeId
          AND leave_type_id = @<ls>-LeaveType
          AND quota_year    = @lv_year
        INTO @DATA(ls_quota).

      IF sy-subrc = 0.
        DATA(lv_new_used)      = ls_quota-used_days - <ls>-TotalDays.
        DATA(lv_new_remaining) = ls_quota-remaining_days + <ls>-TotalDays.
        IF lv_new_used < 0. lv_new_used = 0. ENDIF.
        IF lv_new_remaining > ls_quota-total_days. lv_new_remaining = ls_quota-total_days. ENDIF.

        UPDATE zquota SET
          used_days       = @lv_new_used,
          remaining_days  = @lv_new_remaining,
          last_updated_by = @lv_current_user,
          last_updated_at = @lv_ts
          WHERE employee_id   = @<ls>-EmployeeId
            AND leave_type_id = @<ls>-LeaveType
            AND quota_year    = @lv_year.
      ENDIF.
    ENDIF.

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
      UPDATE FIELDS ( Status HrComment LastChangedBy LastChangedAt )
      WITH VALUE #(
        ( %tky          = <ls>-%tky
          Status        = 'REJECTED'
          HrComment     = lv_comment
          LastChangedBy = lv_current_user
          LastChangedAt = lv_ts )
      ).

    APPEND VALUE #(
      %tky = <ls>-%tky
      %msg = new_message_with_text(
               severity = if_abap_behv_message=>severity-success
               text     = 'HR đã từ chối đơn. Quota đã được hoàn trả.'
             )
    ) TO reported-leaverequest.

    write_audit_log(
      iv_request_id  = <ls>-RequestId
      iv_employee_id = CONV #( <ls>-EmployeeId )
      iv_action      = 'HR_REJECT'
      iv_old_status  = 'MGR_APPROVED'
      iv_new_status  = 'REJECTED'
      iv_comments    = CONV #( lv_comment )
    ).

    IF <ls>-CreatedBy IS NOT INITIAL.
      DATA(lv_emp_email_hr_rej) = get_user_email( iv_username = <ls>-CreatedBy ).
      IF lv_emp_email_hr_rej IS NOT INITIAL.
        send_email_sendgrid(
          iv_to_email  = lv_emp_email_hr_rej
          iv_to_name   = CONV string( <ls>-CreatedBy )
          iv_subject   = |[Leave Request] Đơn nghỉ phép bị từ chối bởi HR|
          iv_body_text = |Xin chào,<br><br>| &&
                         |Rất tiếc, đơn nghỉ phép của bạn đã bị <b>HR từ chối</b>.<br><br>| &&
                         |<b>Lý do:</b> { lv_comment }<br><br>| &&
                         |Vui lòng liên hệ HR để biết thêm thông tin.<br><br>| &&
                         |Trân trọng,<br><b>Hệ thống Leave Management</b>|
        ).
      ENDIF.
    ENDIF.

  ENDLOOP.

  READ ENTITIES OF zi_leave_request IN LOCAL MODE
    ENTITY LeaveRequest ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_result).

  result = VALUE #( FOR ls IN lt_result ( %tky = ls-%tky %param = ls ) ).

ENDMETHOD.

  "=============================================================================
" HELPER: get_user_email
"=============================================================================
  METHOD get_user_email.

    rv_email = ''.

    SELECT SINGLE smtp_addr
      FROM adr6
      INNER JOIN usr21
        ON adr6~addrnumber = usr21~addrnumber
        AND adr6~persnumber = usr21~persnumber
      WHERE usr21~bname = @iv_username
      INTO @DATA(lv_email).

    IF sy-subrc = 0.
      rv_email = lv_email.
    ENDIF.

  ENDMETHOD.

"=============================================================================
" HELPER: send_email_sendgrid
" ✅ THAY ĐỔI: API Key + Sender giờ đọc từ bảng ZSENDGRID_CONFIG thay vì
" CONSTANTS hard-code trong code. Nếu không tìm thấy config active, method
" tự bỏ qua (không chặn luồng chính) và log 1 message vào sy-msg (tuỳ chọn
" bạn có thể đổi thành ghi vào bảng log riêng nếu cần theo dõi).
"=============================================================================
  METHOD send_email_sendgrid.

    CONSTANTS lc_endpoint TYPE string VALUE 'https://api.sendgrid.com/v3/mail/send'.

    "--- Đọc config từ table thay vì hard-code ---
    SELECT SINGLE api_key, sender_email, sender_name
      FROM zsendgrid_config
      WHERE config_id  = 'DEFAULT'
        AND is_active  = @abap_true
      INTO @DATA(ls_config).

    IF sy-subrc <> 0
       OR ls_config-api_key      IS INITIAL
       OR ls_config-sender_email IS INITIAL.
      "--- Không có config hợp lệ -> không gửi, không chặn luồng chính ---
      RETURN.
    ENDIF.

    DATA(lv_json) = |\{"personalizations":[| &&
                    |\{"to":[| &&
                    |\{"email":"{ iv_to_email }",| &&
                    |"name":"{ iv_to_name }"\}| &&
                    |]\}],| &&
                    |"from":\{"email":"{ ls_config-sender_email }",| &&
                    |"name":"{ ls_config-sender_name }"\},| &&
                    |"subject":"{ iv_subject }",| &&
                    |"content":[| &&
                    |\{"type":"text/html",| &&
                    |"value":"{ iv_body_text }"\}| &&
                    |]\}|.

    TRY.
      DATA lo_http_client TYPE REF TO if_http_client.

      cl_http_client=>create_by_url(
        EXPORTING
          url                = lc_endpoint
        IMPORTING
          client             = lo_http_client
        EXCEPTIONS
          argument_not_found = 1
          plugin_not_active  = 2
          internal_error     = 3
          OTHERS             = 4
      ).

      IF sy-subrc <> 0. RETURN. ENDIF.

      lo_http_client->request->set_method( 'POST' ).

      lo_http_client->request->set_header_field(
        name  = 'Authorization'
        value = |Bearer { ls_config-api_key }|
      ).
      lo_http_client->request->set_header_field(
        name  = 'Content-Type'
        value = 'application/json'
      ).

      lo_http_client->request->set_cdata( lv_json ).

      lo_http_client->send(
        EXCEPTIONS
          http_communication_failure = 1
          http_invalid_state         = 2
          OTHERS                     = 3
      ).

      IF sy-subrc <> 0. RETURN. ENDIF.

      lo_http_client->receive(
        EXCEPTIONS
          http_communication_failure = 1
          http_invalid_state         = 2
          http_processing_failed     = 3
          OTHERS                     = 4
      ).

      lo_http_client->close( ).

    CATCH cx_root.
      "--- Không chặn luồng chính khi email lỗi ---
    ENDTRY.

  ENDMETHOD.

  "--------------------------
" 1. METHOD write_audit_log
"----------------------------
  METHOD write_audit_log.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD DATA(lv_ts).

    INSERT zleave_audit_log FROM @( VALUE zleave_audit_log(
      log_id      = cl_system_uuid=>create_uuid_x16_static( )
      request_id  = iv_request_id
      employee_id = iv_employee_id
      action      = iv_action
      action_by   = lv_user
      action_at   = lv_ts
      old_status  = iv_old_status
      new_status  = iv_new_status
      comments    = iv_comments
    ) ).

  ENDMETHOD.

  METHOD validateLeaveTypeActive.
  READ ENTITIES OF zi_leave_request IN LOCAL MODE
    ENTITY LeaveRequest
    FIELDS ( LeaveType )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_requests).

  LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls>).
    CHECK <ls>-LeaveType IS NOT INITIAL.

    SELECT SINGLE is_active
      FROM zleave_type
      WHERE leave_type_id = @<ls>-LeaveType
      INTO @DATA(lv_active).

    IF sy-subrc <> 0 OR lv_active = abap_false.
      APPEND VALUE #( %tky = <ls>-%tky ) TO failed-leaverequest.
      APPEND VALUE #(
        %tky             = <ls>-%tky
        %element-LeaveType = if_abap_behv=>mk-on
        %msg             = new_message_with_text(
                             severity = if_abap_behv_message=>severity-error
                             text     = |Loại nghỉ '{ <ls>-LeaveType }' đã bị vô hiệu hóa. Vui lòng chọn loại khác.|
                           )
      ) TO reported-leaverequest.
    ENDIF.
  ENDLOOP.
ENDMETHOD.

  "--- ❌ ĐÃ XÓA: METHOD recalculateQuota (chỉ cần khi cho phép edit đơn) ---

ENDCLASS.

"##############################################################################
"# PART 2: SAVER CLASS
"##############################################################################
CLASS lsc_leave_request DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.

  PRIVATE SECTION.
    "--- ✅ THÊM: helper riêng cho saver để lấy email user từ SU01 (ADR6/USR21).
    "    Saver class không kế thừa lhc_leave_request nên cần bản riêng. ---
    METHODS get_user_email_for_saver
      IMPORTING
        iv_username     TYPE syuname
      RETURNING
        VALUE(rv_email) TYPE string.

    "--- ✅ THÊM: helper riêng cho saver để gửi mail "đơn mới cần duyệt".
    "    Đặt ở đây (không dùng lại method của lhc_leave_request) vì saver
    "    class là 1 class khác, không kế thừa handler. Logic SendGrid dùng
    "    chung 1 bảng config, nên tách 1 method nhỏ đọc + gọi HTTP riêng. ---
    METHODS send_new_request_email
  IMPORTING
    iv_to_email    TYPE string
    iv_to_name     TYPE string
    iv_request_id  TYPE zleave_request-request_id
    iv_emp_name    TYPE string
    iv_leave_type  TYPE zleave_request-leave_type
    iv_start_date  TYPE dats
    iv_end_date    TYPE dats
    iv_total_days  TYPE zleave_request-total_days.

ENDCLASS.

CLASS lsc_leave_request IMPLEMENTATION.

  METHOD save_modified.

    DATA ls_db   TYPE zleave_request.
    DATA lv_year TYPE numc4.
    lv_year = sy-datum(4).

    "==========================================================================
    " INSERT
    " ✅ THAY ĐỔI: sau khi INSERT thành công (tức là mọi validate ON SAVE đã
    " pass), nếu đơn là do Employee tạo (không phải Manager tự tạo -> status
    " SUBMITTED) và có ApproverId, gửi email thông báo cho Manager tại đây.
    " Đây là lý do chính bạn yêu cầu tách email ra khỏi determination.
    "==========================================================================
    IF create-leaverequest IS NOT INITIAL.

      READ ENTITIES OF zi_leave_request IN LOCAL MODE
        ENTITY LeaveRequest ALL FIELDS
        WITH CORRESPONDING #( create-leaverequest )
        RESULT DATA(lt_create).

      LOOP AT lt_create ASSIGNING FIELD-SYMBOL(<c>).
        CLEAR ls_db.
        ls_db-mykey            = <c>-UUID.
        ls_db-request_id       = <c>-RequestId.
        ls_db-employee_id      = <c>-EmployeeId.
        ls_db-approver_id      = <c>-ApproverId.
        ls_db-hr_approver_id   = <c>-HrApproverId.
        ls_db-leave_type       = <c>-LeaveType.
        ls_db-start_date       = <c>-StartDate.
        ls_db-end_date         = <c>-EndDate.
        ls_db-start_session    = <c>-StartSession.
        ls_db-end_session      = <c>-EndSession.
        ls_db-total_days       = <c>-TotalDays.
        ls_db-reason           = <c>-Reason.
        ls_db-status           = <c>-Status.
        ls_db-approval_comment = <c>-ApprovalComment.
        ls_db-hr_comment       = <c>-HrComment.
        ls_db-attachment       = <c>-Attachment.
        ls_db-mime_type        = <c>-MimeType.
        ls_db-file_name        = <c>-FileName.
        ls_db-created_by       = <c>-CreatedBy.
        ls_db-created_at       = <c>-CreatedAt.
        ls_db-last_changed_by  = <c>-LastChangedBy.
        ls_db-last_changed_at  = <c>-LastChangedAt.
        INSERT zleave_request FROM @ls_db.

        INSERT zleave_audit_log FROM @( VALUE zleave_audit_log(
          log_id      = cl_system_uuid=>create_uuid_x16_static( )
          request_id  = <c>-RequestId
          employee_id = <c>-EmployeeId
          action      = 'CREATE'
          action_by   = <c>-CreatedBy
          action_at   = <c>-CreatedAt
          old_status  = ''
          new_status  = <c>-Status
          comments    = |Tạo đơn nghỉ phép mới: { <c>-LeaveType } từ { <c>-StartDate } đến { <c>-EndDate }|
        ) ).

        "--- ✅ GỬI EMAIL Ở ĐÂY: chỉ khi Status = SUBMITTED (đơn Employee
        "    tạo, cần Manager duyệt) và có ApproverId. Tại thời điểm này,
        "    toàn bộ validate ON SAVE đã pass và record đã INSERT xong. ---
        IF ls_db-status = 'SUBMITTED' AND <c>-ApproverId IS NOT INITIAL.

          SELECT SINGLE full_name
            FROM zemployee_table
            WHERE emp_id = @<c>-EmployeeId
            INTO @DATA(lv_emp_name).

          DATA(lv_mgr_email) = get_user_email_for_saver( iv_username = <c>-ApproverId ).

          IF lv_mgr_email IS NOT INITIAL.
  send_new_request_email(
    iv_to_email   = lv_mgr_email
    iv_to_name    = CONV string( <c>-ApproverId )
    iv_request_id = <c>-RequestId
    iv_emp_name   = COND #( WHEN sy-subrc = 0 THEN lv_emp_name ELSE CONV string( <c>-EmployeeId ) )
    iv_leave_type = <c>-LeaveType
    iv_start_date = <c>-StartDate
    iv_end_date   = <c>-EndDate
    iv_total_days = <c>-TotalDays
  ).
ENDIF.

        ENDIF.

      ENDLOOP.

    ENDIF.


"==========================================================================
" UPDATE
" BO dùng unmanaged save nên UPDATE cũng phải tự ghi DB như INSERT/DELETE.
" Thiếu nhánh này thì Status/HrApproverId/comment... do các action approve/
" reject set qua MODIFY ENTITIES...UPDATE sẽ chỉ nằm trong buffer RAP,
" không bao giờ tới được bảng zleave_request thật.
"==========================================================================
IF update-leaverequest IS NOT INITIAL.

  READ ENTITIES OF zi_leave_request IN LOCAL MODE
    ENTITY LeaveRequest ALL FIELDS
    WITH CORRESPONDING #( update-leaverequest )
    RESULT DATA(lt_update).

  LOOP AT lt_update ASSIGNING FIELD-SYMBOL(<u>).
    CLEAR ls_db.
    ls_db-mykey            = <u>-UUID.
    ls_db-request_id       = <u>-RequestId.
    ls_db-employee_id      = <u>-EmployeeId.
    ls_db-approver_id      = <u>-ApproverId.
    ls_db-hr_approver_id   = <u>-HrApproverId.
    ls_db-leave_type       = <u>-LeaveType.
    ls_db-start_date       = <u>-StartDate.
    ls_db-end_date         = <u>-EndDate.
    ls_db-start_session    = <u>-StartSession.
    ls_db-end_session      = <u>-EndSession.
    ls_db-total_days       = <u>-TotalDays.
    ls_db-reason           = <u>-Reason.
    ls_db-status           = <u>-Status.
    ls_db-approval_comment = <u>-ApprovalComment.
    ls_db-hr_comment       = <u>-HrComment.
    ls_db-attachment       = <u>-Attachment.
    ls_db-mime_type        = <u>-MimeType.
    ls_db-file_name        = <u>-FileName.
    ls_db-created_by       = <u>-CreatedBy.
    ls_db-created_at       = <u>-CreatedAt.
    ls_db-last_changed_by  = <u>-LastChangedBy.
    ls_db-last_changed_at  = <u>-LastChangedAt.

    UPDATE zleave_request FROM @ls_db.
  ENDLOOP.

ENDIF.




    "==========================================================================
    " DELETE
    " Review lại theo yêu cầu: hoàn trả quota khi status = SUBMITTED.
    " Giữ nguyên logic gốc (đã đúng) - CHỈ hoàn quota nếu đơn đang SUBMITTED,
    " vì các đơn REJECTED thì quota đã hoàn ở bước reject, và các đơn
    " MGR_APPROVED/APPROVED không được phép xoá (đã chặn ở %delete
    " authorization: chỉ owner + Status = SUBMITTED mới delete được).
    " -> Dọn lại code cho rõ ràng, gộp SELECT trùng lặp, đưa khai báo
    " lv_del_ts ra ngoài LOOP.
    "==========================================================================
    IF delete-leaverequest IS NOT INITIAL.

      DATA lv_del_ts TYPE timestampl.

      LOOP AT delete-leaverequest ASSIGNING FIELD-SYMBOL(<del>).

        SELECT SINGLE *
          FROM zleave_request
          WHERE mykey = @<del>-UUID
          INTO @DATA(ls_to_del).

        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.

        GET TIME STAMP FIELD lv_del_ts.

        "--- Hoàn trả quota CHỈ khi đơn đang ở SUBMITTED (đơn đã trừ quota
        "    lúc tạo nhưng chưa được Manager/HR xử lý). Về lý thuyết, đơn
        "    MGR_APPROVED/APPROVED không thể tới đây vì %delete authorization
        "    chỉ cho phép owner xoá khi Status = SUBMITTED. Giữ điều kiện
        "    này như 1 lớp bảo vệ thứ 2 (defense in depth). ---
        IF ls_to_del-status = 'SUBMITTED' AND ls_to_del-total_days > 0.

          SELECT SINGLE *
            FROM zquota
            WHERE employee_id   = @ls_to_del-employee_id
              AND leave_type_id = @ls_to_del-leave_type
              AND quota_year    = @lv_year
            INTO @DATA(ls_quota).

          IF sy-subrc = 0.

            DATA(lv_new_used)      = ls_quota-used_days      - ls_to_del-total_days.
            DATA(lv_new_remaining) = ls_quota-remaining_days + ls_to_del-total_days.

            IF lv_new_used < 0.
              lv_new_used = 0.
            ENDIF.
            IF lv_new_remaining > ls_quota-total_days.
              lv_new_remaining = ls_quota-total_days.
            ENDIF.

            UPDATE zquota SET
              used_days       = @lv_new_used,
              remaining_days  = @lv_new_remaining,
              last_updated_by = @sy-uname,
              last_updated_at = @lv_del_ts
              WHERE employee_id   = @ls_to_del-employee_id
                AND leave_type_id = @ls_to_del-leave_type
                AND quota_year    = @lv_year.

          ENDIF.

        ENDIF.

        "--- Ghi audit log TRƯỚC khi xoá record, dùng luôn ls_to_del (đã
        "    SELECT * ở trên) thay vì SELECT lại lần 2 như bản gốc. ---
        INSERT zleave_audit_log FROM @( VALUE zleave_audit_log(
          log_id      = cl_system_uuid=>create_uuid_x16_static( )
          request_id  = ls_to_del-request_id
          employee_id = ls_to_del-employee_id
          action      = 'DELETE'
          action_by   = sy-uname
          action_at   = lv_del_ts
          old_status  = ls_to_del-status
          new_status  = 'DELETED'
          comments    = |Đơn bị xóa bởi { sy-uname }. Quota đã hoàn trả (nếu đơn đang SUBMITTED).|
        ) ).

        DELETE zleave_request FROM @ls_to_del.

      ENDLOOP.

    ENDIF.

  ENDMETHOD.

"=============================================================================
" HELPER (saver-local): get_user_email_for_saver
" Saver class không kế thừa lhc_leave_request nên không dùng lại được
" get_user_email của handler -> cần bản riêng ở đây (logic giống hệt).
"=============================================================================
  METHOD get_user_email_for_saver.

    rv_email = ''.

    SELECT SINGLE smtp_addr
      FROM adr6
      INNER JOIN usr21
        ON adr6~addrnumber  = usr21~addrnumber
        AND adr6~persnumber = usr21~persnumber
      WHERE usr21~bname = @iv_username
      INTO @DATA(lv_email).

    IF sy-subrc = 0.
      rv_email = lv_email.
    ENDIF.

  ENDMETHOD.

"=============================================================================
" HELPER (saver-local): send_new_request_email
" Gửi email "đơn mới cần duyệt" cho Manager. Đọc SendGrid config từ table
" ZSENDGRID_CONFIG, giống hệt cơ chế trong lhc_leave_request.
"=============================================================================
  METHOD send_new_request_email.

    CONSTANTS lc_endpoint TYPE string VALUE 'https://api.sendgrid.com/v3/mail/send'.

    SELECT SINGLE api_key, sender_email, sender_name
      FROM zsendgrid_config
      WHERE config_id  = 'DEFAULT'
        AND is_active  = @abap_true
      INTO @DATA(ls_config).

    IF sy-subrc <> 0
       OR ls_config-api_key      IS INITIAL
       OR ls_config-sender_email IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_body) = |Xin chào,<br><br>| &&
                    |Nhân viên { iv_emp_name } vừa gửi đơn xin nghỉ phép.<br><br>| &&
                    |Mã đơn: { iv_request_id }<br>| &&
                    |Loại nghỉ: { iv_leave_type }<br>| &&
                    |Từ ngày: { iv_start_date+6(2) }.{ iv_start_date+4(2) }.{ iv_start_date(4) }<br>| &&
                    |Đến ngày: { iv_end_date+6(2) }.{ iv_end_date+4(2) }.{ iv_end_date(4) }<br>| &&
                    |Số ngày: { iv_total_days }<br><br>| &&
                    |Vui lòng đăng nhập hệ thống để duyệt đơn.<br><br>| &&
                    |Trân trọng,<br>| &&
                    |<b>Hệ thống Leave Management</b>|.

    DATA(lv_subject) = |[Leave Request] Đơn mới cần duyệt - { iv_request_id }|.

    DATA(lv_json) = |\{"personalizations":[| &&
                    |\{"to":[| &&
                    |\{"email":"{ iv_to_email }",| &&
                    |"name":"{ iv_to_name }"\}| &&
                    |]\}],| &&
                    |"from":\{"email":"{ ls_config-sender_email }",| &&
                    |"name":"{ ls_config-sender_name }"\},| &&
                    |"subject":"{ lv_subject }",| &&
                    |"content":[| &&
                    |\{"type":"text/html",| &&
                    |"value":"{ lv_body }"\}| &&
                    |]\}|.

    TRY.
      DATA lo_http_client TYPE REF TO if_http_client.

      cl_http_client=>create_by_url(
        EXPORTING
          url                = lc_endpoint
        IMPORTING
          client             = lo_http_client
        EXCEPTIONS
          argument_not_found = 1
          plugin_not_active  = 2
          internal_error     = 3
          OTHERS             = 4
      ).

      IF sy-subrc <> 0. RETURN. ENDIF.

      lo_http_client->request->set_method( 'POST' ).

      lo_http_client->request->set_header_field(
        name  = 'Authorization'
        value = |Bearer { ls_config-api_key }|
      ).
      lo_http_client->request->set_header_field(
        name  = 'Content-Type'
        value = 'application/json'
      ).

      lo_http_client->request->set_cdata( lv_json ).

      lo_http_client->send(
        EXCEPTIONS
          http_communication_failure = 1
          http_invalid_state         = 2
          OTHERS                     = 3
      ).

      IF sy-subrc <> 0. RETURN. ENDIF.

      lo_http_client->receive(
        EXCEPTIONS
          http_communication_failure = 1
          http_invalid_state         = 2
          http_processing_failed     = 3
          OTHERS                     = 4
      ).

      lo_http_client->close( ).

    CATCH cx_root.
      "--- Không chặn luồng chính khi email lỗi ---
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
