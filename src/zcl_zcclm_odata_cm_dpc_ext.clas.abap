class ZCL_ZCCLM_ODATA_CM_DPC_EXT definition
  public
  inheriting from ZCL_ZCCLM_ODATA_CM_DPC
  create public .

public section.

  class-methods UPDATE_ALL_SYSTEMS .

  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~EXECUTE_ACTION
    redefinition .
protected section.

  methods ANALYSIS_JOBSET_GET_ENTITYSET
    redefinition .
  methods ANALYSIS_JOB_RUN_GET_ENTITYSET
    redefinition .
  methods BESTPRACTICESET_GET_ENTITY
    redefinition .
  methods BESTPRACTICESET_GET_ENTITYSET
    redefinition .
  methods BESTPRACTICESET_UPDATE_ENTITY
    redefinition .
  methods LANDSCAPE_STATUS_GET_ENTITYSET
    redefinition .
  methods NOTESET_GET_ENTITYSET
    redefinition .
  methods SOLMAN_BWSET_GET_ENTITYSET
    redefinition .
  methods SOLMAN_JOBSET_GET_ENTITYSET
    redefinition .
  methods SOLMAN_JOB_RUNSE_GET_ENTITY
    redefinition .
  methods SOLMAN_JOB_RUNSE_GET_ENTITYSET
    redefinition .
  methods SOLMAN_NOTESET_GET_ENTITYSET
    redefinition .
  methods SYSTEM_STATUSSET_GET_ENTITY
    redefinition .
  methods SYSTEM_STATUSSET_GET_ENTITYSET
    redefinition .
private section.

  class-methods GET_SYSTEM_STATUS
    importing
      !SYS_ID type SYSTEM_ID
      !LN_ID type SYSTEM_ID
      !UPDATE type BOOLEAN
    exporting
      !ER_ENTITY type ZCL_ZCCLM_ODATA_CM_MPC=>TS_SYSTEM_STATUS .
ENDCLASS.



CLASS ZCL_ZCCLM_ODATA_CM_DPC_EXT IMPLEMENTATION.


  METHOD /iwbep/if_mgw_appl_srv_runtime~execute_action.

    DATA ls_parameter TYPE /iwbep/s_mgw_name_value_pair.

    IF iv_action_name = 'MASS_UPDATE'.

    DATA lv_jobname TYPE char32 VALUE 'ZCCLM_STATUS_UPDATE'.
    DATA lv_job_count TYPE tbtco-jobcount.

    CALL FUNCTION 'JOB_OPEN'
       EXPORTING
         jobname  =  lv_jobname
       IMPORTING
         jobcount = lv_job_count.

***********Submit The Main Program
     SUBMIT ZCCLM_STATUS_UPDATE VIA JOB lv_jobname NUMBER lv_job_count
     AND RETURN.


***********Close The JOB
     CALL FUNCTION 'JOB_CLOSE'
       EXPORTING
         jobname              = lv_jobname
         jobcount             = lv_job_count
         strtimmed            = 'X'
       EXCEPTIONS
         cant_start_immediate = 1
         invalid_startdate    = 2
         jobname_missing      = 3
         job_close_failed     = 4
         job_nosteps          = 5
         job_notex            = 6
         lock_failed          = 7
         invalid_target       = 8
         OTHERS               = 9.

    ENDIF.

  ENDMETHOD.


  METHOD analysis_jobset_get_entityset.

    DATA(lt_filters) = io_tech_request_context->get_filter( )->get_filter_select_options( ).
    DATA ls_entity LIKE LINE OF et_entityset.
    DATA lt_entityset TYPE STANDARD TABLE OF zags_cc_schedule_s.
    READ TABLE lt_filters WITH TABLE KEY property = 'SYSTEM_ID' INTO DATA(ls_sys_id_filter).

    IF sy-subrc EQ 0.
      READ TABLE ls_sys_id_filter-select_options INTO DATA(ls_so) INDEX 1.
      DATA(lv_sys_id) = ls_so-low.
    ENDIF.


*    READ TABLE lt_filters WITH TABLE KEY property = 'CLIENT' INTO DATA(ls_sys_cl_filter).
*
*    IF sy-subrc EQ 0.
*      READ TABLE ls_sys_cl_filter-select_options INTO ls_so INDEX 1.
*      DATA(lv_sys_cl) = ls_so-low.
*    ENDIF.

    SELECT SYS_CLNT
    FROM ZAGSCCL_LTOS
    INTO @DATA(lv_sys_cl)
    WHERE SYS_ID = @lv_sys_id.
    ENDSELECT.

    READ TABLE lt_filters WITH TABLE KEY property = 'BEST_PRACTICE' INTO DATA(ls_bp_cl_filter).

    IF sy-subrc EQ 0.
      READ TABLE ls_bp_cl_filter-select_options INTO ls_so INDEX 1.
      DATA(lv_bp_cl) = ls_so-low.
    ENDIF.

*    CALL METHOD cl_assist_ext_coll=>get_analys_job
*      EXPORTING
*        iv_sid       = CONV #( lv_sys_id )    " System ID
*        iv_client    = CONV #( lv_sys_cl )   " Client
*      IMPORTING
*        et_activ_job = DATA(lt_activ_job)   " table of AGS_CC_EXTRACTOR_S
*        et_job       = DATA(lt_job)   " Table of scheduling job data.
*        es_usage     = DATA(ls_usage_info).
    CALL METHOD cl_assist_ext_coll=>get_analys_job
      EXPORTING
        iv_sid       = CONV #( lv_sys_id )    " System ID
        iv_client    = CONV #( lv_sys_cl )   " Client
      IMPORTING
        et_activ_job = DATA(lt_activ_job)   " table of AGS_CC_EXTRACTOR_S
        et_job       = DATA(lt_job)   " Table of scheduling job data.
        ev_upl_env   = DATA(lv_upl).   " Boolean Variable (X=True, -=False, Space=Unknown).

    SORT lt_job BY jobname DESCENDING start_date DESCENDING start_time DESCENDING.

    DELETE ADJACENT DUPLICATES FROM lt_job COMPARING jobname.

    SELECT system_role
        FROM zagsccl_system
        INTO @DATA(ls_role)
        WHERE system_id = @lv_sys_id.
    ENDSELECT.

    DATA lv_uc TYPE i VALUE 0.
    DATA lv_cc TYPE i VALUE 0.
    DATA lv_rc TYPE i VALUE 0.
    DATA lv_sc TYPE i VALUE 0.
    DATA lv_usage_type TYPE i VALUE 0.
    LOOP AT lt_job INTO DATA(ls_job).

      ls_job-system_id = lv_sys_id.
      ls_job-client = lv_sys_cl.
      MOVE-CORRESPONDING ls_job TO ls_entity.

      IF ls_job-jobname NS 'SIMIL' AND ls_job-jobname NS 'BUSI_CRIT'.
        CALL METHOD cl_assist_ext_coll=>get_rfc_destination
        EXPORTING
          system_id      = CONV #( lv_sys_id )
          client         = CONV #( lv_sys_cl )
        IMPORTING
          rfcdestination = DATA(lv_destination).
      ELSE.
        CLEAR lv_destination.
      ENDIF.

      IF ls_job-jobname CS '/SDF/UPL'.
        lv_usage_type = 1.
      ENDIF.
      IF ls_job-jobname CS 'ABAP CALL'.
        lv_usage_type = 2.
      ENDIF.

      CALL FUNCTION 'ZCCLM_CHECK_JOB'
        EXPORTING
          jobname = ls_job-jobname   " Background job name
          dest    = lv_destination
        IMPORTING
          status  = ls_entity-status.

      SELECT *
        FROM zagsccl_srtj
        INTO TABLE @DATA(lv_bpt)
        WHERE system_role = @ls_role.

      IF lv_usage_type = 1.
        DELETE lv_bpt WHERE job_name CS 'ABAP CALL'.
      ENDIF.

      IF lv_usage_type = 2.
        DELETE lv_bpt WHERE job_name CS '/SDF/UPL'.
      ENDIF.

     DATA lv_bpc TYPE i VALUE 0.
     LOOP AT lv_bpt INTO DATA(ls_bpt).
       IF ls_job-jobname CS ls_bpt-job_name .
         lv_bpc = lv_bpc + 1.
       ENDIF.
     ENDLOOP.
      IF lv_bpc > 0.
        ls_entity-best_practice = 0.
      ELSE.
        ls_entity-best_practice = 1.
      ENDIF.
      APPEND ls_entity TO lt_entityset.
      CLEAR lv_bpc.
    ENDLOOP.

