CLASS lhc_employee DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_role,
             is_admin TYPE abap_bool,
             is_hr    TYPE abap_bool,
           END OF ty_role.

    METHODS get_current_user_role
      RETURNING VALUE(result) TYPE ty_role.

    METHODS get_instance_authorizations
      FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations
      FOR Employee
      RESULT result.

    METHODS setauditfields FOR DETERMINE ON SAVE
      IMPORTING keys FOR employee~setauditfields.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE employee.

    METHODS initializeQuota FOR DETERMINE ON SAVE
      IMPORTING keys FOR employee~initializeQuota.

    METHODS deactivate FOR MODIFY
      IMPORTING keys FOR ACTION Employee~deactivate RESULT result.

    METHODS activate FOR MODIFY
      IMPORTING keys FOR ACTION Employee~activate RESULT result.
ENDCLASS.

CLASS lhc_employee IMPLEMENTATION.

  METHOD get_current_user_role.
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    SELECT SINGLE is_admin, is_hr
      FROM zemployee_table
      WHERE sap_user  = @lv_user
        AND is_active = @abap_true
      INTO @DATA(ls_role).

    result-is_admin = xsdbool( ls_role-is_admin = 'X' ).
    result-is_hr    = xsdbool( ls_role-is_hr    = 'X' ).
  ENDMETHOD.

  METHOD get_instance_authorizations.
    DATA(ls_role) = get_current_user_role( ).

    READ ENTITIES OF zi_employee_admin IN LOCAL MODE
      ENTITY Employee FIELDS ( EmployeeId )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_emp)
      FAILED DATA(lt_failed).

    LOOP AT lt_emp ASSIGNING FIELD-SYMBOL(<ls>).
      APPEND VALUE #(
        %tky = <ls>-%tky

        "--- Update: Admin + HR đều được ---
        %update = COND #(
          WHEN ls_role-is_admin = abap_true OR ls_role-is_hr = abap_true
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )

        "--- Deactivate / Activate: chỉ Admin (thay cho delete cũ) ---
        %action-deactivate = COND #(
          WHEN ls_role-is_admin = abap_true
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )

        %action-activate = COND #(
          WHEN ls_role-is_admin = abap_true
          THEN if_abap_behv=>auth-allowed
          ELSE if_abap_behv=>auth-unauthorized )

      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_create.

    DATA: lv_max_id  TYPE zemployee_table-emp_id,
          lv_next    TYPE i,
          lv_next_c  TYPE zemployee_table-emp_id.

    SELECT SINGLE MAX( emp_id )
      FROM zemployee_table
      INTO @lv_max_id.

    IF lv_max_id IS INITIAL.
      lv_next = 1001.
    ELSE.
      lv_next = lv_max_id + 1.
    ENDIF.

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<entity>).
      UNPACK lv_next TO lv_next_c.

      APPEND VALUE #(
        %cid       = <entity>-%cid
        EmployeeId = lv_next_c
      ) TO mapped-employee.

      lv_next += 1.
    ENDLOOP.

  ENDMETHOD.

  METHOD setAuditFields.
    DATA: lv_created_at TYPE timestampl.

    GET TIME STAMP FIELD lv_created_at.

    MODIFY ENTITIES OF zi_employee_admin IN LOCAL MODE
      ENTITY Employee
      UPDATE FIELDS ( CreatedBy CreatedAt )
      WITH VALUE #(
        FOR key IN keys
        ( %tky      = key-%tky
          CreatedBy  = cl_abap_context_info=>get_user_technical_name( )
          CreatedAt  = lv_created_at )
      ).
  ENDMETHOD.

  METHOD initializeQuota.
    DATA(lv_year) = sy-datum(4).
    GET TIME STAMP FIELD DATA(lv_ts).
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    READ ENTITIES OF zi_employee_admin IN LOCAL MODE
      ENTITY Employee
      FIELDS ( EmployeeId )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_emp).

    SELECT leave_type_id, max_day
      FROM zleave_type
      WHERE is_active = @abap_true
      INTO TABLE @DATA(lt_leave_types).

    IF lt_leave_types IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_emp ASSIGNING FIELD-SYMBOL(<emp>).

      CHECK <emp>-EmployeeId IS NOT INITIAL.

      LOOP AT lt_leave_types ASSIGNING FIELD-SYMBOL(<lt>).

        SELECT SINGLE employee_id FROM zquota
          WHERE employee_id   = @<emp>-EmployeeId
            AND leave_type_id = @<lt>-leave_type_id
            AND quota_year    = @lv_year
          INTO @DATA(lv_exist).

        IF sy-subrc = 0.
          CONTINUE.
        ENDIF.

        INSERT zquota FROM @( VALUE zquota(
          employee_id     = <emp>-EmployeeId
          leave_type_id   = <lt>-leave_type_id
          quota_year      = lv_year
          total_days      = <lt>-max_day
          used_days       = 0
          remaining_days  = <lt>-max_day
          valid_from      = |{ lv_year }0101|
          valid_to        = |{ lv_year }1231|
          last_updated_by = lv_user
          last_updated_at = lv_ts
        ) ).

      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

  METHOD deactivate.

    MODIFY ENTITIES OF zi_employee_admin IN LOCAL MODE
      ENTITY Employee
      UPDATE FIELDS ( IsActive )
      WITH VALUE #(
        FOR key IN keys
        ( %tky     = key-%tky
          IsActive = abap_false )
      )
      FAILED   DATA(lt_failed)
      REPORTED DATA(lt_reported).

    READ ENTITIES OF zi_employee_admin IN LOCAL MODE
      ENTITY Employee
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls IN lt_result
      ( %tky   = ls-%tky
        %param = ls ) ).

  ENDMETHOD.

  METHOD activate.

    MODIFY ENTITIES OF zi_employee_admin IN LOCAL MODE
      ENTITY Employee
      UPDATE FIELDS ( IsActive )
      WITH VALUE #(
        FOR key IN keys
        ( %tky     = key-%tky
          IsActive = abap_true )
      )
      FAILED   DATA(lt_failed)
      REPORTED DATA(lt_reported).

    READ ENTITIES OF zi_employee_admin IN LOCAL MODE
      ENTITY Employee
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls IN lt_result
      ( %tky   = ls-%tky
        %param = ls ) ).

  ENDMETHOD.

ENDCLASS.
