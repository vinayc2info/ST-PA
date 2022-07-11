CREATE PROCEDURE "DBA"."usp_st_week_time_insertion"()
begin
  declare @tray_time_weekly_data_cnt numeric(12);
  declare @min_week_time date;
  select "count"() into @tray_time_weekly_data_cnt from "tray_time_weekly";
  if @tray_time_weekly_data_cnt = 0 then
    insert into "tray_time_weekly"
      ( "c_doc_no","n_inout","c_tray_code","c_work_place","c_user","c_rack_grp_code","c_stage_code","t_time","t_action_start_time","t_action_end_time",
      "n_bounce_count","n_pick_count" ) on existing skip
      select "c_doc_no","n_inout","c_tray_code","c_work_place","c_user","c_rack_grp_code","c_stage_code","t_time","t_action_start_time","t_action_end_time",
        "n_bounce_count","n_pick_count"
        from "st_track_tray_time"
        where cast("st_track_tray_time"."t_time" as date) >= "uf_default_date"()-7
  else
    insert into "tray_time_weekly"
      ( "c_doc_no","n_inout","c_tray_code","c_work_place","c_user","c_rack_grp_code","c_stage_code","t_time","t_action_start_time","t_action_end_time",
      "n_bounce_count","n_pick_count" ) on existing update defaults off
      select "c_doc_no","n_inout","c_tray_code","c_work_place","c_user","c_rack_grp_code","c_stage_code","t_time","t_action_start_time","t_action_end_time",
        "n_bounce_count","n_pick_count"
        from "st_track_tray_time"
        where cast("t_time" as date) = "uf_default_date"()-1;
    select "min"(cast("tray_time_weekly"."t_time" as date)) into @min_week_time from "tray_time_weekly";
    delete from "tray_time_weekly" where cast("t_time" as date) = @min_week_time
  end if
end;