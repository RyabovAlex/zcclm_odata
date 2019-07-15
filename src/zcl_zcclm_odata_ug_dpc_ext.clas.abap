class ZCL_ZCCLM_ODATA_UG_DPC_EXT definition
  public
  inheriting from ZCL_ZCCLM_ODATA_UG_DPC
  create public .

public section.
protected section.

  methods BW_MONTHSET_GET_ENTITYSET
    redefinition .
  methods BW_WEEKSET_GET_ENTITYSET
    redefinition .
  methods BW_YEARSET_GET_ENTITYSET
    redefinition .
  methods CONFIGSET_GET_ENTITYSET
    redefinition .
  methods DSO_DAYSET_GET_ENTITYSET
    redefinition .
  methods DSO_MONTHSET_GET_ENTITYSET
    redefinition .
  methods DSO_WEEKSET_GET_ENTITYSET
    redefinition .
  methods DSO_YEARSET_GET_ENTITYSET
    redefinition .
  methods SYSTEMSET_GET_ENTITYSET
    redefinition .
private section.
ENDCLASS.



CLASS ZCL_ZCCLM_ODATA_UG_DPC_EXT IMPLEMENTATION.


  METHOD bw_monthset_get_entityset.
    DATA(lt_filters) = io_tech_request_context->get_filter( )->get_filter_select_options( ).
    READ TABLE lt_filters WITH TABLE KEY property = 'SYSTEM_ID' INTO DATA(ls_sys_id_filter).
    IF sy-subrc EQ 0.
      READ TABLE ls_sys_id_filter-select_options INTO DATA(ls_so) INDEX 1.
      DATA(lv_sys_id) = ls_so-low.

      DATA:
        g_s_sfc   TYPE rsdri_s_sfc,   "G_S_SFC  = description of a characteristic or navigational attribute that is requested by a query
        g_th_sfc  TYPE rsdri_th_sfc,
        g_s_sfk   TYPE rsdri_s_sfk,   "G_S_SFK  = description of a key figure that is requested by a query
        g_th_sfk  TYPE rsdri_th_sfk,
        g_s_range TYPE rsdri_s_range, "G_S_RANGE = description of a restriction on a characteristic or navigational attribute
        g_t_range TYPE rsdri_t_range.


      TYPES:
        BEGIN OF gt_s_data,
          smd_lsid(8) TYPE c, " System name
          calmonth(6) TYPE n, " Calendar Year/Month
        END OF gt_s_data.

      DATA: lv_msg TYPE string.
      DATA: g_s_data TYPE gt_s_data,
            g_t_data TYPE TABLE OF gt_s_data. " G_T_DATA = an internal table that can hold the result set
      DATA: g_end_of_data TYPE rs_bool,
            g_first_call  TYPE rs_bool.
      DATA: es_entityset LIKE LINE OF et_entityset.



      g_end_of_data = rs_c_false.
      g_first_call  = rs_c_true.
      CLEAR g_th_sfc.

* System
      CLEAR g_s_sfc.
      g_s_sfc-chanm    = '0SMD_LSID'.     " name of characteristic
      g_s_sfc-chaalias = 'SMD_LSID'.     " name of corresponding column in G_T_DATA
      g_s_sfc-orderby  = 0.               " no ORDER-BY
      INSERT g_s_sfc INTO TABLE g_th_sfc. " include into list of characteristics


* Available calendar months
      CLEAR g_s_sfc.
      g_s_sfc-chanm    = '0CALMONTH'.
      g_s_sfc-chaalias = 'CALMONTH'.
      g_s_sfc-orderby  = 0.
      INSERT g_s_sfc INTO TABLE g_th_sfc.


* These are the restrictions:
      CLEAR g_t_range.
      CLEAR g_s_range.

      g_s_range-chanm    = '0SMD_LSID'.
      g_s_range-sign     = rs_c_range_sign-including.
      g_s_range-compop   = rs_c_range_opt-equal.
      g_s_range-low      = lv_sys_id.
      APPEND g_s_range TO g_t_range.

      WHILE g_end_of_data = rs_c_false.

        CALL FUNCTION 'RSDRI_INFOPROV_READ'
          EXPORTING
            i_infoprov             = '0SM_UPL_M'
            i_th_sfc               = g_th_sfc
            i_th_sfk               = g_th_sfk
            i_t_range              = g_t_range
            i_reference_date       = sy-datum
            i_save_in_table        = rs_c_false
            i_save_in_file         = rs_c_false
            i_packagesize          = 10000000
     "      i_authority_check      = rsdrc_c_authchk-read
          IMPORTING
            e_t_data               = g_t_data
            e_end_of_data          = g_end_of_data
          CHANGING
            c_first_call           = g_first_call
          EXCEPTIONS
            illegal_input          = 1
            illegal_input_sfc      = 2
            illegal_input_sfk      = 3
            illegal_input_range    = 4
            illegal_input_tablesel = 5
            no_authorization       = 6
            illegal_download       = 8
            illegal_tablename      = 9
            OTHERS                 = 11.

        IF sy-subrc <> 0.
          MESSAGE 'BW cube 0SM_UPL_M was not read successfully' TYPE 'E'.
          EXIT.
        ELSE.
          DESCRIBE TABLE g_t_data LINES DATA(lv_lines).
        ENDIF.

      ENDWHILE.

      IF lv_lines NE 0.

        SORT g_t_data BY calmonth.
        READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data_first>) INDEX 1.
        READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data_last>)  INDEX lv_lines.

        "DATA: lv_first_month TYPE n.
        DATA(lv_first_month) = <fs_t_data_first>-calmonth.
        "DATA: lv_last_month  TYPE n.
        "DATA(lv_last_month)  = <fs_t_data_last>-calmonth.
        DATA(lv_last_month)  = sy-datum(6).

        IF lv_last_month+4(2) < lv_first_month+4(2).
          DATA(s_m) = 12 - lv_first_month+4(2).
          "      DATA(e_m) = lv_last_month+4(2).
          DATA(e_m) = lv_last_month+4(2) - 01.
          DATA(number_of_months) = s_m + e_m + 1.
        ELSE.
          number_of_months = lv_last_month+4(2) - lv_first_month+4(2).
        ENDIF.

        " DATA(number_of_months) = lv_last_month - lv_first_month.


        DATA: BEGIN OF ls_months,
                calmonth(6) TYPE c,
                avail(1)    TYPE c,
              END OF ls_months.

        DATA: lt_months LIKE TABLE OF ls_months.
        DATA: current_month(6) TYPE c.

        current_month = lv_first_month.

        DO number_of_months TIMES.
          es_entityset-months = current_month.
          es_entityset-system_id = <fs_t_data_first>-smd_lsid.  "think about it later!!!
          READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data>) WITH  KEY calmonth = current_month BINARY SEARCH.
          IF sy-subrc = 0.
            es_entityset-availability = 'X'.
          ENDIF.
          APPEND es_entityset TO et_entityset.
          IF current_month+4(2) < 12.
            ADD 1 TO current_month.
          ELSEIF current_month+4(2) = 12.
            ADD 1 TO current_month+3(1).
            current_month+4(2) = '01'.
          ENDIF.
          CLEAR es_entityset.
        ENDDO.

        loop at et_entityset into es_entityset.

        endloop.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD bw_weekset_get_entityset.
    DATA(lt_filters) = io_tech_request_context->get_filter( )->get_filter_select_options( ).
    READ TABLE lt_filters WITH TABLE KEY property = 'SYSTEM_ID' INTO DATA(ls_sys_id_filter).
    IF sy-subrc EQ 0.
      READ TABLE ls_sys_id_filter-select_options INTO DATA(ls_so) INDEX 1.
      DATA(lv_sys_id) = ls_so-low.
    ENDIF.


    DATA:
      g_s_sfc   TYPE rsdri_s_sfc, "G_S_SFC  = description of a characteristic or navigational attribute that is requested by a query
      g_th_sfc  TYPE rsdri_th_sfc,
      g_s_sfk   TYPE rsdri_s_sfk, "G_S_SFK  = description of a key figure that is requested by a query
      g_th_sfk  TYPE rsdri_th_sfk,
      g_s_range TYPE rsdri_s_range, "G_S_RANGE = description of a restriction on a characteristic or navigational attribute
      g_t_range TYPE rsdri_t_range.


    TYPES:
      BEGIN OF gt_s_data,
        smd_lsid(8)  TYPE c, " System name
        smd_tihm(12) TYPE n, " Time (yyyyMMddhhmm)
        calweek(6)   TYPE n, " Calendar Year/Month
      END OF gt_s_data.

    DATA: lv_msg TYPE string.
    DATA: g_s_data TYPE gt_s_data,
          g_t_data TYPE TABLE OF gt_s_data. " G_T_DATA = an internal table that can hold the result set
    DATA: g_end_of_data TYPE rs_bool,
          g_first_call  TYPE rs_bool.
    DATA: es_entityset LIKE LINE OF et_entityset.



    g_end_of_data = rs_c_false.
    g_first_call  = rs_c_true.
    CLEAR g_th_sfc.