*    SELECT *
*    FROM zagsccl_srtj
*    INTO TABLE @DATA(lt_bpt)
*    WHERE system_role = @ls_role.


    LOOP AT lv_bpt INTO DATA(ls_bp_job).
      DATA lv_temp TYPE i VALUE 0.
      LOOP AT lt_job INTO ls_job.
        IF ls_job-jobname CS ls_bp_job-job_name.
          lv_temp = 1.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_temp = 0.
        CLEAR ls_entity.
        ls_entity-jobname = ls_bp_job-job_name.
        ls_entity-best_practice = 2.
      ELSE.
        lv_temp = 0.
        CONTINUE.
      ENDIF.
      APPEND ls_entity TO lt_entityset.

    ENDLOOP.


    LOOP AT lt_entityset INTO DATA(ls_temp) WHERE best_practice = lv_bp_cl.
      APPEND ls_temp TO et_entityset.
      CLEAR: ls_temp.
    ENDLOOP.

  ENDMETHOD.


  METHOD analysis_job_run_get_entityset.
    DATA(lt_filters) = io_tech_request_context->get_filter( )->get_filter_select_options( ).
    READ TABLE lt_filters WITH TABLE KEY property = 'JOBNAME' INTO DATA(ls_name).
    READ TABLE ls_name-select_options INTO DATA(ls_name_so) INDEX 1.
    DATA(lv_jobname) = ls_name_so-low.

    READ TABLE lt_filters WITH TABLE KEY property = 'SYSTEM_ID' INTO DATA(ls_sys).
    READ TABLE ls_sys-select_options INTO DATA(ls_sys_so) INDEX 1.
    DATA(lv_sys_id) = ls_sys_so-low.


    READ TABLE lt_filters WITH TABLE KEY property = 'CLIENT' INTO DATA(ls_clnt).
    READ TABLE ls_clnt-select_options INTO DATA(ls_clnt_so) INDEX 1.
    DATA(lv_sys_cl) = ls_clnt_so-low.


    DATA es_entity LIKE LINE OF et_entityset.

    IF lv_jobname NS 'SIMIL' AND lv_jobname NS 'BUSI_CRIT'.
      CALL METHOD cl_assist_ext_coll=>get_rfc_destination
        EXPORTING
          system_id      = CONV #( lv_sys_id )
          client         = CONV #( lv_sys_cl )
        IMPORTING
          rfcdestination = DATA(lv_destination).
    ENDIF.

    DATA lt_fld TYPE TABLE OF rfc_db_fld.
    DATA lt_opt TYPE TABLE OF rfc_db_opt.
    DATA ls_fld TYPE rfc_db_fld.
    DATA ls_opt TYPE rfc_db_opt.
    DATA lt_tab TYPE TABLE OF tab512.


    IF lv_jobname NS `'`.
      CONCATENATE `JOBNAME = '` lv_jobname `'` INTO ls_opt-text .
    ELSE.
      CONCATENATE `JOBNAME = ` lv_jobname INTO ls_opt-text.
    ENDIF.
    APPEND ls_opt TO lt_opt.

    ls_fld-fieldname = 'JOBNAME'.
    ls_fld-offset = 0.
    ls_fld-length = 32.
    ls_fld-type = 'C'.
    APPEND ls_fld TO lt_fld.
    CLEAR ls_fld.
    ls_fld-fieldname = 'SDLSTRTDT'.
    ls_fld-offset = 33.
    ls_fld-length = 8.
    ls_fld-type = 'D'.
    APPEND ls_fld TO lt_fld.
    ls_fld-fieldname = 'SDLSTRTTM'.
    ls_fld-offset = 42.
    ls_fld-length = 6.
    ls_fld-type = 'T'.
    APPEND ls_fld TO lt_fld.
    ls_fld-fieldname = 'STATUS'.
    ls_fld-offset = 49.
    ls_fld-length = 1.
    ls_fld-type = 'C'.
    APPEND ls_fld TO lt_fld.

    CALL FUNCTION 'RFC_READ_TABLE'
      DESTINATION lv_destination
      EXPORTING
        delimiter   = ';'
        query_table = 'TBTCO'   " Table read
        rowcount    = 5
      TABLES
        options     = lt_opt   " Selection entries, "WHERE clauses" (in)
        fields      = lt_fld   " Names (in) and structure (out) of fields read
        data        = lt_tab   " Data read (out).
      EXCEPTIONS
        OTHERS      = 1.

    LOOP AT lt_tab INTO DATA(ls_tab).
      CLEAR es_entity.
      es_entity-system_id = lv_sys_id.
      es_entity-client = lv_sys_cl.
      SPLIT ls_tab AT ';' INTO es_entity-jobname es_entity-start_date es_entity-start_time es_entity-status.
      APPEND es_entity TO et_entityset.
    ENDLOOP.

    SORT et_entityset DESCENDING STABLE BY start_date start_time.

  ENDMETHOD.


  METHOD bestpracticeset_get_entity.
    DATA lv_extc TYPE i.
    DATA lv_colc TYPE i.
    DATA lv_jobc TYPE i.
    DATA role TYPE char256.
    FIELD-SYMBOLS <fs> TYPE any.
    DATA: r_descr TYPE REF TO cl_abap_structdescr.
    DATA lt_comp TYPE abap_compdescr_tab.

    READ TABLE it_key_tab INTO DATA(ls_scn) WITH KEY name = 'Scenario'.
    er_entity-scenario = ls_scn-value.
    r_descr ?= cl_abap_typedescr=>describe_by_data( er_entity ).
    APPEND LINES OF r_descr->components FROM 2 TO lt_comp.

    IF er_entity-scenario = 'Object Inventory'.
      LOOP AT r_descr->components INTO DATA(ls_comp) FROM 2.
        ASSIGN COMPONENT sy-tabix OF STRUCTURE er_entity TO <fs>.
        role = ls_comp-name.
        SELECT COUNT( * )
          FROM zagsccl_srte
          INTO  lv_extc
          WHERE extractor_name LIKE 'AGS_CC_OBJ%' AND system_role = role.

        SELECT COUNT( * )
          FROM zagsccl_srtc
          INTO lv_colc
          WHERE ( collector_id = 'CUST' OR collector_id = 'ENHS' OR collector_id = 'MODS' ) AND
                system_role = role.
        IF lv_extc = 6 AND lv_colc = 3.
          <fs> = 'X'.
        ELSE.
          <fs> = ''.
        ENDIF.
      ENDLOOP.
    ELSEIF er_entity-scenario = 'Usage'.
      LOOP AT r_descr->components INTO ls_comp FROM 2.
        ASSIGN COMPONENT sy-tabix OF STRUCTURE er_entity TO <fs>.
        role = ls_comp-name.
        SELECT COUNT( * )
          FROM zagsccl_srte
          INTO  lv_extc
          WHERE system_role = role AND
          ( extractor_name LIKE 'AGS_CC_SCMON%' OR
            extractor_name = 'E2E_LUW_ECL_0CCMSATPH' ) .

        SELECT COUNT( * )
          FROM zagsccl_srtc
          INTO lv_colc
          WHERE collector_id = 'LUSG' AND
                system_role = role.

        SELECT COUNT( * )
          FROM zagsccl_srtj
          INTO lv_jobc
          WHERE ( job_name = '/SDF/UPL_PERIODIC_EXT_JOB' OR job_name = 'ABAP CALL MONITOR: COLLECT' ) AND
                system_role = role.

        IF lv_extc = 3 AND lv_colc = 1 AND ( lv_jobc = 1 OR lv_jobc = 2 ).
          <fs> = 'X'.
        ELSE.
          <fs> = ''.
        ENDIF.
      ENDLOOP.
    ELSEIF er_entity-scenario = 'Quality'.
      LOOP AT r_descr->components INTO ls_comp FROM 2.
        ASSIGN COMPONENT sy-tabix OF STRUCTURE er_entity TO <fs>.
        role = ls_comp-name.
        SELECT COUNT( * )
          FROM zagsccl_srte
          INTO  lv_extc
          WHERE extractor_name LIKE 'AGS_EXTRACT_ATC%' AND system_role = role.

        SELECT COUNT( * )
          FROM zagsccl_srtc
          INTO lv_colc
          WHERE collector_id = 'QUAL' AND
                system_role = role.
        IF lv_extc = 2 AND lv_colc = 1.
          <fs> = 'X'.
        ELSE.
          <fs> = ''.
        ENDIF.
      ENDLOOP.
    ELSEIF er_entity-scenario = 'References'.
      LOOP AT r_descr->components INTO ls_comp FROM 2.
        ASSIGN COMPONENT sy-tabix OF STRUCTURE er_entity TO <fs>.
        role = ls_comp-name.
        SELECT COUNT( * )
          FROM zagsccl_srte
          INTO  lv_extc
          WHERE extractor_name = '/SDF/CC_REF_EXTRACT_EFWK' AND system_role = role.

        SELECT COUNT( * )
          FROM zagsccl_srtc
          INTO lv_colc
          WHERE collector_id = 'REF' AND
                system_role = role.

        SELECT COUNT( * )
          FROM zagsccl_srtj
          INTO lv_jobc
          WHERE job_name = '/SDF/CC_REFERENCES' AND
                system_role = role.

        IF lv_extc = 1 AND lv_colc = 1 AND lv_jobc = 1.
          <fs> = 'X'.
        ELSE.
          <fs> = ''.
        ENDIF.
      ENDLOOP.
    ELSEIF er_entity-scenario = 'Similarity'.
      LOOP AT r_descr->components INTO ls_comp FROM 2.
        ASSIGN COMPONENT sy-tabix OF STRUCTURE er_entity TO <fs>.
        role = ls_comp-name.
        SELECT COUNT( * )
          FROM zagsccl_srte
          INTO  lv_extc
          WHERE extractor_name = 'AGS_CC_EXTRACT_SIMILARITY' AND system_role = role.

        SELECT COUNT( * )
          FROM zagsccl_srtc
          INTO lv_colc
          WHERE collector_id = 'SIMIL' AND
                system_role = role.

        SELECT COUNT( * )
          FROM zagsccl_srtj
          INTO lv_jobc
          WHERE job_name = 'EFWK JOB FOR SIMILARITY' AND
                system_role = role.

        IF lv_extc = 1 AND lv_colc = 1 AND lv_jobc = 1.
          <fs> = 'X'.
        ELSE.
          <fs> = ''.
        ENDIF.
      ENDLOOP.
    ELSEIF  er_entity-scenario = 'SQLM'.
      LOOP AT r_descr->components INTO ls_comp FROM 2.
        ASSIGN COMPONENT sy-tabix OF STRUCTURE er_entity TO <fs>.
        role = ls_comp-name.
        SELECT COUNT( * )
          FROM zagsccl_srte
          INTO  lv_extc
          WHERE extractor_name = 'AGS_CC_SQLM_EXTRACTOR' AND system_role = role.

