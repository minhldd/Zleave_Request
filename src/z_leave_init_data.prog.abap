*&---------------------------------------------------------------------*

*& Report  Z_LEAVE_INIT_DATA

*& Mục đích : Khởi tạo dữ liệu mẫu cho Leave Management

*& Chạy 1 lần trong SE38 / ADT, package $TMP

*& CẢNH BÁO : Xóa data cũ trước khi insert. Chỉ dùng DEV/QAS.

*&---------------------------------------------------------------------*

REPORT z_leave_init_data.



DATA: lv_timestamp TYPE timestampl,

      lv_count     TYPE i.



GET TIME STAMP FIELD lv_timestamp.



WRITE: / '========================================'.

WRITE: / 'Z_LEAVE_INIT_DATA - Bắt đầu'.

WRITE: / 'Run by:', sy-uname, '| Date:', sy-datum.

WRITE: / '========================================'.



"=============================================================================

" BƯỚC 1: ZLEAVE_TYPE

" FIX: Bỏ client khỏi WHERE và VALUE (ABAP tự xử lý client)

"      Field đúng: max_days_per_year (theo DDL đã activate)

"=============================================================================

WRITE: / ''.

WRITE: / '[1/3] ZLEAVE_TYPE...'.



DELETE FROM zleave_type.

lv_count = sy-dbcnt.

WRITE: / '  Đã xóa', lv_count, 'record cũ.'.



INSERT zleave_type FROM TABLE @( VALUE #(

  ( leave_type_id    = 'AL'

    leave_type_name  = 'Nghỉ phép năm'

    max_day = '12.00'

    requires_approval = abap_true

    is_active         = abap_true )



  ( leave_type_id    = 'SL'

    leave_type_name  = 'Nghỉ ốm'

    max_day = '30.00'

    requires_approval = abap_true

    is_active         = abap_true )



  ( leave_type_id    = 'UL'

    leave_type_name  = 'Nghỉ không lương'

    max_day = '99.00'

    requires_approval = abap_false

    is_active         = abap_true )



  ( leave_type_id    = 'ML'

    leave_type_name  = 'Nghỉ thai sản'

    max_day = '90.00'

    requires_approval = abap_true

    is_active         = abap_true )

) ).



IF sy-subrc = 0.

  WRITE: / '  Insert ZLEAVE_TYPE: OK (4 records).'.

ELSE.

  WRITE: / '  Insert ZLEAVE_TYPE: LỖI sy-subrc =', sy-subrc.

ENDIF.



"=============================================================================

" BƯỚC 2: ZEMPLOYEE_TABLE

" !! Sửa sap_user thành SAP username thật từ SU01 trước khi chạy !!

"=============================================================================

WRITE: / ''.

WRITE: / '[2/3] ZEMPLOYEE...'.



DELETE FROM zemployee_table.

lv_count = sy-dbcnt.

WRITE: / '  Đã xóa', lv_count, 'record cũ.'.



INSERT zemployee_table FROM TABLE @( VALUE #(

  ( emp_id    = '0000001001'

    sap_user       = sy-uname        "← user đang login (tự động)

    full_name      = 'Nguyen Van A'

    email          = 'a@company.com'

    department     = 'HR'

    position_title = 'Employee'

    manager_user   = 'LR_MGR'        "← sửa thành username Manager thật

    is_active      = abap_true

    created_by     = sy-uname

    created_at     = lv_timestamp )



  ( emp_id    = '0000001002'

    sap_user       = 'LR_EMP'        "← sửa thành SAP username thật

    full_name      = 'Tran Thi B'

    email          = 'b@company.com'

    department     = 'IT'

    position_title = 'Developer'

    manager_user   = 'LR_MGR'

    is_active      = abap_true

    created_by     = sy-uname

    created_at     = lv_timestamp )



  ( emp_id    = '0000001003'

    sap_user       = 'LR_MGR'        "← sửa thành SAP username thật

    full_name      = 'Le Van C'

    email          = 'c@company.com'

    department     = 'IT'

    position_title = 'Manager'

    manager_user   = 'LR_ADMIN'

    is_active      = abap_true

    is_manager      = abap_true

    created_by     = sy-uname

    created_at     = lv_timestamp )



  ( emp_id    = '0000001004'

    sap_user       = 'LR_ADMIN'      "← sửa thành SAP username thật

    full_name      = 'Pham Thi D'

    email          = 'd@company.com'

    department     = 'HR'

    position_title = 'HR Admin'

    manager_user   = ''

    is_active      = abap_true
    is_admin      = abap_true

    created_by     = sy-uname

    created_at     = lv_timestamp )





    ( emp_id    = '0000001005'

    sap_user       = 'LR_HR'        "← sửa thành SAP username thật

    full_name      = 'Tran Thi M'

    email          = 'b@company.com'

    department     = 'HR'

    position_title = 'Developer'

    is_active      = abap_true

    is_hr      = abap_true

    created_by     = sy-uname

    created_at     = lv_timestamp )

) ).