* System
    CLEAR g_s_sfc.
    g_s_sfc-chanm    = '0SMD_LSID'.     " name of characteristic
    g_s_sfc-chaalias = 'SMD_LSID'.     " name of corresponding column in G_T_DATA
    g_s_sfc-orderby  = 0.               " no ORDER-BY
    INSERT g_s_sfc INTO TABLE g_th_sfc. " include into list of characteristics


* Available calendar weeks
    CLEAR g_s_sfc.
    g_s_sfc-chanm    = '0CALWEEK'.
    g_s_sfc-chaalias = 'CALWEEK'.
    g_s_sfc-orderby  = 0.
    INSERT g_s_sfc INTO TABLE g_th_sfc.


* These are the restrictions:
    CLEAR g_t_range.
    CLEAR g_s_range.

    g_s_range-chanm    = '0SMD_LSID'.
    g_s_range-sign     = rs_c_range_sign-including.
    g_s_range-compop   = rs_c_range_opt-equal.
    g_s_range-low      = lv_sys_id.
    APPEND g_s_range TO g_t_range.

    WHILE g_end_of_data = rs_c_false.

      CALL FUNCTION 'RSDRI_INFOPROV_READ'
        EXPORTING
          i_infoprov             = '0SM_UPL_W'
          i_th_sfc               = g_th_sfc
          i_th_sfk               = g_th_sfk
          i_t_range              = g_t_range
          i_reference_date       = sy-datum
          i_save_in_table        = rs_c_false
          i_save_in_file         = rs_c_false
          i_packagesize          = 10000000
   "      i_authority_check      = rsdrc_c_authchk-read
        IMPORTING
          e_t_data               = g_t_data
          e_end_of_data          = g_end_of_data
        CHANGING
          c_first_call           = g_first_call
        EXCEPTIONS
          illegal_input          = 1
          illegal_input_sfc      = 2
          illegal_input_sfk      = 3
          illegal_input_range    = 4
          illegal_input_tablesel = 5
          no_authorization       = 6
          illegal_download       = 8
          illegal_tablename      = 9
          OTHERS                 = 11.

      IF sy-subrc <> 0.
        MESSAGE 'BW cube 0SM_UPL_W was not read successfully' TYPE 'E'.
        EXIT.
      ELSE.
        "CLEAR: lv_lines, lv_linesc, lv_msg.
        DESCRIBE TABLE g_t_data LINES DATA(lv_lines).
        IF lv_lines = 0.
          EXIT.
        ENDIF.
        "DATA lv_linesc(6) TYPE c.
        "MOVE lv_lines TO lv_linesc.
        "CONCATENATE 'Fetched from BW: ' lv_linesc  INTO lv_msg IN CHARACTER MODE.
        "MESSAGE lv_msg TYPE 'S'.
      ENDIF.

    ENDWHILE.

    IF lv_lines NE 0.

      SORT g_t_data BY calweek.
      READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data_first>) INDEX 1.
      READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data_last>)  INDEX lv_lines.

      DATA: lv_first_week TYPE scal-week.
      lv_first_week = <fs_t_data_first>-calweek.

      DATA: lv_curd TYPE scal-date.
      DATA: lv_curw TYPE scal-week.

      lv_curd = sy-datum.

      CALL FUNCTION 'DATE_GET_WEEK'
        EXPORTING
          date = lv_curd
        IMPORTING
          week = lv_curw
*     EXCEPTIONS
*         DATE_INVALID       = 1
*         OTHERS             = 2
        .
      IF sy-subrc <> 0.
        MESSAGE 'wrong date format' TYPE 'I'.
      ELSE.
        DATA: lv_last_week  TYPE scal-week. lv_last_week  = lv_curw.
      ENDIF.

      IF lv_last_week(4) > lv_first_week(4). "compare years
        DATA(s_w) = 52 - lv_first_week+4(2).
        DATA(e_w) = lv_last_week+4(2) - 01.
        DATA(number_of_weeks) = s_w + e_w + 1.
      ELSE.
        number_of_weeks = ( lv_last_week - lv_first_week ).
      ENDIF.



      DATA: BEGIN OF ls_weeks,
              calweek(6) TYPE c,
              avail(1)   TYPE c,
            END OF ls_weeks.

      DATA: lt_weeks LIKE TABLE OF ls_weeks.
      DATA: current_week TYPE scal-week.

      current_week = <fs_t_data_first>-calweek.

      SELECT SINGLE deletor_id FROM e2e_bi_delete INTO @DATA(id) WHERE infoobject = '0SMD_LSID' AND low = @lv_sys_id.
      SELECT target_cube, low FROM e2e_bi_delete INTO TABLE @DATA(lt_hk_conf) WHERE deletor_id = @id.

      READ TABLE lt_hk_conf INTO DATA(ls_sys_hk_day) WITH KEY target_cube = '0SM_UPL_W'.
      IF ls_sys_hk_day-low IS INITIAL.
        "es_entityset-tbaggregated = 'Not defined'.
      ELSE.
        DATA: lv_0 TYPE string.
        lv_0 = ls_sys_hk_day-low.
        SPLIT lv_0 AT '=' INTO DATA(lv_1) DATA(lv_2).
        SPLIT lv_2 AT '$' INTO DATA(hk_days) DATA(lv_3).
      ENDIF.

      DATA del_days TYPE i.
      MOVE hk_days TO del_days.
      DATA lv_date TYPE dats.


      DO number_of_weeks TIMES.
        es_entityset-weeks = current_week.
        es_entityset-system_id = <fs_t_data_first>-smd_lsid.  "think about it later!!!
        READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data>) WITH  KEY calweek = current_week BINARY SEARCH.
        IF sy-subrc = 0.
          es_entityset-availability = 'X'.
        ENDIF.

        "MOVE current_week TO lv_date.
        IF ( sy-datum(6) - current_week(6) ) > del_days.
          es_entityset-tbdeleted = 'X'   .
        ENDIF.

        APPEND es_entityset TO et_entityset.

        IF current_week+4(2) < 52.
          ADD 1 TO current_week.
        ELSEIF current_week+4(2) = 52.
          ADD 1 TO current_week+3(1).
          current_week+4(2) = '01'.
        ENDIF.

        CLEAR es_entityset.
      ENDDO.
    ENDIF.
  ENDMETHOD.


  METHOD bw_yearset_get_entityset.
    DATA(lt_filters) = io_tech_request_context->get_filter( )->get_filter_select_options( ).
    READ TABLE lt_filters WITH TABLE KEY property = 'SYSTEM_ID' INTO DATA(ls_sys_id_filter).
    IF sy-subrc EQ 0.
      READ TABLE ls_sys_id_filter-select_options INTO DATA(ls_so) INDEX 1.
      DATA(lv_sys_id) = ls_so-low.

      DATA:
        g_s_sfc   TYPE rsdri_s_sfc,   "G_S_SFC  = description of a characteristic or navigational attribute that is requested by a query
        g_th_sfc  TYPE rsdri_th_sfc,
        g_s_sfk   TYPE rsdri_s_sfk,   "G_S_SFK  = description of a key figure that is requested by a query
        g_th_sfk  TYPE rsdri_th_sfk,
        g_s_range TYPE rsdri_s_range, "G_S_RANGE = description of a restriction on a characteristic or navigational attribute
        g_t_range TYPE rsdri_t_range.


      TYPES:
        BEGIN OF gt_s_data,
          smd_lsid(8) TYPE c, " System name
          calyear(4) TYPE n, " Calendar Year/Month
        END OF gt_s_data.

      DATA: lv_msg TYPE string.
      DATA: g_s_data TYPE gt_s_data,
            g_t_data TYPE TABLE OF gt_s_data. " G_T_DATA = an internal table that can hold the result set
      DATA: g_end_of_data TYPE rs_bool,
            g_first_call  TYPE rs_bool.
      DATA: es_entityset LIKE LINE OF et_entityset.



      g_end_of_data = rs_c_false.
      g_first_call  = rs_c_true.
      CLEAR g_th_sfc.

