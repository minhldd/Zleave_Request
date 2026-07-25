
"##############################################################################
"# UNIT TEST cho ZBP_I_LEAVE_REQUEST
"# Paste toàn bộ nội dung này vào tab "Test Classes" của behavior
"# implementation class ZBP_I_LEAVE_REQUEST trong ADT (Eclipse).
"##############################################################################


CLASS ltc_leave_request DEFINITION FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT
  FINAL.

  PRIVATE SECTION.

    CONSTANTS:
      "--- Dữ liệu test cố định, dùng chung cho toàn bộ class ---
      c_emp_id       TYPE zleave_request-employee_id   VALUE '0000000001',
      c_hr_emp_id    TYPE zleave_request-employee_id   VALUE '0000000002',
      c_leave_type   TYPE zleave_type-leave_type_id VALUE 'AL',
      c_year         TYPE zquota-quota_year        VALUE '2026'.

    CLASS-DATA:
      "--- CDS Test Double Framework: double cho entity ZI_LEAVE_REQUEST ---
      environment TYPE REF TO if_cds_test_environment,
      "--- OSQL Test Double Framework: double cho các bảng DB thường ---
      sql_environment TYPE REF TO if_osql_test_environment.

    DATA:
      cut TYPE REF TO lhc_leave_request. "class under test (chỉ dùng cho helper thuần)

    CLASS-METHODS:
      class_setup,
      class_teardown.

    METHODS:
      setup,

      "--- Test cho helper thuần calculate_total_days ---
      full_day_multi_days       FOR TESTING,
      half_day_same_day         FOR TESTING,
      half_day_start_afternoon  FOR TESTING,
      half_day_end_morning      FOR TESTING,
      invalid_end_before_start  FOR TESTING,

      "--- Test cho validateDates ---
      dates_end_before_start    FOR TESTING,
      dates_before_current_mth  FOR TESTING,
      dates_valid_ok            FOR TESTING,

      "--- Test cho validateSession ---
      session_full_day_ok       FOR TESTING,
      session_missing_start     FOR TESTING,
      session_missing_end       FOR TESTING,

      "--- Test cho validateLeaveTypeActive ---
      leavetype_active_ok       FOR TESTING,
      leavetype_inactive_fails   FOR TESTING,

      "--- Test cho validateLeaveQuota ---
      quota_sufficient_ok        FOR TESTING,
      quota_exceeded_fails        FOR TESTING,

      "--- Test cho validateOverlap ---
      overlap_detected_fails      FOR TESTING,
      overlap_none_ok              FOR TESTING,

      "--- Test cho determination determineEmployeeAndManager ---
      determ_sets_submitted_status FOR TESTING,
      determ_deducts_quota         FOR TESTING,
      determ_insufficient_quota    FOR TESTING,

      "--- Test cho action approveResult ---
      approve_changes_status        FOR TESTING,
      approve_sets_hr_approver      FOR TESTING,

      "--- Test cho action rejectResult ---
      reject_changes_status          FOR TESTING,
      reject_refunds_quota            FOR TESTING,

      "--- Test cho action hrApproveResult ---
      hr_approve_changes_status       FOR TESTING,

      "--- Test cho action hrRejectResult ---
      hr_reject_refunds_quota          FOR TESTING,

      "--- Test cho saver class lsc_leave_request (save_modified) ---
      save_modified_inserts_record      FOR TESTING,
      save_modified_writes_audit_log    FOR TESTING,

      "--- Helper để tạo 1 record leave request đầy đủ trong double ---
      insert_leave_request
        IMPORTING
          iv_uuid       TYPE sysuuid_x16
          iv_status     TYPE zleave_request-status
          iv_start_date TYPE dats
          iv_end_date   TYPE dats
          iv_emp_id     TYPE zleave_request-employee_id DEFAULT c_emp_id
          iv_leave_type TYPE zleave_request-leave_type  DEFAULT c_leave_type
          iv_total_days TYPE zleave_request-total_days  DEFAULT '1.00'.

ENDCLASS.