*        SELECT COUNT( * )
*        FROM zagsccl_srtj
*        INTO lv_jobc
*        WHERE job_name = 'RTM_PERIODIC_JOB' AND system_role = role.

      IF lv_extc = 1. "and lv_jobc = 1.
          <fs> = 'X'.
        ELSE.
          <fs> = ''.
        ENDIF.
      ENDLOOP.
    ELSEIF er_entity-scenario = 'CCLM'.
      LOOP AT r_descr->components INTO ls_comp FROM 2.
        ASSIGN COMPONENT sy-tabix OF STRUCTURE er_entity TO <fs>.
        role = ls_comp-name.
        SELECT COUNT( * )
          FROM zagsccl_srte
          INTO  lv_extc
          WHERE ( extractor_name = 'AGS_CC_EXTRACT_CCITY' OR
                  extractor_name = 'AGS_CC_CCLM_EXTRACT' OR
                  extractor_name = 'E2E_ICIDB_EXT_CCLM' ) AND system_role = role.

        IF lv_extc = 3 AND lv_colc = 1.
          <fs> = 'X'.
        ELSE.
          <fs> = ''.
        ENDIF.
      ENDLOOP.
    ELSEIF er_entity-scenario = 'Criticality'.
      LOOP AT r_descr->components INTO ls_comp FROM 2.
        ASSIGN COMPONENT sy-tabix OF STRUCTURE er_entity TO <fs>.
        role = ls_comp-name.
        SELECT COUNT( * )
          FROM zagsccl_srtc
          INTO lv_colc
          WHERE collector_id = 'CRIT' AND
                system_role = role.
        SELECT COUNT( * )
          FROM zagsccl_srtj
          INTO lv_jobc
          WHERE job_name = 'AGS_CC_BUSI_CRIT' AND
                system_role = role.

        IF lv_colc = 1 AND lv_jobc = 1.
          <fs> = 'X'.
        ELSE.
          <fs> = ''.
        ENDIF.
      ENDLOOP.
    ELSEIF er_entity-scenario = 'Version'.
      LOOP AT r_descr->components INTO ls_comp FROM 2.
        ASSIGN COMPONENT sy-tabix OF STRUCTURE er_entity TO <fs>.
        role = ls_comp-name.
        SELECT COUNT( * )
          FROM zagsccl_srtc
          INTO lv_colc
          WHERE collector_id = 'VERS' AND
                system_role = role.

        IF lv_extc = 1.
          <fs> = 'X'.
        ELSE.
          <fs> = ''.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD bestpracticeset_get_entityset.
    DATA es_entity LIKE LINE OF et_entityset.
    DATA lv_extc TYPE i.
    DATA lv_colc TYPE i.
    DATA lv_jobc TYPE i.
    DATA role TYPE char256.
    FIELD-SYMBOLS <fs> TYPE any.
    DATA: r_descr TYPE REF TO cl_abap_structdescr.
    DATA lt_comp TYPE abap_compdescr_tab.

    r_descr ?= cl_abap_typedescr=>describe_by_data( es_entity ).
    APPEND LINES OF r_descr->components FROM 2 TO lt_comp.

    es_entity-scenario = 'Object Inventory'.
    CLEAR lv_extc.
    CLEAR lv_colc.
    CLEAR lv_jobc.

    LOOP AT r_descr->components INTO DATA(ls_comp) FROM 2.
      ASSIGN COMPONENT sy-tabix OF STRUCTURE es_entity TO <fs>.
      role = ls_comp-name.
      SELECT COUNT( * )
        FROM zagsccl_srte
        INTO  lv_extc
        WHERE extractor_name LIKE 'AGS_CC_OBJ%' AND system_role = role.

      SELECT COUNT( * )
        FROM zagsccl_srtc
        INTO lv_colc
        WHERE ( collector_id = 'CUST' OR collector_id = 'ENHS' OR collector_id = 'MODS' ) AND
              system_role = role.

      IF lv_extc = 6 AND lv_colc = 3.
        <fs> = 'X'.
      ELSE.
        <fs> = ''.
      ENDIF.
    ENDLOOP.
    APPEND es_entity TO et_entityset.


    es_entity-scenario = 'Usage'.
    CLEAR lv_extc.
    CLEAR lv_colc.
    CLEAR lv_jobc.

    LOOP AT r_descr->components INTO ls_comp FROM 2.
      ASSIGN COMPONENT sy-tabix OF STRUCTURE es_entity TO <fs>.
      role = ls_comp-name.
      SELECT COUNT( * )
        FROM zagsccl_srte
        INTO  lv_extc
        WHERE system_role = role AND
                 ( extractor_name LIKE 'AGS_CC_SCMON%' OR
                   ( extractor_name LIKE 'E2E_LUW_SECONDAR_EXTRACTOR_SSR' ) ) .

      SELECT COUNT( * )
        FROM zagsccl_srtc
        INTO lv_colc
        WHERE collector_id = 'LUSG' AND
              system_role = role.

      SELECT COUNT( * )
        FROM zagsccl_srtj
        INTO lv_jobc
        WHERE ( job_name = '/SDF/UPL_PERIODIC_EXT_JOB' OR job_name = 'ABAP CALL MONITOR: COLLECT' ) AND system_role = role.

      IF lv_extc = 3 AND lv_colc = 1 AND ( lv_jobc = 1 OR lv_jobc = 2 ).
        <fs> = 'X'.
      ELSE.
        <fs> = ''.
      ENDIF.
    ENDLOOP.
    APPEND es_entity TO et_entityset.

    es_entity-scenario = 'Quality'.

    LOOP AT r_descr->components INTO ls_comp FROM 2.
      ASSIGN COMPONENT sy-tabix OF STRUCTURE es_entity TO <fs>.
      role = ls_comp-name.
      SELECT COUNT( * )
        FROM zagsccl_srte
        INTO  lv_extc
        WHERE extractor_name LIKE 'AGS_EXTRACT_ATC%' AND system_role = role.

      SELECT COUNT( * )
        FROM zagsccl_srtc
        INTO lv_colc
        WHERE collector_id = 'QUAL' AND
              system_role = role.
      IF lv_extc = 2 AND lv_colc = 1.
        <fs> = 'X'.
      ELSE.
        <fs> = ''.
      ENDIF.
    ENDLOOP.
    APPEND es_entity TO et_entityset.

    es_entity-scenario = 'References'.

    LOOP AT r_descr->components INTO ls_comp FROM 2.
      ASSIGN COMPONENT sy-tabix OF STRUCTURE es_entity TO <fs>.
      role = ls_comp-name.
      SELECT COUNT( * )
        FROM zagsccl_srte
        INTO  lv_extc
        WHERE extractor_name = '/SDF/CC_REF_EXTRACT_EFWK' AND system_role = role.

      SELECT COUNT( * )
        FROM zagsccl_srtc
        INTO lv_colc
        WHERE collector_id = 'REF' AND
              system_role = role.

      SELECT COUNT( * )
        FROM zagsccl_srtj
        INTO lv_jobc
        WHERE job_name = '/SDF/CC_REFERENCES' AND system_role = role.

      IF lv_extc = 1 AND lv_colc = 1 AND lv_jobc = 1.
        <fs> = 'X'.
      ELSE.
        <fs> = ''.
      ENDIF.
    ENDLOOP.
    APPEND es_entity TO et_entityset.

    es_entity-scenario = 'Similarity'.

    LOOP AT r_descr->components INTO ls_comp FROM 2.
      ASSIGN COMPONENT sy-tabix OF STRUCTURE es_entity TO <fs>.
      role = ls_comp-name.
      SELECT COUNT( * )
        FROM zagsccl_srte
        INTO  lv_extc
        WHERE extractor_name = 'AGS_CC_EXTRACT_SIMILARITY' AND system_role = role.

      SELECT COUNT( * )
        FROM zagsccl_srtc
        INTO lv_colc
        WHERE collector_id = 'SIMIL' AND
              system_role = role.

      SELECT COUNT( * )
        FROM zagsccl_srtj
        INTO lv_jobc
        WHERE job_name = 'EFWK JOB FOR SIMILARITY' AND system_role = role.

      IF lv_extc = 1 AND lv_colc = 1 AND lv_jobc = 1.
        <fs> = 'X'.
      ELSE.
        <fs> = ''.
      ENDIF.
    ENDLOOP.
    APPEND es_entity TO et_entityset.


    es_entity-scenario = 'SQLM'.

    LOOP AT r_descr->components INTO ls_comp FROM 2.
      ASSIGN COMPONENT sy-tabix OF STRUCTURE es_entity TO <fs>.
      role = ls_comp-name.
      SELECT COUNT( * )
        FROM zagsccl_srte
        INTO  lv_extc
        WHERE extractor_name = 'AGS_CC_SQLM_EXTRACTOR' AND system_role = role.

