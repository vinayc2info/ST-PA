CREATE SERVICE "pawebservices" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>' from "DBA"."usp_pa_webservice"();
CREATE SERVICE "ws_ADMIN_VIEW_COMPLETED_USERS" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "USP_ADMIN_VIEW_COMPLETED_USERS"();
CREATE SERVICE "ws_admin_view_user_srno_item_list" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "usp_stk_audit_pending_item_list_for_admin"();
CREATE SERVICE "ws_admin_view_user_srno_list" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "USP_ADMIN_VIEW_SRNO_USERS"();
CREATE SERVICE "ws_check_connection" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select 'SUCCESS';
CREATE SERVICE "ws_doc_dman_list" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "DBA"."usp_doc_dman_list"();
CREATE SERVICE "ws_doc_insert" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "DBA"."usp_doc_insert"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8);
CREATE SERVICE "ws_doc_location_list" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "DBA"."usp_doc_Location_list"();
CREATE SERVICE "ws_full_doc_location_list" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "DBA"."usp_full_doc_Location_list"();
CREATE SERVICE "ws_get_default_date" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select "DATEFORMAT"("uf_default_date"(),'DD-MM-YYYY');
CREATE SERVICE "ws_get_inv_details" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "DBA"."usp_get_inv_details"(:url1,:url2);
CREATE SERVICE "ws_get_inv_track_details" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "DBA"."usp_get_inv_track_details"(:url1,:url2);
CREATE SERVICE "ws_get_inv_track_stage_rpt" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS call "usp_get_inv_track_stage_rpt"(:url1,:url2,:url3,:url4);
CREATE SERVICE "ws_get_menu_rights" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>' from "usp_get_menu_rights"(:url1,:url2,:url3,:url4);
CREATE SERVICE "ws_get_mfac_list" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "usp_get_mfac_list"();
CREATE SERVICE "ws_login" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "DBA"."usp_login"(:url1,:url2);
CREATE SERVICE "ws_login_validation" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select "ls_result_str" from "usp_login_validation"();
CREATE SERVICE "ws_messaging" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>' from "DBA"."usp_messaging"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8,:url9,:url10,:url11,:url12,:url13,:url14,:url15,:url15);
CREATE SERVICE "ws_ps_get_delimiter" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS call "dba"."usp_ps_get_delimiter"(:url1,:url2,:url3);
CREATE SERVICE "ws_st_cycle_audit" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>'
  from "DBA"."usp_st_cycle_audit"(:url1,:url2,:url3,:url4,:url5);
CREATE SERVICE "ws_st_dashboard" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>'
  from "usp_st_dashboard"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8,:url9,:url10);
CREATE SERVICE "ws_st_error_tracking_supervisor_dashboard" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>'
  from "DBA"."usp_st_error_tracking_supervisor_dashboard"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8,:url9,:url10,:url11);
CREATE SERVICE "ws_st_get_tray_details" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS call "usp_st_get_tray_details"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8);
CREATE SERVICE "ws_st_get_tray_status_details" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>'
  from "usp_st_get_tray_status_details"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8);
CREATE SERVICE "ws_st_login_validation" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>'
  from "DBA"."usp_st_login_validation"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8,:url19,:url110);
CREATE SERVICE "ws_st_multi_doc_done" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>'
  from "DBA"."usp_st_multi_doc_done"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8,:url9,:url10,:url11);
CREATE SERVICE "ws_st_operational_avg" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>'
  from "DBA"."usp_st_operational_avg"(:url1,:url2,:url3,:url4,:url5,:url6);
CREATE SERVICE "ws_st_operational_dashboard" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>'
  from "DBA"."usp_st_operational_dashboard"(:url1,:url2,:url3,:url4,:url5,:url6);
CREATE SERVICE "ws_st_stock_audit" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>' from "DBA"."usp_st_stock_audit"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8,:url9,:url10,:url11);
CREATE SERVICE "ws_st_stock_removal" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>'
  from "DBA"."usp_st_stock_removal"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8,:url9,:url10,:url11);
CREATE SERVICE "ws_st_stock_removal_rkgrp_in_exit" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>'
  from "usp_st_stock_removal_rkgrp_in_exit"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8,:url9,:url10,:url11);
CREATE SERVICE "ws_st_store_in" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>' from "DBA"."usp_st_store_in"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8,:url9,:url10,:url11,:url12);
CREATE SERVICE "ws_st_store_in_assignment" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>' from "DBA"."usp_st_store_in_assignment"();
CREATE SERVICE "ws_st_storein_quarantine" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>' from "DBA"."usp_st_storein_quarantine"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8,:url9,:url10,:url11,:url12);
CREATE SERVICE "ws_st_tray_exceptional_dashboard" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>' from "DBA"."usp_st_tray_exceptional_dashboard"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8,:url9,:url10,:url11);
CREATE SERVICE "ws_st_tray_pickup" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>' from "DBA"."usp_st_tray_pickup"(:url1,:url2,:url3,:url4,:url5,:url6,:url7,:url8,:url9,:url10,:url11);
CREATE SERVICE "Ws_stk_admin_approve_tmp123" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "usp_stk_admin_approve_tmp123"();
CREATE SERVICE "ws_stk_audit_batch_list" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "usp_stk_audit_batch_list"();
CREATE SERVICE "ws_stk_audit_get_item_list" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "usp_stk_audit_get_item_list"();
CREATE SERVICE "ws_stk_audit_get_rack_code" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "usp_stk_audit_get_rack_code"();
CREATE SERVICE "ws_stk_audit_get_rack_group" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "usp_stk_audit_get_rack_group"();
CREATE SERVICE "Ws_stk_audit_peding_list" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "usp_stk_audit_peding_list"();
CREATE SERVICE "ws_stk_audit_pending_item_batch_list_for_admin" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "usp_stk_audit_pending_item_batch_list_for_admin"();
CREATE SERVICE "ws_stk_audit_store_track_update_item" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"is_xml_string"+'</root>'
  from "DBA"."usp_stk_audit_store_track_update_item"();
CREATE SERVICE "ws_stk_audit_user_assignment" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>'
  from "usp_stk_audit_user_assignment"();
CREATE SERVICE "ws_stk_audit_user_item_list" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<ROOT>'+"ls_result_str"+'</ROOT>' from "usp_stk_audit_user_item_list"();
CREATE SERVICE "ws_stk_email_send" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_string_str"+'</root>' from "usp_stk_email_send"();
CREATE SERVICE "ws_stk_get_logon" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_string_str"+'</root>' from "usp_stk_get_logon"();
CREATE SERVICE "Ws_stk_user_submit_list" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<root>'+"ls_result_str"+'</root>' from "usp_stk_user_submit_list"();
CREATE SERVICE "ws_user_list" TYPE 'RAW' AUTHORIZATION OFF USER "DBA" URL ELEMENTS AS select '<ROOT>'+"ls_result_str"+'</ROOT>' from "USP_USER_LIST"();