CLASS ltc_leave_request IMPLEMENTATION.

  METHOD class_setup.

    "--- Double cho entity RAP: mọi READ/MODIFY/COMMIT ENTITIES nhắm vào
    "    ZI_LEAVE_REQUEST sẽ chạy trên buffer test double, không đụng DB thật ---
    environment = cl_cds_test_environment=>create(
                    i_for_entity = 'ZI_LEAVE_REQUEST' ).

    "--- Double cho các bảng DB thường mà code SELECT/UPDATE trực tiếp.
    "    LƯU Ý: KHÔNG đưa ZLEAVE_REQUEST vào đây — bảng này là nguồn dữ liệu
    "    của CDS view ZI_LEAVE_REQUEST nên đã được cl_cds_test_environment
    "    (biến "environment") tự động double rồi. Double 2 lần cùng 1 bảng
    "    qua 2 framework khác nhau sẽ gây xung đột buffer / dữ liệu không
    "    nhất quán giữa READ ENTITIES và SELECT thường. ---
    sql_environment = cl_osql_test_environment=>create(
                        VALUE #(
                          ( 'ZQUOTA' )
                          ( 'ZEMPLOYEE_TABLE' )
                          ( 'ZLEAVE_TYPE' )
                          ( 'ZSENDGRID_CONFIG' )
                          ( 'ZLEAVE_AUDIT_LOG' )
                          ( 'AGR_USERS' )
                        ) ).

  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.

    "--- Xoá sạch dữ liệu test double trước mỗi test case, đảm bảo test
    "    độc lập với nhau (không phụ thuộc thứ tự chạy) ---
    environment->clear_doubles( ).
    sql_environment->clear_doubles( ).


    "--- Chuẩn bị dữ liệu nền dùng chung: employee, leave type active,
    "    quota còn hạn mức, config SendGrid KHÔNG active (để không bao giờ
    "    gọi HTTP thật ra ngoài trong lúc test) ---
    DATA(lv_current_user) = cl_abap_context_info=>get_user_technical_name( ).

    INSERT zemployee_table FROM TABLE @( VALUE #(
      ( client = sy-mandt emp_id = c_emp_id    sap_user = lv_current_user
        full_name = 'Nguyen Van Test' is_active = abap_true
        is_manager = '' is_hr = '' is_admin = '' )
      ( client = sy-mandt emp_id = c_hr_emp_id sap_user = lv_current_user
        full_name = 'HR Test User'    is_active = abap_true
        is_manager = '' is_hr = 'X' is_admin = '' )
    ) ).

    INSERT zleave_type FROM TABLE @( VALUE #(
      ( client = sy-mandt leave_type_id = c_leave_type
        leave_type_name = 'Annual Leave' max_day = '12.00'
        is_paid = abap_true requires_approval = abap_true
        is_active = abap_true )
      ( client = sy-mandt leave_type_id = 'INA'
        leave_type_name = 'Inactive Type' max_day = '5.00'
        is_paid = abap_true requires_approval = abap_true
        is_active = abap_false )
    ) ).

    INSERT zquota FROM TABLE @( VALUE #(
      ( client = sy-mandt employee_id = c_emp_id leave_type_id = c_leave_type
        quota_year = c_year total_days = '12.00'
        used_days = '2.00' remaining_days = '10.00' )
    ) ).

    "--- KHÔNG insert record ZSENDGRID_CONFIG nào -> send_email_sendgrid( )
    "    sẽ luôn RETURN sớm trước khi gọi HTTP thật ---

  ENDMETHOD.

  METHOD insert_leave_request.

    "--- ZLEAVE_REQUEST là bảng nguồn của CDS view ZI_LEAVE_REQUEST, nên
    "    phải nạp dữ liệu test qua CDS Test Double Framework (environment),
    "    KHÔNG dùng INSERT/OSQL thường - nếu không, READ ENTITIES/MODIFY
    "    ENTITIES (chạy trên buffer CDS double) sẽ không thấy được dữ liệu
    "    này, vì nó nằm ở 1 buffer OSQL khác. ---
    DATA lt_data TYPE STANDARD TABLE OF zleave_request WITH EMPTY KEY.

    lt_data = VALUE #( (
      client       = sy-mandt
      mykey        = iv_uuid
      request_id   = |LR-{ iv_uuid }|
      employee_id  = iv_emp_id
      leave_type   = iv_leave_type
      start_date   = iv_start_date
      end_date     = iv_end_date
      total_days   = iv_total_days
      status       = iv_status
      created_by   = cl_abap_context_info=>get_user_technical_name( )
    ) ).

    environment->insert_test_data( i_data = lt_data ).

  ENDMETHOD.