* System
      CLEAR g_s_sfc.
      g_s_sfc-chanm    = '0SMD_LSID'.     " name of characteristic
      g_s_sfc-chaalias = 'SMD_LSID'.     " name of corresponding column in G_T_DATA
      g_s_sfc-orderby  = 0.               " no ORDER-BY
      INSERT g_s_sfc INTO TABLE g_th_sfc. " include into list of characteristics


* Available calendar months
      CLEAR g_s_sfc.
      g_s_sfc-chanm    = '0CALYEAR'.
      g_s_sfc-chaalias = 'CALYEAR'.
      g_s_sfc-orderby  = 0.
      INSERT g_s_sfc INTO TABLE g_th_sfc.


* These are the restrictions:
      CLEAR g_t_range.
      CLEAR g_s_range.

      g_s_range-chanm    = '0SMD_LSID'.
      g_s_range-sign     = rs_c_range_sign-including.
      g_s_range-compop   = rs_c_range_opt-equal.
      g_s_range-low      = lv_sys_id.
      APPEND g_s_range TO g_t_range.

      WHILE g_end_of_data = rs_c_false.

        CALL FUNCTION 'RSDRI_INFOPROV_READ'
          EXPORTING
            i_infoprov             = '0SM_UPL_Y'
            i_th_sfc               = g_th_sfc
            i_th_sfk               = g_th_sfk
            i_t_range              = g_t_range
            i_reference_date       = sy-datum
            i_save_in_table        = rs_c_false
            i_save_in_file         = rs_c_false
            i_packagesize          = 10000000
     "      i_authority_check      = rsdrc_c_authchk-read
          IMPORTING
            e_t_data               = g_t_data
            e_end_of_data          = g_end_of_data
          CHANGING
            c_first_call           = g_first_call
          EXCEPTIONS
            illegal_input          = 1
            illegal_input_sfc      = 2
            illegal_input_sfk      = 3
            illegal_input_range    = 4
            illegal_input_tablesel = 5
            no_authorization       = 6
            illegal_download       = 8
            illegal_tablename      = 9
            OTHERS                 = 11.

        IF sy-subrc <> 0.
          MESSAGE 'BW cube 0SM_UPL_Y was not read successfully' TYPE 'E'.
          EXIT.
        ELSE.
          "CLEAR: lv_lines, lv_linesc, lv_msg.
          DESCRIBE TABLE g_t_data LINES DATA(lv_lines).
          "DATA lv_linesc(6) TYPE c.
          "MOVE lv_lines TO lv_linesc.
          "CONCATENATE 'Fetched from BW: ' lv_linesc  INTO lv_msg IN CHARACTER MODE.
          "MESSAGE lv_msg TYPE 'S'.
        ENDIF.

      ENDWHILE.

      IF lv_lines NE 0.

        SORT g_t_data BY calyear.
        READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data_first>) INDEX 1.
        READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data_last>)  INDEX lv_lines.

        DATA(lv_first_year) = <fs_t_data_first>-calyear.
        DATA(lv_last_year)  = sy-datum(4).

        data(number_of_years) = lv_last_year - lv_first_year.

        DATA: current_year(4) TYPE c.

        current_year = lv_first_year.

        DO number_of_years TIMES.
          es_entityset-years = current_year.
          es_entityset-system_id = <fs_t_data_first>-smd_lsid.  "think about it later!!!
          READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data>) WITH  KEY calyear = current_year.
          IF sy-subrc = 0.
            es_entityset-availability = 'X'.
          ENDIF.
          APPEND es_entityset TO et_entityset.
            ADD 1 TO current_year.
          CLEAR es_entityset.
        ENDDO.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD configset_get_entityset.

    DATA(lt_filters) = io_tech_request_context->get_filter( )->get_filter_select_options( ).
    DATA: es_entityset LIKE LINE OF et_entityset.


    READ TABLE lt_filters WITH TABLE KEY property = 'SYSTEM_ID' INTO DATA(ls_sys_id_filter).
    IF sy-subrc EQ 0.
      READ TABLE ls_sys_id_filter-select_options INTO DATA(ls_so) INDEX 1.
      DATA(lv_sys_id) = ls_so-low.
    ENDIF.

    SELECT * FROM ags_cc_custom INTO TABLE @DATA(lt_cc_custom).

    select parameter_key, parameter_value from AGS_UPL_SETTING INTO TABLE @DATA(lt_ags_upl_setting) where SYSTEM_ID = @lv_sys_id.

    SELECT single deletor_id FROM e2e_bi_delete INTO @DATA(id) WHERE infoobject = '0SMD_LSID' AND low = @lv_sys_id.

    SELECT target_cube, low FROM e2e_bi_delete INTO TABLE @DATA(lt_hk_conf) WHERE deletor_id = @id.

    "-----Daily data-----"
    es_entityset-system_id = lv_sys_id.
    es_entityset-granularity = 'Day'.
    es_entityset-aggregation = 'Not relevant'.

    READ TABLE lt_cc_custom INTO DATA(lv_sdef_hk_day) WITH KEY cc_key = 'SAP_UPL_HK_DAY' TRANSPORTING cc_content.
    IF lv_sdef_hk_day IS INITIAL.
        es_entityset-sap_hk = 'Not defined'.
      ELSE.
        CONDENSE lv_sdef_hk_day.
        es_entityset-sap_hk = lv_sdef_hk_day.
    ENDIF.


    READ TABLE lt_cc_custom INTO DATA(lv_cdef_hk_day) WITH KEY cc_key = 'CUST_UPL_HK_DAY' TRANSPORTING cc_content.
    IF lv_cdef_hk_day IS INITIAL.
      es_entityset-cust_hk = 'Not defined'.
    ELSE.
      CONDENSE lv_cdef_hk_day.
      es_entityset-cust_hk = lv_cdef_hk_day.
    ENDIF.

    READ TABLE lt_hk_conf INTO data(ls_sys_hk_day) WITH KEY target_cube = '0SM_UPLDD'.
    IF ls_sys_hk_day-low IS INITIAL.
      es_entityset-cursys_hk = 'Not defined'.
    ELSE.
      data: lV_0 type string.
      lv_0 = ls_sys_hk_day-low.
      SPLIT lv_0 AT '=' INTO DATA(lv_1) DATA(lv_2).
      SPLIT lv_2 AT '$' INTO es_entityset-cursys_hk DATA(lv_3).
    ENDIF.

    APPEND es_entityset TO et_entityset.
    CLEAR: lv_0, lv_1, lv_2, lv_3, ls_sys_hk_day, es_entityset.


    "-----Weekly data-----"
    es_entityset-system_id = lv_sys_id.
    es_entityset-granularity = 'Week'.

    READ TABLE lt_ags_upl_setting INTO DATA(lv_tg_week) WITH KEY parameter_key = 'UPL_WEEK_ACTIVE' TRANSPORTING parameter_value.

    IF lv_tg_week IS INITIAL.
      es_entityset-aggregation = 'Not defined'.
    ELSE.
      "CONDENSE lv_tg_week.
      "es_entityset-aggregation = lv_tg_week.
      es_entityset-aggregation = 'Active'.
    ENDIF.


    READ TABLE lt_cc_custom INTO DATA(lv_sdef_hk_week) WITH KEY cc_key = 'SAP_UPL_HK_WEEK' TRANSPORTING cc_content.
    IF lv_sdef_hk_week IS INITIAL.
      es_entityset-sap_hk = 'Not defined'.
    ELSE.
      CONDENSE lv_sdef_hk_week.
      es_entityset-sap_hk = lv_sdef_hk_week.
    ENDIF.


    READ TABLE lt_cc_custom INTO DATA(lv_cdef_hk_week) WITH KEY cc_key = 'CUST_UPL_HK_WEEK' TRANSPORTING cc_content.
    IF lv_cdef_hk_week IS INITIAL.
      es_entityset-cust_hk = 'Not defined'.
    ELSE.
      CONDENSE lv_cdef_hk_week.
      es_entityset-cust_hk = lv_cdef_hk_week.
    ENDIF.


    READ TABLE lt_hk_conf INTO ls_sys_hk_day WITH KEY target_cube = '0SM_UPL_W'.
    IF ls_sys_hk_day-low IS INITIAL.
      es_entityset-cursys_hk = 'Not defined'.
    ELSE.
      lv_0 = ls_sys_hk_day-low.
      SPLIT lv_0 AT '=' INTO lv_1 lv_2.
      SPLIT lv_2 AT '$' INTO es_entityset-cursys_hk lv_3.
    ENDIF.

    APPEND es_entityset TO et_entityset.
    CLEAR: lv_0, lv_1, lv_2, lv_3, ls_sys_hk_day, es_entityset.

    "-----Monthly data-----"
    es_entityset-system_id = lv_sys_id.
    es_entityset-granularity = 'Month'.
    READ TABLE lt_ags_upl_setting INTO DATA(lv_tg_month) WITH KEY parameter_key = 'UPL_MONTH_ACTIVE' TRANSPORTING parameter_value.
    IF lv_tg_month IS INITIAL.
        es_entityset-aggregation = 'Not defined'.
    ELSE.
        "CONDENSE lv_tg_month.
        "es_entityset-aggregation = lv_tg_month.
        es_entityset-aggregation = 'Active'.
    ENDIF.

    READ TABLE lt_cc_custom INTO DATA(lv_sdef_hk_month) WITH KEY cc_key = 'SAP_UPL_HK_MONTH' TRANSPORTING cc_content.
    IF lv_sdef_hk_month IS INITIAL.
      es_entityset-sap_hk = 'Not defined'.
    ELSE.
      CONDENSE lv_sdef_hk_month.
      es_entityset-sap_hk = lv_sdef_hk_month.
    ENDIF.

    READ TABLE lt_cc_custom INTO DATA(lv_cdef_hk_month) WITH KEY cc_key = 'CUST_UPL_HK_MONTH' TRANSPORTING cc_content.
    IF lv_cdef_hk_month IS INITIAL.
      es_entityset-cust_hk = 'Not defined'.
    ELSE.
      CONDENSE lv_cdef_hk_month.
      es_entityset-cust_hk = lv_cdef_hk_month.
    ENDIF.

    READ TABLE lt_hk_conf INTO ls_sys_hk_day WITH KEY target_cube = '0SM_UPL_M'.
    IF ls_sys_hk_day-low IS INITIAL.
      es_entityset-cursys_hk = 'Not defined'.
    ELSE.
      lv_0 = ls_sys_hk_day-low.
      SPLIT lv_0 AT '=' INTO lv_1 lv_2.
      SPLIT lv_2 AT '$' INTO es_entityset-cursys_hk lv_3.
    ENDIF.


    APPEND es_entityset TO et_entityset.
    CLEAR: lv_0, lv_1, lv_2, lv_3, ls_sys_hk_day, es_entityset.

    "-----YEARLY data-----"
    es_entityset-system_id = lv_sys_id.
    es_entityset-granularity = 'Year'.
    READ TABLE lt_ags_upl_setting INTO DATA(lv_tg_year) WITH KEY parameter_key = 'UPL_YEAR_ACTIVE' TRANSPORTING parameter_value.
    IF lv_tg_year IS INITIAL.
      es_entityset-aggregation = 'Not defined'.
    ELSE.
      "CONDENSE lv_tg_year.
      "es_entityset-aggregation = lv_tg_year.
      es_entityset-aggregation = 'Active'.
    ENDIF.

    READ TABLE lt_cc_custom INTO DATA(lv_sdef_hk_year) WITH KEY cc_key = 'SAP_UPL_HK_YEAR' TRANSPORTING cc_content.
    IF lv_sdef_hk_year IS INITIAL.
      es_entityset-sap_hk = 'Not defined'.
    ELSE.
      CONDENSE lv_sdef_hk_year.
      es_entityset-sap_hk = lv_sdef_hk_year.
    ENDIF.


    READ TABLE lt_cc_custom INTO DATA(lv_cdef_hk_year) WITH KEY cc_key = 'CUST_UPL_HK_YEAR' TRANSPORTING cc_content.
    IF lv_cdef_hk_year IS INITIAL.
      es_entityset-cust_hk = 'Not defined'.
    ELSE.
      CONDENSE lv_cdef_hk_year.
      es_entityset-cust_hk = lv_cdef_hk_year.
    ENDIF.



    READ TABLE lt_hk_conf INTO ls_sys_hk_day WITH KEY target_cube = '0SM_UPL_Y'.
    IF ls_sys_hk_day-low IS INITIAL.
      es_entityset-cursys_hk = 'Not defined'.
    ELSE.
      lv_0 = ls_sys_hk_day-low.
      SPLIT lv_0 AT '=' INTO lv_1 lv_2.
      SPLIT lv_2 AT '$' INTO es_entityset-cursys_hk lv_3.
    ENDIF.


    APPEND es_entityset TO et_entityset.
    CLEAR: lv_0, lv_1, lv_2, lv_3, ls_sys_hk_day, es_entityset.



  ENDMETHOD.


  METHOD dso_dayset_get_entityset.
    DATA(lt_filters) = io_tech_request_context->get_filter( )->get_filter_select_options( ).
    READ TABLE lt_filters WITH TABLE KEY property = 'SYSTEM_ID' INTO DATA(ls_sys_id_filter).
    IF sy-subrc EQ 0.
      READ TABLE ls_sys_id_filter-select_options INTO DATA(ls_so) INDEX 1.
      DATA(lv_sys_id) = ls_so-low.
    ENDIF.


    DATA:
      g_s_sfc   TYPE rsdri_s_sfc, "G_S_SFC  = description of a characteristic or navigational attribute that is requested by a query
      g_th_sfc  TYPE rsdri_th_sfc,
      g_s_sfk   TYPE rsdri_s_sfk, "G_S_SFK  = description of a key figure that is requested by a query
      g_th_sfk  TYPE rsdri_th_sfk,
      g_s_range TYPE rsdri_s_range, "G_S_RANGE = description of a restriction on a characteristic or navigational attribute
      g_t_range TYPE rsdri_t_range.


    TYPES:
      BEGIN OF gt_s_data,
        smd_lsid TYPE system_id, " System name
        calday   TYPE dats, " Calendar day
        sm_cclud TYPE dats, "not needed
      END OF gt_s_data.

    DATA: lv_msg TYPE string.
    DATA: g_s_data TYPE gt_s_data,
          g_t_data TYPE TABLE OF gt_s_data. " G_T_DATA = an internal table that can hold the result set
    DATA: g_end_of_data TYPE rs_bool,
          g_first_call  TYPE rs_bool.
    DATA: es_entityset LIKE LINE OF et_entityset.



    g_end_of_data = rs_c_false.
    g_first_call  = rs_c_true.
    CLEAR g_th_sfc.

