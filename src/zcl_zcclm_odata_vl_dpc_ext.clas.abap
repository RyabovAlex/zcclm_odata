class ZCL_ZCCLM_ODATA_VL_DPC_EXT definition
  public
  inheriting from ZCL_ZCCLM_ODATA_VL_DPC
  create public .

public section.

  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CHANGESET_BEGIN
    redefinition .
  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CHANGESET_END
    redefinition .
protected section.

  methods LANDSCAPESET_CREATE_ENTITY
    redefinition .
  methods LANDSCAPESET_DELETE_ENTITY
    redefinition .
  methods LANDSCAPESET_UPDATE_ENTITY
    redefinition .
  methods LTOSSET_CREATE_ENTITY
    redefinition .
  methods LTOSSET_DELETE_ENTITY
    redefinition .
  methods LTOSSET_UPDATE_ENTITY
    redefinition .
  methods MAILSET_CREATE_ENTITY
    redefinition .
  methods MAILSET_GET_ENTITYSET
    redefinition .
  methods SYSTEMSET_UPDATE_ENTITY
    redefinition .
  methods MAILSET_DELETE_ENTITY
    redefinition .
private section.
ENDCLASS.



CLASS ZCL_ZCCLM_ODATA_VL_DPC_EXT IMPLEMENTATION.


  method /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CHANGESET_BEGIN.
**TRY.
*CALL METHOD SUPER->/IWBEP/IF_MGW_APPL_SRV_RUNTIME~CHANGESET_BEGIN
*  EXPORTING
*    IT_OPERATION_INFO =
**  CHANGING
**    CV_DEFER_MODE     =
*    .
** CATCH /IWBEP/CX_MGW_BUSI_EXCEPTION .
** CATCH /IWBEP/CX_MGW_TECH_EXCEPTION .
**ENDTRY.
  endmethod.


  method /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CHANGESET_END.
**TRY.
*CALL METHOD SUPER->/IWBEP/IF_MGW_APPL_SRV_RUNTIME~CHANGESET_END
*    .
** CATCH /IWBEP/CX_MGW_BUSI_EXCEPTION .
** CATCH /IWBEP/CX_MGW_TECH_EXCEPTION .
**ENDTRY.
  endmethod.


  method LANDSCAPESET_CREATE_ENTITY.
    DATA ls_request_input_data LIKE er_entity.
    DATA ls_lnscp TYPE zagsccl_lnscp.

    io_data_provider->read_entry_data( IMPORTING es_data = ls_request_input_data ).

    ls_lnscp-id   = ls_request_input_data-id.
    ls_lnscp-descr = ls_request_input_data-description.
    INSERT zagsccl_lnscp FROM ls_lnscp.

    IF sy-subrc = 0.
      er_entity = ls_request_input_data.
    ENDIF.
  endmethod.


  method LANDSCAPESET_DELETE_ENTITY.

    READ TABLE it_key_tab INTO DATA(ls_key_tab) WITH KEY name = 'Id'.

    DATA(lv_ln_id) = ls_key_tab-value.

    IF lv_ln_id IS NOT INITIAL.

      DELETE FROM zagsccl_lnscp WHERE id = lv_ln_id.  " From landscapes table

      DELETE FROM zagsccl_ltos WHERE lnscp_id = lv_ln_id.   " From landscape - system relations

    ENDIF.
  endmethod.


  method LANDSCAPESET_UPDATE_ENTITY.
    DATA ls_request_input_data LIKE er_entity.
    DATA ls_lnscp TYPE zagsccl_lnscp.

    io_data_provider->read_entry_data( IMPORTING es_data = ls_request_input_data ).

    READ TABLE it_key_tab INTO DATA(ls_tab) WITH KEY name = 'Id'.
    DELETE FROM zagsccl_lnscp WHERE Id = ls_tab-value.

    SELECT *
      FROM zagsccl_ltos
      INTO TABLE @DATA(lt_ltos)
      WHERE lnscp_id = @ls_tab-value.

    DATA lt_new_ltos LIKE lt_ltos.
    LOOP AT lt_ltos INTO DATA(ls_ltos).
      ls_ltos-lnscp_id = ls_request_input_data-id.
      APPEND ls_ltos TO lt_new_ltos.
    ENDLOOP.

    DELETE
      FROM zagsccl_ltos
      WHERE lnscp_id = ls_tab-value.


    ls_lnscp-id   = ls_request_input_data-id.
    ls_lnscp-descr = ls_request_input_data-description.
    INSERT zagsccl_lnscp FROM ls_lnscp.

    INSERT zagsccl_ltos FROM TABLE lt_new_ltos.

    IF sy-subrc = 0.
      er_entity = ls_request_input_data.
    ENDIF.
  endmethod.


  method LTOSSET_CREATE_ENTITY.
    DATA ls_request_input_data LIKE er_entity.
    DATA ls_ltos TYPE zagsccl_ltos.

    io_data_provider->read_entry_data( IMPORTING es_data = ls_request_input_data ).

    ls_ltos-lnscp_id = ls_request_input_data-landscapeid.
    ls_ltos-sys_id = ls_request_input_data-systemid.
    SELECT SINGLE clt
      FROM e2e_efwk_status
      INTO ls_ltos-sys_clnt
      WHERE sid = ls_ltos-sys_id AND EXTRACTOR LIKE 'AGS_CC%'.
    INSERT zagsccl_ltos FROM ls_ltos.

    IF sy-subrc = 0.
      er_entity = ls_request_input_data.
    ENDIF.
  endmethod.


    method LTOSSET_DELETE_ENTITY.

    READ TABLE it_key_tab INTO DATA(ls_sys_key_tab) WITH KEY name = 'Systemid'.
    READ TABLE it_key_tab INTO DATA(ls_ln_key_tab) WITH KEY name = 'Landscapeid'.

    DATA(lv_sys_id) = ls_sys_key_tab-value.
    DATA(lv_ln_id) = ls_ln_key_tab-value.

    IF lv_ln_id IS NOT INITIAL AND lv_sys_id IS NOT INITIAL.

      DELETE FROM zagsccl_ltos WHERE lnscp_id = lv_ln_id AND sys_id = lv_sys_id.   " From landscape - system relations

    ENDIF.
  endmethod.


  method LTOSSET_UPDATE_ENTITY.