"=============================================================================
" HELPER PURE FUNCTION: calculate_total_days
"=============================================================================

  METHOD full_day_multi_days.
    "--- Không chọn Session -> Full Day, 3 ngày liên tục ---
    DATA(lv_result) = cut->calculate_total_days(
                         iv_start_date    = '20260701'
                         iv_end_date      = '20260703'
                         iv_start_session = ''
                         iv_end_session   = '' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_result
      exp = CONV decfloat16( '3' )
      msg = 'Full day 3 ngày liên tục phải trả về 3' ).
  ENDMETHOD.

  METHOD half_day_same_day.
    "--- Cùng 1 ngày, có chọn Session -> luôn là 0.5 ---
    DATA(lv_result) = cut->calculate_total_days(
                         iv_start_date    = '20260701'
                         iv_end_date      = '20260701'
                         iv_start_session = 'M'
                         iv_end_session   = '' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_result
      exp = CONV decfloat16( '0.5' )
      msg = 'Half day cùng 1 ngày phải trả về 0.5' ).
  ENDMETHOD.

  METHOD half_day_start_afternoon.
    "--- Nghỉ 2 ngày, ngày đầu nghỉ chiều -> trừ 0.5 ---
    DATA(lv_result) = cut->calculate_total_days(
                         iv_start_date    = '20260701'
                         iv_end_date      = '20260702'
                         iv_start_session = 'A'
                         iv_end_session   = '' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_result
      exp = CONV decfloat16( '1.5' )
      msg = 'Bắt đầu nghỉ chiều ngày đầu phải trừ 0.5 (2 - 0.5 = 1.5)' ).
  ENDMETHOD.

  METHOD half_day_end_morning.
    "--- Nghỉ 3 ngày, ngày cuối nghỉ sáng -> trừ 0.5 ---
    DATA(lv_result) = cut->calculate_total_days(
                         iv_start_date    = '20260701'
                         iv_end_date      = '20260703'
                         iv_start_session = ''
                         iv_end_session   = 'M' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_result
      exp = CONV decfloat16( '2.5' )
      msg = 'Kết thúc nghỉ sáng ngày cuối phải trừ 0.5 (3 - 0.5 = 2.5)' ).
  ENDMETHOD.

  METHOD invalid_end_before_start.
    "--- EndDate < StartDate -> method phải trả về 0 (guard bằng CHECK) ---
    DATA(lv_result) = cut->calculate_total_days(
                         iv_start_date    = '20260705'
                         iv_end_date      = '20260701'
                         iv_start_session = ''
                         iv_end_session   = '' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_result
      exp = CONV decfloat16( '0' )
      msg = 'EndDate < StartDate phải trả về 0 ngày' ).
  ENDMETHOD.

"=============================================================================
" VALIDATION: validateDates
"=============================================================================

  METHOD dates_end_before_start.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId )
        WITH VALUE #( (
          %cid       = 'C1'
          %key-UUID  = lv_uuid
          LeaveType  = c_leave_type
          StartDate  = |20260710|
          EndDate    = |20260705|
          ApproverId = cl_abap_context_info=>get_user_technical_name( )
        ) )
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    "--- validateDates (ON SAVE) chỉ thực sự chạy khi trigger toàn bộ save
    "    sequence qua COMMIT ENTITIES. FAILED/REPORTED ở đây phản ánh kết
    "    quả validate, không phải kết quả của MODIFY ENTITIES ở trên. ---
COMMIT ENTITIES
  RESPONSES
    FAILED   DATA(ls_check_failed)
    REPORTED DATA(ls_check_reported).
    "--- Dọn buffer RAP sau COMMIT để không rò rỉ sang test khác ---
    ROLLBACK ENTITIES.

cl_abap_unit_assert=>assert_not_initial(
  act = lines( ls_check_failed )
      msg = 'EndDate < StartDate phải bị validateDates chặn (failed)' ).

  ENDMETHOD.

  METHOD dates_before_current_mth.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    "--- Ngày tháng trước tháng hiện tại: luôn nhỏ hơn ngày 01 tháng này ---
    DATA(lv_last_month_date) = sy-datum.
    lv_last_month_date+6(2) = '01'.
    lv_last_month_date = lv_last_month_date - 1. "ngày cuối tháng trước

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId )
        WITH VALUE #( (
          %cid       = 'C1'
          %key-UUID  = lv_uuid
          LeaveType  = c_leave_type
          StartDate  = lv_last_month_date
          EndDate    = lv_last_month_date
          ApproverId = cl_abap_context_info=>get_user_technical_name( )
        ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES
      RESPONSES
      FAILED   DATA(ls_check_failed)
      REPORTED DATA(ls_check_reported).

    ROLLBACK ENTITIES.

    cl_abap_unit_assert=>assert_not_initial(
      act = ls_check_failed
      msg = 'StartDate ở tháng trước phải bị validateDates chặn' ).

  ENDMETHOD.

  METHOD dates_valid_ok.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
    DATA(lv_today) = sy-datum.

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId )
        WITH VALUE #( (
          %cid       = 'C1'
          %key-UUID  = lv_uuid
          LeaveType  = c_leave_type
          StartDate  = lv_today
          EndDate    = lv_today
          ApproverId = cl_abap_context_info=>get_user_technical_name( )
        ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES
      RESPONSES
      FAILED   DATA(ls_check_failed)
      REPORTED DATA(ls_check_reported).

    ROLLBACK ENTITIES.

    cl_abap_unit_assert=>assert_initial(
      act = ls_check_failed
      msg = 'Ngày hợp lệ (hôm nay) không được bị validateDates chặn' ).

  ENDMETHOD.

