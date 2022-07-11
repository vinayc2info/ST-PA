CREATE PROCEDURE "DBA"."usp_st_operational_avg"( 
  in @gsBr char(6),
  in @devID char(200),
  in @sKey char(20),
  in @cIndex char(30),
  in @workplace char(100),
  in @grp_code char(6) ) 
result( "is_xml_string" xml ) 
begin
  declare @c_user char(10);
  declare "YA" numeric(20,10);
  declare "WA" numeric(20,15);
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
  case @cIndex
  when 'get_avg_today' then
    --http://172.16.18.201:18503/ws_st_operational_avg?&cIndex=get_avg_today&workplace=PICKING&grp_code=STGP&gsbr=503&devID=eb4604b2594f3a4e20042017010511664&sKEY=sKey&UserId=
    select "avg"("Tot_avg_time_today") as "Today_avg"
      from(select distinct "c_user" as "c_usr",
          "sum"("isnull"("TA"/if "today_pick_count" = 0 then 1 else "today_pick_count" endif,0)) as "Tot_avg_time_today"
          from(select "st_daywise_emp_performance"."c_user" as "c_user",
              "sum"("st_daywise_emp_performance"."n_avg_time_in_seconds") as "TA",
              "sum"("n_item_count") as "today_pick_count"
              from "st_daywise_emp_performance"
              where "d_date" = "uf_default_date"()
              and "st_daywise_emp_performance"."c_work_place" = @workplace
              and "st_daywise_emp_performance"."c_work_place" = 'PICKING'
              and "st_daywise_emp_performance"."c_stage_grp_code" = @grp_code
              group by "c_user" union all
            select "st_daywise_emp_performance"."c_user" as "c_user",
              "sum"("st_daywise_emp_performance"."n_avg_time_in_seconds") as "TA",
              "sum"("n_item_count") as "today_pick_count"
              from "st_daywise_emp_performance"
              where "st_daywise_emp_performance"."d_date" = "uf_default_date"()
              and "st_daywise_emp_performance"."c_work_place" = @workplace
              and "st_daywise_emp_performance"."c_work_place" <> 'PICKING'
              and "st_daywise_emp_performance"."c_stage_grp_code" = @grp_code
              group by "c_user") as "t"
          group by "c_usr") as "t1" for xml raw,elements
  when 'get_avg_week_yest' then
    --http://172.16.18.201:18503/ws_st_operational_avg?&cIndex=get_avg_week_yest&workplace=PICKING&grp_code=STGP&gsbr=503&devID=eb4604b2594f3a4e20042017010511664&sKEY=sKey&UserId=
    select "avg"("Tot_avg_time_yestr") as "Ys_Avg"
      -- and cast(tray_time_weekly.t_time as date) = (if dayname(DBA.uf_default_date()-1) = 'Sunday' then DBA.uf_default_date()-2 else DBA.uf_default_date()-1 endif)
      into "YA"
      from(select distinct "c_user" as "c_usr",
          "sum"("isnull"("Tot_avg_time_yestr"/if "yday_pick_count" = 0 then 1 else "yday_pick_count" endif,0)) as "Tot_avg_time_yestr",
          0 as "Tot_avg_time_week"
          from(select "st_daywise_emp_performance"."c_user" as "c_user",
              "sum"("n_avg_time_in_seconds") as "Tot_avg_time_yestr",
              "sum"("n_item_count") as "yday_pick_count",
              0 as "Lw_avg",
              0 as "Lw_pick_count"
              from "st_daywise_emp_performance"
              where "d_date" = "uf_default_date"()-1
              and "st_daywise_emp_performance"."c_work_place" = 'PICKING'
              and "st_daywise_emp_performance"."c_work_place" = @workplace
              and "st_daywise_emp_performance"."c_stage_grp_code" = @grp_code
              group by "c_user" union all
            select "st_daywise_emp_performance"."c_user" as "c_user",
              "sum"("n_avg_time_in_seconds") as "Tot_avg_time_yestr",
              "sum"("n_item_count") as "yday_pick_count",
              0 as "Lw_avg",
              0 as "Lw_pick_count"
              from "st_daywise_emp_performance"
              where "d_date" = (if "dayname"("DBA"."uf_default_date"()-1) = 'Sunday' then "DBA"."uf_default_date"()-2
              else "DBA"."uf_default_date"()-1
              endif) and "st_daywise_emp_performance"."c_work_place" <> 'PICKING'
              and "st_daywise_emp_performance"."c_work_place" = @workplace
              and "st_daywise_emp_performance"."c_stage_grp_code" = @grp_code
              group by "c_user") as "t"
          group by "c_usr") as "t1";
    --week
    select "avg"("Tot_avg_time_week") as "Week_Avg"
      into "WA"
      from(select distinct "c_user" as "c_usr",
          "sum"("isnull"("Lw_avg"/if "Lw_pick_count" = 0 then 1 else "Lw_pick_count" endif,0)) as "Tot_avg_time_week"
          from(select "st_daywise_emp_performance"."c_user" as "c_user",
              "sum"("st_daywise_emp_performance"."n_avg_time_in_seconds") as "Lw_avg",
              "sum"("n_item_count") as "Lw_pick_count"
              from "st_daywise_emp_performance"
              where "d_date"
              between if "trim"("left"("uf_date_of_previous_week"("uf_default_date"()),"charindex"('|',"uf_date_of_previous_week"("uf_default_date"()))-1)) = '' then
                null else "left"("uf_date_of_previous_week"("uf_default_date"()),"charindex"('|',"uf_date_of_previous_week"("uf_default_date"()))-1) endif
              and if "trim"("right"("uf_date_of_previous_week"("uf_default_date"()),"charindex"('|',"uf_date_of_previous_week"("uf_default_date"()))-1)) = '' then
                null else "right"("uf_date_of_previous_week"("uf_default_date"()),"charindex"('|',"uf_date_of_previous_week"("uf_default_date"()))-1) endif
              and "st_daywise_emp_performance"."c_work_place" = 'PICKING'
              and "st_daywise_emp_performance"."c_work_place" = @workplace
              and "st_daywise_emp_performance"."c_stage_grp_code" = @grp_code
              group by "c_user" union all
            select "st_daywise_emp_performance"."c_user" as "c_user",
              "sum"("n_avg_time_in_seconds") as "Lw_avg",
              "sum"("n_item_count") as "Lw_pick_count"
              from "st_daywise_emp_performance"
              where "d_date"
              between if "trim"("left"("uf_date_of_previous_week"("uf_default_date"()),"charindex"('|',"uf_date_of_previous_week"("uf_default_date"()))-1)) = '' then
                null else "left"("uf_date_of_previous_week"("uf_default_date"()),"charindex"('|',"uf_date_of_previous_week"("uf_default_date"()))-1) endif
              and if "trim"("right"("uf_date_of_previous_week"("uf_default_date"()),"charindex"('|',"uf_date_of_previous_week"("uf_default_date"()))-1)) = '' then
                null else "right"("uf_date_of_previous_week"("uf_default_date"()),"charindex"('|',"uf_date_of_previous_week"("uf_default_date"()))-1) endif
              and "st_daywise_emp_performance"."c_work_place" <> 'PICKING'
              and "st_daywise_emp_performance"."c_work_place" = @workplace
              and "st_daywise_emp_performance"."c_stage_grp_code" = @grp_code
              group by "c_user") as "t"
          group by "c_usr") as "t1";
    -----------------------------------------------------------------------
    select "WA","YA" for xml raw,elements
  end case
end