*      SELECT COUNT( * )
*        FROM zagsccl_srtj
*        INTO lv_jobc
*        WHERE job_name = 'RTM_PERIODIC_JOB' AND system_role = role.

      IF lv_extc = 1." and lv_jobc = 1.
        <fs> = 'X'.
      ELSE.
        <fs> = ''.
      ENDIF.
    ENDLOOP.
    APPEND es_entity TO et_entityset.

    es_entity-scenario = 'CCLM'.

    LOOP AT r_descr->components INTO ls_comp FROM 2.
      ASSIGN COMPONENT sy-tabix OF STRUCTURE es_entity TO <fs>.
      role = ls_comp-name.
      SELECT COUNT( * )
        FROM zagsccl_srte
        INTO  lv_extc
        WHERE ( extractor_name = 'AGS_CC_EXTRACT_CCITY' OR
                extractor_name = 'AGS_CC_CCLM_EXTRACT' OR
                extractor_name = 'E2E_ICIDB_EXT_CCLM' ) AND system_role = role.

      IF lv_extc = 3.
        <fs> = 'X'.
      ELSE.
        <fs> = ''.
      ENDIF.
    ENDLOOP.
    APPEND es_entity TO et_entityset.

    es_entity-scenario = 'Criticality'.

    LOOP AT r_descr->components INTO ls_comp FROM 2.
      ASSIGN COMPONENT sy-tabix OF STRUCTURE es_entity TO <fs>.
      role = ls_comp-name.
      SELECT COUNT( * )
        FROM zagsccl_srtc
        INTO lv_colc
        WHERE collector_id = 'CRIT' AND
              system_role = role.
      SELECT COUNT( * )
        FROM zagsccl_srtj
        INTO lv_jobc
        WHERE job_name = 'AGS_CC_BUSI_CRIT' AND
             system_role = role.

      IF lv_colc = 1 AND lv_jobc = 1.
        <fs> = 'X'.
      ELSE.
        <fs> = ''.
      ENDIF.
    ENDLOOP.
    APPEND es_entity TO et_entityset.

    es_entity-scenario = 'Version'.

    LOOP AT r_descr->components INTO ls_comp FROM 2.
      ASSIGN COMPONENT sy-tabix OF STRUCTURE es_entity TO <fs>.
      role = ls_comp-name.
      SELECT COUNT( * )
        FROM zagsccl_srtc
        INTO lv_colc
        WHERE collector_id = 'VERS' AND
              system_role = role.

      IF lv_colc = 1.
        <fs> = 'X'.
      ELSE.
        <fs> = ''.
      ENDIF.
    ENDLOOP.
    APPEND es_entity TO et_entityset.

  ENDMETHOD.


  METHOD bestpracticeset_update_entity.
    DATA ls_input_data LIKE er_entity.
    DATA: r_descr TYPE REF TO cl_abap_structdescr.
    DATA lt_comp TYPE abap_compdescr_tab.
    FIELD-SYMBOLS <fs> TYPE any.
    DATA role TYPE char256.
    DATA lt_srte TYPE TABLE OF zagsccl_srte.
    DATA lt_srtc TYPE TABLE OF zagsccl_srtc.
    DATA lt_srtj TYPE TABLE OF zagsccl_srtj.

    READ TABLE it_key_tab WITH KEY name = 'Scenario' INTO DATA(ls_scn).
    DATA(lv_scn) = ls_scn-value.
    TRY.
        IF lv_scn IS NOT INITIAL.
          io_data_provider->read_entry_data( IMPORTING es_data = ls_input_data ).

          r_descr ?= cl_abap_typedescr=>describe_by_data( ls_input_data ).
          APPEND LINES OF r_descr->components FROM 2 TO lt_comp.

          IF lv_scn = 'Object Inventory'.
            LOOP AT r_descr->components INTO DATA(ls_comp) FROM 2.
              ASSIGN COMPONENT sy-tabix OF STRUCTURE ls_input_data TO <fs>.
              role = ls_comp-name.
              lt_srte = VALUE #( ( system_role = role extractor_name = 'AGS_CC_OBJ_OBJ_EXTRACTOR' )
                                 ( system_role = role extractor_name = 'AGS_CC_OBJ_MOD_EXTRACTOR' )
                                 ( system_role = role extractor_name = 'AGS_CC_OBJ_ENH_EXTRACTOR' )
                                 ( system_role = role extractor_name = 'AGS_CC_OBJ_DELOBJ_EXTRACTOR' )
                                 ( system_role = role extractor_name = 'AGS_CC_OBJ_NAMESPACE_EXTRACTOR' )
                                 ( system_role = role extractor_name = 'AGS_CC_OBJ_CORE_EXTRACTOR' ) ).
              lt_srtc = VALUE #( ( system_role = role collector_id = 'CUST' )
                                 ( system_role = role collector_id = 'MODS' )
                                 ( system_role = role collector_id = 'ENHS' ) ).
              IF <fs> = 'X'.
                INSERT zagsccl_srte FROM TABLE @lt_srte ACCEPTING DUPLICATE KEYS.
                INSERT zagsccl_srtc FROM TABLE @lt_srtc ACCEPTING DUPLICATE KEYS.
              ELSE.
                DELETE FROM zagsccl_srte WHERE system_role = role AND extractor_name LIKE 'AGS_CC_OBJ%'.
                DELETE FROM zagsccl_srtc WHERE system_role = role AND
                                              ( collector_id = 'CUST' OR collector_id = 'MODS' OR collector_id = 'ENHS' ).
              ENDIF.
            ENDLOOP.
          ELSEIF lv_scn = 'Usage'.
            LOOP AT r_descr->components INTO ls_comp FROM 2.
              ASSIGN COMPONENT sy-tabix OF STRUCTURE ls_input_data TO <fs>.
              role = ls_comp-name.
              lt_srte = VALUE #( ( system_role = role extractor_name = 'AGS_CC_SCMON_EXTRACTOR' )
                                 ( system_role = role extractor_name = 'AGS_CC_SCMON_CG_EXTRACTOR' )
                                 ( system_role = role extractor_name = 'E2E_LUW_SECONDAR_EXTRACTOR_SSR' ) ).
              lt_srtc = VALUE #( ( system_role = role collector_id = 'LUSG' ) ).
              lt_srtj = VALUE #( ( system_role = role job_name = '/SDF/UPL_PERIODIC_EXT_JOB')
                                 ( system_role = role job_name = 'ABAP CALL MONITOR: COLLECT') ).
              IF <fs> = 'X'.
                INSERT zagsccl_srte FROM TABLE @lt_srte ACCEPTING DUPLICATE KEYS.
                INSERT zagsccl_srtc FROM TABLE @lt_srtc ACCEPTING DUPLICATE KEYS.
                INSERT zagsccl_srtj FROM TABLE @lt_srtj ACCEPTING DUPLICATE KEYS.
              ELSE.
                DELETE FROM zagsccl_srte WHERE system_role = role AND extractor_name LIKE 'AGS_CC_SCMON%'.
                DELETE FROM zagsccl_srtc WHERE system_role = role AND collector_id = 'LUSG'.
                DELETE FROM zagsccl_srtj WHERE system_role = role AND job_name = '/SDF/UPL_PERIODIC_JOB'
                                                                  OR  job_name = 'ABAP CALL MONITOR: COLLECT'.
              ENDIF.
            ENDLOOP.
          ELSEIF lv_scn = 'Quality'.
            LOOP AT r_descr->components INTO ls_comp FROM 2.
              ASSIGN COMPONENT sy-tabix OF STRUCTURE ls_input_data TO <fs>.
              role = ls_comp-name.
              lt_srte = VALUE #( ( system_role = role extractor_name = 'AGS_EXTRACT_ATC_RESULT_EFWK' )
                                 ( system_role = role extractor_name = 'AGS_EXTRACT_ATC_EXEMPTION_EFWK' ) ).
              lt_srtc = VALUE #( ( system_role = role collector_id = 'QUAL' ) ).
              IF <fs> = 'X'.
                INSERT zagsccl_srte FROM TABLE @lt_srte ACCEPTING DUPLICATE KEYS.
                INSERT zagsccl_srtc FROM TABLE @lt_srtc ACCEPTING DUPLICATE KEYS.
              ELSE.
                DELETE FROM zagsccl_srte WHERE system_role = role AND extractor_name LIKE 'AGS_EXTRACT_ATC%'.
                DELETE FROM zagsccl_srtc WHERE system_role = role AND collector_id = 'QUAL'.
              ENDIF.
            ENDLOOP.
          ELSEIF lv_scn = 'References'.
            LOOP AT r_descr->components INTO ls_comp FROM 2.
              ASSIGN COMPONENT sy-tabix OF STRUCTURE ls_input_data TO <fs>.
              role = ls_comp-name.
              lt_srte = VALUE #( ( system_role = role extractor_name = '/SDF/CC_REF_EXTRACT_EFWK' ) ).
              lt_srtc = VALUE #( ( system_role = role collector_id = 'REF' ) ).
              lt_srtj = VALUE #( ( system_role = role job_name = '/SDF/CC_REFERENCES' ) ).
              IF <fs> = 'X'.
                INSERT zagsccl_srte FROM TABLE @lt_srte ACCEPTING DUPLICATE KEYS.
                INSERT zagsccl_srtc FROM TABLE @lt_srtc ACCEPTING DUPLICATE KEYS.
                INSERT zagsccl_srtj FROM TABLE @lt_srtj ACCEPTING DUPLICATE KEYS.
              ELSE.
                DELETE FROM zagsccl_srte WHERE system_role = role AND extractor_name = '/SDF/CC_REF_EXTRACT_EFWK'.
                DELETE FROM zagsccl_srtc WHERE system_role = role AND collector_id = 'REF'.
                DELETE FROM zagsccl_srtj WHERE system_role = role AND job_name = '/SDF/CC_REFERENCES'.
              ENDIF.
            ENDLOOP.
          ELSEIF lv_scn = 'Similarity'.
            LOOP AT r_descr->components INTO ls_comp FROM 2.
              ASSIGN COMPONENT sy-tabix OF STRUCTURE ls_input_data TO <fs>.
              role = ls_comp-name.
              lt_srte = VALUE #( ( system_role = role extractor_name = 'AGS_CC_EXTRACT_SIMILARITY' ) ).
              lt_srtc = VALUE #( ( system_role = role collector_id = 'SIMIL' ) ).
              lt_srtj = VALUE #( ( system_role = role job_name = 'EFWK JOB FOR SIMILARITY') ).
              IF <fs> = 'X'.
                INSERT zagsccl_srte FROM TABLE @lt_srte ACCEPTING DUPLICATE KEYS.
                INSERT zagsccl_srtc FROM TABLE @lt_srtc ACCEPTING DUPLICATE KEYS.
                INSERT zagsccl_srtj FROM TABLE @lt_srtj ACCEPTING DUPLICATE KEYS.
              ELSE.
                DELETE FROM zagsccl_srte WHERE system_role = role AND extractor_name = 'AGS_CC_EXTRACT_SIMILARITY'.
                DELETE FROM zagsccl_srtc WHERE system_role = role AND collector_id = 'SIMIL'.
                DELETE FROM zagsccl_srtj WHERE system_role = role AND job_name = 'EFWK JOB FOR SIMILARITY'.
              ENDIF.
            ENDLOOP.
          ELSEIF  lv_scn = 'SQLM'.
            LOOP AT r_descr->components INTO ls_comp FROM 2.
              ASSIGN COMPONENT sy-tabix OF STRUCTURE ls_input_data TO <fs>.
              role = ls_comp-name.
              lt_srte = VALUE #( ( system_role = role extractor_name = 'AGS_CC_SQLM_EXTRACTOR' ) ).
              lt_srtj = VALUE #( ( system_role = role job_name = 'RTM_PERIODIC_JOB' ) ).
              IF <fs> = 'X'.
                INSERT zagsccl_srte FROM TABLE @lt_srte ACCEPTING DUPLICATE KEYS.
                "INSERT zagsccl_srtj FROM TABLE @lt_srtj ACCEPTING DUPLICATE KEYS.
              ELSE.
                DELETE FROM zagsccl_srte WHERE system_role = role AND extractor_name = 'AGS_CC_SQLM_EXTRACTOR'.
                "DELETE FROM zagsccl_srtj WHERE system_role = role AND job_name = 'RTM_PERIODIC_JOB'.
              ENDIF.
            ENDLOOP.
          ELSEIF lv_scn = 'CCLM'.
            LOOP AT r_descr->components INTO ls_comp FROM 2.
              ASSIGN COMPONENT sy-tabix OF STRUCTURE ls_input_data TO <fs>.
              role = ls_comp-name.
              lt_srte = VALUE #( ( system_role = role extractor_name = 'AGS_CC_EXTRACT_CCITY' )
                                 ( system_role = role extractor_name = 'AGS_CC_CCLM_EXTRACT' )
                                 ( system_role = role extractor_name = 'E2E_ICIDB_EXT_CCLM' ) ).
              IF <fs> = 'X'.
                INSERT zagsccl_srte FROM TABLE @lt_srte ACCEPTING DUPLICATE KEYS.
              ELSE.
                DELETE FROM zagsccl_srte WHERE system_role = role AND
                                              ( extractor_name = 'AGS_CC_EXTRACT_CCITY' OR
                                                extractor_name = 'AGS_CC_CCLM_EXTRACT' OR
                                                extractor_name = 'E2E_ICIDB_EXT_CCLM' ).
              ENDIF.
            ENDLOOP.
          ELSEIF lv_scn = 'Criticality'.
            LOOP AT r_descr->components INTO ls_comp FROM 2.
              ASSIGN COMPONENT sy-tabix OF STRUCTURE ls_input_data TO <fs>.
              role = ls_comp-name.
              lt_srtc = VALUE #( ( system_role = role collector_id = 'CRIT' ) ).
              lt_srtj = VALUE #( ( system_role = role job_name = 'AGS_CC_BUSI_CRIT') ).
              IF <fs> = 'X'.
                INSERT zagsccl_srtc FROM TABLE @lt_srtc ACCEPTING DUPLICATE KEYS.
                INSERT zagsccl_srtj FROM TABLE @lt_srtj ACCEPTING DUPLICATE KEYS.
              ELSE.
                DELETE FROM zagsccl_srtc WHERE system_role = role AND collector_id = 'CRIT'.
                DELETE FROM zagsccl_srtj WHERE system_role = role AND job_name = 'AGS_CC_BUSI_CRIT'.
              ENDIF.
            ENDLOOP.
          ELSEIF lv_scn = 'Version'.
            LOOP AT r_descr->components INTO ls_comp FROM 2.
              ASSIGN COMPONENT sy-tabix OF STRUCTURE ls_input_data TO <fs>.
              role = ls_comp-name.
              lt_srtc = VALUE #( ( system_role = role collector_id = 'VERS' ) ).
              IF <fs> = 'X'.
                INSERT zagsccl_srtc FROM TABLE @lt_srtc ACCEPTING DUPLICATE KEYS.
              ELSE.
                DELETE FROM zagsccl_srtc WHERE system_role = role AND collector_id = 'VERS'.
              ENDIF.
            ENDLOOP.
          ENDIF.
        ENDIF.

      CATCH cx_sy_open_sql_db.
        "do nothing
    ENDTRY.

    er_entity = ls_input_data.

  ENDMETHOD.


  METHOD get_system_status.

  IF update = 'X'.

    SELECT *
      FROM zagsccl_system
      INTO @DATA(sys_role)
      WHERE system_id = @sys_id.
    ENDSELECT.

    er_entity-system_role = sys_role-system_role.

    SELECT *
          FROM zcclm_cm_ln_lsd
          INTO TABLE @DATA(lt_local_status)
          WHERE systemid = @sys_id AND
                landscapeid = @ln_id.
    READ TABLE lt_local_status INTO DATA(ls_local_status) INDEX 1.
    er_entity-landscape_id = ls_local_status-landscapeid.
    er_entity-system_id = ls_local_status-systemid.
    er_entity-extractor_status = ls_local_status-extractorstatus.
    er_entity-collector_status = ls_local_status-collectorstatus.

    SELECT systemclient
        FROM zcclm_vl_ltos
        INTO @DATA(clnt)
        WHERE systemid = @er_entity-system_id AND
              landscapeid = @er_entity-landscape_id.
    ENDSELECT.

    er_entity-system_clnt = clnt.

    CALL METHOD cl_assist_ext_coll=>get_analys_job
      EXPORTING
        iv_sid       = er_entity-system_id   " System ID
        iv_client    = clnt   " Client
      IMPORTING
        et_activ_job = DATA(lt_activ_job) " table of AGS_CC_EXTRACTOR_S
        et_job       = DATA(lt_job). " Table of scheduling job data

    er_entity-job_status = 0.

    SELECT system_role
        FROM zagsccl_system
        INTO @DATA(ls_role)
        WHERE system_id = @sys_id.
    ENDSELECT.

    DATA lv_uc TYPE i VALUE 0.
    DATA lv_cc TYPE i VALUE 0.
    DATA lv_rc TYPE i VALUE 0.
    DATA lv_sc TYPE i VALUE 0.
    DATA lv_usage_type TYPE i VALUE 0.
    DATA ls_entity TYPE zags_cc_schedule_s.
    DATA lt_entityset TYPE STANDARD TABLE OF zags_cc_schedule_s.
    LOOP AT lt_job INTO DATA(ls_job).

      IF ls_job-jobname NS 'SIMIL' AND ls_job-jobname NS 'BUSI_CRIT'.
        CALL METHOD cl_assist_ext_coll=>get_rfc_destination
          EXPORTING
            system_id      = sys_id
            client         = clnt
          IMPORTING
            rfcdestination = DATA(lv_destination).
      ELSE.
        CLEAR lv_destination.
      ENDIF.

      ls_job-system_id = sys_id.
      ls_job-client = clnt.
      MOVE-CORRESPONDING ls_job TO ls_entity.

      IF ls_job-jobname CS '/SDF/UPL'.
        lv_usage_type = 1.
      ENDIF.
      IF ls_job-jobname CS 'ABAP CALL'.
        lv_usage_type = 2.
      ENDIF.

      CALL FUNCTION 'ZCCLM_CHECK_JOB'
        EXPORTING
          jobname = ls_job-jobname   " Background job name
          dest    = lv_destination
        IMPORTING
          status  = ls_entity-status.

      SELECT *
        FROM zagsccl_srtj
        INTO TABLE @DATA(lv_bpt)
        WHERE system_role = @ls_role.

      IF lv_usage_type = 1.
        DELETE lv_bpt WHERE job_name CS 'ABAP CALL'.
      ENDIF.

      IF lv_usage_type = 2.
        DELETE lv_bpt WHERE job_name CS '/SDF/UPL'.
      ENDIF.

      DATA lv_bpc TYPE i VALUE 0.
      LOOP AT lv_bpt INTO DATA(ls_bpt).
        IF ls_job-jobname CS ls_bpt-job_name .
          lv_bpc = lv_bpc + 1.
        ENDIF.
      ENDLOOP.
      IF lv_bpc > 0.
        ls_entity-best_practice = 0.
      ELSE.
        ls_entity-best_practice = 1.
      ENDIF.
      CLEAR lv_bpc.
      APPEND ls_entity TO lt_entityset.
    ENDLOOP.