* System
    CLEAR g_s_sfc.
    g_s_sfc-chanm    = '0SMD_LSID'.     " name of characteristic
    g_s_sfc-chaalias = 'SMD_LSID'.     " name of corresponding column in G_T_DATA
    g_s_sfc-orderby  = 0.               " no ORDER-BY
    INSERT g_s_sfc INTO TABLE g_th_sfc. " include into list of characteristics

** Usage date
*    CLEAR g_s_sfc.
*    g_s_sfc-chanm    = '0SM_CCLUD'.
*    g_s_sfc-chaalias = 'SM_CCLUD'.
*    g_s_sfc-orderby  = 0.
*    INSERT g_s_sfc INTO TABLE g_th_sfc.


* UPL date
    CLEAR g_s_sfc.
    g_s_sfc-chanm    = '0CALDAY'.
    g_s_sfc-chaalias = 'CALDAY'.
    g_s_sfc-orderby  = 0.
    INSERT g_s_sfc INTO TABLE g_th_sfc.


* These are the restrictions:
    CLEAR g_t_range.
    CLEAR g_s_range.

    g_s_range-chanm    = '0SMD_LSID'.
    g_s_range-sign     = rs_c_range_sign-including.
    g_s_range-compop   = rs_c_range_opt-equal.
    g_s_range-low      = lv_sys_id.
    APPEND g_s_range TO g_t_range.

    WHILE g_end_of_data = rs_c_false.

      CALL FUNCTION 'RSDRI_INFOPROV_READ'
        EXPORTING
          i_infoprov             = '0SM_UPLDD'
          i_th_sfc               = g_th_sfc
          i_th_sfk               = g_th_sfk
          i_t_range              = g_t_range
          i_reference_date       = sy-datum
          i_save_in_table        = rs_c_false
          i_save_in_file         = rs_c_false
          i_packagesize          = 10000000
   "      i_authority_check      = rsdrc_c_authchk-read
        IMPORTING
          e_t_data               = g_t_data
          e_end_of_data          = g_end_of_data
        CHANGING
          c_first_call           = g_first_call
        EXCEPTIONS
          illegal_input          = 1
          illegal_input_sfc      = 2
          illegal_input_sfk      = 3
          illegal_input_range    = 4
          illegal_input_tablesel = 5
          no_authorization       = 6
          illegal_download       = 8
          illegal_tablename      = 9
          OTHERS                 = 11.

      IF sy-subrc <> 0.
        MESSAGE 'BW cube 0SM_UPLDD was not read successfully' TYPE 'E'.
        EXIT.
      ELSE.
        DESCRIBE TABLE g_t_data LINES DATA(lv_lines).
      ENDIF.

    ENDWHILE.

    IF lv_lines NE 0.

    SORT g_t_data BY calday.
    READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data_first>) INDEX 1.
    READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data_last>)  INDEX lv_lines.

    DATA: lv_first_day TYPE dats. lv_first_day = <fs_t_data_first>-calday.
    DATA: lv_last_day  TYPE dats. lv_last_day  = sy-datum.


    DATA(number_of_days) = lv_last_day - lv_first_day.