"=============================================================================
" VALIDATION: validateSession
"=============================================================================

  METHOD session_full_day_ok.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId StartSession EndSession )
        WITH VALUE #( (
          %cid         = 'C1'
          %key-UUID    = lv_uuid
          LeaveType    = c_leave_type
          StartDate    = sy-datum
          EndDate      = sy-datum
          ApproverId   = cl_abap_context_info=>get_user_technical_name( )
          StartSession = ''
          EndSession   = ''
        ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES
      RESPONSES
      FAILED   DATA(ls_check_failed)
      REPORTED DATA(ls_check_reported).

    ROLLBACK ENTITIES.

    cl_abap_unit_assert=>assert_initial(
      act = ls_check_failed
      msg = 'Full day (không chọn Session) không được bị validateSession chặn' ).

  ENDMETHOD.

  METHOD session_missing_start.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId StartSession EndSession )
        WITH VALUE #( (
          %cid         = 'C1'
          %key-UUID    = lv_uuid
          LeaveType    = c_leave_type
          StartDate    = sy-datum
          EndDate      = sy-datum
          ApproverId   = cl_abap_context_info=>get_user_technical_name( )
          StartSession = ''
          EndSession   = 'M'
        ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES
      RESPONSES
      FAILED   DATA(ls_check_failed)
      REPORTED DATA(ls_check_reported).

    ROLLBACK ENTITIES.

    cl_abap_unit_assert=>assert_not_initial(
      act = ls_check_failed
      msg = 'Có EndSession nhưng thiếu StartSession phải bị chặn' ).

  ENDMETHOD.

  METHOD session_missing_end.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId StartSession EndSession )
        WITH VALUE #( (
          %cid         = 'C1'
          %key-UUID    = lv_uuid
          LeaveType    = c_leave_type
          StartDate    = sy-datum
          EndDate      = sy-datum + 1
          ApproverId   = cl_abap_context_info=>get_user_technical_name( )
          StartSession = 'A'
          EndSession   = ''
        ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES
      RESPONSES
      FAILED   DATA(ls_check_failed)
      REPORTED DATA(ls_check_reported).

    ROLLBACK ENTITIES.

    cl_abap_unit_assert=>assert_not_initial(
      act = ls_check_failed
      msg = 'Nghỉ nhiều ngày dạng Half Day nhưng thiếu EndSession phải bị chặn' ).

  ENDMETHOD.

"=============================================================================
" VALIDATION: validateLeaveTypeActive
"=============================================================================

  METHOD leavetype_active_ok.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId )
        WITH VALUE #( (
          %cid       = 'C1'
          %key-UUID  = lv_uuid
          LeaveType  = c_leave_type "AL - active
          StartDate  = sy-datum
          EndDate    = sy-datum
          ApproverId = cl_abap_context_info=>get_user_technical_name( )
        ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES
      RESPONSES
      FAILED   DATA(ls_check_failed)
      REPORTED DATA(ls_check_reported).

    ROLLBACK ENTITIES.

    cl_abap_unit_assert=>assert_initial(
      act = ls_check_failed
      msg = 'Leave type đang active không được bị chặn' ).

  ENDMETHOD.

  METHOD leavetype_inactive_fails.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId )
        WITH VALUE #( (
          %cid       = 'C1'
          %key-UUID  = lv_uuid
          LeaveType  = 'INA' "inactive
          StartDate  = sy-datum
          EndDate    = sy-datum
          ApproverId = cl_abap_context_info=>get_user_technical_name( )
        ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES
      RESPONSES
      FAILED   DATA(ls_check_failed)
      REPORTED DATA(ls_check_reported).

    ROLLBACK ENTITIES.

    cl_abap_unit_assert=>assert_not_initial(
      act = ls_check_failed
      msg = 'Leave type inactive phải bị validateLeaveTypeActive chặn' ).

  ENDMETHOD.

"=============================================================================
" VALIDATION: validateLeaveQuota
" Lưu ý: TotalDays được tính bởi determination (chạy TRƯỚC validate),
" nên chỉ cần CREATE với ngày hợp lệ, quota validate sẽ tự nhìn thấy
" TotalDays đã được xử lý.
"=============================================================================

  METHOD quota_sufficient_ok.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    "--- 1 ngày full day, quota còn 10 ngày -> đủ ---
    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId )
        WITH VALUE #( (
          %cid       = 'C1'
          %key-UUID  = lv_uuid
          LeaveType  = c_leave_type
          StartDate  = sy-datum
          EndDate    = sy-datum
          ApproverId = cl_abap_context_info=>get_user_technical_name( )
        ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES
      RESPONSES
      FAILED   DATA(ls_check_failed)
      REPORTED DATA(ls_check_reported).

    ROLLBACK ENTITIES.

    cl_abap_unit_assert=>assert_initial(
      act = ls_check_failed
      msg = 'Quota còn đủ (10 ngày) không được bị validateLeaveQuota chặn' ).

  ENDMETHOD.

  METHOD quota_exceeded_fails.

    "--- Đặt lại quota chỉ còn 0 ngày để chắc chắn vượt hạn mức ---
    UPDATE zquota SET remaining_days = '0.00'
      WHERE employee_id   = @c_emp_id
        AND leave_type_id = @c_leave_type
        AND quota_year    = @c_year.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId )
        WITH VALUE #( (
          %cid       = 'C1'
          %key-UUID  = lv_uuid
          LeaveType  = c_leave_type
          StartDate  = sy-datum
          EndDate    = sy-datum
          ApproverId = cl_abap_context_info=>get_user_technical_name( )
        ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES
      RESPONSES
      FAILED   DATA(ls_check_failed)
      REPORTED DATA(ls_check_reported).

    ROLLBACK ENTITIES.

    cl_abap_unit_assert=>assert_not_initial(
      act = ls_check_failed
      msg = 'Quota = 0 nhưng vẫn xin nghỉ 1 ngày phải bị validateLeaveQuota chặn' ).

  ENDMETHOD.