*    SELECT *
*    FROM zagsccl_srtj
*    INTO TABLE @DATA(lt_bp_jobs)
*    WHERE system_role = @ls_role.


    LOOP AT lv_bpt INTO DATA(ls_bp_job).
      DATA lv_temp TYPE i VALUE 0.
      LOOP AT lt_job INTO ls_job.
        IF ls_job-jobname CS ls_bp_job-job_name.
          lv_temp = 1.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_temp = 0.
      CLEAR ls_entity.
        ls_entity-jobname = ls_bp_job-job_name.
        ls_entity-best_practice = 2.
      ELSE.
        lv_temp = 0.
        CONTINUE.
      ENDIF.
      APPEND ls_entity TO lt_entityset.
    ENDLOOP.

    DESCRIBE TABLE lt_job LINES DATA(lv_lines).
    DATA lv_tmp TYPE i.
    IF lv_lines <> 0.
      LOOP AT lt_entityset INTO DATA(ls_temp).
        IF ls_temp-best_practice = 0.
         IF ls_temp-status = 'E'.
           lv_tmp = 2.
         ELSEIF ls_temp-status = 'W'.
           lv_tmp = 1.
         ELSE .
           lv_tmp = 0.
         ENDIF.
        ELSEIF ls_temp-best_practice = 1.
          lv_tmp = 1.
        ELSE.
          lv_tmp = 2.
        ENDIF.
        er_entity-job_status = nmax( val1 = lv_tmp val2 = er_entity-job_status ).
        CLEAR: ls_temp.
      ENDLOOP.
    ELSE.
      er_entity-job_status = 2.
    ENDIF.


    DATA flag TYPE boolean.
    DATA lt_notes TYPE zcl_zcclm_odata_cm_mpc=>tt_note.
    flag = ''.
    CALL FUNCTION 'ZCCLM_CHECK_NOTES'
      EXPORTING
        system_id = er_entity-system_id
        isci      = flag
      CHANGING
        result    = lt_notes.
    DESCRIBE TABLE lt_notes LINES DATA(lt_count).
    IF lt_count = 0.
        er_entity-note_status = 0.
    ELSE.
      er_entity-note_status = 2.
    ENDIF.

    MODIFY zcclm_sys_stat FROM er_entity.

