CREATE PROCEDURE "DBA"."usp_st_tray_exceptional_dashboard"( 
  in @gsBr char(6),
  in @devID char(200),
  in @sKey char(20),
  in @UserId char(20),
  in @PhaseCode char(6),
  in @StageCode char(6),
  in @RackGrpCode char(6),
  in @cIndex char(30),
  in @HdrData char(7000),
  in @DetData char(7000),
  in @GodownCode char(6) ) 
result( "is_xml_string" xml ) 
begin
  declare @BrCode char(6);
  declare @t_ltime char(25);
  declare @d_ldate char(20);
  declare @nUserValid integer;
  declare @RackGrpList char(7000);
  --common >>
  declare @ColSep char(6);
  declare @RowSep char(6);
  declare @Pos integer;
  declare @ColPos integer;
  declare @RowPos integer;
  declare @ColMaxLen numeric(4);
  declare @RowMaxLen numeric(4);
  --common <<
  --cIndex get_doc_list >>
  declare @tmp char(20);
  declare local temporary table "temp_rack_grp_list"(
    "c_rack_grp_code" char(6) null,) on commit delete rows; --cIndex get_doc_list <<
  --cIndex get_cust_tray_list>>
  declare @RegionCode char(6);
  declare @nStoreIn integer;
  --cIndex get_cust_tray_list<<
  --cIndex set_selected_tray >>
  declare @StageHdr char(7000);
  declare @StageDet char(7000);
  declare @cUser char(20);
  declare @DocNo char(25);
  declare @StartGrp char(6);
  declare @CurrentGrp char(6);
  declare @EndGrp char(6);
  declare @nStatus integer;
  declare @nClosed integer;
  declare @nOut integer;
  declare @TranBrCode char(6);
  declare @TranPrefix char(4);
  declare @TranYear char(2);
  declare @TranSrno numeric(6);
  declare @CurrentTray char(6);
  --declare @RackGrpList char(7000);
  --cIndex set_selected_tray <<
  --cIndex get_batch_list <<
  declare @ItemCode char(6);
  declare @BatchNo char(20);
  --cIndex get_batch_list <<
  --cIndex setCounter >>
  declare @Counter char(100);
  --cIndex setCounter <<
  declare local temporary table "last_rack_grp"(
    "c_stage_code" char(6) null, --get_tray_items>>	
    "c_rack_grp_code" char(6) null,) on commit preserve rows;declare @Tray char(6);
  declare @nPickCount integer;
  declare @nInOutFlag integer;
  declare @nTrayType integer;
  declare @nCarton integer;
  declare local temporary table "temp_item_receipt_entry"(
    "i_br_code" char(6) null,
    "i_year" char(2) null,
    "i_prefix" char(4) null,
    "i_srno" numeric(9) null,
    "i_seq" numeric(4) null,
    "c_tray_code" char(6) null,
    "c_doc_no" char(25) null,
    "c_stage_code" char(6) null,
    "n_item_count" numeric(6) null,
    "n_item_processed_count" numeric(6) null,
    "n_tray_age" numeric(3) null,) on commit preserve rows;
  --get_tray_items<<
  --assign_to_counter>>
  declare "i" bigint;
  declare @nState integer;
  --assign_to_counter<<
  if @devID = '' or @devID is null then
    set @gsBr = "http_variable"('gsBr'); --1
    set @devID = "http_variable"('devID'); --2
    set @sKey = "http_variable"('sKey'); --3
    set @UserId = "http_variable"('UserId'); --4
    set @PhaseCode = "http_variable"('PhaseCode'); --5		
    set @RackGrpCode = "http_variable"('RackGrpCode'); --6	
    set @StageCode = "http_variable"('StageCode'); --7
    set @cIndex = "http_variable"('cIndex'); --8
    set @HdrData = "http_variable"('HdrData'); --9
    set @DetData = "http_variable"('DetData'); --10
    set @GodownCode = "http_variable"('GodownCode'); --11	
    set @nStoreIn = "http_variable"('nStoreIn')
  end if;
  select "c_delim" into @ColSep from "ps_tab_delimiter" where "n_seq" = 0;
  select "c_delim" into @RowSep from "ps_tab_delimiter" where "n_seq" = 1;
  set @ColMaxLen = "Length"(@ColSep);
  set @RowMaxLen = "Length"(@RowSep);
  set @BrCode = "uf_get_br_code"(@gsBr);
  set @t_ltime = "left"("now"(),19);
  set @d_ldate = "uf_default_date"();
  select top 1 "c_user" into @cUser from "logon_det" order by "t_ltime" desc;
  case @cIndex
  when 'get_exceptional_trays' then
    --http://172.16.17.225:21334/ws_st_tray_exceptional_dashboard?cIndex=get_exceptional_trays&HdrData=&DetData=&PhaseCode=&RackGrpCode=&StageCode=&sKey=KEY&devID=devID&UserId=MYBOSS
    select "sman_mst"."c_code" as "sman_code",
      "sman_mst"."c_name" as "sman_name",
      "st_track_tray_move"."c_doc_no",
      "list"("st_track_tray_move"."c_tray_code") as "c_tray_codes",
      if("st_track_tray_move"."n_flag" = 0 and "st_track_tray_move"."n_inout" = 9 and "st_track_tray_move"."c_rack_grp_code" = '-') then
        'PICKING DONE'
      else if("st_track_tray_move"."n_flag" = 7 and "st_track_tray_move"."n_inout" = 9 and "st_track_tray_move"."c_rack_grp_code" = '-') then
          'CONVERSION STARTED'
        endif
      endif as "tray_status",
      if("st_track_tray_move"."n_flag" = 0 and "st_track_tray_move"."n_inout" = 9 and "st_track_tray_move"."c_rack_grp_code" = '-') then
        0
      else if("st_track_tray_move"."n_flag" = 7 and "st_track_tray_move"."n_inout" = 9 and "st_track_tray_move"."c_rack_grp_code" = '-') then
          1
        endif
      endif as "tray_status_flag",
      if "st_err_track_det"."c_doc_no" is not null then 1 else 0 endif as "n_err_mark_flag",
      if("st_track_tray_move"."n_inout" = 9 and "st_track_tray_move"."c_rack_grp_code" = '-') then
        "max"("st_track_tray_move"."t_time")
      endif as "t_time",
      "st_track_tray_move"."c_user" as "user_id",
      if("st_track_tray_move"."n_flag" = 7 and "st_track_tray_move"."n_inout" = 9 and "st_track_tray_move"."c_rack_grp_code" = '-') then
        "ddds_user_mst"."c_used_by"
      endif as "c_check_user",
      (select "count"("tm"."c_tray_code") from "st_track_tray_move" as "tm"
        where "tm"."c_doc_no" = "st_track_tray_move"."c_doc_no"
        and "tm"."n_inout" <> 9) as "cnt"
      from "st_track_tray_move"
        join "st_track_mst" on "st_track_mst"."c_doc_no" = "st_track_tray_move"."c_doc_no"
        left outer join "st_err_track_det" on "st_track_mst"."c_doc_no" = "st_err_track_det"."c_doc_no"
        and "st_track_mst"."n_inout" = "st_err_track_det"."n_inout"
        join "act_mst" on "act_mst"."c_code" = "st_track_mst"."c_cust_code"
        join "sman_mst" on "sman_mst"."c_code" = "act_mst"."c_sman_code"
        join "ddds_user_mst" on "ddds_user_mst"."c_user_id" = "st_track_tray_move"."c_user"
      where "st_track_mst"."n_inout" = 0 and "cnt" = 0
      group by "st_track_tray_move"."c_doc_no","sman_name","sman_mst"."c_code","st_track_tray_move"."n_flag","c_check_user",
      "st_track_tray_move"."n_inout","st_track_tray_move"."c_rack_grp_code","st_err_track_det"."c_doc_no","st_track_tray_move"."c_user"
      having "sum"(if "st_track_tray_move"."n_inout" = 0 then 1 else 0 endif) = 0 union all
    select "sman_mst"."c_code" as "sman_code",
      "sman_mst"."c_name" as "sman_name",
      "carton_mst"."c_doc_no",
      "list"(distinct "carton_mst"."c_tray_code") as "c_tray_codes",
      if(select top 1 "n_seq" from "doc_stage_mst" where "c_code" = any(select "c_stage_code" from "doc_track_move" where "doc_track_move"."n_inv_no" = "carton_mst"."n_srno") order by "n_seq" desc)
       < (select "n_seq" from "doc_stage_mst" where "c_code" = "uf_sys_para_setup"('S00273','-','0',2)) then
        'CONVERSION DONE, STORE-OUT PENDING'
      else
        if(select top 1 "n_seq" from "doc_stage_mst" where "c_code" = any(select "c_stage_code" from "doc_track_move" where "doc_track_move"."n_inv_no" = "carton_mst"."n_srno") order by "n_seq" desc)
         = (select "n_seq" from "doc_stage_mst" where "c_code" = "uf_sys_para_setup"('S00273','-','0',2)) then
          'STORE-OUT DONE, CHECK-OUT PENDING'
        else
          if(select top 1 "n_seq" from "doc_stage_mst" where "c_code" = any(select "c_stage_code" from "doc_track_move" where "doc_track_move"."n_inv_no" = "carton_mst"."n_srno") order by "n_seq" desc)
           = (select "n_seq" from "doc_stage_mst" where "c_code" = "uf_sys_para_setup"('S00272','-','0',2)) then
            'CHECK-OUT DONE'
          endif
        endif
      endif as "tray_status",
      if(select top 1 "n_seq" from "doc_stage_mst" where "c_code" = any(select "c_stage_code" from "doc_track_move" where "doc_track_move"."n_inv_no" = "carton_mst"."n_srno") order by "n_seq" desc)
       < (select "n_seq" from "doc_stage_mst" where "c_code" = "uf_sys_para_setup"('S00273','-','0',2)) then
        2
      else
        if(select top 1 "n_seq" from "doc_stage_mst" where "c_code" = any(select "c_stage_code" from "doc_track_move" where "doc_track_move"."n_inv_no" = "carton_mst"."n_srno") order by "n_seq" desc)
         = (select "n_seq" from "doc_stage_mst" where "c_code" = "uf_sys_para_setup"('S00273','-','0',2)) then
          3
        else
          if(select top 1 "n_seq" from "doc_stage_mst" where "c_code" = any(select "c_stage_code" from "doc_track_move" where "doc_track_move"."n_inv_no" = "carton_mst"."n_srno") order by "n_seq" desc)
           = (select "n_seq" from "doc_stage_mst" where "c_code" = "uf_sys_para_setup"('S00272','-','0',2)) then
            4
          endif
        endif
      endif as "tray_status_flag",
      0 as "n_err_mark_flag",
      if "tray_status_flag" = 2 then
        (select "max"("t_ltime") from "doc_track" where "n_inv_no" = "reverse"("left"("reverse"("carton_mst"."c_doc_no"),"charindex"('/',("reverse"("carton_mst"."c_doc_no")))-1)))
      else
        if "tray_status_flag" = 3 then
          (select "t_ltime" from "doc_track" where "c_stage_code" = "uf_sys_para_setup"('S00273','-','0',2) and "n_inv_no" = "reverse"("left"("reverse"("carton_mst"."c_doc_no"),"charindex"('/',("reverse"("carton_mst"."c_doc_no")))-1)))
        else
          if "tray_status_flag" = 4 then
            (select "t_ltime" from "doc_track" where "c_stage_code" = "uf_sys_para_setup"('S00272','-','0',2) and "n_inv_no" = "reverse"("left"("reverse"("carton_mst"."c_doc_no"),"charindex"('/',("reverse"("carton_mst"."c_doc_no")))-1)))
          endif
        endif
      endif as "t_time",
      if "tray_status_flag" = 2 then
        "carton_mst"."c_user"
      else
        if "tray_status_flag" = 3 then
          (select "c_user" from "doc_track" where "c_stage_code" = "uf_sys_para_setup"('S00273','-','0',2) and "n_inv_no" = "reverse"("left"("reverse"("carton_mst"."c_doc_no"),"charindex"('/',("reverse"("carton_mst"."c_doc_no")))-1)))
        else // check out done is for future development , its commentted due to a blank empty line in tab
          if "tray_status_flag" = 4 then
            (select "c_user" from "doc_track" where "c_stage_code" = "uf_sys_para_setup"('S00272','-','0',2) and "n_inv_no" = "reverse"("left"("reverse"("carton_mst"."c_doc_no"),"charindex"('/',("reverse"("carton_mst"."c_doc_no")))-1)))
          endif
        endif
      endif as "user_id",
      "ddds_user_mst"."c_used_by" as "c_check_user",
      0 as "cnt"
      from "carton_mst"
        join "st_track_mst" on "st_track_mst"."c_doc_no" = "carton_mst"."c_doc_no"
        join "act_mst" on "act_mst"."c_code" = "st_track_mst"."c_cust_code"
        join "sman_mst" on "sman_mst"."c_code" = "act_mst"."c_sman_code"
        join "ddds_user_mst" on "ddds_user_mst"."c_user_id" = "user_id"
      where "st_track_mst"."n_inout" = 0 and "carton_mst"."d_ldate" = "uf_default_date"() and "tray_status_flag" < 4
      group by "carton_mst"."c_doc_no","sman_code","sman_name","carton_mst"."n_srno","carton_mst"."c_user","c_check_user"
      order by "tray_status" asc,"sman_code" asc for xml raw,elements
  end case
end;