CREATE PROCEDURE "DBA"."usp_st_operational_dashboard"( 
  in @gsBr char(6),
  in @devID char(200),
  in @sKey char(20),
  in @cIndex char(30),
  in @workplace char(100),
  in @grp_code char(6) ) 
result( "is_xml_string" xml ) 
begin
  declare local temporary table "temp_login_user"(
    "c_user" char(10) not null,
    "c_rack_grp_list" char(500) null,
    primary key("c_user" asc),) on commit preserve rows;
  declare local temporary table "temp_activ_user"(
    "c_user" char(10) not null,) on commit preserve rows;
  declare "total_avg_time" numeric(10,2);
  declare @c_user char(10);
  declare @stage_grp_code char(6);
  if @devID = '' or @devID is null then
    set @gsBr = "http_variable"('gsBr'); --1
    set @devID = "http_variable"('devID'); --2
    set @sKey = "http_variable"('sKey'); --3
    set @cIndex = "http_variable"('cIndex'); --4
    set @workplace = "http_variable"('workplace'); --5
    if @workplace = 'SCANNING' then set @workplace = 'SCANNIG' end if;
    set @grp_code = "http_variable"('grp_code') --6
  end if;
  set @c_user = "http_variable"('userid');
  --set @stage_grp_code = http_variable('stage_code');
  --set @workplace='PICKING';
  case @cIndex
  when 'get_stage_grp_list' then
    -- http://172.16.18.201:18513/ws_st_operational_dashboard?&cIndex=get_stage_grp_list&gsbr=503&devID=93041163b2d45c0208102015103228463&sKEY=sKey&UserId=AKSHAY%20BS
    select "st_store_stage_grp_mst"."c_code" as "stage_code",
      "st_store_stage_grp_mst"."c_name" as "grp_name"
      from "st_store_stage_grp_mst" for xml raw,elements
  when 'get_performance' then
    --http://192.168.250.101:18503/ws_st_operational_dashboard?&cIndex=get_performance&workplace=PICKING&grp_code=STGP&gsbr=503&devID=eb4604b2594f3a4e20042017010511664&sKEY=sKey&UserId=
    if @workplace = 'PICKING' then
      insert into "temp_login_user"
        select "st_store_login_det"."c_user_id","list"(distinct "st_store_login_det"."c_rack_grp_code")
          from "st_store_login_det" join "st_store_stage_det" on "st_store_login_det"."c_br_code" = "st_store_stage_det"."c_br_code"
            and "st_store_login_det"."c_rack_grp_code" = "st_store_stage_det"."c_rack_grp_code"
            and "st_store_login_det"."c_stage_code" = "st_store_stage_det"."c_stage_code"
            join "st_store_stage_mst" on "st_store_stage_mst"."c_br_code" = "st_store_stage_det"."c_br_code"
            and "st_store_stage_mst"."c_code" = "st_store_stage_det"."c_stage_code"
            left outer join "st_store_stage_grp_mst" on "st_store_stage_grp_mst"."c_code" = "st_store_stage_mst"."c_stage_grp_code"
          where "st_store_stage_mst"."n_flag" = 1
          and "st_store_login_det"."t_login_time" is not null
          and "st_store_stage_grp_mst"."c_code" = @grp_code
          group by "st_store_login_det"."c_user_id"
    else
      insert into "temp_login_user"
        select "st_store_login_det"."c_user_id","list"(distinct "st_store_login_det"."c_rack_grp_code")
          from "st_store_login_det" join "st_store_stage_det" on "st_store_login_det"."c_br_code" = "st_store_stage_det"."c_br_code"
            and "st_store_login_det"."c_rack_grp_code" = "st_store_stage_det"."c_rack_grp_code"
            and "st_store_login_det"."c_stage_code" = "st_store_stage_det"."c_stage_code"
            join "st_store_stage_mst" on "st_store_stage_mst"."c_br_code" = "st_store_stage_det"."c_br_code"
            and "st_store_stage_mst"."c_code" = "st_store_stage_det"."c_stage_code"
          where "st_store_stage_mst"."n_flag" = 1
          and "st_store_login_det"."t_login_time" is not null
          group by "st_store_login_det"."c_user_id"
    end if;
    select "c_user",
      "sum"("isnull"("Pending_count",0)) as "Pending_count",
      "sum"("isnull"("Tot_avg_time_today"/if "today_pick_count" = 0 then 1 else "today_pick_count" endif,0)) as "Tot_avg_time_today",
      "sum"("isnull"("Tot_avg_time_yestr"/if "yday_pick_count" = 0 then 1 else "yday_pick_count" endif,0)) as "Tot_avg_time_yestr",
      "sum"("isnull"("overall_pick_time"/if "overall_pick_count" = 0 then 1 else "overall_pick_count" endif,0)) as "overall_pick_time",
      "sum"("isnull"("Lw_avg"/if "Lw_pick_count" = 0 then 1 else "Lw_pick_count" endif,0)) as "Lw_avg",
      "sum"("today_pick_count") as "pick_count",
      "Pending_count" as "n_alloted",
      "target"
      --   0 as "Pending_count",
      from(select "sdep"."c_user"+'  -['+"isnull"("temp_login_user"."c_rack_grp_list",'NA')+']' as "c_user",
          if @workplace = 'PICKING' then
            (select "count"("st_track_det"."c_item_code")
              from "st_track_det" left outer join "st_store_stage_mst" on "st_store_stage_mst"."c_code" = "st_track_det"."c_stage_code"
                left outer join "st_store_stage_grp_mst" on "st_store_stage_grp_mst"."c_code" = "st_store_stage_mst"."c_stage_grp_code"
              where "n_complete" = 0 and "st_track_det"."n_inout" = 0 and "st_track_det"."c_godown_code" = '-' and "n_non_pick_flag" = 0
              and "st_store_stage_grp_mst"."c_code" = @grp_code
              and "temp_login_user"."c_rack_grp_list" is not null
              and "c_rack_grp_code" = any(select "c_rack_grp_code" from "st_store_login_det" join "st_store_login" on "st_store_login_det"."c_br_code" = "st_store_login"."c_br_code"
                  and "st_store_login_det"."c_user_id" = "st_store_login"."c_user_id"
                where "st_store_login_det"."t_login_time" is not null and "st_store_login_det"."c_rack_grp_code" = "temp_login_user"."c_rack_grp_list"))
          else
            0
          endif as "Pending_count",
          "sum"("n_avg_time_in_seconds") as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          "sum"("n_item_count") as "today_pick_count",
          0 as "yday_pick_count",
          0 as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          "st_track_target"."n_target" as "target"
          from "st_daywise_emp_performance" as "sdep"
            left outer join "st_track_target" on "st_track_target"."c_stage_grp_code" = "sdep"."c_stage_grp_code"
            left outer join "temp_login_user" on "sdep"."c_user" = "temp_login_user"."c_user"
          where "d_date" = "uf_default_date"()
          and "sdep"."c_work_place" = 'PICKING'
          and "sdep"."c_stage_grp_code" = @grp_code
          and @workplace = 'PICKING'
          group by "sdep"."c_user","temp_login_user"."c_rack_grp_list","target" union all
        select "sdep"."c_user"+'  -['+"isnull"("temp_login_user"."c_rack_grp_list",'NA')+']' as "c_user",
          if @workplace = 'STOREIN' then
            (select "count"("st_track_det"."c_item_code")
              from "st_track_det" left outer join "st_store_stage_mst" on "st_store_stage_mst"."c_code" = "st_track_det"."c_stage_code"
                left outer join "st_store_stage_grp_mst" on "st_store_stage_grp_mst"."c_code" = "st_store_stage_mst"."c_stage_grp_code"
              where "n_complete" = 0 and "st_track_det"."n_inout" = 1 and "st_track_det"."c_godown_code" = '-'
              and "st_store_stage_grp_mst"."c_code" = @grp_code
              and "temp_login_user"."c_rack_grp_list" is not null
              and "c_rack_grp_code" = any(select "c_rack_grp_code" from "st_store_login_det" join "st_store_login" on "st_store_login_det"."c_br_code" = "st_store_login"."c_br_code"
                  and "st_store_login_det"."c_user_id" = "st_store_login"."c_user_id"
                where "st_store_login_det"."t_login_time" is not null and "st_store_login_det"."c_rack_grp_code" = "temp_login_user"."c_rack_grp_list"))
          else
            0
          endif as "Pending_count",
          "sum"("n_avg_time_in_seconds") as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          "sum"("n_item_count") as "today_pick_count",
          0 as "yday_pick_count",
          0 as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          "st_track_target"."n_target" as "target"
          from "st_daywise_emp_performance" as "sdep"
            left outer join "st_track_target" on "st_track_target"."c_stage_grp_code" = "sdep"."c_stage_grp_code"
            left outer join "temp_login_user" on "sdep"."c_user" = "temp_login_user"."c_user"
          where "d_date" = "uf_default_date"()
          and "sdep"."c_work_place" = 'STOREIN'
          and "sdep"."c_stage_grp_code" = @grp_code
          and @workplace = 'STOREIN'
          group by "sdep"."c_user","temp_login_user"."c_rack_grp_list","target" union all
        select "sdep"."c_user" as "c_user",
          0 as "Pending_count",
          "sum"("n_avg_time_in_seconds") as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          "sum"("n_item_count") as "today_pick_count",
          0 as "yday_pick_count",
          0 as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          0 as "target"
          from "st_daywise_emp_performance" as "sdep"
          where "d_date" = "today"()
          and "sdep"."c_work_place" = 'BARCODE PRINT'
          and @workplace = 'BARCODE PRINT'
          group by "c_user" union all
        select "sdep"."c_user" as "c_user",
          0 as "Pending_count",
          "sum"("n_avg_time_in_seconds") as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          "sum"("n_item_count") as "today_pick_count",
          0 as "yday_pick_count",
          0 as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          0 as "target"
          from "st_daywise_emp_performance" as "sdep"
          where "d_date" = "today"()
          and "sdep"."c_work_place" = 'BARCODE VERIFICATION'
          and @workplace = 'BARCODE VERIFICATION'
          group by "c_user" union all
        select "sdep"."c_user" as "c_user",
          0 as "Pending_count",
          "sum"("n_avg_time_in_seconds") as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          "sum"("n_item_count") as "today_pick_count",
          0 as "yday_pick_count",
          0 as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          0 as "target"
          from "st_daywise_emp_performance" as "sdep"
            join "temp_login_user" on "sdep"."c_user" = "temp_login_user"."c_user"
          where "d_date" = "today"()
          and "sdep"."c_work_place" = 'SCANNIG'
          and @workplace = 'SCANNIG'
          group by "c_user","c_rack_grp_list" union all
        select "sdep"."c_user"+'  -['+"isnull"("temp_login_user"."c_rack_grp_list",'NA')+']' as "c_user",
          0 as "Pending_count",
          0 as "Tot_avg_time_today",
          "sum"("n_avg_time_in_seconds") as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          0 as "today_pick_count",
          "sum"("n_item_count") as "yday_pick_count",
          0 as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          "st_track_target"."n_target" as "target"
          from "st_daywise_emp_performance" as "sdep"
            left outer join "st_track_target" on "st_track_target"."c_stage_grp_code" = "sdep"."c_stage_grp_code"
            left outer join "temp_login_user" on "sdep"."c_user" = "temp_login_user"."c_user"
          where "d_date" = (if "dayname"("today"()-1) = 'Sunday' then "today"()-2 else "today"()-1 endif)
          and "sdep"."c_work_place" = 'PICKING'
          and @workplace = 'PICKING'
          and "sdep"."c_stage_grp_code" = @grp_code
          group by "c_user","target" union all
        select "sdep"."c_user"+'  -['+"isnull"("temp_login_user"."c_rack_grp_list",'NA')+']' as "c_user",
          if @workplace = 'STOREIN' then
            (select "count"("st_track_det"."c_item_code")
              from "st_track_det" left outer join "st_store_stage_mst" on "st_store_stage_mst"."c_code" = "st_track_det"."c_stage_code"
                left outer join "st_store_stage_grp_mst" on "st_store_stage_grp_mst"."c_code" = "st_store_stage_mst"."c_stage_grp_code"
              where "n_complete" = 0 and "st_track_det"."n_inout" = 1 and "st_track_det"."c_godown_code" = '-'
              and "st_store_stage_grp_mst"."c_code" = @grp_code
              and "temp_login_user"."c_rack_grp_list" is not null
              and "c_rack_grp_code" = any(select "c_rack_grp_code" from "st_store_login_det" join "st_store_login" on "st_store_login_det"."c_br_code" = "st_store_login"."c_br_code"
                  and "st_store_login_det"."c_user_id" = "st_store_login"."c_user_id"
                where "st_store_login_det"."t_login_time" is not null and "st_store_login_det"."c_rack_grp_code" = "temp_login_user"."c_rack_grp_list"))
          else
            0
          endif as "Pending_count",
          0 as "Tot_avg_time_today",
          "sum"("n_avg_time_in_seconds") as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          0 as "today_pick_count",
          "sum"("n_item_count") as "yday_pick_count",
          0 as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          "st_track_target"."n_target" as "target"
          from "st_daywise_emp_performance" as "sdep"
            left outer join "st_track_target" on "st_track_target"."c_stage_grp_code" = "sdep"."c_stage_grp_code"
            left outer join "temp_login_user" on "sdep"."c_user" = "temp_login_user"."c_user"
          where "d_date" = (if "dayname"("today"()-1) = 'Sunday' then "today"()-2 else "today"()-1 endif)
          and "sdep"."c_work_place" = 'STOREIN'
          and @workplace = 'STOREIN'
          and "sdep"."c_stage_grp_code" = @grp_code
          group by "c_user","target","c_rack_grp_list" union all
        select "sdep"."c_user" as "c_user",
          0 as "Pending_count",
          0 as "Tot_avg_time_today",
          "sum"("n_avg_time_in_seconds") as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          0 as "today_pick_count",
          "sum"("n_item_count") as "yday_pick_count",
          0 as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          0 as "target"
          from "st_daywise_emp_performance" as "sdep"
          where "d_date" = (if "dayname"("today"()-1) = 'Sunday' then "today"()-2 else "today"()-1 endif)
          and "sdep"."c_work_place" = 'BARCODE PRINT'
          and @workplace = 'BARCODE PRINT'
          group by "c_user" union all
        select "sdep"."c_user" as "c_user",
          0 as "Pending_count",
          0 as "Tot_avg_time_today",
          "sum"("n_avg_time_in_seconds") as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          0 as "today_pick_count",
          "sum"("n_item_count") as "yday_pick_count",
          0 as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          0 as "target"
          from "st_daywise_emp_performance" as "sdep"
          where "d_date" = (if "dayname"("today"()-1) = 'Sunday' then "today"()-2 else "today"()-1 endif)
          and "sdep"."c_work_place" = 'BARCODE VERIFICATION'
          and @workplace = 'BARCODE VERIFICATION'
          group by "c_user" union all
        select "sdep"."c_user" as "c_user",
          0 as "Pending_count",
          0 as "Tot_avg_time_today",
          "sum"("n_avg_time_in_seconds") as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          0 as "today_pick_count",
          "sum"("n_item_count") as "yday_pick_count",
          0 as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          0 as "target"
          from "st_daywise_emp_performance" as "sdep"
          where "d_date" = (if "dayname"("today"()-1) = 'Sunday' then "today"()-2 else "today"()-1 endif)
          and "sdep"."c_work_place" = 'SCANNIG'
          and @workplace = 'SCANNIG'
          group by "c_user" union all
        select "sdep"."c_user"+'  -['+"isnull"("temp_login_user"."c_rack_grp_list",'NA')+']' as "c_user",
          0 as "Pending_count",
          0 as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          "sum"("n_avg_time_in_seconds") as "overall_pick_time",
          0 as "today_pick_count",
          0 as "yday_pick_count",
          "sum"("n_item_count") as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          "st_track_target"."n_target" as "target"
          from "st_daywise_emp_performance" as "sdep"
            left outer join "st_track_target" on "st_track_target"."c_stage_grp_code" = "sdep"."c_stage_grp_code"
            left outer join "temp_login_user" on "sdep"."c_user" = "temp_login_user"."c_user"
          where "sdep"."c_work_place" = 'PICKING'
          and "sdep"."c_stage_grp_code" = @grp_code
          and @workplace = 'PICKING'
          group by "c_user","target" union all
        select "sdep"."c_user"+'  -['+"isnull"("temp_login_user"."c_rack_grp_list",'NA')+']' as "c_user",
          if @workplace = 'STOREIN' then
            (select "count"("st_track_det"."c_item_code")
              from "st_track_det" left outer join "st_store_stage_mst" on "st_store_stage_mst"."c_code" = "st_track_det"."c_stage_code"
                left outer join "st_store_stage_grp_mst" on "st_store_stage_grp_mst"."c_code" = "st_store_stage_mst"."c_stage_grp_code"
              where "n_complete" = 0 and "st_track_det"."n_inout" = 1 and "st_track_det"."c_godown_code" = '-'
              and "st_store_stage_grp_mst"."c_code" = @grp_code
              and "temp_login_user"."c_rack_grp_list" is not null
              and "c_rack_grp_code" = any(select "c_rack_grp_code" from "st_store_login_det" join "st_store_login" on "st_store_login_det"."c_br_code" = "st_store_login"."c_br_code"
                  and "st_store_login_det"."c_user_id" = "st_store_login"."c_user_id"
                where "st_store_login_det"."t_login_time" is not null and "st_store_login_det"."c_rack_grp_code" = "temp_login_user"."c_rack_grp_list"))
          else
            0
          endif as "Pending_count",
          0 as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          "sum"("n_avg_time_in_seconds") as "overall_pick_time",
          0 as "today_pick_count",
          0 as "yday_pick_count",
          "sum"("n_item_count") as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          "st_track_target"."n_target" as "target"
          from "st_daywise_emp_performance" as "sdep"
            left outer join "st_track_target" on "st_track_target"."c_stage_grp_code" = "sdep"."c_stage_grp_code"
            left outer join "temp_login_user" on "sdep"."c_user" = "temp_login_user"."c_user"
          where "sdep"."c_work_place" = 'STOREIN'
          and "sdep"."c_stage_grp_code" = @grp_code
          and @workplace = 'STOREIN'
          group by "c_user","target","c_rack_grp_list" union all
        select "sdep"."c_user" as "c_user",
          0 as "Pending_count",
          0 as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          "sum"("n_avg_time_in_seconds") as "overall_pick_time",
          0 as "today_pick_count",
          0 as "yday_pick_count",
          "sum"("n_item_count") as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          0 as "target"
          from "st_daywise_emp_performance" as "sdep"
          where "sdep"."c_work_place" = 'BARCODE PRINT'
          and @workplace = 'BARCODE PRINT'
          group by "c_user" union all
        select "sdep"."c_user" as "c_user",
          0 as "Pending_count",
          0 as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          "sum"("n_avg_time_in_seconds") as "overall_pick_time",
          0 as "today_pick_count",
          0 as "yday_pick_count",
          "sum"("n_item_count") as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          0 as "target"
          from "st_daywise_emp_performance" as "sdep"
          where "sdep"."c_work_place" = 'BARCODE VERIFICATION'
          and @workplace = 'BARCODE VERIFICATION'
          group by "c_user" union all
        select "sdep"."c_user" as "c_user",
          0 as "Pending_count",
          0 as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          "sum"("n_avg_time_in_seconds") as "overall_pick_time",
          0 as "today_pick_count",
          0 as "yday_pick_count",
          "sum"("n_item_count") as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          0 as "target"
          from "st_daywise_emp_performance" as "sdep"
          where "sdep"."c_work_place" = 'SCANNIG'
          and @workplace = 'SCANNIG'
          group by "c_user" union all
        select "sdep"."c_user"+'  -['+"isnull"("temp_login_user"."c_rack_grp_list",'NA')+']' as "c_user",
          0 as "Pending_count",
          0 as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          0 as "today_pick_count",
          0 as "yday_pick_count",
          0 as "overall_pick_count",
          "sum"("n_avg_time_in_seconds") as "Lw_avg",
          "sum"("n_item_count") as "Lw_pick_count",
          "st_track_target"."n_target" as "target"
          from "st_daywise_emp_performance" as "sdep"
            left outer join "st_track_target" on "st_track_target"."c_stage_grp_code" = "sdep"."c_stage_grp_code"
            left outer join "temp_login_user" on "sdep"."c_user" = "temp_login_user"."c_user"
          where "d_date"
          between if "trim"("left"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1)) = '' then
            null else "left"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1) endif
          and if "trim"("right"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1)) = '' then
            null else "right"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1) endif
          and "sdep"."c_work_place" = 'PICKING'
          and @workplace = 'PICKING'
          and "sdep"."c_stage_grp_code" = @grp_code
          group by "c_user","target" union all
        select "sdep"."c_user"+'  -['+"isnull"("temp_login_user"."c_rack_grp_list",'NA')+']' as "c_user",
          if @workplace = 'STOREIN' then
            (select "count"("st_track_det"."c_item_code")
              from "st_track_det" left outer join "st_store_stage_mst" on "st_store_stage_mst"."c_code" = "st_track_det"."c_stage_code"
                left outer join "st_store_stage_grp_mst" on "st_store_stage_grp_mst"."c_code" = "st_store_stage_mst"."c_stage_grp_code"
              where "n_complete" = 0 and "st_track_det"."n_inout" = 1 and "st_track_det"."c_godown_code" = '-'
              and "st_store_stage_grp_mst"."c_code" = @grp_code
              and "temp_login_user"."c_rack_grp_list" is not null
              and "c_rack_grp_code" = any(select "c_rack_grp_code" from "st_store_login_det" join "st_store_login" on "st_store_login_det"."c_br_code" = "st_store_login"."c_br_code"
                  and "st_store_login_det"."c_user_id" = "st_store_login"."c_user_id"
                where "st_store_login_det"."t_login_time" is not null and "st_store_login_det"."c_rack_grp_code" = "temp_login_user"."c_rack_grp_list"))
          else
            0
          endif as "Pending_count",
          0 as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          0 as "today_pick_count",
          0 as "yday_pick_count",
          0 as "overall_pick_count",
          "sum"("n_avg_time_in_seconds") as "Lw_avg",
          "sum"("n_item_count") as "Lw_pick_count",
          "st_track_target"."n_target" as "target"
          from "st_daywise_emp_performance" as "sdep"
            left outer join "st_track_target" on "st_track_target"."c_stage_grp_code" = "sdep"."c_stage_grp_code"
            left outer join "temp_login_user" on "sdep"."c_user" = "temp_login_user"."c_user"
          where "d_date"
          between if "trim"("left"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1)) = '' then
            null else "left"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1) endif
          and if "trim"("right"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1)) = '' then
            null else "right"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1) endif
          and "sdep"."c_work_place" = 'STOREIN'
          and @workplace = 'STOREIN'
          and "sdep"."c_stage_grp_code" = @grp_code
          group by "c_user","target","c_rack_grp_list" union all
        select "sdep"."c_user" as "c_user",
          0 as "Pending_count",
          0 as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          0 as "today_pick_count",
          0 as "yday_pick_count",
          0 as "overall_pick_count",
          "sum"("n_avg_time_in_seconds") as "Lw_avg",
          "sum"("n_item_count") as "Lw_pick_count",
          0 as "target"
          from "st_daywise_emp_performance" as "sdep"
          where "d_date"
          between if "trim"("left"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1)) = '' then
            null else "left"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1) endif
          and if "trim"("right"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1)) = '' then
            null else "right"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1) endif
          and "sdep"."c_work_place" = 'BARCODE PRINT'
          and @workplace = 'BARCODE PRINT'
          group by "c_user" union all
        select "sdep"."c_user" as "c_user",
          0 as "Pending_count",
          0 as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          0 as "today_pick_count",
          0 as "yday_pick_count",
          0 as "overall_pick_count",
          "sum"("n_avg_time_in_seconds") as "Lw_avg",
          "sum"("n_item_count") as "Lw_pick_count",
          0 as "target"
          from "st_daywise_emp_performance" as "sdep"
          where "d_date" between if "trim"("left"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1)) = '' then
            null else "left"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1) endif
          and if "trim"("right"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1)) = '' then
            null else "right"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1) endif
          and "sdep"."c_work_place" = 'BARCODE VERIFICATION'
          and @workplace = 'BARCODE VERIFICATION'
          group by "c_user" union all
        select "sdep"."c_user" as "c_user",
          0 as "Pending_count",
          0 as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          0 as "today_pick_count",
          0 as "yday_pick_count",
          0 as "overall_pick_count",
          "sum"("n_avg_time_in_seconds") as "Lw_avg",
          "sum"("n_item_count") as "Lw_pick_count",
          0 as "target"
          from "st_daywise_emp_performance" as "sdep"
          where "d_date"
          between if "trim"("left"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1)) = '' then
            null else "left"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1) endif
          and if "trim"("right"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1)) = '' then
            null else "right"("uf_date_of_previous_week"("today"()),"charindex"('|',"uf_date_of_previous_week"("today"()))-1) endif
          and "sdep"."c_work_place" = 'SCANNIG'
          and @workplace = 'SCANNIG'
          group by "c_user" union all
        select 'UN-ALLOCATED' as "c_user",
          if @workplace = 'PICKING' then "count"("c_item_code") else 0 endif as "Pending_count",
          0 as "Tot_avg_time_today",
          0 as "Tot_avg_time_yestr",
          0 as "overall_pick_time",
          0 as "today_pick_count",
          0 as "yday_pick_count",
          0 as "overall_pick_count",
          0 as "Lw_avg",
          0 as "Lw_pick_count",
          "st_track_target"."n_target" as "target"
          from "st_track_det"
            left outer join "st_store_login_det" on "st_track_det"."c_rack_grp_code" = "st_store_login_det"."c_rack_grp_code"
            and "st_track_det"."c_stage_code" = "st_store_login_det"."c_stage_code"
            join "st_store_stage_mst" on "st_store_stage_mst"."c_code" = "st_track_det"."c_stage_code"
            join "st_store_stage_grp_mst" on "st_store_stage_grp_mst"."c_code" = "st_store_stage_mst"."c_stage_grp_code"
            left outer join "st_track_target" on "st_track_target"."c_stage_grp_code" = "st_store_stage_grp_mst"."c_code"
          where "st_track_det"."n_complete" = 0 and "st_track_det"."c_tray_code" is null and "st_track_det"."n_inout" = 0
          and "st_track_det"."n_non_pick_flag" = 0
          and "st_store_stage_grp_mst"."c_code" = @grp_code
          and "st_store_login_det"."t_login_time" is null
          group by "target") as "tem"
      group by "c_user","target"
      order by "Tot_avg_time_today" desc,"Tot_avg_time_yestr" desc for xml raw,elements
  // end of new index
  when 'get_break_time' then
    select cast("dateadd"("minute","abs"("DATEDIFF"("minute","t_from_time","t_to_time"))/"isnull"("n_brk_time_per",0),"t_from_time") as time) as "From_time",
      "st_dept_brk_time"."t_to_time" as "To_time"
      from "st_dept_brk_time","st_track_setup"
      where "st_dept_brk_time"."c_work_place" = @workplace for xml raw,elements
  when 'get_estimated_time' then
    insert into "temp_activ_user"
      select distinct "c_user" from "st_daywise_emp_performance" where cast("d_date" as "datetime") > "DATEADD"("hour",-1,"GETDATE"()) and "c_work_place" = 'scannig';
    select "isnull"("avg"("overal_time"),0) as "avg_pick_time",
      (select "count"("temp_activ_user"."c_user") from "temp_activ_user") as "loged_in_user",
      (select "count"(distinct "c_doc_no"+"c_item_code") from "st_track_pick" where "st_track_pick"."n_inout" = 0
        and "st_track_pick"."n_qty"-("st_track_pick"."n_confirm_qty"+"st_track_pick"."n_reject_qty") > 0) as "pending_count"
      from(select "n_item_count" as "total_cnt",
          "n_avg_time_in_seconds" as "overall_pick_time",
          "overall_pick_time"/"total_cnt" as "overal_time"
          from "st_daywise_emp_performance","temp_activ_user"
          where "st_daywise_emp_performance"."c_user" = "temp_activ_user"."c_user"
          and "d_date" > "uf_default_date"()-3
          and "c_work_place" = @workplace) as "a" for xml raw,elements
  when 'get_summary' then
    select cast("avg"("Tot_avg_time_today") as decimal(10,2)) as "Run_rate",cast("max"("Tot_avg_time_today") as decimal(10,2)) as "worst",
      cast("min"("Tot_avg_time_today") as decimal(10,2)) as "best","c_work_place","count"(distinct "c_user") as "user_count",
      if "c_work_place" = 'PICKING' then(select "count"("st_track_det"."c_item_code") from "st_track_det" where "n_complete" = 0 and "st_track_det"."n_inout" = 0
          and "c_godown_code" = '-' and "n_non_pick_flag" = 0)
      else if "c_work_place" = 'SCANNING' then(select "count"(distinct "c_item_code") from "st_track_pick" where "n_qty"-("n_confirm_qty"+"n_reject_qty") > 0)
        else 0
        endif
      endif as "pending_count","target"
      from(select "c_user" as "c_user","n_avg_time_in_seconds"/"n_item_count" as "Tot_avg_time_today",
          "st_daywise_emp_performance"."c_work_place" as "c_work_place",
          (select distinct "n_target" from "st_track_target" join "st_daywise_emp_performance" on "st_track_target"."c_work_place" = "st_daywise_emp_performance"."c_work_place") as "target"
          from "st_daywise_emp_performance"
          where "d_date" = "uf_default_date"()) as "t"
      group by "c_work_place","target" for xml raw,elements
  when 'get_user_performance' then
    if(select "count"("c_code") from "st_track_module_mst" where "c_code" = 'M00043' and "n_active" = 1) = 0 then
      select '' as "c_message" for xml raw,elements;
      return
    end if;
    select top 1 "c_stage_grp_code" into @stage_grp_code from "st_store_stage_mst" where "c_code" = @grp_code;
    select "avg"("OVERALL_AVG_TIME")
      into "total_avg_time"
      from(select "c_user",
          "sum"("n_avg_time_in_seconds"/"n_item_count") as "OVERALL_AVG_TIME"
          from "st_daywise_emp_performance"
          where "c_work_place" = @workplace
          and "d_date" = "uf_default_date"()
          group by "c_user") as "t";
    select("Tot_avg_time_today"/if "today_pick_count" = 0 then 1 else "today_pick_count" endif) as "my_avg_time",
      -- "isnull"(if "today_pick_count" = 0 then 1 else "today_pick_count" endif/"Tot_avg_time_today",0) as "my_avg_time",
      "total_avg_time",
      "isnull"("Pending_count",0) as "pending_count"
      from(select if @workplace = 'PICKING' then
            (select "count"("st_track_det"."c_item_code")
              from "st_track_det"
              where "n_complete" = 0 and "st_track_det"."n_inout" = 0 and "st_track_det"."c_godown_code" = '-'
              and "st_track_det"."n_non_pick_flag" <> 1
              and "c_rack_grp_code" = any(select "c_rack_grp_code" from "st_store_login_det" join "st_store_login" on "st_store_login_det"."c_br_code" = "st_store_login"."c_br_code"
                  and "st_store_login_det"."c_user_id" = "st_store_login"."c_user_id"
                where "st_store_login"."t_login_time" is not null and "st_daywise_emp_performance"."c_user" = "st_store_login"."c_user_id"))
          else
            0
          endif as "pending_count",
          "sum"("n_avg_time_in_seconds") as "Tot_avg_time_today",
          "sum"("n_item_count") as "today_pick_count"
          from "st_daywise_emp_performance"
          where cast("d_date" as date) = "uf_default_date"()
          and "c_work_place" = @workplace
          and @workplace = 'PICKING'
          and "c_stage_grp_code" = @stage_grp_code
          and "c_user" = @c_user
          group by "c_user" union all
        select if @workplace = 'BARCODE VERIFICATION' then
            (select "count"("st_track_pick"."c_item_code")
              from "st_track_pick"
              where "st_track_pick"."n_inout" = 0 and "st_track_pick"."c_godown_code" = '-'
              and "c_barcode_user" = (select "c_user_id" from "st_store_login"
                where "st_store_login"."t_login_time" is not null
                and "st_store_login"."c_user_id" = "st_daywise_emp_performance"."c_user")
              and "st_track_pick"."c_barcode_user" is not null
              and "n_qty"-("n_confirm_qty"+"n_reject_qty") > 0)
          else
            0
          endif as "pending_count",
          "sum"("n_avg_time_in_seconds") as "Tot_avg_time_today",
          "sum"("n_item_count") as "today_pick_count"
          from "st_daywise_emp_performance"
          where cast("d_date" as date) = "uf_default_date"()
          and "c_work_place" = @workplace
          and @workplace = 'BARCODE VERIFICATION'
          and "c_stage_grp_code" = @stage_grp_code
          and "c_user" = @c_user
          group by "c_user" union all
        select 0 as "pending_count",
          "sum"("n_avg_time_in_seconds") as "Tot_avg_time_today",
          "sum"("n_item_count") as "today_pick_count"
          from "st_daywise_emp_performance"
          where cast("d_date" as date) = "uf_default_date"()
          and "c_work_place" = @workplace
          and @workplace = 'SCANNIG'
          and "c_stage_grp_code" = @stage_grp_code
          and "c_user" = @c_user
          group by "c_user") as "tem" for xml raw,elements
  when 'get_target' then
    select "n_target" as "target" from "st_track_target" where "c_work_place" = @workplace and "c_stage_grp_code" = '-' for xml raw,elements
  when 'get_workplace' then
    select 'PICKING' as "c_name" from "dummy" union all
    select 'STOREIN' from "dummy" union all
    select 'BARCODE PRINT' from "dummy" union all
    select 'BARCODE VERIFICATION' from "dummy" union all
    select 'SCANNING' from "dummy" for xml raw,elements
  end case --union all
-- select 'STOREIN_EXP' from "dummy" 
end;