* NOTIFY USING EMAIL

   ELSE.

    SELECT *
        FROM ZCCLM_SYS_STAT
        INTO er_entity
        WHERE system_id = sys_id.
    ENDSELECT.

   ENDIF.

  ENDMETHOD.


  METHOD landscape_status_get_entityset.
    DATA er_entity LIKE LINE OF et_entityset.

    SELECT DISTINCT zagsccl_ltos~lnscp_id, zagsccl_lnscp~descr
      FROM zagsccl_ltos
            INNER JOIN zagsccl_lnscp ON lnscp_id = zagsccl_lnscp~id
      INTO TABLE @DATA(lt_ln).

    LOOP AT lt_ln INTO DATA(ls_ln).
      SELECT sys_id
        FROM zagsccl_ltos
        INTO TABLE @DATA(lt_sys)
        WHERE lnscp_id = @ls_ln-lnscp_id.
      LOOP AT lt_sys INTO DATA(ls_sys).
        CALL METHOD get_system_status
          EXPORTING
            sys_id    = ls_sys-sys_id  " Name of SAP System
            ln_id     = ls_ln-lnscp_id  " Name of SAP System
            update    = ''
          IMPORTING
            er_entity = DATA(er_sys_entity).
        IF er_sys_entity-note_status > er_entity-note_status.
          er_entity-note_status = er_sys_entity-note_status.
        ENDIF.
        IF er_sys_entity-job_status > er_entity-job_status.
          er_entity-job_status = er_sys_entity-job_status.
        ENDIF.
        IF er_sys_entity-extractor_status > er_entity-extractor_status.
          er_entity-extractor_status = er_sys_entity-extractor_status.
        ENDIF.
        IF er_sys_entity-collector_status > er_entity-collector_status.
          er_entity-collector_status = er_sys_entity-collector_status.
        ENDIF.
      ENDLOOP.
      er_entity-landscape_id = ls_ln-lnscp_id.
      er_entity-landscape_description = ls_ln-descr.
      APPEND er_entity TO et_entityset.
      CLEAR er_entity.
    ENDLOOP.

  ENDMETHOD.


  METHOD noteset_get_entityset.
    DATA(lt_filters) = io_tech_request_context->get_filter( )->get_filter_select_options( ).
    DATA es_entity LIKE LINE OF et_entityset.
    DATA l_count TYPE i.
    DATA flag TYPE boolean.
    DATA sid TYPE sysysid.

    READ TABLE lt_filters WITH TABLE KEY property = 'SID' INTO DATA(ls_sid_f).
    READ TABLE ls_sid_f-select_options INTO DATA(ls_sid) INDEX 1.

    flag = ' '.
    sid = ls_sid-low.

    CALL FUNCTION 'ZCCLM_CHECK_NOTES'
      EXPORTING
        system_id = sid
        isci      = flag
      CHANGING
        result    = et_entityset.

  ENDMETHOD.


  METHOD solman_bwset_get_entityset.
    DATA es_entity LIKE LINE OF et_entityset.
    DATA lt_scenarios TYPE TABLE OF char8.
    lt_scenarios = VALUE #( ( 'UPL' ) ( 'ATC' ) ( 'CCREF' ) ( 'SQLM' ) ( 'CCLM' ) ).

    LOOP AT lt_scenarios INTO es_entity-scenario.
      DATA scenario_str TYPE string.
      scenario_str = es_entity-scenario.
      CALL METHOD cl_assist_ext_coll=>check_bw
        EXPORTING
          iv_scenario = scenario_str
        IMPORTING
          ev_active   = es_entity-is_active.
      APPEND es_entity TO et_entityset.
    ENDLOOP.
  ENDMETHOD.


  METHOD solman_jobset_get_entityset.
    DATA es_entity LIKE LINE OF et_entityset.
    DATA lt_jobs TYPE TABLE OF tbtco.
    DATA lt_names TYPE TABLE OF char0032.
    lt_names = VALUE #( ( 'SM:SCMON_CONTROL' ) ( 'SM:SCMON_UPLOAD_STATUS_HK' ) ( 'SM_CCL_COLLECTOR_MONITORING_JOB' ) ( 'SM:AGS_CC_BUSI_CRIT_AVAIL' ) ( 'SM:RAGS_CCM_HK_TRIGGER' ) ( 'SM:AGS_CCM_CCREF_HK' ) ( 'E2E BI HOUSEKEEPING' )
 ).

    LOOP AT lt_names INTO es_entity-jobname.
      SELECT jobname, sdlstrtdt, sdlstrttm, prdmins, prdhours, prddays, prdweeks, prdmonths, status
        FROM tbtco
        INTO CORRESPONDING FIELDS OF TABLE @lt_jobs
        WHERE jobname = @es_entity-jobname.
      SORT lt_jobs DESCENDING STABLE BY sdlstrtdt sdlstrttm.

      READ TABLE lt_jobs  INTO DATA(ls_last_job) INDEX 1.
      READ TABLE lt_jobs  INTO DATA(ls_prev_job) INDEX 2.

      IF ( ls_last_job-status = 'S' OR ls_last_job-status = 'P' OR ls_last_job-status = 'F' ) AND ls_prev_job-status <> 'A'.
        es_entity-status = 'S'.
      ELSE.
        es_entity-status = 'E'.
      ENDIF.

      DATA(date) = ls_last_job-sdlstrtdt.
      DATA(time) = ls_last_job-sdlstrttm.
      DATA(sec) = substring( val = time off = 4 len = 2 ).
      DATA(min) = substring( val = time off = 2 len = 2 ).
      DATA(hou) = substring( val = time off = 0 len = 2 ).
      DATA(day) = substring( val = date off = 6 len = 2 ).
      DATA(mon) = substring( val = date off = 4 len = 2 ).
      DATA(yea) = substring( val = date off = 0 len = 4 ).
      CONCATENATE hou ':' min ':' sec ' ' day '/' mon '/' yea INTO es_entity-start RESPECTING BLANKS.

      es_entity-period = CONV i( ls_last_job-prdmins ) +
                         CONV i( ls_last_job-prdhours ) * 60 +
                         CONV i( ls_last_job-prddays ) * 24 * 60 +
                         CONV i( ls_last_job-prdweeks ) * 7 * 24 * 60 +
                         CONV i( ls_last_job-prdmonths ) * 4 * 7 * 24 * 60.
      APPEND es_entity TO et_entityset.
      CLEAR ls_last_job.
      CLEAR ls_prev_job.
    ENDLOOP.
  ENDMETHOD.


  METHOD solman_job_runse_get_entity.
