CLASS lhc_LeaveType DEFINITION INHERITING FROM CL_ABAP_BEHAVIOR_HANDLER.
  PRIVATE SECTION.

    METHODS get_instance_authorizations
      FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations
      FOR LeaveType
      RESULT result.

    METHODS initializeQuotaForAll
      FOR DETERMINE ON SAVE
      IMPORTING keys FOR LeaveType~initializeQuotaForAll.

    METHODS deactivateLeaveType
      FOR MODIFY
      IMPORTING keys FOR ACTION LeaveType~deactivateLeaveType RESULT result.

    METHODS activateLeaveType
      FOR MODIFY
      IMPORTING keys FOR ACTION LeaveType~activateLeaveType RESULT result.

ENDCLASS.

CLASS lhc_LeaveType IMPLEMENTATION.

  METHOD get_instance_authorizations.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    SELECT SINGLE is_admin
      FROM zemployee_table
      WHERE sap_user  = @lv_user
        AND is_active = @abap_true
      INTO @DATA(lv_is_admin).

    DATA(lv_admin_ok) = xsdbool( sy-subrc = 0 AND lv_is_admin = 'X' ).

    READ ENTITIES OF zi_leave_type_admin IN LOCAL MODE
      ENTITY LeaveType FIELDS ( LeaveTypeId )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_types).

    LOOP AT lt_types ASSIGNING FIELD-SYMBOL(<ls>).
      APPEND VALUE #(
        %tky = <ls>-%tky
        %action-deactivateLeaveType = COND #( WHEN lv_admin_ok = abap_true THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized )
        %action-activateLeaveType   = COND #( WHEN lv_admin_ok = abap_true THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized )
      ) TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD initializeQuotaForAll.
  DATA(lv_year) = sy-datum(4).
  DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
  GET TIME STAMP FIELD DATA(lv_ts).

  READ ENTITIES OF zi_leave_type_admin IN LOCAL MODE
    ENTITY LeaveType
    FIELDS ( LeaveTypeId MaxDaysPerYear )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_types).

  "--- Lấy tất cả nhân viên đang active ---
  SELECT emp_id
    FROM zemployee_table
    WHERE is_active = @abap_true
    INTO TABLE @DATA(lt_employees).

  LOOP AT lt_types ASSIGNING FIELD-SYMBOL(<lt>).
    LOOP AT lt_employees ASSIGNING FIELD-SYMBOL(<emp>).

      "--- Kiểm tra quota đã tồn tại chưa ---
      SELECT SINGLE employee_id FROM zquota
        WHERE employee_id   = @<emp>-emp_id
          AND leave_type_id = @<lt>-LeaveTypeId
          AND quota_year    = @lv_year
        INTO @DATA(lv_exist).

      IF sy-subrc = 0. CONTINUE. ENDIF.

      INSERT zquota FROM @( VALUE zquota(
        employee_id     = <emp>-emp_id
        leave_type_id   = <lt>-LeaveTypeId
        quota_year      = lv_year
        total_days      = <lt>-MaxDaysPerYear
        used_days       = 0
        remaining_days  = <lt>-MaxDaysPerYear
        valid_from      = |{ lv_year }0101|
        valid_to        = |{ lv_year }1231|
        last_updated_by = lv_user
        last_updated_at = lv_ts
      ) ).
    ENDLOOP.
  ENDLOOP.
ENDMETHOD.

METHOD deactivateLeaveType.

    GET TIME STAMP FIELD DATA(lv_ts).
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    MODIFY ENTITIES OF zi_leave_type_admin IN LOCAL MODE
      ENTITY LeaveType
      UPDATE FIELDS ( IsActive )
      WITH VALUE #(
        FOR key IN keys
        ( %tky     = key-%tky
          IsActive = abap_false )
      )
      FAILED   DATA(lt_failed)
      REPORTED DATA(lt_reported).

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<k>).
      APPEND VALUE #(
        %tky = <k>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = 'Loại nghỉ đã bị vô hiệu hóa (soft delete).' )
      ) TO reported-leavetype.
    ENDLOOP.

    READ ENTITIES OF zi_leave_type_admin IN LOCAL MODE
      ENTITY LeaveType ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls IN lt_result ( %tky = ls-%tky %param = ls ) ).

  ENDMETHOD.

 METHOD activateLeaveType.

    MODIFY ENTITIES OF zi_leave_type_admin IN LOCAL MODE
      ENTITY LeaveType
      UPDATE FIELDS ( IsActive )
      WITH VALUE #(
        FOR key IN keys
        ( %tky     = key-%tky
          IsActive = abap_true )
      )
      FAILED   DATA(lt_failed)
      REPORTED DATA(lt_reported).

    READ ENTITIES OF zi_leave_type_admin IN LOCAL MODE
      ENTITY LeaveType ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls IN lt_result ( %tky = ls-%tky %param = ls ) ).

  ENDMETHOD.
ENDCLASS.