*  DATA: BEGIN OF ls_dates,
*          calday      TYPE dats,
*          bundles     TYPE dats,
*          aggr_w(1)   TYPE c,
*          aggr_m(1)   TYPE c,
*          aggr_y(1)   TYPE c,
*        END OF ls_dates.
*  DATA: lt_dates LIKE TABLE OF ls_dates.

*  data: ls_scmon_stat type ags_cc_scmonstat.
*  data: lt_scmon_stat like TABLE OF ls_scmon_stat.


    "select sid scmon_date bundle_id available from ags_cc_scmonstat into CORRESPONDING FIELDS OF table lt_scmon_stat for ALL ENTRIES IN g_t_data where sid = g_t_data-smd_lsid.
*  select sid,scmon_date,bundle_id,available from ags_cc_scmonstat into table @data(lt_scmon_stat) where sid = @lv_sys_id.
*  select * from ags_upl_uploadst into TABLE @data(lt_uploadst) where system_id = @lv_sys_id.

    SELECT a~sid, a~scmon_date, a~bundle_id, a~available, b~upl_week_dso, b~upl_month_dso, b~upl_year_dso
      FROM ags_cc_scmonstat AS a LEFT OUTER JOIN ags_upl_uploadst AS b
      ON a~sid = b~system_id
      "and a~bundle_id = b~bundle_id
      INTO TABLE @DATA(lt_stat)
      WHERE a~sid = @lv_sys_id
      ORDER BY a~scmon_date, a~bundle_id.

    CHECK lt_stat IS NOT INITIAL.
    DELETE ADJACENT DUPLICATES FROM lt_stat COMPARING sid scmon_date bundle_id.

    DATA: current_date TYPE dats.
    "current_date = <fs_t_data_first>-sm_cclud.
    current_date = <fs_t_data_first>-calday.

    SELECT single deletor_id FROM e2e_bi_delete INTO @DATA(id) WHERE infoobject = '0SMD_LSID' AND low = @lv_sys_id.
    SELECT target_cube, low FROM e2e_bi_delete INTO TABLE @DATA(lt_hk_conf) WHERE deletor_id = @id.

    READ TABLE lt_hk_conf INTO data(ls_sys_hk_day) WITH KEY target_cube = '0SM_UPLDD'.
    IF ls_sys_hk_day-low IS INITIAL.
      "es_entityset-tbaggregated = 'Not defined'.
    ELSE.
      data: lV_0 type string.
      lv_0 = ls_sys_hk_day-low.
      SPLIT lv_0 AT '=' INTO DATA(lv_1) DATA(lv_2).
      SPLIT lv_2 AT '$' INTO DATA(HK_DAYS) DATA(lv_3).
    ENDIF.

    data del_days type i.
    move hk_days to del_days.
    data lv_date type dats.

    DO number_of_days TIMES.
      es_entityset-system_id = lv_sys_id.
      write current_date to es_entityset-usagedate DD/MM/YYYY.
      "READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data>) WITH  KEY sm_cclud = current_date BINARY SEARCH.
      READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data>) WITH  KEY calday = current_date BINARY SEARCH.
      IF sy-subrc = 0.
        es_entityset-dsodate = 'X'.
        es_entityset-extractdate = <fs_t_data>-calday.


        move current_date to lv_date.
        if ( sy-datum - lv_date ) > del_days.
            es_entityset-tbaggregated = 'X'   .
        endif.
      ELSE.
        es_entityset-dsodate = ''.
        es_entityset-extractdate = '00000000'.
      ENDIF.
      READ TABLE lt_stat ASSIGNING FIELD-SYMBOL(<fs_stat>) WITH KEY scmon_date = current_date BINARY SEARCH.
      IF sy-subrc = 0.
        es_entityset-scmonstat  = <fs_stat>-available.
        es_entityset-aggrweek   = <fs_stat>-upl_week_dso.
        es_entityset-aggrmonth  = <fs_stat>-upl_month_dso.
        es_entityset-aggryear   = <fs_stat>-upl_year_dso.
      ELSE.
        es_entityset-scmonstat  = ''.
        es_entityset-aggrweek   = ''.
        es_entityset-aggrmonth  = ''.
        es_entityset-aggryear   = ''.
      ENDIF.
      APPEND es_entityset TO et_entityset.
      ADD 1 TO current_date.
      CLEAR es_entityset.
    ENDDO.

    endif.
  ENDMETHOD.


  METHOD dso_monthset_get_entityset.

    DATA(lt_filters) = io_tech_request_context->get_filter( )->get_filter_select_options( ).
    READ TABLE lt_filters WITH TABLE KEY property = 'SYSTEM_ID' INTO DATA(ls_sys_id_filter).
    IF sy-subrc EQ 0.
      READ TABLE ls_sys_id_filter-select_options INTO DATA(ls_so) INDEX 1.
      DATA(lv_sys_id) = ls_so-low.
    ENDIF.

    DATA:
      g_s_sfc   TYPE rsdri_s_sfc, "G_S_SFC  = description of a characteristic or navigational attribute that is requested by a query
      g_th_sfc  TYPE rsdri_th_sfc,
      g_s_sfk   TYPE rsdri_s_sfk, "G_S_SFK  = description of a key figure that is requested by a query
      g_th_sfk  TYPE rsdri_th_sfk,
      g_s_range TYPE rsdri_s_range, "G_S_RANGE = description of a restriction on a characteristic or navigational attribute
      g_t_range TYPE rsdri_t_range.


    TYPES:
      BEGIN OF gt_s_data,
        smd_lsid(8)  TYPE c,                " system name
        smd_tihm(12) TYPE n,                " Time (yyyyMMddhhmm)
        calmonth(6)  TYPE n,                " Calendar Year/Month
      END OF gt_s_data.



    DATA: g_s_data TYPE gt_s_data,
          g_t_data TYPE TABLE OF gt_s_data. " G_T_DATA = an internal table that can hold the result set
    DATA: g_end_of_data TYPE rs_bool,
          g_first_call  TYPE rs_bool.
    DATA: lv_msg TYPE string.
    DATA: es_entityset LIKE LINE OF et_entityset.

    "FIELD-SYMBOLS: <fs_t_data> LIKE LINE OF g_t_data.

    g_end_of_data = rs_c_false.
    g_first_call  = rs_c_true.

    CLEAR g_th_sfc.