**TRY.
*CALL METHOD SUPER->SOLMAN_JOB_RUNSE_GET_ENTITY
*  EXPORTING
*    IV_ENTITY_NAME          =
*    IV_ENTITY_SET_NAME      =
*    IV_SOURCE_NAME          =
*    IT_KEY_TAB              =
**    IO_REQUEST_OBJECT       =
**    IO_TECH_REQUEST_CONTEXT =
*    IT_NAVIGATION_PATH      =
**  IMPORTING
**    ER_ENTITY               =
**    ES_RESPONSE_CONTEXT     =
*    .
** CATCH /IWBEP/CX_MGW_BUSI_EXCEPTION .
** CATCH /IWBEP/CX_MGW_TECH_EXCEPTION .
**ENDTRY.
  ENDMETHOD.


  METHOD solman_job_runse_get_entityset.
    DATA(lt_filters) = io_tech_request_context->get_filter( )->get_filter_select_options( ).
    READ TABLE lt_filters WITH TABLE KEY property = 'JOBNAME' INTO DATA(ls_name).
    READ TABLE ls_name-select_options INTO DATA(ls_name_so) INDEX 1.
    DATA(lv_jobname) = ls_name_so-low.
    DATA es_entity LIKE LINE OF et_entityset.

    SELECT jobname, strtdate, strttime, enddate, endtime , status
            FROM tbtco
            INTO TABLE @DATA(lt_entityset)
            WHERE jobname = @lv_jobname AND  status <> 'S' AND status <> 'P'.
    SORT lt_entityset DESCENDING STABLE BY strtdate strttime.

    LOOP AT lt_entityset INTO DATA(ls_entity).
      CLEAR es_entity.
      es_entity-jobname = ls_entity-jobname.
      es_entity-status = ls_entity-status.
      DATA(date) = ls_entity-strtdate.
      DATA(time) = ls_entity-strttime.
      DATA(sec) = substring( val = time off = 4 len = 2 ).
      DATA(min) = substring( val = time off = 2 len = 2 ).
      DATA(hou) = substring( val = time off = 0 len = 2 ).
      DATA(day) = substring( val = date off = 6 len = 2 ).
      DATA(mon) = substring( val = date off = 4 len = 2 ).
      DATA(yea) = substring( val = date off = 0 len = 4 ).
      CONCATENATE hou ':' min ':' sec ' ' day '/' mon '/' yea INTO es_entity-start RESPECTING BLANKS.

      es_entity-period = ( ls_entity-enddate - date ) * 24 * 60 * 60 +
                         ls_entity-endtime - time.
      APPEND es_entity TO et_entityset.
    ENDLOOP.
  ENDMETHOD.


  METHOD solman_noteset_get_entityset.

    DATA l_count TYPE i.
    DATA flag TYPE boolean.
    DATA sid TYPE sysysid.


    flag = 'X'.
    sid = sy-sysid.

    CALL FUNCTION 'ZCCLM_CHECK_NOTES'
      EXPORTING
        system_id = sid
        isci      = flag
      CHANGING
        result    = et_entityset.

  ENDMETHOD.


  METHOD system_statusset_get_entity.

    READ TABLE it_key_tab INTO DATA(ls_sys) WITH KEY name = 'Systemid'.
    READ TABLE it_key_tab INTO DATA(ls_ln) WITH KEY name = 'Landscapeid'.

    CALL METHOD get_system_status
      EXPORTING
        sys_id    = CONV system_id( ls_sys-value )
        ln_id     = CONV system_id( ls_ln-value )
        update    = 'X'
      IMPORTING
        er_entity = er_entity.


  ENDMETHOD.


  METHOD system_statusset_get_entityset.
    DATA(lt_filters) = io_tech_request_context->get_filter( )->get_filter_select_options( ).

    READ TABLE lt_filters WITH TABLE KEY property = 'LANDSCAPE_ID' INTO DATA(ls_filter_ln).
    IF sy-subrc = 0.
      SELECT *
        FROM zagsccl_ltos
        INTO TABLE @DATA(lt_systems)
        WHERE lnscp_id IN @ls_filter_ln-select_options.
    ELSE.
      SELECT *
          FROM zagsccl_ltos
          INTO TABLE @lt_systems.
    ENDIF.

    LOOP AT lt_systems INTO DATA(ls_system).
      CALL METHOD get_system_status
        EXPORTING
          sys_id    = ls_system-sys_id   " Name of SAP System
          ln_id     = ls_system-lnscp_id   " Name of SAP System
          update    = ''
        IMPORTING
          er_entity = DATA(er_entity).
      APPEND er_entity TO et_entityset.
    ENDLOOP.
  ENDMETHOD.


  METHOD update_all_systems.
    DATA lt_mails TYPE TABLE OF zcclm_ls_mail.

    SELECT DISTINCT lnscp_id, sys_id
        FROM zagsccl_ltos
        INTO TABLE @DATA(lt_systems).

    LOOP AT lt_systems INTO DATA(ls_system).
      CALL METHOD get_system_status
        EXPORTING
          sys_id    = ls_system-sys_id   " Name of SAP System
          ln_id     = ls_system-lnscp_id   " Name of SAP System
          update    = 'X'
        IMPORTING
          er_entity = DATA(temp).

      IF temp-note_status > 0 OR temp-job_status > 0 OR temp-extractor_status > 0 OR temp-collector_status > 0.
        SELECT *
          FROM zcclm_ls_mail
          INTO TABLE @DATA(lt_temp)
          WHERE lnscp_id = @ls_system-lnscp_id.
        APPEND LINES OF lt_temp TO lt_mails.
      ENDIF.
    ENDLOOP.

    SORT lt_mails BY mail.
    DELETE ADJACENT DUPLICATES FROM lt_mails COMPARING mail.

    TRY.
        DATA:
          gv_mlrec         TYPE so_obj_nam,
          gv_sent_to_all   TYPE os_boolean,
          gv_email         TYPE adr6-smtp_addr,
          gv_subject       TYPE so_obj_des,
          gv_text          TYPE bcsy_text,
          gr_send_request  TYPE REF TO cl_bcs,
          gr_bcs_exception TYPE REF TO cx_bcs,
          gr_recipient     TYPE REF TO if_recipient_bcs,
          gr_sender        TYPE REF TO cl_sapuser_bcs,
          gr_document      TYPE REF TO cl_document_bcs.

        gr_send_request = cl_bcs=>create_persistent( ).

        "Email FROM...
        gr_sender = cl_sapuser_bcs=>create( sy-uname ).
        "Add sender to send request
        CALL METHOD gr_send_request->set_sender
          EXPORTING
            i_sender = gr_sender.

        LOOP AT lt_mails INTO DATA(ls_mail).
          gv_email = ls_mail-mail.
          gr_recipient = cl_cam_address_bcs=>create_internet_address( gv_email ).
          "Add recipient to send request
          CALL METHOD gr_send_request->add_recipient
            EXPORTING
              i_recipient = gr_recipient
              i_express   = 'X'.

        ENDLOOP.

        "Email BODY
        CONCATENATE 'CCLM Consistency Monitor indicated one or more landscapes with failures in CCLM configuration.'
                    CL_ABAP_CHAR_UTILITIES=>NEWLINE
                    'Please refer to Consistency Monitor for validation.'
                    CL_ABAP_CHAR_UTILITIES=>NEWLINE
                    'To unsubscribe from emails adjust email list in Virtual Landscapes Cockpit' INTO DATA(lv_temp_text).
        APPEND lv_temp_text TO gv_text.
        gr_document = cl_document_bcs=>create_document(
                        i_type    = 'RAW'
                        i_text    = gv_text
                        i_length  = '200'
                        i_subject = 'CCLM Consistency Monitor Alert' ).
        "Add document to send request
        CALL METHOD gr_send_request->set_document( gr_document ).
        "Send email
        CALL METHOD gr_send_request->send(
          EXPORTING
            i_with_error_screen = 'X'
          RECEIVING
            result              = gv_sent_to_all ).

        "Commit to send email
        COMMIT WORK.

        "Exception handling
      CATCH cx_bcs INTO gr_bcs_exception.
        WRITE:
          'Error!',
          'Error type:',
          gr_bcs_exception->error_type.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
