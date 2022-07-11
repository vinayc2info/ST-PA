CREATE PROCEDURE "DBA"."usp_st_error_tracking_supervisor_dashboard"( 
  in @gsBr char(6),
  in @devID char(200),
  in @sKey char(20),
  in @UserId char(20),
  in @PhaseCode char(6),
  in @StageCode char(6),
  in @RackGrpCode char(300),
  in @cIndex char(30),
  in @HdrData char(7000),
  in @DetData char(32767),
  in @GodownCode char(6) ) 
result( "is_xml_string" xml ) 
/* 
Author              : Vinay Kumar S 
procedure           : usp_st_error_tracking_supervisor_dashboard
Date                : 26-07-2021 
--------------------------------------------------------------------------------------------------------------------------
Modified By     ModifiedDate                ticketNo    IndexName                Purpose                                 
---------------------------------------------------------------------------------------------------------------------------
Pratheesh       2021-07-29 18:13:36.816                   document_done           completed marked and updated to stock table
Pratheesh       2021-08-21 10:20:00.000                   load_data               n_qty converted into integer for praful
---------------------------------------------------------------------------------------------------------------------------
*/
begin
  declare @DocNo char(25);
  declare @TrayCode char(1000);
  declare @doc_no char(30);
  declare @hdr_data varchar(32767);
  declare @hdr_det varchar(7000);
  declare @enable_log numeric(1);
  declare @n_active integer;
  declare @BrCode char(6);
  declare @t_ltime char(25);
  declare @RackGrpList char(7000);
  declare @rackGrp char(6);
  declare @ColSep char(6);
  declare @RowSep char(6);
  declare @Pos integer;
  declare @ColPos integer;
  declare @RowPos integer;
  declare @ColMaxLen numeric(4);
  declare @RowMaxLen numeric(4);
  // variables
  declare @CurrentTray char(20);
  declare @OrgSeq numeric(6);
  declare @ItemCode char(10);
  declare @BatchNo char(20);
  declare @InOutFlag numeric(6);
  declare @Seq numeric(6);
  declare @Qty numeric(11);
  declare @HoldFlag numeric(1);
  declare @cReason char(10);
  declare @det_tray_code char(20);
  declare @n_error_type numeric(1);
  declare @stage_seq integer;
  declare @Det_seq integer;
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
    set @GodownCode = "http_variable"('GodownCode') --11          
  end if;
  select "c_br_code" into @brcode from "System_Parameter";
  select "c_delim" into @ColSep from "ps_tab_delimiter" where "n_seq" = 0;
  select "c_delim" into @RowSep from "ps_tab_delimiter" where "n_seq" = 1;
  set @t_ltime = "now"();
  set @ColMaxLen = "Length"(@ColSep);
  set @RowMaxLen = "Length"(@RowSep);
  case @cIndex
  when 'load_data' then
    //http://172.16.18.19:21547/ws_st_supervisor_dashboard?&cIndex=load_data&HdrData=&DetData=&godown_item_detail=&RackGrpCode=&StageCode=&GodownCode=&PhaseCode=&sKey=&gsBr=&devID=1234&UserId=
    select "c_doc_no" as "doc_no",
      "n_inout",
      "n_complete",
      "c_item_code",
      "item_mst"."c_name" as "item_name",
      "c_contra_batch" as "c_batch_no",
      convert(integer,"n_qty") as "n_qty",
      "c_tray_code" as "pick_tray_code",
      "c_rack","c_rack_grp_code","c_stage_code",
      "st_err_track_det"."c_godown_code",
      "n_seq","n_org_seq",
      "n_err_type" as "n_err_type",
      if "n_err_type" = 1 then 'Contra Item(New Item)'
      else if "n_err_type" = 2 then 'Contra Item(Same Item Picked)'
        else if "n_err_type" = 3 then 'Breakage'
          else if "n_err_type" = 4 then 'Batch Mismatch'
            else if "n_err_type" = 5 then 'Less Qty Pick'
              else 'Excess Qty Pick'
              endif
            endif
          endif
        endif
      endif as "n_err_type_name",
      "c_contra_item",
      "im"."c_name" as "c_contra_item_name",
      if "n_err_type" not in( 1,4,6 ) then null else "st_err_track_det"."c_batch_no" endif as "c_contra_batch_no",
      if "n_err_type" in( 1,4,6 ) then convert(integer,"n_qty") endif as "n_contra_qty",
      "rm"."c_code" as "c_contra_rack",
      "rgm"."c_code" as "c_contra_rack_grp_code",
      "c_pack_tray_code",
      "t_pick_completed_time",
      "c_reason_code",
      "reason_mst"."c_name" as "reason_name",
      "st_err_track_det"."c_note",
      "c_pick_user",
      "ddds_user_mst"."c_used_by" as "c_chk_user",
      "c_err_mark_user" as "supervisor_name",
      "t_err_time" as "supervisor_start_time"
      from "st_err_track_det"
        join "item_mst" on "st_err_track_det"."c_item_code" = "item_mst"."c_code"
        left outer join "item_mst" as "im" on "im"."c_code" = case when "n_err_type" in( 4,6 ) then "c_item_code" else "st_err_track_det"."c_contra_item" end
        left outer join "rack_mst" as "rm" on "rm"."c_code" = "im"."c_rack_code"
        left outer join "rack_group_mst" as "rgm" on "rgm"."c_code" = "rm"."c_group"
        join "reason_mst" on "st_err_track_det"."c_reason_code" = "reason_mst"."c_code"
        join "ddds_user_mst" on "st_err_track_det"."c_chk_user" = "ddds_user_mst"."c_user_id"
      where "n_complete" = 0 for xml raw,elements
  when 'update_supervisor_username' then
    //http://172.16.18.19:19158/ws_st_supervisor_dashboard?&cIndex=update_supervisor_username&HdrData=000/21/I/2100073001&DetData=&gsBr=000&devID=1234&UserId=sandesh
    while @DetData <> '' loop
      --1 ItemCode
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @InOutFlag = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --1 ItemCode
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @ItemCode = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --2 BatchNo
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @BatchNo = "rTrim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --3 Qty
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @OrgSeq = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --5 tray
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @CurrentTray = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      set @det_tray_code = @CurrentTray;
      --6 rackGrp
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @rackGrp = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen)
    end loop;
    // item_wise 
    //    update "st_err_track_det"
    //      set "c_err_mark_user" = @UserId,"t_err_time" = "now"(),"c_luser" = @UserId,"t_ltime" = "now"()
    //      where "c_doc_no" = @HdrData and "n_inout" = @InOutFlag and "c_item_code" = @ItemCode and "c_batch_no" = @BatchNo
    //      and "n_org_seq" = @OrgSeq and "c_tray_code" = @CurrentTray and "c_rack_grp_code" = @rackGrp;
    // document_wise start operation for single user , changed on 23-03-22 as per manoj
    update "st_err_track_det"
      set "c_err_mark_user" = @UserId,"t_err_time" = "now"(),"c_luser" = @UserId,"t_ltime" = "now"()
      where "c_doc_no" = @HdrData;
    select 1 as "n_status",'Success' as "c_message" for xml raw,elements
  when 'document_done' then
    //http://192.168.1.33:21211/ws_st_error_tracking_supervisor_dashboard?&gsBr=000&devID=1234&sKey=&UserId=pra&PhaseCode=&RackGrpCode=&StageCode&cIndex=document_done&HdrData=000/21/I/2100073006375&DetData=158091^^DOBS2145^^3.000^^1^^10053^^1^^0^^1^^A2^^||158092^^.^^3.000^^1^^10053^^1^^0^^2^^A2^^&GodownCode=
    set @DocNo = @hdrdata;
    set @Det_seq = 0;
    while @DetData <> '' loop
      --1 ItemCode
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @ItemCode = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --2 BatchNo
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @BatchNo = "rTrim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --3 Qty
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @Qty = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --4 HoldFlag
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @HoldFlag = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --5 tray
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @CurrentTray = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      set @det_tray_code = @CurrentTray;
      --6 ERROR TYPE
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @n_error_type = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --7 InOutFlag
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @InOutFlag = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --8 OrgSeq
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @OrgSeq = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --9 rackGrp
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @rackGrp = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      -- Row Seperator--
      select "Locate"(@DetData,@RowSep) into @RowPos;
      set @DetData = "SubString"(@DetData,@RowPos+@RowMaxLen);
      set @Det_seq = @Det_seq+1;
      update "st_err_track_det"
        set "n_complete" = 1,
        "c_luser" = @UserId,
        "t_ltime" = "now"()
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "n_org_seq" = @OrgSeq
        and "c_tray_code" = @CurrentTray
        and "c_rack_grp_code" = @rackGrp;
      if @HoldFlag = 1 and @n_error_type in( 1,2,4,6 ) then
        update "stock" set "n_hold_qty" = "n_hold_qty"-@Qty,"n_store_track_qty" = "n_store_track_qty"-@Qty where "c_item_code" = @ItemCode and "c_batch_no" = @BatchNo
      end if
    end loop;
    select 1 as "n_status",'Success' as "c_message" for xml raw,elements
  end case
end;