* System
    CLEAR g_s_sfc.
    g_s_sfc-chanm    = '0SMD_LSID'.       " name of characteristic
    g_s_sfc-chaalias = 'SMD_LSID'.        " name of corresponding column in G_T_DATA
    g_s_sfc-orderby  = 0.                 " no ORDER-BY
    INSERT g_s_sfc INTO TABLE g_th_sfc.   " include into list of characteristics


* Available days
    CLEAR g_s_sfc.
    g_s_sfc-chanm    = '0SMD_TIHM'.
    g_s_sfc-chaalias = 'SMD_TIHM'.
    g_s_sfc-orderby  = 0.
    INSERT g_s_sfc INTO TABLE g_th_sfc.

* Available months
    CLEAR g_s_sfc.
    g_s_sfc-chanm    = '0CALMONTH'.
    g_s_sfc-chaalias = 'CALMONTH'.
    g_s_sfc-orderby  = 0.
    INSERT g_s_sfc INTO TABLE g_th_sfc.


* These are the restrictions:
    CLEAR g_t_range.
    CLEAR g_s_range.


    g_s_range-chanm    = '0SMD_LSID'.               " the characteristic
    g_s_range-sign     = rs_c_range_sign-including. " including or excluding condition ?
    g_s_range-compop   = rs_c_range_opt-equal.      " comparison operator
    g_s_range-low      = lv_sys_id.                     " low value
    APPEND g_s_range TO g_t_range.                  " Include into list of restrictions

    WHILE g_end_of_data = rs_c_false.

      CALL FUNCTION 'RSDRI_INFOPROV_READ'
        EXPORTING
          i_infoprov             = '0SM_UPLDM'
          i_th_sfc               = g_th_sfc
          i_th_sfk               = g_th_sfk
          i_t_range              = g_t_range
          i_reference_date       = sy-datum
          i_save_in_table        = rs_c_false
          i_save_in_file         = rs_c_false
          i_packagesize          = 10000000
   "      i_authority_check      = rsdrc_c_authchk-read
        IMPORTING
          e_t_data               = g_t_data
          e_end_of_data          = g_end_of_data
        CHANGING
          c_first_call           = g_first_call
        EXCEPTIONS
          illegal_input          = 1
          illegal_input_sfc      = 2
          illegal_input_sfk      = 3
          illegal_input_range    = 4
          illegal_input_tablesel = 5
          no_authorization       = 6
          illegal_download       = 8
          illegal_tablename      = 9
          OTHERS                 = 11.

      IF sy-subrc <> 0.
        MESSAGE 'BW cubes was not read successfully' TYPE 'E'.
        EXIT.
      ELSE.
        "CLEAR: lv_lines, lv_linesc, lv_msg.
        DESCRIBE TABLE g_t_data LINES DATA(lv_lines).
        "DATA lv_linesc(6) TYPE c.
        "MOVE lv_lines TO lv_linesc.
        "CONCATENATE 'Referenced objects fetched from BW: ' lv_linesc  INTO lv_msg IN CHARACTER MODE.
        "MESSAGE lv_msg TYPE 'S'.
      ENDIF.

    ENDWHILE.
    "---------------------------------------

    IF lv_lines NE 0.

    SORT g_t_data BY smd_tihm.
    READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data_first>) INDEX 1.
    READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data_last>)  INDEX lv_lines.

    DATA: lv_first_day TYPE dats. CONCATENATE <fs_t_data_first>-smd_tihm(6) '01' INTO lv_first_day.
    DATA: lv_last_day  TYPE dats.
    "lv_last_day  = <fs_t_data_last>-smd_tihm(8).
    lv_last_day  = sy-datum.


    DATA(number_of_days) = lv_last_day - lv_first_day.

    DATA: BEGIN OF ls_dates,
            date        TYPE dats,
            calmonth(6) TYPE c,
            avail(1)    TYPE c,
          END OF ls_dates.
    DATA: lt_dates LIKE TABLE OF ls_dates.

    DATA: current_date TYPE dats.

    DATA: lv_curd TYPE scal-date.
    DATA: lv_curw TYPE scal-week.

    current_date = lv_first_day.

    data(lv_this_week) = sy-datum+4(2).

    DO number_of_days TIMES.
      write current_date to es_entityset-days DD/MM/YYYY.
      es_entityset-months = current_date(6).
      es_entityset-system_id = <fs_t_data_first>-smd_lsid.  "think about it later!!!
      READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data>) WITH  KEY smd_tihm(8) = current_date BINARY SEARCH.
      IF sy-subrc = 0.
        es_entityset-availability = 'X'.
      ENDIF.

       if es_entityset-months+4(02) <> lv_this_week.
            es_entityset-tbaggregated = 'X'   .
       endif.

      APPEND es_entityset TO et_entityset.
      ADD 1 TO current_date.
      CLEAR es_entityset.
    ENDDO.
    endif.
  ENDMETHOD.


  METHOD dso_weekset_get_entityset.
    DATA(lt_filters) = io_tech_request_context->get_filter( )->get_filter_select_options( ).
    READ TABLE lt_filters WITH TABLE KEY property = 'SYSTEM_ID' INTO DATA(ls_sys_id_filter).
    IF sy-subrc EQ 0.
      READ TABLE ls_sys_id_filter-select_options INTO DATA(ls_so) INDEX 1.
      DATA(lv_sys_id) = ls_so-low.
    ENDIF.


    DATA:
      g_s_sfc   TYPE rsdri_s_sfc, "G_S_SFC  = description of a characteristic or navigational attribute that is requested by a query
      g_th_sfc  TYPE rsdri_th_sfc,
      g_s_sfk   TYPE rsdri_s_sfk, "G_S_SFK  = description of a key figure that is requested by a query
      g_th_sfk  TYPE rsdri_th_sfk,
      g_s_range TYPE rsdri_s_range, "G_S_RANGE = description of a restriction on a characteristic or navigational attribute
      g_t_range TYPE rsdri_t_range.


    TYPES:
      BEGIN OF gt_s_data,
        smd_lsid(8)  TYPE c, " System name
        smd_tihm(12) TYPE n, " Time (yyyyMMddhhmm)
        calweek(6)   TYPE n, " Calendar Year/Month
      END OF gt_s_data.

    DATA: lv_msg TYPE string.
    DATA: g_s_data TYPE gt_s_data,
          g_t_data TYPE TABLE OF gt_s_data. " G_T_DATA = an internal table that can hold the result set
    DATA: g_end_of_data TYPE rs_bool,
          g_first_call  TYPE rs_bool.
    DATA: es_entityset LIKE LINE OF et_entityset.



    g_end_of_data = rs_c_false.
    g_first_call  = rs_c_true.
    CLEAR g_th_sfc.

* System
    CLEAR g_s_sfc.
    g_s_sfc-chanm    = '0SMD_LSID'.     " name of characteristic
    g_s_sfc-chaalias = 'SMD_LSID'.     " name of corresponding column in G_T_DATA
    g_s_sfc-orderby  = 0.               " no ORDER-BY
    INSERT g_s_sfc INTO TABLE g_th_sfc. " include into list of characteristics


* Available calendar weeks
    CLEAR g_s_sfc.
    g_s_sfc-chanm    = '0CALWEEK'.
    g_s_sfc-chaalias = 'CALWEEK'.
    g_s_sfc-orderby  = 0.
    INSERT g_s_sfc INTO TABLE g_th_sfc.

* Available days
    CLEAR g_s_sfc.
    g_s_sfc-chanm    = '0SMD_TIHM'.
    g_s_sfc-chaalias = 'SMD_TIHM'.
    g_s_sfc-orderby  = 0.
    INSERT g_s_sfc INTO TABLE g_th_sfc.