IF sy-subrc = 0.

  WRITE: / '  Insert ZEMPLOYEE: OK (4 records).'.

ELSE.

  WRITE: / '  Insert ZEMPLOYEE: LỖI sy-subrc =', sy-subrc.

ENDIF.



"=============================================================================

" BƯỚC 3: ZLEAVE_QUOTA

" LƯU Ý: Chỉ chạy được sau khi ZLEAVE_QUOTA đã active trong SE11/ADT

"=============================================================================

WRITE: / ''.

WRITE: / '[3/3] ZLEAVE_QUOTA (2026)...'.



DELETE FROM zquota WHERE quota_year = '2026'.

lv_count = sy-dbcnt.

WRITE: / '  Đã xóa', lv_count, 'record quota 2026 cũ.'.



INSERT zquota FROM TABLE @( VALUE #(

  ( employee_id = '0000001001'  leave_type_id = 'AL'  quota_year = '2026'

    total_days = '12.00'  used_days = '0.00'  remaining_days = '12.00'

    valid_from = '20260101'  valid_to = '20261231'

    last_updated_by = sy-uname  last_updated_at = lv_timestamp )



  ( employee_id = '0000001001'  leave_type_id = 'SL'  quota_year = '2026'

    total_days = '30.00'  used_days = '0.00'  remaining_days = '30.00'

    valid_from = '20260101'  valid_to = '20261231'

    last_updated_by = sy-uname  last_updated_at = lv_timestamp )



  ( employee_id = '0000001002'  leave_type_id = 'AL'  quota_year = '2026'

    total_days = '12.00'  used_days = '0.00'  remaining_days = '12.00'

    valid_from = '20260101'  valid_to = '20261231'

    last_updated_by = sy-uname  last_updated_at = lv_timestamp )



  ( employee_id = '0000001002'  leave_type_id = 'SL'  quota_year = '2026'

    total_days = '30.00'  used_days = '0.00'  remaining_days = '30.00'

    valid_from = '20260101'  valid_to = '20261231'

    last_updated_by = sy-uname  last_updated_at = lv_timestamp )



  ( employee_id = '0000001003'  leave_type_id = 'AL'  quota_year = '2026'

    total_days = '12.00'  used_days = '0.00'  remaining_days = '12.00'

    valid_from = '20260101'  valid_to = '20261231'

    last_updated_by = sy-uname  last_updated_at = lv_timestamp )



  ( employee_id = '0000001003'  leave_type_id = 'SL'  quota_year = '2026'

    total_days = '30.00'  used_days = '0.00'  remaining_days = '30.00'

    valid_from = '20260101'  valid_to = '20261231'

    last_updated_by = sy-uname  last_updated_at = lv_timestamp )



  ( employee_id = '0000001004'  leave_type_id = 'AL'  quota_year = '2026'

    total_days = '12.00'  used_days = '0.00'  remaining_days = '12.00'

    valid_from = '20260101'  valid_to = '20261231'

    last_updated_by = sy-uname  last_updated_at = lv_timestamp )

) ).



IF sy-subrc = 0.

  WRITE: / '  Insert ZLEAVE_QUOTA: OK (7 records).'.

ELSE.

  WRITE: / '  Insert ZLEAVE_QUOTA: LỖI sy-subrc =', sy-subrc.

ENDIF.



COMMIT WORK AND WAIT.



WRITE: / ''.

WRITE: / '========================================'.

WRITE: / 'HOÀN TẤT. Kiểm tra:'.

WRITE: / '  SE16 → ZLEAVE_TYPE  (4 records)'.

WRITE: / '  SE16 → ZEMPLOYEE    (4 records)'.

WRITE: / '  SE16 → ZLEAVE_QUOTA (7 records)'.

WRITE: / '========================================'.
