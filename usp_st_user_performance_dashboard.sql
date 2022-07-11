CREATE PROCEDURE "DBA"."usp_st_user_performance_dashboard"( 
  in @gsBr char(6), --1
  in @devID char(200), --2
  in @sKey char(20), --3
  in @UserId char(20), --4
  in @cIndex char(30), --5
  in @GodownCode char(6), --6
  in @HdrData char(7000), --7
  in @DetData char(7000) )  --8
result( 
  "is_xml_string" xml ) 
begin
  /*
--http://172.16.18.38:16503/ws_st_user_performance_dashboard?
&gsbr=503&devID=3c824667f4396fc729062016041357979&sKEY=&UserId=MYBOSS&cIndex=pick_summary&GodownCode=-HdrData=&DetData=
Author          : Saneesh C G
Procedure       : usp_st_user_performance_dashboard
SERVICE         : ws_st_user_performance_dashboard
Date            : 25-04-2017
modified by : Gargee
Ldate           : 
Purpose         : User Performance Dashboard
Input           : 
Service Call (Format): 
*/
  --common >>
  declare @BrCode char(6);
  declare @t_ltime char(25);
  declare @d_ldate char(20);
  declare @nUserValid integer;
  declare @RackGrpList char(7000);
  declare @ColSep char(6);
  declare @RowSep char(6);
  declare @Pos integer;
  declare @ColPos integer;
  declare @RowPos integer;
  declare @ColMaxLen numeric(4);
  declare @RowMaxLen numeric(4);
  declare @cUser char(20);
  declare @d_date date;
  declare local temporary table "temp_user_list"(
    "c_user_id" char(10) null,
    ) on commit preserve rows;
  declare @tmp char(20);
  --common <<
  if @devID = '' or @devID is null then
    set @gsBr = "http_variable"('gsBr'); --1
    set @devID = "http_variable"('devID'); --2
    set @sKey = "http_variable"('sKey'); --3
    set @UserId = "http_variable"('UserId'); --4
    set @cIndex = "http_variable"('cIndex'); --5
    set @GodownCode = "http_variable"('GodownCode'); --6
    set @HdrData = "http_variable"('HdrData'); --7
    set @DetData = "http_variable"('DetData') --8
  end if;
  insert into "user_perf_log"
    ( "c_index","t_time","c_input" ) values( @cIndex,"getdate"(),@devID ) ;
  select "c_delim" into @ColSep from "ps_tab_delimiter" where "n_seq" = 0;
  select "c_delim" into @RowSep from "ps_tab_delimiter" where "n_seq" = 1;
  set @ColMaxLen = "Length"(@ColSep);
  set @RowMaxLen = "Length"(@RowSep);
  set @BrCode = "uf_get_br_code"(@gsBr);
  set @t_ltime = "left"("now"(),19);
  set @d_ldate = "uf_default_date"();
  case @cIndex
  when 'Pick_Summary' then
    select "t"."c_work_place",
      "t"."c_name",
      "t"."c_user",
      "t"."time_in_sec",
      "t"."item_pick_count",
      "t"."item_bounce_count"
      --order by c_work_place asc,st_store_stage_grp_mst.c_name asc,c_user asc 
      --order by c_work_place asc,st_store_stage_grp_mst.c_name asc,c_user asc 
      from(select "c_work_place",
          "st_store_stage_grp_mst"."c_name" as "c_name",
          "st_track_tray_time"."c_user",
          "sum"("DATEDIFF"("ss","t_action_start_time","t_action_end_time")) as "time_in_sec",
          "isnull"("sum"("n_pick_count"),0) as "item_pick_count",
          "isnull"("sum"("n_bounce_count"),0) as "item_bounce_count"
          from "st_track_tray_time"
            left outer join "st_store_stage_mst" on "st_store_stage_mst"."c_code" = "st_track_tray_time"."c_stage_code"
            left outer join "st_store_stage_grp_mst" on "st_store_stage_grp_mst"."c_code" = "st_store_stage_mst"."c_stage_grp_code"
          where "t_action_end_time" is not null
          and "date"("t_time") >= "uf_default_date"()
          and "c_work_place" <> 'BARCODE PRINT' and "t_action_start_time" is not null
          group by "c_work_place","st_track_tray_time"."c_user","st_store_stage_grp_mst"."c_name"
          having "item_pick_count" > 0 union
        select 'Inward as Purchase' as "c_work_place",
          '-' as "c_name",
          "pur_mst"."c_user",
          1 as "time_in_sec",
          "count"("pur_mst"."n_srno") as "item_pick_count",
          0 as "item_bounce_count"
          from "pur_mst"
          where "pur_mst"."d_ldate" >= "uf_default_date"() and "pur_mst"."c_prefix" = 'K'
          group by "c_work_place","pur_mst"."c_user","c_name"
          having "item_pick_count" > 0 union
        select 'Inward as GRE' as "c_work_place",
          '-' as "c_name",
          "goods_rec_det"."c_user",
          1 as "time_in_sec",
          "count"("goods_rec_det"."c_item_code") as "item_pick_count",
          0 as "item_bounce_count"
          from "goods_rec_det" join "goods_rec_mst" on "goods_rec_mst"."c_br_code" = "goods_rec_det"."c_br_code" and "goods_rec_mst"."c_year" = "goods_rec_det"."c_year" and "goods_rec_mst"."c_prefix" = "goods_rec_det"."c_prefix" and "goods_rec_mst"."n_srno" = "goods_rec_det"."n_srno"
          where "goods_rec_det"."d_ldate" >= "uf_default_date"() and "goods_rec_mst"."c_prefix" = '158'
          group by "c_work_place","goods_rec_det"."c_user","c_name"
          having "item_pick_count" > 0) as "t"
      order by "t"."c_work_place" asc,"t"."c_name" asc,"t"."c_user" asc for xml raw,elements
  when 'Get_image' then
    --HdrData-->User1^^ Usre2^^ User3^^
    --http://172.16.18.38:16503/ws_st_user_performance_dashboard?&gsbr=503&devID=3c824667f4396fc729062016041357979&sKEY=&UserId=MYBOSS&cIndex=Get_image&GodownCode=-HdrData=User1^^User2^^User3^^&DetData=
    while @HdrData <> '' loop
      select "Locate"(@HdrData,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@HdrData,@ColPos-1));
      set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
      insert into "temp_user_list"( "c_user_id" ) values( @tmp ) 
    end loop;
    select "user_mst"."c_code","user_mst"."c_user_id" as "c_user",
      "isnull"((select top 1 "BASE64_ENCODE"(("b_image"))
        from "win_image"
        where "win_image"."n_cancel_flag" = 0
        and "win_image"."c_key_code" = "user_mst"."c_Code"
        order by "t_ltime" desc),
      'NOIMAGE') as "image"
      from "user_mst"
        join "temp_user_list" on "temp_user_list"."c_user_id" = "user_mst"."c_user_id" for xml raw,elements
  --where c_user_id ='MYBOSS'
  when 'get_prev_data' then
    --http://172.16.18.38:16503/ws_st_user_performance_dashboard?&gsbr=503&devID=3c824667f4396fc729062016041357979&sKEY=&UserId=MYBOSS&cIndex=get_prev_data&GodownCode=-HdrData=&DetData=
    select "t1"."c_work_place" as "c_work_place",
      "t1"."stagename" as "c_name",
      "sum"("t1"."prev_day_time_in_sec") as "prev_day_time_in_sec",
      "sum"("t1"."prev_day_time_item_pick_count") as "prev_day_time_item_pick_count",
      "sum"("t1"."last_week_time_in_sec") as "last_week_time_in_sec",
      "sum"("t1"."last_week_item_pick_count") as "last_week_item_pick_count"
      from(select "tem"."c_work_place",
          "tem"."stagename",
          "sum"("time_in_sec") as "prev_day_time_in_sec",
          "sum"("item_pick_count") as "prev_day_time_item_pick_count",
          0 as "last_week_time_in_sec",
          0 as "last_week_item_pick_count"
          from(select "c_work_place",
              "st_store_stage_grp_mst"."c_name" as "stagename",
              "c_user",
              "sum"("DATEDIFF"("ss","t_action_start_time","t_action_end_time")) as "time_in_sec",
              "isnull"("sum"("n_pick_count"),0) as "item_pick_count",
              "isnull"("sum"("n_bounce_count"),0) as "item_bounce_count"
              from "st_track_tray_time"
                left outer join "st_store_stage_mst" on "st_store_stage_mst"."c_code"
                 = "st_track_tray_time"."c_stage_code"
                left outer join "st_store_stage_grp_mst" on "st_store_stage_grp_mst"."c_code"
                 = "st_store_stage_mst"."c_stage_grp_code"
              where "t_action_end_time" is not null
              and "date"("t_time") = "uf_default_date"()-1
              and "c_work_place" <> 'BARCODE PRINT'
              group by "c_work_place","c_user","st_store_stage_grp_mst"."c_name") as "Tem"
          group by "c_work_place","tem"."stagename" union all
        select "tem"."c_work_place",
          "tem"."stagename",
          0 as "prev_day_time_in_sec",
          0 as "prev_day_time_item_pick_count",
          "sum"("time_in_sec") as "last_week_time_in_sec",
          "sum"("item_pick_count") as "last_week_item_pick_count"
          from(select "c_work_place",
              "st_store_stage_grp_mst"."c_name" as "stagename",
              "c_user",
              "sum"("DATEDIFF"("ss","t_action_start_time","t_action_end_time")) as "time_in_sec",
              "isnull"("sum"("n_pick_count"),0) as "item_pick_count",
              "isnull"("sum"("n_bounce_count"),0) as "item_bounce_count"
              from "st_track_tray_time"
                left outer join "st_store_stage_mst" on "st_store_stage_mst"."c_code" = "st_track_tray_time"."c_stage_code"
                left outer join "st_store_stage_grp_mst" on "st_store_stage_grp_mst"."c_code" = "st_store_stage_mst"."c_stage_grp_code"
              where "t_action_end_time" is not null
              and "date"("t_time") = "uf_default_date"()-7
              and "c_work_place" <> 'BARCODE PRINT'
              group by "c_work_place","c_user","st_store_stage_grp_mst"."c_name") as "Tem"
          group by "tem"."c_work_place","tem"."stagename" union all
        select "tem"."c_work_place",
          "tem"."stagename",
          "sum"("time_in_sec") as "prev_day_time_in_sec",
          "sum"("item_pick_count") as "prev_day_time_item_pick_count",
          0 as "last_week_time_in_sec",
          0 as "last_week_item_pick_count"
          from(select 'Inward as Purchase' as "c_work_place",
              '-' as "stagename",
              "c_user",
              1 as "time_in_sec",
              "count"("pur_mst"."n_srno") as "item_pick_count",
              0 as "item_bounce_count"
              from "pur_mst"
              where "pur_mst"."d_ldate" = "uf_default_date"()-1 and "pur_mst"."c_prefix" = 'K'
              group by "c_work_place","c_user","stagename") as "Tem"
          group by "tem"."c_work_place","tem"."stagename" union all
        select "tem"."c_work_place",
          "tem"."stagename",
          0 as "prev_day_time_in_sec",
          0 as "prev_day_time_item_pick_count",
          "sum"("time_in_sec") as "last_week_time_in_sec",
          "sum"("item_pick_count") as "last_week_item_pick_count"
          from(select 'Inward as Purchase' as "c_work_place",
              '-' as "stagename",
              "c_user",
              1 as "time_in_sec",
              "count"("pur_mst"."n_srno") as "item_pick_count",
              0 as "item_bounce_count"
              from "pur_mst"
              where "pur_mst"."d_ldate" = "uf_default_date"()-7 and "pur_mst"."c_prefix" = 'K'
              group by "c_work_place","c_user","stagename") as "Tem"
          group by "tem"."c_work_place","tem"."stagename" union all
        select "tem"."c_work_place",
          "tem"."stagename",
          "sum"("time_in_sec") as "prev_day_time_in_sec",
          "sum"("item_pick_count") as "prev_day_time_item_pick_count",
          0 as "last_week_time_in_sec",
          0 as "last_week_item_pick_count"
          from(select 'Inward as GRE' as "c_work_place",
              '-' as "stagename",
              "c_user",
              1 as "time_in_sec",
              "count"("goods_rec_det"."c_item_code") as "item_pick_count",
              0 as "item_bounce_count"
              from "goods_rec_det" join "goods_rec_mst" on "goods_rec_mst"."c_br_code" = "goods_rec_det"."c_br_code"
                and "goods_rec_mst"."c_year" = "goods_rec_det"."c_year" and "goods_rec_mst"."c_prefix" = "goods_rec_det"."c_prefix"
                and "goods_rec_mst"."n_srno" = "goods_rec_det"."n_srno"
              where "goods_rec_det"."d_ldate" = "uf_default_date"()-1 and "goods_rec_mst"."c_prefix" = '158'
              group by "c_work_place","c_user","stagename") as "Tem"
          group by "tem"."c_work_place","tem"."stagename" union all
        select "tem"."c_work_place",
          "tem"."stagename",
          0 as "prev_day_time_in_sec",
          0 as "prev_day_time_item_pick_count",
          "sum"("time_in_sec") as "last_week_time_in_sec",
          "sum"("item_pick_count") as "last_week_item_pick_count"
          from(select 'Inward as GRE' as "c_work_place",
              '-' as "stagename",
              "c_user",
              1 as "time_in_sec",
              "count"("goods_rec_det"."c_item_code") as "item_pick_count",
              0 as "item_bounce_count"
              from "goods_rec_det" join "goods_rec_mst" on "goods_rec_mst"."c_br_code" = "goods_rec_det"."c_br_code"
                and "goods_rec_mst"."c_year" = "goods_rec_det"."c_year" and "goods_rec_mst"."c_prefix" = "goods_rec_det"."c_prefix"
                and "goods_rec_mst"."n_srno" = "goods_rec_det"."n_srno"
              where "goods_rec_det"."d_ldate" = "uf_default_date"()-7 and "goods_rec_mst"."c_prefix" = '158'
              group by "c_work_place","c_user","stagename") as "Tem"
          group by "tem"."c_work_place","tem"."stagename") as "t1"
      group by "t1"."c_work_place","t1"."stagename" for xml raw,elements
  when 'Get_timer' then
    --http://172.16.18.38:16503/ws_st_user_performance_dashboard?&gsbr=503&devID=3c824667f4396fc729062016041357979&sKEY=&UserId=MYBOSS&cIndex=Get_timer&GodownCode=-HdrData=&DetData=
    select 5 as "n_timer",
      180 as "n_refresh_time",
      "c_module_name",
      "c_code",
      "c_menu_id"
      from "st_track_module_mst" where "c_code" in( 'M00035','M00036' ) for xml raw,elements
  else
    select 'Invalid Index!!' as "c_message" for xml raw,elements
  end case
end;