* These are the restrictions:
    CLEAR g_t_range.
    CLEAR g_s_range.

    g_s_range-chanm    = '0SMD_LSID'.
    g_s_range-sign     = rs_c_range_sign-including.
    g_s_range-compop   = rs_c_range_opt-equal.
    g_s_range-low      = lv_sys_id.
    APPEND g_s_range TO g_t_range.

    WHILE g_end_of_data = rs_c_false.

      CALL FUNCTION 'RSDRI_INFOPROV_READ'
        EXPORTING
          i_infoprov             = '0SM_UPLDW'
          i_th_sfc               = g_th_sfc
          i_th_sfk               = g_th_sfk
          i_t_range              = g_t_range
          i_reference_date       = sy-datum
          i_save_in_table        = rs_c_false
          i_save_in_file         = rs_c_false
          i_packagesize          = 10000000
   "      i_authority_check      = rsdrc_c_authchk-read
        IMPORTING
          e_t_data               = g_t_data
          e_end_of_data          = g_end_of_data
        CHANGING
          c_first_call           = g_first_call
        EXCEPTIONS
          illegal_input          = 1
          illegal_input_sfc      = 2
          illegal_input_sfk      = 3
          illegal_input_range    = 4
          illegal_input_tablesel = 5
          no_authorization       = 6
          illegal_download       = 8
          illegal_tablename      = 9
          OTHERS                 = 11.

      IF sy-subrc <> 0.
        MESSAGE 'BW cube 0SM_UPLDW was not read successfully' TYPE 'E'.
        exit.
      ELSE.
        "CLEAR: lv_lines, lv_linesc, lv_msg.
        DESCRIBE TABLE g_t_data LINES DATA(lv_lines).
        if lv_lines = 0.
          exit.
        endif.
        "DATA lv_linesc(6) TYPE c.
        "MOVE lv_lines TO lv_linesc.
        "CONCATENATE 'Fetched from BW: ' lv_linesc  INTO lv_msg IN CHARACTER MODE.
        "MESSAGE lv_msg TYPE 'S'.
      ENDIF.

    ENDWHILE.

    IF lv_lines NE 0.

    SORT g_t_data BY smd_tihm.
    READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data_first>) INDEX 1.
    READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data_last>)  INDEX lv_lines.

    DATA: lv_first_day TYPE dats. lv_first_day = <fs_t_data_first>-smd_tihm(8).
    "lv_first_day+6(2) = '01'.
    DATA: lv_last_day  TYPE dats. lv_last_day  = sy-datum.


    DATA(number_of_days) = lv_last_day - lv_first_day.



    DATA: BEGIN OF ls_dates,
            calweek(6) TYPE c,
            date       TYPE dats,
            avail(1)   TYPE c,
          END OF ls_dates.
    DATA: lt_dates LIKE TABLE OF ls_dates.
    DATA: current_date TYPE dats.
    DATA: lv_curd TYPE scal-date.
    DATA: lv_curw TYPE scal-week.
    DATA: lv_week_today type scal-week.
    DATA: lv_today TYPE scal-date.


    current_date = <fs_t_data_first>-smd_tihm(8).
    lv_today = sy-datum.

    CALL FUNCTION 'DATE_GET_WEEK'
        EXPORTING
          date = lv_today
        IMPORTING
          week = lv_week_today
     EXCEPTIONS
         DATE_INVALID       = 1
         OTHERS             = 2
        .


    DO number_of_days TIMES.
      write current_date to es_entityset-days DD/MM/YYYY.

      lv_curd = current_date.

      CALL FUNCTION 'DATE_GET_WEEK'
        EXPORTING
          date = lv_curd
        IMPORTING
          week = lv_curw
     EXCEPTIONS
         DATE_INVALID       = 1
         OTHERS             = 2
        .
      IF sy-subrc <> 0.
        MESSAGE 'wrong date format' TYPE 'I'.
      ENDIF.
      es_entityset-weeks = lv_curw.
      es_entityset-system_id = <fs_t_data_first>-smd_lsid.  "think about it later!!!
      READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data>) WITH  KEY smd_tihm(8) = current_date BINARY SEARCH.
      IF sy-subrc = 0.
        es_entityset-availability = 'X'.
      ENDIF.

        if lv_curw <> lv_week_today.
            es_entityset-tbaggregated = 'X'   .
        endif.

      APPEND es_entityset TO et_entityset.
      ADD 1 TO current_date.
      CLEAR es_entityset.
    ENDDO.
    endif.
  ENDMETHOD.


  METHOD dso_yearset_get_entityset.

    DATA(lt_filters) = io_tech_request_context->get_filter( )->get_filter_select_options( ).
    READ TABLE lt_filters WITH TABLE KEY property = 'SYSTEM_ID' INTO DATA(ls_sys_id_filter).
    IF sy-subrc EQ 0.
      READ TABLE ls_sys_id_filter-select_options INTO DATA(ls_so) INDEX 1.
      DATA(lv_sys_id) = ls_so-low.
    ENDIF.

    DATA:
      g_s_sfc   TYPE rsdri_s_sfc, "G_S_SFC  = description of a characteristic or navigational attribute that is requested by a query
      g_th_sfc  TYPE rsdri_th_sfc,
      g_s_sfk   TYPE rsdri_s_sfk, "G_S_SFK  = description of a key figure that is requested by a query
      g_th_sfk  TYPE rsdri_th_sfk,
      g_s_range TYPE rsdri_s_range, "G_S_RANGE = description of a restriction on a characteristic or navigational attribute
      g_t_range TYPE rsdri_t_range.


    TYPES:
      BEGIN OF gt_s_data,
        smd_lsid(8)  TYPE c,                " system name
        smd_tihm(12) TYPE n,                " Time (yyyyMMddhhmm)
        calyear(6)   TYPE n,                " Calendar Year/Month
      END OF gt_s_data.



    DATA: g_s_data TYPE gt_s_data,
          g_t_data TYPE TABLE OF gt_s_data. " G_T_DATA = an internal table that can hold the result set
    DATA: g_end_of_data TYPE rs_bool,
          g_first_call  TYPE rs_bool.
    DATA: lv_msg TYPE string.
    DATA: es_entityset LIKE LINE OF et_entityset.

    "FIELD-SYMBOLS: <fs_t_data> LIKE LINE OF g_t_data.

    g_end_of_data = rs_c_false.
    g_first_call  = rs_c_true.

    CLEAR g_th_sfc.

* System
    CLEAR g_s_sfc.
    g_s_sfc-chanm    = '0SMD_LSID'.       " name of characteristic
    g_s_sfc-chaalias = 'SMD_LSID'.        " name of corresponding column in G_T_DATA
    g_s_sfc-orderby  = 0.                 " no ORDER-BY
    INSERT g_s_sfc INTO TABLE g_th_sfc.   " include into list of characteristics


* Available days
    CLEAR g_s_sfc.
    g_s_sfc-chanm    = '0SMD_TIHM'.
    g_s_sfc-chaalias = 'SMD_TIHM'.
    g_s_sfc-orderby  = 0.
    INSERT g_s_sfc INTO TABLE g_th_sfc.

* Available months
    CLEAR g_s_sfc.
    g_s_sfc-chanm    = '0CALYEAR'.
    g_s_sfc-chaalias = 'CALYEAR'.
    g_s_sfc-orderby  = 0.
    INSERT g_s_sfc INTO TABLE g_th_sfc.


* These are the restrictions:
    CLEAR g_t_range.
    CLEAR g_s_range.


    g_s_range-chanm    = '0SMD_LSID'.               " the characteristic
    g_s_range-sign     = rs_c_range_sign-including. " including or excluding condition ?
    g_s_range-compop   = rs_c_range_opt-equal.      " comparison operator
    g_s_range-low      = lv_sys_id.                     " low value
    APPEND g_s_range TO g_t_range.                  " Include into list of restrictions

    WHILE g_end_of_data = rs_c_false.

      CALL FUNCTION 'RSDRI_INFOPROV_READ'
        EXPORTING
          i_infoprov             = '0SM_UPLDY'
          i_th_sfc               = g_th_sfc
          i_th_sfk               = g_th_sfk
          i_t_range              = g_t_range
          i_reference_date       = sy-datum
          i_save_in_table        = rs_c_false
          i_save_in_file         = rs_c_false
          i_packagesize          = 10000000
   "      i_authority_check      = rsdrc_c_authchk-read
        IMPORTING
          e_t_data               = g_t_data
          e_end_of_data          = g_end_of_data
        CHANGING
          c_first_call           = g_first_call
        EXCEPTIONS
          illegal_input          = 1
          illegal_input_sfc      = 2
          illegal_input_sfk      = 3
          illegal_input_range    = 4
          illegal_input_tablesel = 5
          no_authorization       = 6
          illegal_download       = 8
          illegal_tablename      = 9
          OTHERS                 = 11.

      IF sy-subrc <> 0.
        MESSAGE 'BW cubes was not read successfully' TYPE 'E'.
        EXIT.
      ELSE.
        "CLEAR: lv_lines, lv_linesc, lv_msg.
        DESCRIBE TABLE g_t_data LINES DATA(lv_lines).
        "DATA lv_linesc(6) TYPE c.
        "MOVE lv_lines TO lv_linesc.
        "CONCATENATE 'Referenced objects fetched from BW: ' lv_linesc  INTO lv_msg IN CHARACTER MODE.
        "MESSAGE lv_msg TYPE 'S'.
      ENDIF.

    ENDWHILE.
    "---------------------------------------

    IF lv_lines NE 0.

    SORT g_t_data BY smd_tihm.
    READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data_first>) INDEX 1.
    READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data_last>)  INDEX lv_lines.

    DATA: lv_first_day TYPE dats. "lv_first_day = <fs_t_data_first>-smd_tihm(8).
    CONCATENATE <fs_t_data_first>-smd_tihm(4) '01' '01' INTO lv_first_day.
    DATA: lv_last_day  TYPE dats.
    lv_last_day  = sy-datum.


    DATA(number_of_days) = lv_last_day - lv_first_day.

    DATA: current_date TYPE dats.
    DATA: current_month TYPE dats.

    DATA: lv_first_day_year TYPE dats.
    DATA: lv_last_day_year TYPE dats.
    DATA: lv_current_month(10) TYPE c.
    current_date = lv_first_day.

