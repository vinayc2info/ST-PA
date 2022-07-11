CREATE EVENT "DBA"."event_MTD_SCH"
SCHEDULE "mtd_sch" BETWEEN '09:40' AND '11:55' EVERY 24 HOURS
HANDLER
begin
  declare "s_app_path" char(1000);
  select "left"("db_property"('file'),"length"("db_property"('file'))-("length"("db_name"())*2+5)) into "s_app_path";
  set "s_app_path" = "s_app_path"+'\\pharmassist2.exe'+' '+"s_app_path"+'@MTDSCHEDULE PATH='+"s_app_path";
  call "xp_cmdshell"("s_app_path",'no_output')
end;
CREATE EVENT "DBA"."event_sms_scheduler"
SCHEDULE "sch" BETWEEN '00:00' AND '23:59' EVERY 999 MINUTES
HANDLER
begin call "usp_send_sms"()
end;
CREATE EVENT "DBA"."kill_all_cmd_line_con_expvdc" TYPE "DatabaseStart"
HANDLER
begin update "exportvdc_conn_info" set "d_end_time" = "getdate"(),"n_close_flag" = -1;
  commit work
end;
CREATE EVENT "DBA"."tray_time"
SCHEDULE "tt" START TIME '00:00' EVERY 10 MINUTES
HANDLER
begin
  declare "max_time" "datetime";
  select "max"("t_time") into "max_time" from "tray_time_incr";
  if "max_time" is null then set "max_time" = "uf_default_date"() end if;
  insert into "tray_time_incr"
    ( "c_doc_no","n_inout","c_tray_code","c_work_place","c_user","c_rack_grp_code","c_stage_code","t_time","t_action_start_time","t_action_end_time",
    "n_bounce_count","n_pick_count" ) on existing skip
    select "c_doc_no","n_inout","c_tray_code","c_work_place","c_user","c_rack_grp_code","c_stage_code","t_time","t_action_start_time","t_action_end_time",
      "n_bounce_count","n_pick_count"
      from "st_track_tray_time"
      where "t_time" > "max_time";
  commit work
end;