"=============================================================================
" VALIDATION: validateOverlap
"=============================================================================

  METHOD overlap_detected_fails.

    "--- Tạo sẵn 1 đơn SUBMITTED trong DB double, chiếm ngày 10-15/07/2026 ---
    DATA(lv_existing_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
    insert_leave_request(
      iv_uuid       = lv_existing_uuid
      iv_status     = 'SUBMITTED'
      iv_start_date = '20260710'
      iv_end_date   = '20260715' ).

    "--- Tạo đơn mới trùng ngày (12-13/07/2026) cho cùng nhân viên ---
    DATA(lv_new_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId )
        WITH VALUE #( (
          %cid       = 'C2'
          %key-UUID  = lv_new_uuid
          LeaveType  = c_leave_type
          StartDate  = '20260712'
          EndDate    = '20260713'
          ApproverId = cl_abap_context_info=>get_user_technical_name( )
        ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES
      RESPONSES
      FAILED   DATA(ls_check_failed)
      REPORTED DATA(ls_check_reported).

    ROLLBACK ENTITIES.

    cl_abap_unit_assert=>assert_not_initial(
      act = ls_check_failed
      msg = 'Ngày trùng với đơn SUBMITTED khác phải bị validateOverlap chặn' ).

  ENDMETHOD.

  METHOD overlap_none_ok.

    "--- Đơn cũ đã REJECTED -> không tính overlap dù trùng ngày ---
    DATA(lv_existing_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
    insert_leave_request(
      iv_uuid       = lv_existing_uuid
      iv_status     = 'REJECTED'
      iv_start_date = '20260710'
      iv_end_date   = '20260715' ).

    DATA(lv_new_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId )
        WITH VALUE #( (
          %cid       = 'C2'
          %key-UUID  = lv_new_uuid
          LeaveType  = c_leave_type
          StartDate  = '20260712'
          EndDate    = '20260713'
          ApproverId = cl_abap_context_info=>get_user_technical_name( )
        ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES
      RESPONSES
      FAILED   DATA(ls_check_failed)
      REPORTED DATA(ls_check_reported).

    ROLLBACK ENTITIES.

    cl_abap_unit_assert=>assert_initial(
      act = ls_check_failed
      msg = 'Trùng ngày với đơn đã REJECTED không được bị validateOverlap chặn' ).

  ENDMETHOD.

"=============================================================================
" DETERMINATION: determineEmployeeAndManager
" Lưu ý quan trọng: user chạy test KHÔNG có role Manager/Admin trong
" AGR_USERS double (double rỗng theo mặc định) -> luôn đi nhánh Employee
" thường => Status phải là 'SUBMITTED', không phải 'MGR_APPROVED'.
"=============================================================================

  METHOD determ_sets_submitted_status.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId )
        WITH VALUE #( (
          %cid       = 'C1'
          %key-UUID  = lv_uuid
          LeaveType  = c_leave_type
          StartDate  = sy-datum
          EndDate    = sy-datum
          ApproverId = cl_abap_context_info=>get_user_technical_name( )
        ) )
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    "--- Determination chạy ON MODIFY -> đã áp dụng ngay sau MODIFY ENTITIES,
    "    không cần check_before_save. Đọc lại field Status/RequestId/EmployeeId ---
    READ ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        FIELDS ( Status RequestId EmployeeId TotalDays )
        WITH VALUE #( ( %key-UUID = lv_uuid ) )
      RESULT DATA(lt_result).

    cl_abap_unit_assert=>assert_equals(
      act = lt_result[ 1 ]-Status
      exp = 'SUBMITTED'
      msg = 'Employee thường tạo đơn phải có Status = SUBMITTED' ).

    cl_abap_unit_assert=>assert_not_initial(
      act = lt_result[ 1 ]-RequestId
      msg = 'RequestId phải được sinh tự động (number range)' ).

    cl_abap_unit_assert=>assert_equals(
      act = lt_result[ 1 ]-EmployeeId
      exp = c_emp_id
      msg = 'EmployeeId phải được xác định từ ZEMPLOYEE_TABLE theo user hiện tại' ).

  ENDMETHOD.

  METHOD determ_deducts_quota.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    "--- Quota ban đầu: remaining_days = 10.00 (setup ở method setup) ---
    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId )
        WITH VALUE #( (
          %cid       = 'C1'
          %key-UUID  = lv_uuid
          LeaveType  = c_leave_type
          StartDate  = sy-datum
          EndDate    = sy-datum + 1  "2 ngày full day
          ApproverId = cl_abap_context_info=>get_user_technical_name( )
        ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    SELECT SINGLE remaining_days, used_days
      FROM zquota
      WHERE employee_id   = @c_emp_id
        AND leave_type_id = @c_leave_type
        AND quota_year    = @c_year
      INTO @DATA(ls_quota_after).

    cl_abap_unit_assert=>assert_equals(
      act = ls_quota_after-remaining_days
      exp = CONV zquota-remaining_days( '8.00' )
      msg = 'Quota còn lại phải giảm 2 ngày ngay khi tạo đơn (10 - 2 = 8)' ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_quota_after-used_days
      exp = CONV zquota-used_days( '4.00' )
      msg = 'Used days phải tăng thêm 2 ngày (2 ban đầu + 2 = 4)' ).

  ENDMETHOD.

  METHOD determ_insufficient_quota.

    "--- Đặt quota còn 0.5 ngày, xin nghỉ 2 ngày -> phải bị từ chối ---
    UPDATE zquota SET remaining_days = '0.5'
      WHERE employee_id   = @c_emp_id
        AND leave_type_id = @c_leave_type
        AND quota_year    = @c_year.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId )
        WITH VALUE #( (
          %cid       = 'C1'
          %key-UUID  = lv_uuid
          LeaveType  = c_leave_type
          StartDate  = sy-datum
          EndDate    = sy-datum + 1
          ApproverId = cl_abap_context_info=>get_user_technical_name( )
        ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    cl_abap_unit_assert=>assert_not_initial(
      act = ls_reported-leaverequest
      msg = 'Thiếu quota phải sinh ra message lỗi trong reported ngay tại determination' ).

    "--- Quota KHÔNG được trừ khi không đủ ---
    SELECT SINGLE remaining_days
      FROM zquota
      WHERE employee_id   = @c_emp_id
        AND leave_type_id = @c_leave_type
        AND quota_year    = @c_year
      INTO @DATA(lv_remaining_after).

    cl_abap_unit_assert=>assert_equals(
      act = lv_remaining_after
      exp = CONV zquota-remaining_days( '0.5' )
      msg = 'Quota không được trừ khi số ngày xin nghỉ vượt quá hạn mức còn lại' ).

  ENDMETHOD.