*    DO number_of_days TIMES.
*      IF current_date(4) <> sy-datum(4).
*
*      ELSE.
*        IF     current_date+4(2) = '01'.
*          lv_current_month = 'January'.
*        ELSEIF current_date+4(2) = '02'.
*          lv_current_month = 'February'.
*        ELSEIF current_date+4(2) = '03'.
*          lv_current_month = 'March'.
*        ELSEIF current_date+4(2) = '04'.
*          lv_current_month = 'April'.
*        ELSEIF current_date+4(2) = '05'.
*          lv_current_month = 'May'.
*        ELSEIF current_date+4(2) = '06'.
*          lv_current_month = 'June'.
*        ELSEIF current_date+4(2) = '07'.
*          lv_current_month = 'July'.
*        ELSEIF current_date+4(2) = '08'.
*          lv_current_month = 'August'.
*        ELSEIF current_date+4(2) = '09'.
*          lv_current_month = 'September'.
*        ELSEIF current_date+4(2) = '10'.
*          lv_current_month = 'October'.
*        ELSEIF current_date+4(2) = '11'.
*          lv_current_month = 'November'.
*        ELSEIF current_date+4(2) = '12'.
*          lv_current_month = 'December'.
*        ENDIF.
*
*        es_entityset-days = 1.
*        es_entityset-years = lv_current_month.
*        es_entityset-system_id = <fs_t_data_first>-smd_lsid.
*
*        READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data>) WITH  KEY smd_tihm(8) = current_date BINARY SEARCH.
*        IF sy-subrc = 0.
*          es_entityset-availability = 'X'.
*        ENDIF.
*      ENDIF.
*    ENDDO.

    DO number_of_days TIMES.
      es_entityset-days = current_date.
      es_entityset-years = current_date(6).
      es_entityset-system_id = <fs_t_data_first>-smd_lsid.  "think about it later!!!
      READ TABLE g_t_data ASSIGNING FIELD-SYMBOL(<fs_t_data>) WITH  KEY smd_tihm(8) = current_date BINARY SEARCH.
      IF sy-subrc = 0.
        es_entityset-availability = 'X'.
      ENDIF.
      APPEND es_entityset TO et_entityset.
      ADD 1 TO current_date.
      CLEAR es_entityset.
    ENDDO.

    data: lt_temp TYPE ZCL_ZCCLM_ODATA_UG_MPC=>TT_DSO_YEAR.
    data: ls_temp like line of lt_temp.

    current_date = lv_first_day.
*    DO number_of_days TIMES.
*       READ TABLE et_entityset index 1 into es_entityset.
*       AT NEW es_entityset-years+4(2).
*        IF     es_entityset+4(2) = '01'.
*          lv_current_month = 'January'.
*        ELSEIF es_entityset+4(2) = '02'.
*          lv_current_month = 'February'.
*        ELSEIF es_entityset+4(2) = '03'.
*          lv_current_month = 'March'.
*        ELSEIF es_entityset+4(2) = '04'.
*          lv_current_month = 'April'.
*        ELSEIF es_entityset+4(2) = '05'.
*          lv_current_month = 'May'.
*        ELSEIF es_entityset+4(2) = '06'.
*          lv_current_month = 'June'.
*        ELSEIF es_entityset+4(2) = '07'.
*          lv_current_month = 'July'.
*        ELSEIF es_entityset+4(2) = '08'.
*          lv_current_month = 'August'.
*        ELSEIF es_entityset+4(2) = '09'.
*          lv_current_month = 'September'.
*        ELSEIF es_entityset+4(2) = '10'.
*          lv_current_month = 'October'.
*        ELSEIF es_entityset+4(2) = '11'.
*          lv_current_month = 'November'.
*        ELSEIF es_entityset+4(2) = '12'.
*          lv_current_month = 'December'.
*        ENDIF.
*    enddo.
    endif.
  ENDMETHOD.


  method SYSTEMSET_GET_ENTITYSET.
    DATA: es_entityset LIKE LINE OF et_entityset.

    SELECT SYSTEM_ID, SYSTEM_ROLE
    FROM agsccl_system
    INTO TABLE @DATA(lt_sys).

    SELECT * FROM ags_cc_custom INTO TABLE @DATA(lt_cc_custom).

    SELECT parameter_key, parameter_value from AGS_UPL_SETTING INTO TABLE @DATA(lt_ags_upl_setting).



    LOOP AT lt_sys INTO DATA(ls_sys).
      CLEAR es_entityset.
      es_entityset-id = ls_sys-system_id.
      es_entityset-role = ls_sys-system_role.

      SELECT single deletor_id FROM e2e_bi_delete INTO @DATA(id) WHERE infoobject = '0SMD_LSID' AND low = @ls_sys-system_id.


      SELECT target_cube, low FROM e2e_bi_delete INTO TABLE @DATA(lt_hk_conf) WHERE deletor_id = @id.

      READ TABLE lt_hk_conf INTO DATA(ls_sys_hk_1) WITH KEY target_cube = '0SM_UPLDD'.
      READ TABLE lt_hk_conf INTO DATA(ls_sys_hk_2) WITH KEY target_cube = '0SM_UPL_W'.
      READ TABLE lt_hk_conf INTO DATA(ls_sys_hk_3) WITH KEY target_cube = '0SM_UPL_M'.
      READ TABLE lt_hk_conf INTO DATA(ls_sys_hk_4) WITH KEY target_cube = '0SM_UPL_Y'.

      IF ls_sys_hk_1-low IS NOT INITIAL AND
         ls_sys_hk_2-low IS NOT INITIAL AND
         ls_sys_hk_3-low IS NOT INITIAL AND
         ls_sys_hk_4-low IS NOT INITIAL.
          es_entityset-housekeeping = 'X'.
      ELSE.
        es_entityset-housekeeping = ' '.
      ENDIF.

      SELECT PARAMETER_VALUE FROM AGS_UPL_SETTING INTO @DATA(lv_w_a) WHERE system_id = @ls_sys-system_id AND
                                                                           parameter_key = 'UPL_WEEK_ACTIVE'.
      ENDSELECT.
      SELECT PARAMETER_VALUE FROM AGS_UPL_SETTING INTO @DATA(lv_m_a) WHERE system_id = @ls_sys-system_id AND
                                                                           parameter_key = 'UPL_MONTH_ACTIVE'.
      ENDSELECT.
      SELECT PARAMETER_VALUE FROM AGS_UPL_SETTING INTO @DATA(lv_y_a) WHERE system_id = @ls_sys-system_id AND
                                                                           parameter_key = 'UPL_YEAR_ACTIVE'.
      ENDSELECT.

      IF lv_w_a IS NOT INITIAL AND
         lv_m_a IS NOT INITIAL AND
         lv_y_a IS NOT INITIAL.
          es_entityset-aggregation = 'X'.
      ELSE.
          es_entityset-aggregation = ' '.
      ENDIF.
      APPEND es_entityset to et_entityset.
    ENDLOOP.

  endmethod.
ENDCLASS.