DATA ls_request_input_data LIKE er_entity.

    io_data_provider->read_entry_data( IMPORTING es_data = ls_request_input_data ).

    SELECT SINGLE *
    FROM zagsccl_ltos
    INTO @DATA(ls_ltos)
    WHERE sys_id = @ls_request_input_data-systemid and
          lnscp_id = @ls_request_input_data-landscapeid.

    ls_ltos-sys_id   = ls_request_input_data-systemid.
    ls_ltos-lnscp_id = ls_request_input_data-landscapeid.
    ls_ltos-sys_clnt = ls_request_input_data-systemclient.
    MODIFY zagsccl_ltos FROM ls_ltos.

    IF sy-subrc = 0.
      er_entity = ls_request_input_data.
    ENDIF.
  endmethod.


  method MAILSET_CREATE_ENTITY.
DATA ls_request_input_data LIKE er_entity.
    DATA ls_mail TYPE zcclm_ls_mail.

    io_data_provider->read_entry_data( IMPORTING es_data = ls_request_input_data ).

    ls_mail-lnscp_id = ls_request_input_data-lnscp_id.
    ls_mail-mail = ls_request_input_data-mail.

    MODIFY zcclm_ls_mail FROM ls_mail.

  endmethod.


  method MAILSET_DELETE_ENTITY.
    READ TABLE it_key_tab INTO DATA(ls_ln_key_tab) WITH KEY name = 'LnscpId'.
    READ TABLE it_key_tab INTO DATA(ls_mail_key_tab) WITH KEY name = 'Mail'.

    DATA(lv_ln_id) = ls_ln_key_tab-value.
    DATA(lv_mail)  = ls_mail_key_tab-value.

    IF lv_ln_id IS NOT INITIAL AND lv_mail IS NOT INITIAL.

      DELETE FROM zcclm_ls_mail WHERE lnscp_id = lv_ln_id AND mail = lv_mail.

    ENDIF.
  endmethod.


  METHOD mailset_get_entityset.
    DATA(lt_filters) = io_tech_request_context->get_filter( )->get_filter_select_options( ).

    READ TABLE lt_filters WITH TABLE KEY property = 'LNSCP_ID' INTO DATA(ls_name).
    READ TABLE ls_name-select_options INTO DATA(ls_name_so) INDEX 1.
    DATA(lv_lnscp) = ls_name_so-low.

    IF lv_lnscp IS NOT INITIAL.

      SELECT *
      FROM zcclm_ls_mail
      INTO TABLE et_entityset
      WHERE lnscp_id = lv_lnscp.

    ELSE.
      SELECT *
      FROM zcclm_ls_mail
      INTO TABLE et_entityset.
    ENDIF.


  ENDMETHOD.


  method SYSTEMSET_UPDATE_ENTITY.
    DATA ls_request_input_data LIKE er_entity.

    io_data_provider->read_entry_data( IMPORTING es_data = ls_request_input_data ).

    SELECT SINGLE *
    FROM agsccl_system
    INTO @DATA(ls_sys)
    WHERE system_id = @ls_request_input_data-id AND
          instno = '0000000000'.

    ls_sys-system_id   = ls_request_input_data-id.
    ls_sys-system_role = ls_request_input_data-role.
    MODIFY agsccl_system FROM ls_sys.

    IF sy-subrc = 0.
      er_entity = ls_request_input_data.
    ENDIF.
  endmethod.
ENDCLASS.