"=============================================================================
" ACTION: approveResult (Manager duyệt cấp 1)
"=============================================================================

  METHOD approve_changes_status.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
    insert_leave_request(
      iv_uuid       = lv_uuid
      iv_status     = 'SUBMITTED'
      iv_start_date = sy-datum
      iv_end_date   = sy-datum ).

    "--- Đồng bộ dữ liệu vào double CDS entity qua READ (framework tự nạp
    "    từ bảng DB double zleave_request nhờ mapping trong BDEF) ---
    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        EXECUTE approveResult
        FROM VALUE #( ( %key-UUID = lv_uuid %param-ApprovalComment = 'OK duyệt' ) )
      RESULT DATA(lt_result)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    cl_abap_unit_assert=>assert_initial(
      act = ls_failed-leaverequest
      msg = 'approveResult trên đơn SUBMITTED không được thất bại' ).

    READ ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        FIELDS ( Status ApprovalComment )
        WITH VALUE #( ( %key-UUID = lv_uuid ) )
      RESULT DATA(lt_check).

    cl_abap_unit_assert=>assert_equals(
      act = lt_check[ 1 ]-Status
      exp = 'MGR_APPROVED'
      msg = 'Sau approveResult, Status phải chuyển thành MGR_APPROVED' ).

    cl_abap_unit_assert=>assert_equals(
      act = lt_check[ 1 ]-ApprovalComment
      exp = 'OK duyệt'
      msg = 'ApprovalComment phải được lưu lại từ action parameter' ).

  ENDMETHOD.

  METHOD approve_sets_hr_approver.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
    insert_leave_request(
      iv_uuid       = lv_uuid
      iv_status     = 'SUBMITTED'
      iv_start_date = sy-datum
      iv_end_date   = sy-datum ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        EXECUTE approveResult
        FROM VALUE #( ( %key-UUID = lv_uuid %param-ApprovalComment = '' ) )
      RESULT DATA(lt_result)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    READ ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        FIELDS ( HrApproverId )
        WITH VALUE #( ( %key-UUID = lv_uuid ) )
      RESULT DATA(lt_check).

    cl_abap_unit_assert=>assert_not_initial(
      act = lt_check[ 1 ]-HrApproverId
      msg = 'HrApproverId phải được tự động gán từ ZEMPLOYEE_TABLE (is_hr = X)' ).

  ENDMETHOD.

"=============================================================================
" ACTION: rejectResult (Manager từ chối)
"=============================================================================

  METHOD reject_changes_status.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
    insert_leave_request(
      iv_uuid       = lv_uuid
      iv_status     = 'SUBMITTED'
      iv_start_date = sy-datum
      iv_end_date   = sy-datum
      iv_total_days = '1.00' ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        EXECUTE rejectResult
        FROM VALUE #( ( %key-UUID = lv_uuid %param-ApprovalComment = 'Không đủ nhân sự' ) )
      RESULT DATA(lt_result)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    READ ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        FIELDS ( Status ApprovalComment )
        WITH VALUE #( ( %key-UUID = lv_uuid ) )
      RESULT DATA(lt_check).

    cl_abap_unit_assert=>assert_equals(
      act = lt_check[ 1 ]-Status
      exp = 'REJECTED'
      msg = 'Sau rejectResult, Status phải chuyển thành REJECTED' ).

    cl_abap_unit_assert=>assert_equals(
      act = lt_check[ 1 ]-ApprovalComment
      exp = 'Không đủ nhân sự'
      msg = 'ApprovalComment phải được lưu lại từ action parameter' ).

  ENDMETHOD.

  METHOD reject_refunds_quota.

    "--- Quota ban đầu (từ setup): total=12, used=2, remaining=10 ---
    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
DATA lv_end_date TYPE dats.
lv_end_date = sy-datum + 1.

insert_leave_request(
  iv_uuid       = lv_uuid
  iv_status     = 'SUBMITTED'
  iv_start_date = sy-datum
  iv_end_date   = lv_end_date
  iv_total_days = '2.00' ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        EXECUTE rejectResult
        FROM VALUE #( ( %key-UUID = lv_uuid %param-ApprovalComment = 'Từ chối' ) )
      RESULT DATA(lt_result)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    SELECT SINGLE remaining_days, used_days
      FROM zquota
      WHERE employee_id   = @c_emp_id
        AND leave_type_id = @c_leave_type
        AND quota_year    = @c_year
      INTO @DATA(ls_quota_after).

    cl_abap_unit_assert=>assert_equals(
      act = ls_quota_after-remaining_days
      exp = CONV zquota-remaining_days( '12.00' )
      msg = 'Reject phải hoàn trả 2 ngày quota (10 + 2 = 12)' ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_quota_after-used_days
      exp = CONV zquota-used_days( '0.00' )
      msg = 'Used days phải giảm 2 ngày (2 - 2 = 0)' ).

  ENDMETHOD.

"=============================================================================
" ACTION: hrApproveResult (HR duyệt cấp 2)
"=============================================================================

  METHOD hr_approve_changes_status.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
    insert_leave_request(
      iv_uuid       = lv_uuid
      iv_status     = 'MGR_APPROVED'
      iv_start_date = sy-datum
      iv_end_date   = sy-datum ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        EXECUTE hrApproveResult
        FROM VALUE #( ( %key-UUID = lv_uuid %param-ApprovalComment = 'HR xác nhận' ) )
      RESULT DATA(lt_result)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    cl_abap_unit_assert=>assert_initial(
      act = ls_failed-leaverequest
      msg = 'hrApproveResult trên đơn MGR_APPROVED không được thất bại' ).

    READ ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        FIELDS ( Status HrComment )
        WITH VALUE #( ( %key-UUID = lv_uuid ) )
      RESULT DATA(lt_check).

    cl_abap_unit_assert=>assert_equals(
      act = lt_check[ 1 ]-Status
      exp = 'APPROVED'
      msg = 'Sau hrApproveResult, Status phải chuyển thành APPROVED' ).

    cl_abap_unit_assert=>assert_equals(
      act = lt_check[ 1 ]-HrComment
      exp = 'HR xác nhận'
      msg = 'HrComment phải được lưu lại từ action parameter' ).

  ENDMETHOD.

"=============================================================================
" ACTION: hrRejectResult (HR từ chối cấp 2)
"=============================================================================

  METHOD hr_reject_refunds_quota.

    "--- Quota ban đầu (từ setup): total=12, used=2, remaining=10 ---
    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
    insert_leave_request(
      iv_uuid       = lv_uuid
      iv_status     = 'MGR_APPROVED'
      iv_start_date = sy-datum
      iv_end_date   = sy-datum
      iv_total_days = '1.00' ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        EXECUTE hrRejectResult
        FROM VALUE #( ( %key-UUID = lv_uuid %param-ApprovalComment = 'HR từ chối' ) )
      RESULT DATA(lt_result)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    READ ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        FIELDS ( Status )
        WITH VALUE #( ( %key-UUID = lv_uuid ) )
      RESULT DATA(lt_check).

    cl_abap_unit_assert=>assert_equals(
      act = lt_check[ 1 ]-Status
      exp = 'REJECTED'
      msg = 'Sau hrRejectResult, Status phải chuyển thành REJECTED' ).

    SELECT SINGLE remaining_days
      FROM zquota
      WHERE employee_id   = @c_emp_id
        AND leave_type_id = @c_leave_type
        AND quota_year    = @c_year
      INTO @DATA(lv_remaining_after).

    cl_abap_unit_assert=>assert_equals(
      act = lv_remaining_after
      exp = CONV zquota-remaining_days( '11.00' )
      msg = 'HR reject phải hoàn trả 1 ngày quota (10 + 1 = 11)' ).

  ENDMETHOD.

"=============================================================================
" SAVER CLASS: lsc_leave_request -> save_modified
" save_modified CHỈ chạy khi có COMMIT ENTITIES (mô phỏng đúng RAP save
" sequence thật). Vì bảng ZLEAVE_REQUEST và ZLEAVE_AUDIT_LOG đều nằm dưới
" CDS test double / OSQL test double, các câu lệnh INSERT/UPDATE thường mà
" save_modified thực thi (unmanaged save) sẽ tự động được route vào đúng
" buffer double tương ứng, không đụng DB thật.
"=============================================================================

  METHOD save_modified_inserts_record.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId )
        WITH VALUE #( (
          %cid       = 'C1'
          %key-UUID  = lv_uuid
          LeaveType  = c_leave_type
          StartDate  = sy-datum
          EndDate    = sy-datum
          ApproverId = cl_abap_context_info=>get_user_technical_name( )
        ) )
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    cl_abap_unit_assert=>assert_initial(
      act = ls_failed-leaverequest
      msg = 'CREATE với dữ liệu hợp lệ không được thất bại trước khi save' ).

    "--- Trigger toàn bộ save sequence: validate ON SAVE -> save_modified.
    "    Nếu bất kỳ validate nào chặn, COMMIT sẽ trả về failed tương ứng. ---
    COMMIT ENTITIES
      RESPONSES
      FAILED   DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

    cl_abap_unit_assert=>assert_initial(
      act = ls_failed-leaverequest
      msg = 'COMMIT ENTITIES không được thất bại với dữ liệu hợp lệ' ).

    "--- Sau COMMIT, save_modified phải đã INSERT record vào bảng
    "    zleave_request (double) -> SELECT lại phải tìm thấy ---
    SELECT SINGLE mykey, status, employee_id
      FROM zleave_request
      WHERE mykey = @lv_uuid
      INTO @DATA(ls_saved).

    cl_abap_unit_assert=>assert_not_initial(
      act = ls_saved-mykey
      msg = 'save_modified phải INSERT record vào ZLEAVE_REQUEST sau COMMIT ENTITIES' ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_saved-status
      exp = 'SUBMITTED'
      msg = 'Record đã lưu phải có Status = SUBMITTED' ).

  ENDMETHOD.

  METHOD save_modified_writes_audit_log.

    DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

    MODIFY ENTITIES OF zi_leave_request IN LOCAL MODE
      ENTITY LeaveRequest
        CREATE FIELDS ( LeaveType StartDate EndDate ApproverId )
        WITH VALUE #( (
          %cid       = 'C1'
          %key-UUID  = lv_uuid
          LeaveType  = c_leave_type
          StartDate  = sy-datum
          EndDate    = sy-datum
          ApproverId = cl_abap_context_info=>get_user_technical_name( )
        ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES
      RESPONSES
      FAILED   DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

    "--- save_modified phải ghi 1 dòng audit log action = 'CREATE' cho
    "    RequestId tương ứng ---
    SELECT request_id, action, new_status, action_at
      FROM zleave_audit_log
      WHERE action = 'CREATE'
      ORDER BY action_at DESCENDING
      INTO TABLE @DATA(lt_audit).


    cl_abap_unit_assert=>assert_not_initial(
      act = lt_audit
      msg = 'save_modified phải ghi ít nhất 1 dòng ZLEAVE_AUDIT_LOG với action = CREATE' ).

    DATA(ls_audit) = lt_audit[ 1 ].

    cl_abap_unit_assert=>assert_equals(
      act = ls_audit-new_status
      exp = 'SUBMITTED'
      msg = 'Audit log phải ghi new_status = SUBMITTED' ).

  ENDMETHOD.

ENDCLASS.
