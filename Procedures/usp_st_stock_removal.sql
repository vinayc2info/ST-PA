CREATE OR REPLACE PROCEDURE "DBA"."usp_st_stock_removal"( 
  -------------------------------------------------------------------------------------------------------------------------------
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
begin
  /* 
Author          : vinay
Procedure       : usp_st_stock_removal
SERVICE         : ws_st_stock_removal
Date            : 20-10-2016 
Modified By     : Vinay Kumar S
Ldate           : 30-04-2021 19:21
Purpose         : Store Track TRANSACTION to TAB/DESKTOP
Input           : 
IndexDetails: 
Tags            : if <c_message> contains "Error" then force logout (android)
Note            :
Service Call (Format): Just a test
Changes         : 
:
*/
  --common >>
  declare @ignore_urgent_color integer;
  declare @org_qty integer;
  declare @shift_qty integer;
  declare @shift_max_seq integer;
  declare @partial_shift_to_godown integer;
  declare @n_multi_user_flag integer;
  declare @stage_list char(100);
  declare "module_M00100" integer;
  declare @pending_item_cnt integer;
  declare @TrayCode char(1000);
  declare @TrayList char(1000);
  declare @cust_code char(6);
  declare @short_exp_days numeric(3);
  declare @doc_stage_code char(6);
  declare @doc_seq integer;
  declare @doc_sort_outstation integer;
  declare @ExpBatch varchar(5000);
  declare @batchreasoncode char(6);
  declare @selected_batch char(25);
  declare @store_code char(6);
  declare @det_item numeric(8);
  declare @parent_item_seq numeric(11);
  declare @from_ord_inv numeric(8);
  declare @inv_batch char(15);
  declare @tmp_rg char(20);
  declare @d_item_pick_count numeric(8);
  declare @d_item_bounce_count numeric(8);
  declare @det_item_cnt numeric(11);
  declare @det_item_n_f_cnt numeric(11);
  declare @det_item_qty numeric(11);
  declare @det_item_bal_qty numeric(11);
  declare "urgent_flag" numeric(1);
  declare @doc_no char(30);
  declare @itemcount integer;
  declare @log_seq numeric(30);
  declare @d_pend_qty_to_pick_next_rg numeric(11,4);
  declare @hdr_data varchar(32767);
  declare @hdr_det varchar(7000);
  declare @gdn_qty numeric(8);
  declare @bal_qty numeric(8);
  declare @gdn_item_code char(6);
  declare @gdn_batch_no char(15);
  declare @req_quantity numeric(11,3);
  declare @stage_exit numeric(1);
  declare @hold_godown_code char(8);
  declare @hold_stage_code char(6);
  declare @hold_rack_grp_code char(6);
  declare @hold_rack char(8);
  declare @godown_item_detail char(32767);
  declare @non_pick_flag numeric(1);
  declare @enable_log numeric(1);
  declare @tray_in_progress numeric(9);
  declare @n_active integer;
  declare @BrCode char(6);
  declare @t_ltime char(25);
  declare @t_tray_move_time char(25);
  declare @t_pick_time char(25);
  declare @t_preserve_ltime char(25);
  declare @d_ldate char(20);
  declare @nUserValid integer;
  declare @RackGrpList char(7000);
  declare @rackGrp char(6);
  declare @ColSep char(6);
  declare @RowSep char(6);
  declare @Pos integer;
  declare @ColPos integer;
  declare @RowPos integer;
  declare @ColMaxLen numeric(4);
  declare @RowMaxLen numeric(4);
  declare @document_list_cnt numeric(4);
  declare @link_stage integer;
  declare @tray_assignment_active integer;
  declare @min_pos_seq numeric(11);
  declare @fast_tracking_picking_flag numeric(1);
  --common <<
  declare @nSingleUser integer;
  declare @n_tray_movement integer;
  declare @n_tray_assignment integer;
  --cIndex get_rack_group>>
  declare @ValidateRG integer;
  declare @ValidRGUser char(20);
  declare @rgCount integer;
  --cIndex get_rack_group<<
  --cIndex login_status>>
  declare @loginRGCount integer;
  declare @tmRGcount integer;
  declare @stageRGcount integer;
  declare @seltmRGcount integer;
  declare @n_pick_count integer;
  --cIndex login_status<<
  --cIndex get_doc_list >>      
  declare @LoginFlag char(1);
  declare @FirstRackGroup char(6);
  declare @cStageCode char(6);
  declare @TraycStageCode char(6);
  declare @FirstEmpInStage char(10);
  declare @t_s_time time;
  declare @t_e_time time;
  declare @next_rack_user char(10);
  declare @n_eb_flag integer;
  declare @RetString char(10);
  declare @n_allow_split integer;
  declare @stage_seq integer;
  declare @next_stage char(6);
  declare @next_rack_grp char(6);
  declare @preserve_tray_full numeric(1);
  declare @non_pick_tray char(6);
  declare @non_pick_hdr char(2000);
  declare local temporary table "temp_tray_list"(
    "c_tray_code" char(6) null,) on commit preserve rows;
  declare local temporary table "temp_rack_grp_list"(
    "c_rack_grp_code" char(6) null,
    "c_stage_code" char(6) null,
    "n_seq" numeric(11) null,) on commit preserve rows;
  declare @tmp char(20);
  -------Chnaged By Saneesh 
  declare local temporary table "item_split_list"(
    "c_item_code" char(6) null,) on commit delete rows;
  declare local temporary table "tray_list"(
    "c_tray_code" char(6) null,
    "n_first_in_stage" numeric(1) null,
    "c_doc_no" char(25) null,
    "n_inout" numeric(1) null,
    "t_time" "datetime" null,
    "c_message" char(100) null,
    "n_item_count" numeric(6) null,
    "n_max_seq" numeric(11) null,
    "n_confirm" numeric(1) null,
    "n_urgent" numeric(1) null,
    "c_sort" char(10) null,
    "c_user" char(10) null,) on commit delete rows;
  --###
  -------Chnaged By Saneesh                     
  declare local temporary table "doc_list"(
    "c_doc_no" char(25) null,
    "n_first_in_stage" numeric(1) null,
    "c_doc_name" char(25) null,
    "c_tray_code" char(10) null,
    "n_inout" numeric(1) null,
    "c_message" char(100) null,
    "t_time_in" timestamp null,
    "tray_count" numeric(9) null,
    "n_item_count" numeric(9) null,
    "n_items_in_stage" numeric(9) null,
    "c_user" char(20) null,) on commit delete rows;
  -------Chnaged By Saneesh     
  declare local temporary table "document_list"(
    "c_doc_no" char(25) null,
    "n_first_in_stage" numeric(1) null,
    "c_doc_name" char(25) null,
    "c_ref_no" char(25) null,
    "n_inout" numeric(1) null,
    "c_message" char(200) null,
    "t_time_in" timestamp null,
    "tray_count_rg" numeric(9) null,
    "tray_count_stage" numeric(9) null,
    "n_item_count" numeric(9) null,
    "n_items_in_stage" numeric(9) null,
    "n_items_qty_in_stage" numeric(9) null,
    "n_confirm" numeric(9) null,
    "n_urgent" numeric(1) null,
    "c_sort" char(100) null,
    "c_user" char(20) null,
    "d_date" date null,
    "c_godown_code" char(6) null,
    "n_exp_doc" numeric(1) null,
    "t_prev_stage_tray_sort" "datetime" null,
    "n_non_pick_flag_item_count" numeric(5) null,
    "sman_code" char(10) null,
    "sman_name" char(25) null,
    "t_doc_confirm_time" "datetime" null,
    "n_non_pick_item_count" numeric(9) null,
    "c_color" char(11) null,) on commit delete rows;
  declare local temporary table "batch_list"(
    "c_item_code" char(6) null,
    "c_batch_no" char(25) null,
    "n_mrp" numeric(11,3) null,
    "n_sale_rate" numeric(11,3) null,
    "d_exp_dt" date null,
    "n_act_stock_qty" numeric(11,3) null,
    "n_stock_qty" numeric(11,3) null,
    "n_issue_qty" numeric(11,3) null,
    "n_tran_exp_days" numeric(11,3) null,
    "n_godown_qty" numeric(11,3) null,
    "n_billed_batch" numeric null,
    ) on commit delete rows;
  declare @LastRGSeq integer;
  declare @CurrentRGSeq integer;
  declare @PrevRackGrp char(6);
  declare @RestrictFlag integer;
  declare @ValidateDevId char(50);
  declare @isLoggedOut integer;
  declare @LoginStatus char(5000);
  declare @IncompleteTray char(6);
  declare @nNotfoundItemCount integer;
  declare @nQtyMisMatchWOPick integer;
  declare @nQtyMisMatchWPick integer;
  --cIndex get_doc_list <<
  --cIndex set_selected_tray >> 
  declare @HdrData_Set_Selected_Tray char(7000);
  declare @cUser char(20);
  declare @DocNo char(25);
  declare @StartGrp char(6);
  declare @CurrentGrp char(6);
  declare @EndGrp char(6);
  declare @TranBrCode char(6);
  declare @TranPrefix char(4);
  declare @TranYear char(2);
  declare @TranSrno numeric(18);
  declare @CurrentTray char(20);
  declare @NextTray char(20);
  declare @ValidateTray numeric(1);
  declare @TrayExistsInRackGrp integer;
  declare @TrayExistsInTrackMove integer;
  declare @Tray_in_pick_list char(5000);
  declare @DocInTrackMove char(20);
  declare @LoginTime timestamp;
  declare @ActionStart timestamp;
  declare @isSoPo integer;
  declare @OldTray char(6);
  declare @nOldTrayItemCountPick integer;
  declare @nOldTrayItemCountDet integer;
  declare @cDocAlreadyAssignedToUser char(20);
  declare @cTrayAssigned char(6);
  declare @UnprocessedTray char(6);
  declare @UnprocessedDoc char(15);
  declare @UnmovedTray char(6);
  declare @nTrayAssigned integer;
  declare @nVerifyDocUser integer;
  declare @nFilterNoBatchItems integer;
  --cIndex set_selected_tray <<
  --cIndex get_batch_list <<
  declare @ItemCode char(6);
  declare @BatchNo char(20);
  declare @tranExpDays numeric(3);
  --cIndex get_batch_list <<
  --cIndex ItemDone
  declare @ForwardFlag numeric(1);
  declare @PickedQty integer;
  declare @RemainingQty integer;
  declare @ReasonCode char(6);
  --cIndex ItemDone<<
  --cIndex document_done>>
  declare @FirstInStage numeric(1);
  declare @Qty numeric(11);
  declare @Seq numeric(11);
  declare @OrgSeq numeric(11);
  declare @InOutFlag numeric(1);
  declare @HoldFlag numeric(1);
  declare @cReason char(10);
  declare @cNote char(100);
  declare @RackCode char(10);
  declare @DetSuccessFlag integer;
  declare @ItemNotFound integer;
  declare @ItemsInDetail integer;
  declare @nextRackGrp char(6);
  declare @nextRackGrp_New char(6);
  declare @maxSeq integer;
  declare @maxRackGrp char(6);
  declare @nDocItemCount integer;
  declare @nDocItemNotFoundCount integer;
  declare @nTrayFull integer;
  declare @nTrayInCurrRG integer;
  declare @nIter bigint;
  --godown request 
  declare @godownTo char(6);
  declare @godownFrom char(6);
  declare @NewSrno numeric(9);
  declare @nPrefixCount integer;
  --cIndex document_done<<    
  --cIndex change_tray>>
  declare @NewTray char(20);
  declare @AssignedDocNo char(25);
  declare @AssignedStageCode char(6);
  --cIndex change_tray<<
  --<< cIndex get_notif
  declare @storeInNotifNeeded integer;
  declare @storeInCount integer;
  declare @msgCount integer;
  --cIndex get_notif >>
  declare @li_gdn_count numeric(8);
  declare @d_gdn_qty numeric(8);
  declare @n_type integer;
  declare @CustCode char(6);
  declare @d_mark_as_complete_no_item_to_pick_next_rg numeric(1);
  declare @d_auto_complete_tray numeric(1);
  declare @n_chk_id numeric(6);
  declare @c_val char(100);
  --vinay
  declare @hdr_doc_no char(25);
  declare @hdr_tray_code char(20);
  declare @det_tray_code char(20);
  declare @n_pos_seq numeric(11);
  declare @ref_srno numeric(18);declare @ref_doc_no char(25); --vinay added to test on 20-01-2020
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
    set @godown_item_detail = "http_variable"('godown_item_detail');
    set @GodownCode = "http_variable"('GodownCode') --11          
  end if;
  --gargee
  --set @enable_log = 1; //IF 1 its start recording in Log tables -->> st_doc_done_log & st+log_ret
  select "isnull"("n_active",0) into @fast_tracking_picking_flag from "st_track_module_mst" where "c_code" = 'M00058';
  if @fast_tracking_picking_flag is null or @fast_tracking_picking_flag = '' then
    set @fast_tracking_picking_flag = 0
  end if;
  select "n_active" into @enable_log from "st_track_module_mst" where "st_track_module_mst"."c_code" = 'M00039';
  if @enable_log is null then
    set @enable_log = 0
  end if;
  select "c_delim" into @ColSep from "ps_tab_delimiter" where "n_seq" = 0;
  select "c_delim" into @RowSep from "ps_tab_delimiter" where "n_seq" = 1;
  set @ColMaxLen = "Length"(@ColSep);
  set @RowMaxLen = "Length"(@RowSep);
  set @BrCode = "uf_get_br_code"(@gsBr);
  set @t_ltime = "now"();
  set @t_tray_move_time = "now"();
  set @d_mark_as_complete_no_item_to_pick_next_rg = 0;
  set @d_auto_complete_tray = 0;
  set @d_ldate = "uf_default_date"();
  select "n_flag" into @nSingleUser from "st_store_stage_mst" where "c_code" = @StageCode;
  select "n_active"
    into @d_mark_as_complete_no_item_to_pick_next_rg from "st_track_module_mst" where "c_code" = 'M00020';
  set @d_item_pick_count = 0;
  set @d_item_bounce_count = 0;
  case @cIndex
  when 'get_notif' then
    --HdrData: storeInNotifNeeded
    set @storeInNotifNeeded = @HdrData;
    set @storeInCount = 0;
    if @storeInNotifNeeded = 1 then
      set @RackGrpList = @RackGrpCode;
      --load storeInCount here
      while @RackGrpList <> '' loop
        --1 RackGrpList
        select "Locate"(@RackGrpList,@ColSep) into @ColPos;
        set @tmp = "Trim"("Left"(@RackGrpList,@ColPos-1));
        set @RackGrpList = "SubString"(@RackGrpList,@ColPos+@ColMaxLen);
        --message 'RackGrpList '+@tmp type warning to client;                   
        if(select "COUNT"("C_CODE") from "RACK_GROUP_MST" where "n_lock" = 0 and "C_CODE" = @tmp) > 0 then --valid rack group selection                           
          select "n_pos_seq" into @Seq from "st_store_stage_det" where "c_rack_grp_code" = @tmp;
          insert into "temp_rack_grp_list"( "c_rack_grp_code","c_stage_code","n_seq" ) values( @tmp,@StageCode,@Seq ) 
        end if
      end loop;
      select top 1 "c_rack_grp_code"
        into @FirstRackGroup from "st_store_stage_det"
        where "c_stage_code" = @StageCode
        order by "n_pos_seq" asc;
      --if user is FirstInStage then DOC_LIST else TRAY_LIST 
      ----------Chnaged By Saneesh 
      insert into "doc_list"
        select "st_track_det"."c_doc_no" as "c_doc_no",
          1 as "n_first_in_stage",
          "st_track_det"."c_doc_no" as "c_doc_name",
          "st_track_det"."c_tray_code" as "c_tray_code",
          "st_track_det"."n_inout" as "n_inout",
          '' as "c_message",
          "st_track_mst"."t_time_in" as "t_time_in",
          (select "count"("c_doc_no") from "st_track_tray_move" where "c_stage_code" = @StageCode and "c_doc_no" = "st_track_det"."c_doc_no") as "tray_count",
          "sum"(if "isnull"("st_track_det"."c_rack_grp_code",'') <> '' and "st_track_det"."n_complete" = 0 and "temp_rack_grp_list"."c_rack_grp_code" is not null then 1 else 0 endif) as "n_item_count",
          "sum"(if "st_track_det"."n_complete" = 0 then 1 else 0 endif) as "n_items_in_stage",
          (if @nSingleUser = 0 then "st_track_det"."c_user" else '-' endif) as "c_user"
          from "st_track_det"
            join "st_track_mst" on "st_track_det"."c_doc_no" = "st_track_mst"."c_doc_no"
            and "st_track_det"."n_inout" = "st_track_mst"."n_inout"
            left outer join "temp_rack_grp_list" on "st_track_det"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
          where "st_track_det"."c_stage_code" = @StageCode
          and "st_track_det"."c_tray_code" is not null
          and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode
          group by "st_track_det"."c_doc_no","n_first_in_stage","c_doc_name","c_tray_code",
          "st_track_det"."n_inout","c_message","st_track_mst"."t_time_in","c_user"
          order by "st_track_mst"."t_time_in" asc;
      -----------------------------------
      if(select "count"("c_rack_grp_code") from "temp_rack_grp_list" where "c_rack_grp_code" = @FirstRackGroup) > 0 then
        select "count"()
          into @storeInCount
          from(select "c_tray_code",
              "n_first_in_stage",
              "c_doc_no",
              "n_inout",
              "c_message",
              "n_item_count",
              0 as "n_max_seq"
              from "doc_list"
              where(select "count"("sd"."c_doc_no")
                from "st_track_det" as "sd"
                where "sd"."c_doc_no" = "doc_list"."c_doc_no"
                and("sd"."c_rack" is null or "sd"."c_stage_code" is null or "sd"."c_rack_grp_code" is null))
               = 0
              and "isnull"("doc_list"."c_user",'-') = (if @nSingleUser = 0 then(if "doc_list"."c_user" is null then "isnull"("doc_list"."c_user",'-') else @UserId endif) else "isnull"("doc_list"."c_user",'-') endif)
              and "doc_list"."n_inout" = 1
              and("n_item_count" > 0 or(("n_items_in_stage"-"n_item_count") > 0 and "tray_count" = 0))
              and "n_items_in_stage" > 0) as "t1"
      else
        ----------------------
        ---Chnaged By Saneesh 
        insert into "tray_list"
          select distinct "st_track_tray_move"."c_tray_code" as "c_tray_code",
            0 as "n_first_in_stage",
            "st_track_tray_move"."c_doc_no" as "c_doc_no",
            "st_track_tray_move"."n_inout" as "n_inout",
            "st_track_tray_move"."t_time" as "t_time",
            '' as "c_message",
            (select "count"("b"."c_item_code") from "st_track_det" as "b" join "temp_rack_grp_list" on "b"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code" where "b"."c_doc_no" = "st_track_det"."c_doc_no" and "b"."n_complete" = 0) as "n_item_count",
            0 as "n_max_seq",
            "st_track_mst"."n_confirm" as "n_confirm",
            "st_track_mst"."n_urgent" as "n_urgent",
            "st_track_mst"."c_sort" as "c_sort",
            "st_track_det"."c_user" as "c_user"
            from "st_track_tray_move"
              left outer join "st_track_det" on "st_track_tray_move"."c_doc_no" = "st_track_det"."c_doc_no"
              and "st_track_tray_move"."n_inout" = "st_track_det"."n_inout"
              and "st_track_tray_move"."c_tray_code" = "st_track_det"."c_tray_code"
              and "st_track_tray_move"."c_rack_grp_code" = "st_track_det"."c_rack_grp_code"
              join "temp_rack_grp_list" on "st_track_tray_move"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
              join "st_track_mst" on "st_track_mst"."c_doc_no" = "st_track_tray_move"."c_doc_no"
              and "st_track_mst"."n_inout" = "st_track_tray_move"."n_inout"
            where "st_track_tray_move"."n_inout" not in( 9,8,0 ) 
            and "isnull"("st_track_tray_move"."c_godown_code",'-') = @GodownCode;
        ---Chnaged By Saneesh 
        select "count"()
          into @storeInCount
          from(select "c_tray_code" as "c_tray_code",
              "n_first_in_stage",
              "c_doc_no",
              "n_inout",
              "c_message",
              "max"("n_item_count") as "n_item_count",
              "n_max_seq",
              "t_time"
              from "tray_list"
              group by "c_tray_code","n_first_in_stage","c_doc_no","n_inout","c_message","n_max_seq","t_time"
              order by "t_time" asc) as "t2"
      end if end if;
    select "COUNT"("n_srno")
      into @msgCount from "msg_mst"
      where "c_stage_code" = @StageCode
      and "c_from_user" is not null
      and "c_to_user" = @UserId
      and "n_status" = 0;
    select @storeInCount as "n_storein_count",@msgCount as "n_msg_count" for xml raw,elements
  when 'get_store_stage' then -----------------------------------------------------------------------
    if(select "count"("c_code") from "st_store_stage_mst" where "n_cancel_flag" = 0) = 0 then
      select '' as "c_stage_code",
        '' as "c_stage_name",
        0 as "n_single_user",
        'Warning!! : No Stage found or All Stages are Locked' as "c_message" for xml raw,elements
    else
      select distinct "st_store_stage_mst"."c_code" as "c_stage_code",
        "st_store_stage_mst"."c_name" as "c_stage_name",
        "st_store_stage_mst"."n_flag" as "n_single_user",
        "st_store_stage_mst"."n_pick_mode" as "n_pick_mode",
        "isnull"(if "st_associated_stage_mapping"."c_associated_stage_code" = "st_store_stage_mst"."c_code" then 1 else 0 endif,0) as "n_associated_flag",
        '' as "c_message"
        from "st_store_stage_mst"
          left outer join "manual_stock_removal_stage" on "st_store_stage_mst"."c_br_code" = "manual_stock_removal_stage"."c_br_code"
          and "st_store_stage_mst"."c_code" = "manual_stock_removal_stage"."c_stage_code"
          left outer join "st_associated_stage_mapping" on "st_associated_stage_mapping"."c_associated_stage_code" = "st_store_stage_mst"."c_code"
        where "manual_stock_removal_stage"."c_stage_code" is null
        and "st_store_stage_mst"."n_cancel_flag" = 0 and "st_store_stage_mst"."c_godown_code" = @GodownCode --->for godown shift
        order by 1 asc for xml raw,elements
    end if when 'get_rack_group' then
    if(select "count"("c_code") from "st_store_stage_mst" where "c_code" = @StageCode) > 0 then
      if(select "count"("c_code") from "st_store_stage_mst" where "c_code" = @StageCode and "n_cancel_flag" = 1) > 0 then
        select '' as "c_rack_grp_code",
          '' as "c_rack_grp_name",
          'Warning!! : Stage '+"string"("c_name")+'['+"string"("c_code")+'] is locked' as "c_message"
          from "st_store_stage_mst"
          where "c_code" = @StageCode for xml raw,elements;
        return
      end if;
      select "count"("rack_group_mst"."c_code")
        into @rgCount from "rack_group_mst"
          join "st_store_stage_det" on "rack_group_mst"."c_code" = "st_store_stage_det"."c_rack_grp_code"
        --and st_store_stage_det.c_br_code = rack_group_mst.c_br_code
        where "st_store_stage_det"."c_stage_code" = @StageCode
        and "rack_group_mst"."n_lock" = 0;
      if @rgCount = 0 then
        select '' as "c_rack_grp_code",
          '' as "c_rack_grp_name",
          'Warning!! : No Rack Groups Found for Stage : '+"string"(@StageCode) as "c_message" for xml raw,elements;
        return
      end if;
      --STORE STAGE WISE RACK GROUP SELECTION
      select "rack_group_mst"."c_code" as "c_rack_grp_code",
        "rack_group_mst"."c_name" as "c_rack_grp_name",
        '' as "c_message"
        from "rack_group_mst" left outer join "manual_rack_group" on "manual_rack_group"."c_rack_code" = "rack_group_mst"."c_code"
          join "st_store_stage_det" on "rack_group_mst"."c_code" = "st_store_stage_det"."c_rack_grp_code"
        --and st_store_stage_det.c_br_code = rack_group_mst.c_br_code
        where "st_store_stage_det"."c_stage_code" = @StageCode
        and "rack_group_mst"."n_lock" = 0
        and "manual_rack_group"."c_rack_code" is null and "st_store_stage_det"."n_tray_in_exit" in( 0,2 ) 
        order by "st_store_stage_det"."n_pos_seq" asc for xml raw,elements
    else
      select '' as "c_rack_grp_code",
        '' as "c_rack_grp_name",
        'Warning!! : Stage - '+"string"(@StageCode)+' not found' as "c_message" for xml raw,elements
    end if when 'godown_mst' then -----------------------------------------------------------------------
    --http://172.16.18.26:16201/ws_st_stock_removal?&cIndex=godown_mst&GodownCode=&gsbr=000&devID=3c824667f4396fc729062016041357979&sKEY=sKey&UserId=C2
    if(select "count"("c_code") from "godown_mst" where "n_lock" = 0) = 0 then
      select '' as "c_godown_code",
        '' as "c_godown_name",
        'Warning!! : No Godown found or All Godowns are Locked' as "c_message" for xml raw,elements
    else
      select "c_code" as "c_godown_code",
        "c_name" as "c_godown_name",
        '' as "c_message"
        from "godown_mst"
        where "n_lock" = 0
        order by 1 asc for xml raw,elements
    end if when 'login_status' then -----------------------------------------------------------------------
    set @LoginFlag = 1;
    --message @RackGrpCode      type warning to client;
    --to display only items from the given rack groups 
    set @RackGrpList = @RackGrpCode;
    while @RackGrpList <> '' loop
      --1 RackGrpList
      select "Locate"(@RackGrpList,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@RackGrpList,@ColPos-1));
      set @RackGrpList = "SubString"(@RackGrpList,@ColPos+@ColMaxLen);
      --message 'RackGrpList '+@tmp type warning to client;                     
      if(select "COUNT"("C_CODE") from "RACK_GROUP_MST" where "n_lock" = 0 and "C_CODE" = @tmp) > 0 then --valid rack group selection                             
        select "n_pos_seq" into @Seq from "st_store_stage_det" where "c_rack_grp_code" = @tmp;
        insert into "temp_rack_grp_list"( "c_rack_grp_code","c_stage_code","n_seq" ) values( @tmp,@StageCode,@Seq ) 
      end if
    end loop;
    select "count"()
      into @loginRGCount from "temp_rack_grp_list";
    if(select "count"("c_rack_grp_code") from "st_track_tray_move" where "c_stage_code" = @StageCode and "n_inout" = 0) > 0 then
      select top 1 "c_doc_no","c_tray_code","count"("c_rack_grp_code") as "rg_cnt"
        into @DocNo,@CurrentTray,@tmRGcount
        from "st_track_tray_move"
        where "n_inout" = 0
        and "c_stage_code" = @StageCode
        group by "c_doc_no","c_tray_code"
        having "rg_cnt" <> @loginRGCount;
      if @tmRGcount is null and @loginRGCount > 1 then
        select top 1 "count"("tm"."c_rack_grp_code")
          into @seltmRGcount from "st_track_tray_move" as "tm"
            join "temp_rack_grp_list" as "rg" on "tm"."c_rack_grp_code" = "rg"."c_rack_grp_code" and "tm"."c_stage_code" = "rg"."c_stage_code"
          where "tm"."c_stage_code" = @StageCode and "tm"."n_inout" = 0;
        select top 1 "count"("tm"."c_rack_grp_code")
          into @stageRGcount from "st_track_tray_move" as "tm"
          where "tm"."c_stage_code" = @StageCode and "tm"."n_inout" = 0
      end if end if;
    if @seltmRGcount <> @stageRGcount or @tmRGcount is not null then
      select 'Error! : Cannot login to the selected rack groups '+@ColSep+' Please process the pending documents' as "c_message" for xml raw,elements;
      return
    end if;
    while @RackGrpList <> '' loop
      --1 RackGrpList
      select "Locate"(@RackGrpList,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@RackGrpList,@ColPos-1));
      set @RackGrpList = "SubString"(@RackGrpList,@ColPos+@ColMaxLen);
      select "uf_st_login_status"(@BrCode,@tmp,@LoginFlag,@UserId,@devID)
        into @LoginStatus;
      if "length"(@LoginStatus) > 1 then
        select @LoginStatus as "c_message" for xml raw,elements;
        --select 'Error!!: Rack Group : '+@tmp+' already assigned to User : '+@ValidRGUser;
        return
      end if
    end loop;
    select '' as "c_message" for xml raw,elements
  when 'get_doc_list' then -----------------------------------------------------------------------
    select "n_active" into @tray_assignment_active from "st_track_module_mst" where "c_code" = 'M00048';
    select "n_active" into @doc_sort_outstation from "st_track_module_mst" where "c_code" = 'M00082';
    select "n_active" into @ignore_urgent_color from "st_track_module_mst" where "c_code" = 'M00115';
    if @doc_sort_outstation is null then
      set @doc_sort_outstation = 0
    end if;
    if @tray_assignment_active = 0 then
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @LoginFlag = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --get_doc_list log 
      insert into "st_get_doc_list"( "c_hdr","c_rg","n_tray_time","c_user","c_device_id" ) values
        ( @HdrData,@RackGrpCode,@t_ltime,@UserId,@devID ) ;
      --message 'LoginFlag '+@LoginFlag type warning to client;
      if @LoginFlag = '' then
        set @LoginFlag = 0
      end if;
      --message @RackGrpCode    type warning to client;
      set @RackGrpList = @RackGrpCode;
      --print '@RackGrpList'+@RackGrpList;
      while @RackGrpList <> '' loop
        --1 RackGrpList
        select "Locate"(@RackGrpList,@ColSep) into @ColPos;
        set @tmp = "Trim"("Left"(@RackGrpList,@ColPos-1));
        set @RackGrpList = "SubString"(@RackGrpList,@ColPos+@ColMaxLen);
        --message 'RackGrpList '+@tmp type warning to client;
        --to check if force logged out on each get doclist call....
        select "uf_st_login_status"(@BrCode,@tmp,@LoginFlag,@UserId,@devID) into @LoginStatus;
        if "length"(@LoginStatus) > 1 then
          select '' as "c_doc_no",
            '' as "n_first_in_stage",
            '' as "c_doc_name",
            '' as "c_ref_no",
            '' as "n_inout",
            @LoginStatus as "c_message" for xml raw,elements;
          return
        end if;
        if(select "COUNT"("C_CODE") from "RACK_GROUP_MST" where "n_lock" = 0 and "C_CODE" = @tmp) > 0 then --valid rack group selection 
          select "n_pos_seq" into @Seq from "st_store_stage_det" where "c_rack_grp_code" = @tmp;
          insert into "temp_rack_grp_list"( "c_rack_grp_code","c_stage_code","n_seq" ) values( @tmp,@StageCode,@Seq ) ;
          --update st_track_det set c_user = @UserId where c_rack_grp_code = @tmp and c_doc_no = @DocNo;
          commit work
        --Tray Assignmnet is controlled by n_tray_assignment flag 
        end if
      end loop;
      select top 1 "c_rack_grp_code"
        into @FirstRackGroup from "st_store_stage_det"
          left outer join "manual_rack_group"
          on "st_store_stage_det"."c_stage_code" = "manual_rack_group"."c_stage_code"
          and "st_store_stage_det"."c_rack_grp_code" = "manual_rack_group"."c_rack_code"
        where "manual_rack_group"."c_rack_code" is null
        and "st_store_stage_det"."c_stage_code" = @StageCode
        order by "st_store_stage_det"."n_pos_seq" asc;
      ---------------------------------
      if(select "count"("c_rack_grp_code") from "temp_rack_grp_list" where "c_rack_grp_code" = @FirstRackGroup) > 0 then
        insert into "document_list"
          ( "c_doc_no",
          "n_first_in_stage",
          "c_doc_name",
          "c_ref_no",
          "n_inout",
          "c_message",
          "t_time_in",
          "tray_count_rg",
          "tray_count_stage",
          "n_item_count",
          "n_items_in_stage",
          "sman_code",
          "sman_name",
          "n_items_qty_in_stage",
          "n_confirm",
          "n_urgent",
          "c_sort",
          "c_user",
          "d_date",
          "c_godown_code",
          "n_exp_doc","t_doc_confirm_time","n_non_pick_item_count",
          "c_color" ) 
          select "st_track_det"."c_doc_no" as "c_doc_no",
            1 as "n_first_in_stage",
            "st_track_det"."c_doc_no" as "c_doc_name",
            "st_track_det"."c_doc_no" as "c_ref_no",
            "st_track_det"."n_inout" as "n_inout",
            '' as "c_message",
            "st_track_mst"."t_time_in" as "t_time_in",
            (select "count"("c_doc_no") from "st_track_tray_move"
                --(Select 'P12A'  c_rack_grp_code ,'P12'c_stage_code, 1 n_seq  )
                join "temp_rack_grp_list" on "st_track_tray_move"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code" where "st_track_tray_move"."n_inout" = 0 and "st_track_tray_move"."c_stage_code" = @StageCode and "c_doc_no" = "st_track_det"."c_doc_no" and "c_godown_code" = @GodownCode) as "tray_count_rg",
            (select "count"("c_doc_no") from "st_track_tray_move" where "c_stage_code" = @StageCode and "c_doc_no" = "st_track_det"."c_doc_no") as "tray_count_stage",
            "sum"(if "isnull"("st_track_det"."c_rack_grp_code",'') <> '' and "st_track_det"."n_complete" = 0 and "temp_rack_grp_list"."c_rack_grp_code" is not null then 1 else 0 endif) as "n_item_count",
            //            "sum"(if "st_track_det"."n_complete" = 0 and st_track_det.n_non_pick_flag = 0 then 1 else 0 endif) as "n_items_in_stage",
            "sum"(if "st_track_det"."n_complete" = 0 and "n_non_pick_flag" = 0 then 1 else 0 endif) as "n_items_in_stage",
            "sman_mst"."c_code" as "sman_code",
            "sman_mst"."c_name" as "sman_name",
            "sum"(if "st_track_det"."n_complete" = 0 and "n_non_pick_flag" = 0 then "n_qty"+"n_sch_qty" else 0 endif) as "n_items_qty_in_stage",
            "st_track_mst"."n_confirm" as "n_confirm",
            --st_track_mst.n_urgent as n_urgent,
            //            if isnull(st_track_urgent_doc.n_urgent,0) <> 4 then st_track_mst.n_urgent else st_track_urgent_doc.n_urgent endif as n_urgent,
            if "isnull"("st_track_urgent_doc"."n_urgent",0) <> 4 then "st_track_mst"."n_urgent"
            else if(select "n_active" from "st_track_module_mst" where "c_code" = 'M00097') = 1 then 2 else "st_track_urgent_doc"."n_urgent" endif
            endif as "n_urgent", --- "isnull"("st_track_mst"."c_sort",'')as "c_sort",
            if @doc_sort_outstation = 1 then if "isnull"("act_mst"."n_outstation",0) = 1 then 'B' else 'A' endif else "isnull"("st_track_mst"."c_sort",'') endif as "c_sort",
            (if @nSingleUser = 0 then "st_track_det"."c_user" else '-' endif) as "c_user",
            "st_track_mst"."d_date" as "d_date",
            "st_track_det"."c_godown_code",
            0 as "n_exp_doc","st_track_mst"."t_confirm_time",
            "sum"(if "isnull"("st_track_det"."c_rack_grp_code",'') <> '' and "st_track_det"."n_non_pick_flag" = 1 and "st_track_det"."n_complete" = 0 and "temp_rack_grp_list"."c_rack_grp_code" = "st_track_det"."c_rack_grp_code" then 1 else 0 endif) as "n_non_pick_item_count",
            "isnull"(
            if("n_urgent" = 1 and "n_confirm" = 2) and @ignore_urgent_color = 0 then
              "urgent_doc"."c_rgb_colour_code"
            else
              if "act_mst"."n_outstation" = 1 then
                if "act_outstation"."c_rgb_colour_code" is not null then
                  "act_outstation"."c_rgb_colour_code"
                else
                  if "act_color"."c_rgb_colour_code" is not null then
                    "act_color"."c_rgb_colour_code"
                  else
                    "cat_color"."c_rgb_colour_code"
                  endif
                endif
              else
                if "act_color"."c_rgb_colour_code" is not null then
                  "act_color"."c_rgb_colour_code"
                else
                  "cat_color"."c_rgb_colour_code"
                endif
              endif
            endif,'255:255:255') as "d_color"
            from "st_track_det"
              join "st_track_mst" on "st_track_det"."c_doc_no" = "st_track_mst"."c_doc_no"
              and "st_track_det"."n_inout" = "st_track_mst"."n_inout"
              left outer join "invoice_mst"
              on("reverse"("left"("reverse"("st_track_det"."c_doc_no"),"charindex"('/',("reverse"("st_track_det"."c_doc_no")))-1))) = "invoice_mst"."n_srno"
              left outer join "sman_mst" on "c_code" = "invoice_mst"."c_sman_code"
              left outer join "temp_rack_grp_list" on "st_track_det"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
              left outer join "st_track_urgent_doc" on "st_track_urgent_doc"."c_doc_no" = "st_track_det"."c_doc_no"
              and "st_track_urgent_doc"."n_inout" = "st_track_det"."n_inout"
              left outer join "act_mst" on "act_mst"."c_code" = "st_track_mst"."c_cust_code"
              left outer join "st_cust_category_colour_mst" as "act_outstation" on "act_outstation"."c_mst_code" = '-' and "act_outstation"."n_mst_type" = 1
              left outer join "st_cust_category_colour_mst" as "act_color" on "act_color"."c_mst_code" = "st_track_mst"."c_cust_code" and "act_color"."n_mst_type" = 2
              left outer join "st_cust_category_colour_mst" as "cat_color" on "cat_color"."c_mst_code" = "act_mst"."c_cust_category_code" and "cat_color"."n_mst_type" = 3
              left outer join "st_cust_category_colour_mst" as "urgent_doc" on "urgent_doc"."c_mst_code" = '-' and "urgent_doc"."n_mst_type" = 4
            where "st_track_det"."c_stage_code" = @StageCode
            and(("st_track_mst"."n_confirm" = 1) or("st_track_mst"."n_confirm" = 2 and @fast_tracking_picking_flag = 1))
            and "st_track_det"."c_godown_code" = @GodownCode
            group by "st_track_det"."c_doc_no","st_track_det"."c_doc_no","st_track_det"."c_doc_no","st_track_det"."n_inout",
            "st_track_mst"."t_time_in","st_track_mst"."n_confirm","st_track_mst"."n_urgent","st_track_mst"."c_sort",
            "st_track_det"."c_user","st_track_mst"."d_date","st_track_det"."c_godown_code","n_urgent","n_exp_doc",
            "st_track_mst"."t_confirm_time","act_outstation"."c_rgb_colour_code","cat_color"."c_rgb_colour_code","sman_code","sman_name",
            "act_color"."c_rgb_colour_code","act_mst"."n_outstation","urgent_doc"."c_rgb_colour_code";
        select
          "isnull"(
          (select "max"("c_tray_code")
            from "st_track_det"
            where "st_track_det"."c_doc_no" = "document_list"."c_doc_no"
            and "st_track_det"."c_stage_code" = @StageCode
            and "st_track_det"."n_complete" = 0
            and "st_track_det"."c_godown_code" = @GodownCode),
          '') as "c_tray_code",
          "n_first_in_stage",
          "c_doc_no",
          "n_inout",
          "c_message",
          "n_item_count",
          0 as "n_max_seq",
          "t_time_in" as "t_time", --X (not req for import at tab )
          "tray_count_rg","tray_count_stage",
          "n_items_in_stage",
          "sman_code",
          "sman_name",
          "n_items_qty_in_stage",
          0 as "n_exp_doc",
          "n_urgent",
          "n_non_pick_flag_item_count",
          "c_color" as "rgb_color_code"
          from "document_list"
          where(select "count"("sd"."c_doc_no")
            from "st_track_det" as "sd"
            where "sd"."c_doc_no" = "document_list"."c_doc_no"
            and("sd"."c_rack" is null or "sd"."c_stage_code" is null or "sd"."c_rack_grp_code" is null)
            and "sd"."c_godown_code" = @GodownCode)
           = 0
          and "isnull"("document_list"."c_user",'-') = (if @nSingleUser = 0 then(if "document_list"."c_user" is null then "isnull"("document_list"."c_user",'-') else @UserId endif) else "isnull"("document_list"."c_user",'-') endif)
          and "document_list"."n_inout" = 0
          and("tray_count_rg" > 0 or "n_item_count" > 0 or "n_non_pick_item_count" = 1) /* or "tray_count_stage" = 0 */
          and "n_items_in_stage" > 0
          order by(if "c_tray_code" = '' then 'zzzzzz' else "c_tray_code" endif) asc,
          ("left"("substr"("substring"("left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))),"charindex"('/',"left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))))+1),"charindex"('/',"substring"("left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))),"charindex"('/',"left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))))+1))+1),"charindex"('/',"substr"("substring"("left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))),"charindex"('/',"left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))))+1),"charindex"('/',"substring"("left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))),"charindex"('/',"left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))))+1))+1))-1)) desc,
          "document_list"."n_urgent" desc,
          "document_list"."d_date" asc,"c_sort" asc,"document_list"."t_doc_confirm_time" asc,"document_list"."c_doc_no" asc for xml raw,elements
      else
        select "c_tray_code" as "c_tray_code",
          "n_first_in_stage",
          "c_doc_no",
          "n_inout",
          "c_message",
          "max"("n_item_count") as "n_item_count",
          "n_max_seq" as "n_max_seq",
          "t_time",
          "n_exp_doc",
          "n_urgent",
          0 as "c_sort",
          null as "c_user",
          "n_confirm",
          "M00097_active",
          if "n_urgent" <> 0 then
            "d_color"
          else ''
          endif as "rgb_color_code"
          from(select distinct "st_track_tray_move"."c_tray_code" as "c_tray_code",
              0 as "n_first_in_stage",
              "st_track_tray_move"."c_doc_no" as "c_doc_no",
              "st_track_tray_move"."n_inout" as "n_inout",
              "st_track_tray_move"."t_time" as "t_time",
              '' as "c_message",
              (select "count"("b"."c_item_code") from "st_track_det" as "b" join "temp_rack_grp_list" on "b"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code" where "b"."c_doc_no" = "st_track_det"."c_doc_no" and "b"."c_tray_code" = "st_track_det"."c_tray_code" and "b"."n_complete" = 0) as "n_item_count",
              "isnull"(@maxSeq,0) as "n_max_seq",
              "st_track_mst"."n_confirm" as "n_confirm",
              if "isnull"("st_track_urgent_doc"."n_urgent",0) <> 4 then "st_track_mst"."n_urgent"
              else if(select "n_active" from "st_track_module_mst" where "c_code" = 'M00097') = 1 then 2 else "st_track_urgent_doc"."n_urgent" endif
              endif as "n_urgent","st_track_mst"."c_sort" as "c_sort",
              "st_track_det"."c_user" as "c_user",
              0 as "n_exp_doc",
              "urgent_doc"."c_rgb_colour_code" as "d_color",
              "isnull"("module"."n_active",0) as "M00097_active"
              from "st_track_tray_move"
                left outer join "st_track_det" on "st_track_tray_move"."c_doc_no" = "st_track_det"."c_doc_no"
                and "st_track_tray_move"."n_inout" = "st_track_det"."n_inout"
                and "st_track_tray_move"."c_tray_code" = "st_track_det"."c_tray_code"
                and "st_track_tray_move"."c_godown_code" = "st_track_det"."c_godown_code"
                join "temp_rack_grp_list" on "st_track_tray_move"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
                join "st_track_mst" on "st_track_mst"."c_doc_no" = "st_track_tray_move"."c_doc_no"
                and "st_track_mst"."n_inout" = "st_track_tray_move"."n_inout"
                left outer join "st_track_urgent_doc" on "st_track_urgent_doc"."c_doc_no" = "st_track_det"."c_doc_no"
                and "st_track_urgent_doc"."n_inout" = "st_track_det"."n_inout"
                left outer join "act_mst" on "act_mst"."c_code" = "st_track_mst"."c_cust_code"
                left outer join "st_cust_category_colour_mst" as "urgent_doc" on "urgent_doc"."c_mst_code" = '-' and "urgent_doc"."n_mst_type" = 4
                left outer join "st_track_module_mst" as "module" on "module"."c_code" = 'M00097'
              where "st_track_tray_move"."n_inout" not in( 8,9,1 ) 
              and "st_track_tray_move"."c_godown_code" = @GodownCode) as "tray_list"
          group by "c_tray_code","n_first_in_stage","c_doc_no","n_inout","c_message","n_max_seq","t_time","n_exp_doc","n_urgent","n_confirm",
          "d_color","M00097_active"
          //          order by t_time asc,n_urgent desc 
          order by if "M00097_active" = 1 then "n_urgent" else 0 endif desc,"t_time" asc for xml raw,elements
      -- @tray_assignment_active =1 
      end if
    else select "min"("n_pos_seq") into @min_pos_seq from "st_store_stage_det" where "n_tray_in_exit" = 1 and "c_stage_code" = @StageCode;
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @LoginFlag = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --get_doc_list log 
      insert into "st_get_doc_list"( "c_hdr","c_rg","n_tray_time","c_user","c_device_id" ) values
        ( @HdrData,@RackGrpCode,@t_ltime,@UserId,@devID ) ;
      --message 'LoginFlag '+@LoginFlag type warning to client;
      if @LoginFlag = '' then
        set @LoginFlag = 0
      end if;
      --message @RackGrpCode    type warning to client;
      set @RackGrpList = @RackGrpCode;
      --print '@RackGrpList'+@RackGrpList;
      while @RackGrpList <> '' loop
        --1 RackGrpList
        select "Locate"(@RackGrpList,@ColSep) into @ColPos;
        set @tmp = "Trim"("Left"(@RackGrpList,@ColPos-1));
        set @RackGrpList = "SubString"(@RackGrpList,@ColPos+@ColMaxLen);
        --message 'RackGrpList '+@tmp type warning to client;
        --to check if force logged out on each get doclist call....
        select "uf_st_login_status"(@BrCode,@tmp,@LoginFlag,@UserId,@devID) into @LoginStatus;
        if "length"(@LoginStatus) > 1 then
          select '' as "c_doc_no",
            '' as "n_first_in_stage",
            '' as "c_doc_name",
            '' as "c_ref_no",
            '' as "n_inout",
            @LoginStatus as "c_message" for xml raw,elements;
          return
        end if;
        if(select "COUNT"("C_CODE") from "RACK_GROUP_MST" where "n_lock" = 0 and "C_CODE" = @tmp) > 0 then --valid rack group selection 
          select "n_pos_seq" into @Seq from "st_store_stage_det" where "c_rack_grp_code" = @tmp;
          insert into "temp_rack_grp_list"( "c_rack_grp_code","c_stage_code","n_seq" ) values( @tmp,@StageCode,@Seq ) ;
          update "st_track_det" set "c_user" = @UserId where "c_rack_grp_code" = @tmp and "c_doc_no" = @DocNo;
          commit work
        --Tray Assignmnet is controlled by n_tray_assignment flag 
        end if
      end loop;
      select top 1 "c_rack_grp_code"
        into @FirstRackGroup from "st_store_stage_det"
          left outer join "manual_rack_group"
          on "st_store_stage_det"."c_stage_code" = "manual_rack_group"."c_stage_code"
          and "st_store_stage_det"."c_rack_grp_code" = "manual_rack_group"."c_rack_code"
        where "manual_rack_group"."c_rack_code" is null
        and "st_store_stage_det"."c_stage_code" = @StageCode
        order by "st_store_stage_det"."n_pos_seq" asc;
      --@maxSeq - Document wise Rack group wise max SEQUENCE
      select "max"("st_track_pick"."n_seq") as "n_max_seq"
        into @maxSeq from "st_track_pick"
          join "temp_rack_grp_list" on "st_track_pick"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
        where "st_track_pick"."c_doc_no" = @DocNo
        and "st_track_pick"."c_stage_code" = @StageCode
        and "st_track_pick"."c_godown_code" = @GodownCode;
      if(select "count"("c_rack_grp_code") from "temp_rack_grp_list" where "c_rack_grp_code" = @FirstRackGroup) > 0 then
        insert into "document_list"
          ( "c_doc_no",
          "n_first_in_stage",
          "c_doc_name",
          "c_ref_no",
          "n_inout",
          "c_message",
          "t_time_in",
          "tray_count_rg",
          "tray_count_stage",
          "n_item_count",
          "n_items_in_stage",
          "sman_code",
          "sman_name",
          "n_items_qty_in_stage",
          "n_confirm",
          "n_urgent",
          "c_sort",
          "c_user",
          "d_date",
          "c_godown_code",
          "n_exp_doc",
          "t_doc_confirm_time",
          "n_non_pick_item_count",
          "c_color" ) 
          select "st_track_det"."c_doc_no" as "c_doc_no",
            1 as "n_first_in_stage",
            "st_track_det"."c_doc_no" as "c_doc_name",
            "st_track_det"."c_doc_no" as "c_ref_no",
            "st_track_det"."n_inout" as "n_inout",
            '' as "c_message",
            "st_track_mst"."t_time_in" as "t_time_in",
            (select "count"("c_doc_no") from "st_track_tray_move"
                --(Select 'P12A'  c_rack_grp_code ,'P12'c_stage_code, 1 n_seq  )
                join "temp_rack_grp_list" on "st_track_tray_move"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code" where "st_track_tray_move"."n_inout" = 0 and "st_track_tray_move"."c_stage_code" = @StageCode and "c_doc_no" = "st_track_det"."c_doc_no" and "c_godown_code" = @GodownCode) as "tray_count_rg",
            (select "count"("c_doc_no") from "st_track_tray_move" where "c_stage_code" = @StageCode and "c_doc_no" = "st_track_det"."c_doc_no") as "tray_count_stage",
            "sum"(if "isnull"("st_track_det"."c_rack_grp_code",'') <> '' and "st_track_det"."n_complete" = 0 and "temp_rack_grp_list"."c_rack_grp_code" is not null then 1 else 0 endif) as "n_item_count",
            //            "sum"(if "st_track_det"."n_complete" = 0 and st_track_det.n_non_pick_flag = 0 then 1 else 0 endif) as "n_items_in_stage",
            "sum"(if "st_track_det"."n_complete" = 0 and "n_non_pick_flag" = 0 then 1 else 0 endif) as "n_items_in_stage",
            "sman_mst"."c_code" as "sman_code",
            "sman_mst"."c_name" as "sman_name",
            "sum"(if "st_track_det"."n_complete" = 0 and "n_non_pick_flag" = 0 then "n_qty"+"n_sch_qty" else 0 endif) as "n_items_qty_in_stage",
            "st_track_mst"."n_confirm" as "n_confirm",
            --st_track_mst.n_urgent as n_urgent,
            //            if "isnull"("st_track_urgent_doc"."n_urgent",0) <> 4 then "st_track_mst"."n_urgent" else "st_track_urgent_doc"."n_urgent" endif as "n_urgent",
            if "isnull"("st_track_urgent_doc"."n_urgent",0) <> 4 then "st_track_mst"."n_urgent"
            else if(select "n_active" from "st_track_module_mst" where "c_code" = 'M00097') = 1 then 2 else "st_track_urgent_doc"."n_urgent" endif
            endif as "n_urgent","isnull"("st_track_mst"."c_sort",'') as "c_sort",
            (if @nSingleUser = 0 then "st_track_det"."c_user" else '-' endif) as "c_user",
            "st_track_mst"."d_date" as "d_date",
            "st_track_det"."c_godown_code",
            0 as "n_exp_doc","st_track_mst"."t_confirm_time",
            "sum"(if "isnull"("st_track_det"."c_rack_grp_code",'') <> '' and "st_track_det"."n_non_pick_flag" = 1 and "st_track_det"."n_complete" = 0 and "temp_rack_grp_list"."c_rack_grp_code" = "st_track_det"."c_rack_grp_code" then 1 else 0 endif) as "n_non_pick_item_count",
            "isnull"(if("n_urgent" = 1 and "n_confirm" = 2) and @ignore_urgent_color = 0 then
              "urgent_doc"."c_rgb_colour_code"
            else
              if "act_mst"."n_outstation" = 1 then
                if "act_outstation"."c_rgb_colour_code" is not null then
                  "act_outstation"."c_rgb_colour_code"
                else
                  if "act_color"."c_rgb_colour_code" is not null then
                    "act_color"."c_rgb_colour_code"
                  else
                    "cat_color"."c_rgb_colour_code"
                  endif
                endif
              else
                if "act_color"."c_rgb_colour_code" is not null then
                  "act_color"."c_rgb_colour_code"
                else
                  "cat_color"."c_rgb_colour_code"
                endif
              endif
            endif,'255:255:255') as "d_color"
            from "st_track_det"
              join "st_track_mst" on "st_track_det"."c_doc_no" = "st_track_mst"."c_doc_no"
              and "st_track_det"."n_inout" = "st_track_mst"."n_inout"
              left outer join "invoice_mst"
              on("reverse"("left"("reverse"("st_track_det"."c_doc_no"),"charindex"('/',("reverse"("st_track_det"."c_doc_no")))-1))) = "invoice_mst"."n_srno"
              left outer join "sman_mst" on "c_code" = "invoice_mst"."c_sman_code"
              --(Select 'P12A'    c_rack_grp_code ,'P12'c_stage_code, 1 n_seq  )
              left outer join "temp_rack_grp_list" on "st_track_det"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
              left outer join "st_track_urgent_doc" on "st_track_urgent_doc"."c_doc_no" = "st_track_det"."c_doc_no"
              and "st_track_urgent_doc"."n_inout" = "st_track_det"."n_inout"
              left outer join "act_mst" on "act_mst"."c_code" = "st_track_mst"."c_cust_code"
              left outer join "st_cust_category_colour_mst" as "act_outstation" on "act_outstation"."c_mst_code" = '-' and "act_outstation"."n_mst_type" = 1
              left outer join "st_cust_category_colour_mst" as "act_color" on "act_color"."c_mst_code" = "st_track_mst"."c_cust_code" and "act_color"."n_mst_type" = 2
              left outer join "st_cust_category_colour_mst" as "cat_color" on "cat_color"."c_mst_code" = "act_mst"."c_cust_category_code" and "cat_color"."n_mst_type" = 3
              left outer join "st_cust_category_colour_mst" as "urgent_doc" on "urgent_doc"."c_mst_code" = '-' and "urgent_doc"."n_mst_type" = 4
            where "st_track_det"."c_stage_code" = @StageCode
            and(("st_track_mst"."n_confirm" = 1) or("st_track_mst"."n_confirm" = 2 and @fast_tracking_picking_flag = 1))
            and "st_track_det"."c_godown_code" = @GodownCode
            and(("st_track_det"."c_rack_grp_code" = any(select "c_rack_grp_code" from "st_store_stage_det" where "n_pos_seq" < @min_pos_seq)) or @nSingleUser = 0)
            group by "st_track_det"."c_doc_no","st_track_det"."c_doc_no","st_track_det"."c_doc_no","st_track_det"."n_inout",
            "st_track_mst"."t_time_in","st_track_mst"."n_confirm","st_track_mst"."n_urgent","st_track_mst"."c_sort",
            "st_track_det"."c_user","st_track_mst"."d_date","st_track_det"."c_godown_code","n_urgent","n_exp_doc","st_track_mst"."t_confirm_time","sman_code","sman_name",
            "act_outstation"."c_rgb_colour_code","cat_color"."c_rgb_colour_code","act_color"."c_rgb_colour_code","act_mst"."n_outstation",
            "urgent_doc"."c_rgb_colour_code";
        --print 'stage2 inv';
        select
          "isnull"(
          (select "max"("c_tray_code")
            from "st_track_det"
            where "st_track_det"."c_doc_no" = "document_list"."c_doc_no"
            and "st_track_det"."c_stage_code" = @StageCode
            and "st_track_det"."n_complete" = 0
            and "st_track_det"."c_godown_code" = @GodownCode),
          '') as "c_tray_code",
          "n_first_in_stage",
          "c_doc_no",
          "n_inout",
          "c_message",
          "n_item_count",
          0 as "n_max_seq",
          "t_time_in" as "t_time", --X (not req for import at tab )
          "tray_count_rg","tray_count_stage",
          "n_items_in_stage",
          "sman_code",
          "sman_name",
          "n_items_qty_in_stage",
          0 as "n_exp_doc",
          "n_non_pick_flag_item_count","n_urgent",
          "c_color" as "rgb_color_code"
          from "document_list"
          where(select "count"("sd"."c_doc_no")
            from "st_track_det" as "sd"
            where "sd"."c_doc_no" = "document_list"."c_doc_no"
            and("sd"."c_rack" is null or "sd"."c_stage_code" is null or "sd"."c_rack_grp_code" is null)
            and "sd"."c_godown_code" = @GodownCode)
           = 0
          and "isnull"("document_list"."c_user",'-') = (if @nSingleUser = 0 then(if "document_list"."c_user" is null then "isnull"("document_list"."c_user",'-') else @UserId endif) else "isnull"("document_list"."c_user",'-') endif)
          and "document_list"."n_inout" = 0
          and("tray_count_rg" > 0 or "n_item_count" > 0 or "n_non_pick_item_count" = 1) /* or "tray_count_stage" = 0 */
          and "n_items_in_stage" > 0
          --order by(if c_tray_code = '' then 'zzzzzz' else c_tray_code endif) asc,document_list.n_urgent desc,document_list.d_date asc,c_sort asc,document_list.t_time_in asc,document_list.c_doc_no asc for xml raw,elements
          order by(if "c_tray_code" = '' then 'zzzzzz' else "c_tray_code" endif) asc,
          ("left"("substr"("substring"("left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))),"charindex"('/',"left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))))+1),"charindex"('/',"substring"("left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))),"charindex"('/',"left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))))+1))+1),"charindex"('/',"substr"("substring"("left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))),"charindex"('/',"left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))))+1),"charindex"('/',"substring"("left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))),"charindex"('/',"left"("document_list"."c_doc_no",("length"("document_list"."c_doc_no")-("charindex"('/',"reverse"("document_list"."c_doc_no"))-1))))+1))+1))-1)) desc,
          "document_list"."n_urgent" desc,"document_list"."d_date" asc,"c_sort" asc,"document_list"."t_doc_confirm_time" asc,"document_list"."c_doc_no" asc for xml raw,elements
      else
        --print 'stg3';
        select "c_tray_code" as "c_tray_code",
          "n_first_in_stage",
          "c_doc_no",
          "n_inout",
          "c_message",
          "max"("n_item_count") as "n_item_count",
          "n_max_seq" as "n_max_seq",
          "t_time",
          "n_exp_doc",
          "n_urgent",
          0 as "c_sort",
          null as "c_user",
          "n_confirm",
          //          "d_color" as "rgb_color_code"
          if "n_urgent" <> 0 then
            "d_color"
          else ''
          endif as "rgb_color_code"
          --  and st_track_det.c_rack_grp_code = any(select c_rack_grp_code from st_store_stage_det where n_pos_seq > @min_pos_seq)
          //              "isnull"(if("n_urgent" = 1 or "n_confirm" = 2) then
          //                "urgent_doc"."c_rgb_colour_code"
          //              else
          //                if "act_mst"."n_outstation" = 1 then
          //                  if "act_outstation"."c_rgb_colour_code" is not null then
          //                    "act_outstation"."c_rgb_colour_code"
          //                  else
          //                    if "act_color"."c_rgb_colour_code" is not null then
          //                      "act_color"."c_rgb_colour_code"
          //                    else
          //                      "cat_color"."c_rgb_colour_code"
          //                    endif
          //                  endif
          //                else
          //                  if "act_color"."c_rgb_colour_code" is not null then
          //                    "act_color"."c_rgb_colour_code"
          //                  else
          //                    "cat_color"."c_rgb_colour_code"
          //                  endif
          //                endif
          //              endif,'255:255:255') as "d_color",
          //                left outer join "st_cust_category_colour_mst" as "act_outstation" on "act_outstation"."c_mst_code" = '-' and "act_outstation"."n_mst_type" = 1
          //                left outer join "st_cust_category_colour_mst" as "act_color" on "act_color"."c_mst_code" = "st_track_mst"."c_cust_code" and "act_color"."n_mst_type" = 2
          //                left outer join "st_cust_category_colour_mst" as "cat_color" on "cat_color"."c_mst_code" = "act_mst"."c_cust_category_code" and "cat_color"."n_mst_type" = 3
          from(select distinct "st_track_tray_move"."c_tray_code" as "c_tray_code",
              0 as "n_first_in_stage",
              "st_track_tray_move"."c_doc_no" as "c_doc_no",
              "st_track_tray_move"."n_inout" as "n_inout",
              "st_track_tray_move"."t_time" as "t_time",
              '' as "c_message",
              (select "count"("b"."c_item_code") from "st_track_det" as "b" join "temp_rack_grp_list" on "b"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code" where "b"."c_doc_no" = "st_track_det"."c_doc_no" and "b"."c_tray_code" = "st_track_det"."c_tray_code" and "b"."n_complete" = 0) as "n_item_count",
              "isnull"(@maxSeq,0) as "n_max_seq",
              "st_track_mst"."n_confirm" as "n_confirm",
              if "isnull"("st_track_urgent_doc"."n_urgent",0) <> 4 then "st_track_mst"."n_urgent"
              else if(select "n_active" from "st_track_module_mst" where "c_code" = 'M00097') = 1 then 2 else "st_track_urgent_doc"."n_urgent" endif
              endif as "n_urgent","st_track_mst"."c_sort" as "c_sort",
              "st_track_det"."c_user" as "c_user",
              0 as "n_exp_doc",
              "urgent_doc"."c_rgb_colour_code" as "d_color",
              "isnull"("module"."n_active",0) as "M00097_active"
              from "st_track_tray_move"
                left outer join "st_track_det" on "st_track_tray_move"."c_doc_no" = "st_track_det"."c_doc_no"
                and "st_track_tray_move"."n_inout" = "st_track_det"."n_inout"
                and "st_track_tray_move"."c_tray_code" = "st_track_det"."c_tray_code"
                and "st_track_tray_move"."c_godown_code" = "st_track_det"."c_godown_code"
                join "temp_rack_grp_list" on "st_track_tray_move"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code" and "st_track_tray_move"."c_stage_code" = "temp_rack_grp_list"."c_stage_code"
                join "st_track_mst" on "st_track_mst"."c_doc_no" = "st_track_tray_move"."c_doc_no"
                and "st_track_mst"."n_inout" = "st_track_tray_move"."n_inout"
                left outer join "st_track_urgent_doc" on "st_track_urgent_doc"."c_doc_no" = "st_track_det"."c_doc_no"
                and "st_track_urgent_doc"."n_inout" = "st_track_det"."n_inout"
                left outer join "act_mst" on "act_mst"."c_code" = "st_track_mst"."c_cust_code"
                left outer join "st_cust_category_colour_mst" as "urgent_doc" on "urgent_doc"."c_mst_code" = '-' and "urgent_doc"."n_mst_type" = 4
                left outer join "st_track_module_mst" as "module" on "module"."c_code" = 'M00097'
              where "st_track_tray_move"."n_inout" not in( 8,9,1 ) 
              and "st_track_tray_move"."c_godown_code" = @GodownCode) as "tray_list"
          group by "c_tray_code","n_first_in_stage","c_doc_no","n_inout","c_message","n_max_seq","t_time","n_exp_doc","n_urgent","n_confirm",
          "d_color","M00097_active"
          order by if "M00097_active" = 1 then "n_urgent" else 0 endif desc,"t_time" asc for xml raw,elements
      //"n_urgent" desc , "t_time" asc  for xml raw,elements
      end if end if when 'set_selected_tray' then -----------------------------------------------------------------------
    --@HdrData  : 1 Tranbrcode~2 TranYear~3 TranPrefix~4 TranSrno~5 CurrentTray~6 FirstInStage~7 OldTray~8 nVerifyDocUser~9 nFilterNoBatchItems
    --@DetData : ValidateTray**__
    --(validateTray : 1 - new tray assigned ,
    --  - to retrieve the items in the existing tray)
    call "usp_set_selected_tray"(@UserId,@HdrData,@DetData,@RackGrpCode,@StageCode,@GodownCode,@gsBr,@t_preserve_ltime);
    return
  when 'get_batch_list' then -----------------------------------------------------------------------
    --DetData = @ItemCode**@BatchNo**__
    --HdrData
    --1 Tranbrcode~2 TranYear~3 TranPrefix~4 TranSrno
    --1 Tranbrcode
    (select "isnull"("n_active",0) into "module_M00100" from "st_track_module_mst" where "c_code" = 'M00100');
    if "module_M00100" is null then
      set "module_M00100" = 0
    end if;
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @Tranbrcode = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --2 TranYear
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @TranYear = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --3 TranPrefix
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @TranPrefix = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --4 TranSrno
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @TranSrno = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --DetData = @ItemCode**@BatchNo**__
    --1 ItemCode
    select "Locate"(@DetData,@ColSep) into @ColPos;
    set @ItemCode = "Trim"("Left"(@DetData,@ColPos-1));
    set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
    --2 BatchNo
    select "Locate"(@DetData,@ColSep) into @ColPos;
    set @BatchNo = "Trim"("Left"(@DetData,@ColPos-1));
    set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
    set @DocNo = @Tranbrcode+'/'+@TranYear+'/'+@TranPrefix+'/'+"string"(@TranSrno);
    set @tranExpDays = 0;
    select "c_cust_code" into @cust_code from "st_track_mst" where "c_doc_no" = @docNo;
    select "n_sale_day_before_expiry" into @short_exp_days from "act_mst" where "c_code" = @cust_code;
    insert into "batch_list"
      select "stock"."c_item_code" as "c_item_code",
        "stock"."c_batch_no" as "c_batch_no",
        "stock"."n_mrp" as "n_mrp",
        "stock"."n_sale_rate" as "n_sale_rate",
        "stock"."d_expiry_date" as "d_exp_dt",
        "isnull"("stock"."n_balance_qty",0)-"isnull"("stock"."n_dc_qty",0)-"isnull"("stock"."n_hold_qty",0)
        -if "module_M00100" = 1 then 0 else "isnull"("n_godown_qty",0) endif as "n_act_stock_qty",
        (if @GodownCode = '-' then
          ("stock"."n_balance_qty"-"stock"."n_hold_qty"-"Isnull"("stock"."n_dc_qty",0)-if "module_M00100" = 1 then 0 else(if "n_godown_qty" < 0 then 0 else "n_godown_qty" endif) endif)
        else
          if "n_act_stock_qty" < 0 then "n_godown_qty"-"abs"("n_act_stock_qty") else "n_godown_qty" endif
        endif) as "n_stock_qty",
        0 as "n_issue_qty",
        @tranExpDays as "n_tran_exp_days",
        "n_godown_qty" as "n_godown_qty",
        0 as "n_billed_batch"
        from "stock"
        where "stock"."c_item_code" = @ItemCode
        and "stock"."n_balance_qty" > 0
        and "dateadd"("day",(-1)*"n_tran_exp_days","stock"."d_expiry_date") >= "uf_default_date"() union all
      select "st_track_det"."c_item_code" as "c_item_code",
        "st_track_det"."c_batch_no" as "c_batch_no",
        "stock"."n_mrp" as "n_mrp",
        "stock"."n_sale_rate" as "n_sale_rate",
        "stock"."d_expiry_date" as "d_exp_dt",
        0 as "n_act_stock_qty",
        0 as "n_stock_qty",
        (if "st_track_det"."n_complete" = 2 and "st_track_det"."n_bal_qty" < "st_track_det"."n_qty" then
          "st_track_det"."n_bal_qty"
        else
          if @DocNo = "st_track_det"."c_doc_no" then
            "st_track_det"."n_qty"
          else
            0
          endif
        endif) as "n_issue_qty",
        0 as "n_tran_exp_days",
        0 as "n_godown_qty",
        1 as "n_billed_batch"
        from "st_track_det"
          left outer join "stock" on "stock"."c_item_code" = "st_track_det"."c_item_code"
          and "stock"."c_batch_no" = "st_track_det"."c_batch_no"
        where "st_track_det"."c_item_code" = @ItemCode
        and "st_track_det"."c_batch_no" is not null
        and "st_track_det"."n_hold_flag" = 0
        and "n_issue_qty" > 0
        and "st_track_det"."n_inout" = 0
        and "st_track_det"."n_complete" not in( 1,9,2 ) 
        and "st_track_det"."c_godown_code" = @GodownCode;
    select "batch_list"."c_batch_no",
      "max"("batch_list"."n_mrp") as "n_mrp",
      "max"("batch_list"."n_sale_rate") as "n_sale_rate",
      "date"("max"("batch_list"."d_exp_dt")) as "d_exp_dt",
      if("d_exp_dt" <= ("uf_default_date"()+@short_exp_days)) then 1 else 0 endif as "n_batch_block_flag",
      "TRIM"("STR"("TRUNCNUM"("sum"("batch_list"."n_stock_qty")+"sum"("batch_list"."n_issue_qty"),3),10,0)) as "n_bal_qty",
      1 as "n_qty_per_box",
      if "item_mst"."c_rack_slot" is null or "item_mst"."c_rack_slot" = '' then
        'NA'
      else
        "item_mst"."c_rack_slot"
      endif as "rack_slot",
      "TRIM"("STR"("TRUNCNUM"("sum"("batch_list"."n_stock_qty"),3),10,0)) as "n_eg_stock",
      "TRIM"("STR"("TRUNCNUM"("sum"("batch_list"."n_godown_qty"),3),10,0)) as "n_gdn_qty",
      "sum"("n_billed_batch") as "n_billed_flag"
      from "batch_list"
        join "item_mst" on "item_mst"."c_code" = "batch_list"."c_item_code"
      where "item_mst"."c_code" = @ItemCode
      group by "batch_list"."c_batch_no","n_qty_per_box","c_rack_slot"
      having "n_bal_qty" > 0
      order by "n_billed_flag" desc,4 asc for xml raw,elements
  when 'document_done' then -----------------------------------------------------------------------
    /*  set @hold_godown_code = 'GDN';
set @hold_stage_code = 'Z';
set @hold_rack_grp_code = 'Z1';
set @hold_rack = 'ZA01';*/
    --print 'Start @DetData';
    -- print @DetData;
    --  print 'Start @Hdr';
    --  print @HdrData;
    select "N_ACTIVE" into @partial_shift_to_godown from "st_track_module_mst" where "c_code" = 'M00107';
    select "c_menu_id" into @hold_godown_code from "st_track_module_mst" where "c_code" = 'M00045';
    select "c_menu_id" into @hold_stage_code from "st_track_module_mst" where "c_code" = 'M00045';
    select "c_menu_id" into @hold_rack_grp_code from "st_track_module_mst" where "c_code" = 'M00045';
    select "c_menu_id" into @hold_rack from "st_track_module_mst" where "c_code" = 'M00045';
    select "n_active" into @link_stage from "st_track_module_mst" where "c_code" = 'M00046';
    set @TrayList = @TrayCode;
    while @TrayList <> '' loop
      select "Locate"(@TrayList,@ColSep) into @ColPos;
      set @associate_tray_code = "Trim"("Left"(@TrayList,@ColPos-1));
      set @RackGrpList = "SubString"(@TrayList,@ColPos+@ColMaxLen);
      insert into "temp_tray_list"( "c_rack_grp_code" ) values( @associate_tray_code ) 
    end loop;
    //print '1';
    /*
@HdrData :  1 ItemsInDetail~2 Tranbrcode~3 TranYear~4 TranPrefix~5 TranSrno
~6 @CurrentTray~7 InOutFlag 8 ~nTrayFull 
If @HdrData Contains the @HdrData arg  vals of Set_selected_Tray Index  ,@NextTray  = 1 ,else NextTray =0 
select n_active  from st_track_module_mst where c_code = 'M00046';
*/
    set @hdr_data = @HdrData;
    set @hdr_det = @DetData;
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @ItemsInDetail = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --2 Tranbrcode
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @Tranbrcode = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --3 TranYear
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @TranYear = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --4 TranPrefix
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @TranPrefix = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --5 TranSrno
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @TranSrno = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --6 CurrentTray(= -nulltray- if FirstInStage = 1 )
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @CurrentTray = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --7 InOutFlag
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @InOutFlag = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --8 nTrayFull
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @nTrayFull = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --9 @HdrData_Set_Selected_Tray 
    select "Locate"(@HdrData,'~') into @ColPos;
    set @HdrData = "SubString"(@HdrData,@ColPos+1);
    select "Locate"(@HdrData,'~') into @ColPos;
    set @HdrData_Set_Selected_Tray = "Trim"("Left"(@HdrData,@ColPos-1));
    set @non_pick_hdr = @HdrData_Set_Selected_Tray;
    //1
    select "Locate"(@non_pick_hdr,@ColSep) into @ColPos;
    //set @TranSrno = Trim("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@non_pick_hdr,@ColPos+@ColMaxLen);
    //2
    select "Locate"(@non_pick_hdr,@ColSep) into @ColPos;
    //set @TranSrno = Trim("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@non_pick_hdr,@ColPos+@ColMaxLen);
    //3 
    select "Locate"(@non_pick_hdr,@ColSep) into @ColPos;
    //set @TranSrno = Trim("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@non_pick_hdr,@ColPos+@ColMaxLen);
    //4
    select "Locate"(@non_pick_hdr,@ColSep) into @ColPos;
    //set @TranSrno = Trim("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@non_pick_hdr,@ColPos+@ColMaxLen);
    //5
    select "Locate"(@non_pick_hdr,@ColSep) into @ColPos;
    -- set @non_pick_hdr = Trim("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@non_pick_hdr,@ColPos+@ColMaxLen);
    //6
    select "Locate"(@non_pick_hdr,@ColSep) into @ColPos;
    set @non_pick_tray = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@non_pick_hdr,@ColPos+@ColMaxLen);
    --print 'HdrData_Set_Selected_Tray';
    --print @HdrData_Set_Selected_Tray;
    --print('@HdrData_Set_Selected_Tray' + @HdrData_Set_Selected_Tray);
    select "Locate"(@HdrData,'~') into @ColPos;
    if @HdrData_Set_Selected_Tray is null or "trim"(@HdrData_Set_Selected_Tray) = '' then
      set @NextTray = ''
    else
      set @NextTray = '1'
    end if;
    --print '@NextTray';
    --print @NextTray;
    --print '@CurrentTray';
    --print @CurrentTray;
    --print +'njan'+@DetData;
    --#####  vinay  #####
    set @hdr_doc_no = @TranSrno;
    set @hdr_tray_code = @CurrentTray;
    --#####  vinay  #####
    set @DocNo = @Tranbrcode+'/'+@TranYear+'/'+@TranPrefix+'/'+"string"(@TranSrno);
    //print '2';
    if @DetData = '' and @nTrayFull = 1 and @CurrentTray <> '-nulltray-' then
      --second RACK GRP USER in the sequence if clicks on tray full validate if no items in tray 
      --if item_count in tray = 0 then error 
      select "count"("c_tray_code")
        into @nOldTrayItemCountPick from "DBA"."st_track_pick"
        where "c_tray_code" = @CurrentTray
        and "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
    end if;
    //print '3';
    if @enable_log = 1 then
      //print '4';
      insert into "st_doc_tray_status"
        ( "c_index","c_rg","c_doc_no","c_tray_code","c_stage_code","n_item_det_flag","c_hdr","c_det","t_time" ) values
        ( @cIndex,@RackGrpCode,@DocNo,"LEFT"(@CurrentTray,6),@StageCode,@ItemsInDetail,@hdr_data,@hdr_det,"now"() ) ;
      insert into "st_doc_done_log"
        ( "c_doc","c_tray","c_stage","c_hdr","c_det","c_rg","n_item_det_flag","n_item_count","n_bounce_cnt","n_tray_full","t_s_time" ) values
        ( @DocNo,"LEFT"(@CurrentTray,6),'',@hdr_data,@hdr_det,@RackGrpCode,@ItemsInDetail,null,null,if @NextTray = '1' then 1 else 0 endif,"getdate"() ) ;
      set @log_seq = @@identity
    end if;
    //print '5';
    if @CurrentTray = '-nulltray-' then
      //print '6';
      if @ItemsInDetail = 1 then
        select top 1 "det"."c_tray_code"
          into @CurrentTray from "st_track_det" as "det" left outer join "manual_rack_group" on "manual_rack_group"."c_stage_code" = "det"."c_stage_code"
            and "manual_rack_group"."c_rack_code" = "det"."c_rack_grp_code"
          where "det"."c_doc_no" = @DocNo
          and "det"."c_stage_code" = @StageCode
          and "det"."c_godown_code" = @GodownCode
          and "manual_rack_group"."c_rack_code" is null
          and "det"."n_inout" = @InOutFlag;
        insert into "st_doc_done_log"
          ( "c_doc","c_tray","c_stage","c_hdr","c_det","c_rg","n_item_det_flag","n_item_count","n_bounce_cnt","n_tray_full","t_s_time" ) values
          ( @DocNo,"LEFT"(@CurrentTray,6),'',@hdr_data,'null tray check and item_det check||Tray= '+"isnull"(@CurrentTray,'###'),@RackGrpCode,@ItemsInDetail,null,null,if @NextTray = '1' then 1 else 0 endif,"getdate"() ) 
      else
        //print '7';
        insert into "st_doc_tray_status"
          ( "c_index","c_rg","c_doc_no","c_tray_code","c_stage_code","n_item_det_flag","c_hdr","c_det","t_time" ) values
          ( @cIndex,@RackGrpCode,@DocNo,"LEFT"(@CurrentTray,6),@StageCode,@ItemsInDetail,@hdr_data,'@non_pick_tray==> '+"isnull"(@non_pick_tray,'####'),"now"() ) ;
        insert into "st_doc_done_log"
          ( "c_doc","c_tray","c_stage","c_hdr","c_det","c_rg","n_item_det_flag","n_item_count","n_bounce_cnt","n_tray_full","t_s_time" ) values
          ( @DocNo,"LEFT"(@CurrentTray,6),'',@hdr_data,'@non_pick_tray==> '+"isnull"(@non_pick_tray,'####'),@RackGrpCode,@ItemsInDetail,null,null,if @NextTray = '1' then 1 else 0 endif,"getdate"() ) ;
        set @CurrentTray = @non_pick_tray
      end if;
      //print '8';
      if @CurrentTray is null or @CurrentTray = '-nulltray-' then
        //print '9';
        select 'Warning!! : No Tray assigned for Document - '+"string"(@DocNo) as "c_message" for xml raw,elements;
        return
      end if end if;
    --EXTRACT USER SELECTED RACK GROUPS       
    //print '10';
    set @RackGrpList = @RackGrpCode;
    while @RackGrpList <> '' loop
      --1 RackGrpList
      --RackGrpList = RG0001**RG0002**__
      select "Locate"(@RackGrpList,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@RackGrpList,@ColPos-1));
      set @RackGrpList = "SubString"(@RackGrpList,@ColPos+@ColMaxLen);
      if(select "COUNT"("C_CODE") from "RACK_GROUP_MST" where "C_CODE" = @tmp) > 0 then --valid rack group selection 
        select "n_pos_seq" into @Seq from "st_store_stage_det" where "c_rack_grp_code" = @tmp and "st_store_stage_det"."c_br_code" = @BrCode;
        insert into "temp_rack_grp_list"( "c_rack_grp_code","c_stage_code","n_seq" ) values( @tmp,@StageCode,@Seq ) 
      //print '11';
      end if
    end loop;
    set @nIter = 0;
    /*gargee*/
    --n_tray_movement -0 --a--b -- c normal 
    --n_tray_movement -1 --b--to frist in substage 
    --n_tray_movement -2 --b--to direct to nth rack grp
    select "n_tray_movement" into @n_tray_movement from "st_track_setup";
    if @n_tray_movement = 0 then
      select "c_rack_grp_code"
        into @nextRackGrp from "st_store_stage_det"
        where "c_stage_code" = @StageCode
        and "n_pos_seq"
         = any(select top 1 "n_seq"+1 as "n_seq" from "temp_rack_grp_list"
          order by "n_seq" desc)
        and "st_store_stage_det"."c_br_code" = @BrCode --br misiing
    end if;
    //print '12';
    --change for urgent documnt by gargee
    select "n_confirm" into "urgent_flag" from "st_track_mst" where "c_doc_no" = @DocNo and "n_inout" = 0 and "n_inout" = @InOutFlag;
    //print 'urgent_flag';
    //print urgent_flag;
    //print '13';
    if "urgent_flag" = 2 then
      //        print '@DocNo urgent';
      //        print @DocNo;
      //        print @CurrentTray;
      select distinct "rack_group_mst"."c_store_code","ssm"."n_flag" into @store_code,@n_multi_user_flag
        from "st_track_det"
          join "rack_group_mst" on "rack_group_mst"."c_code" = "st_track_det"."c_rack_grp_code"
          join "st_store_stage_det" as "ssd" on "ssd"."c_rack_grp_code" = "rack_group_mst"."c_code"
          join "st_store_stage_mst" as "ssm" on "ssm"."c_code" = "ssd"."c_stage_code"
        where "c_doc_no" = @DocNo and "c_tray_code" = @CurrentTray and "n_inout" = 0;
      //print '@n_multi_user_flag';
      //print @n_multi_user_flag;
      if @n_multi_user_flag = 1 then // added by vinay on 23-04-21 to retain the multi_user_records
        delete from "st_track_tray_move" where "c_doc_no" = @DocNo and "n_inout" = 0 and "c_stage_code" <> 'FTRA'+"right"(@store_code,2)
      end if;
      commit work;
      if @fast_tracking_picking_flag = 0 then
        //        print 'urgent_flag';
        select 'Success' as "c_message",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements;
        return
      end if end if;
    --exp_items_management if diff batch Picked
    set @ExpBatch = "http_variable"('ExpBatch');
    set @doc_seq = 0;
    while @ExpBatch <> '' loop
      select "Locate"(@ExpBatch,@ColSep) into @ColPos;
      set @InOutFlag = "Trim"("Left"(@ExpBatch,@ColPos-1));
      set @ExpBatch = "SubString"(@ExpBatch,@ColPos+@ColMaxLen);
      --2 Seq
      select "Locate"(@ExpBatch,@ColSep) into @ColPos;
      set @OrgSeq = "Trim"("Left"(@ExpBatch,@ColPos-1));
      set @ExpBatch = "SubString"(@ExpBatch,@ColPos+@ColMaxLen);
      --3 ItemCode
      select "Locate"(@ExpBatch,@ColSep) into @ColPos;
      set @ItemCode = "Trim"("Left"(@ExpBatch,@ColPos-1));
      set @ExpBatch = "SubString"(@ExpBatch,@ColPos+@ColMaxLen);
      --4 batchreason
      select "Locate"(@ExpBatch,@ColSep) into @ColPos;
      set @batchreasoncode = "Trim"("Left"(@ExpBatch,@ColPos-1));
      set @ExpBatch = "SubString"(@ExpBatch,@ColPos+@ColMaxLen);
      --5 First batch
      select "Locate"(@ExpBatch,@ColSep) into @ColPos;
      set @BatchNo = "Trim"("Left"(@ExpBatch,@ColPos-1));
      set @ExpBatch = "SubString"(@ExpBatch,@ColPos+@ColMaxLen);
      -- 6 Selected batch
      select "Locate"(@ExpBatch,@ColSep) into @ColPos;
      set @selected_batch = "Trim"("Left"(@ExpBatch,@ColPos-1));
      set @ExpBatch = "SubString"(@ExpBatch,@ColPos+@ColMaxLen);
      --7 Qty
      select "Locate"(@ExpBatch,@ColSep) into @ColPos;
      set @Qty = "Trim"("Left"(@ExpBatch,@ColPos-1));
      set @ExpBatch = "SubString"(@ExpBatch,@ColPos+@ColMaxLen);
      -- Row Seperator--
      select "Locate"(@ExpBatch,@RowSep) into @RowPos;
      set @ExpBatch = "SubString"(@ExpBatch,@RowPos+@RowMaxLen);
      set @doc_seq = @doc_seq+1;
      if @ItemCode <> '' then
        insert into "st_batch_error"( "c_doc_no","d_date","c_item_code","c_batch_no","n_doc_seq","n_seq","c_reason_code","c_note","c_user","c_tray_code","c_checked_user","n_status","n_error_type","n_qty","c_rack_grp_code","c_stage_code" ) on existing update defaults off
          select @DocNo,@t_ltime,@ItemCode,@BatchNo,@doc_seq,@OrgSeq,@batchreasoncode,@selected_batch,@UserId,@CurrentTray,'',0,0,@Qty,@tmp,@StageCode
      --exp batch 
      end if
    end loop;
    while @DetData <> '' and @ItemsInDetail = 1 loop
      /*
@DetData : 1 InOutFlag~2 Seq~3 OrgSeq~4 ItemCode~5 BatchNo
~6 Qty~7 HoldFlag~8 cReason~9 cNote~10 CurrentTray
~11 RackCode~12 CurrentGrp~13 ItemNotFound ~14 t_pick_time
*/
      --saneesh
      set @nIter = @nIter+1;
      -- DocNo                
      --1 InOutFlag
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @InOutFlag = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --2 Seq
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @Seq = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --3 OrgSeq
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @OrgSeq = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --4 ItemCode
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @ItemCode = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --5 BatchNo
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @BatchNo = "rTrim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --6 Qty
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @Qty = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --7 HoldFlag
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @HoldFlag = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --8 cReason
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @cReason = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --9 cNote
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @cNote = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --10 tray
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @CurrentTray = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      set @det_tray_code = @CurrentTray;
      if(select "count"("c_doc_no") from "st_track_tray_move" where "c_tray_code" = @CurrentTray and "n_auto_complete_tray" = 1) > 0 then
        if @enable_log = 1 then
          insert into "st_log_ret"
            ( "c_doc_no","c_tray","c_stage","c_rg","n_flag","t_time" ) values
            ( @DocNo,@CurrentTray,@StageCode,'Emergency Bill',9,"getdate"() ) 
        end if;
        select 'Success' as "c_message",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements;
        return
      end if;
      if @nIter = 1 then --check for server response error
        //Added on 07-08-19 by vinay to avoid double document_done 
        //****************************************************************************************************
        select "sum"("isnull"("n_tray_flag",0))
          into @tray_in_progress from "st_track_tray_move","temp_rack_grp_list"
          where "temp_rack_grp_list"."c_rack_grp_code" = "st_track_tray_move"."c_rack_grp_code"
          and "st_track_tray_move"."c_doc_no" = @DocNo
          and "st_track_tray_move"."c_tray_code" = @CurrentTray;
        if @tray_in_progress is null then
          set @tray_in_progress = 0
        end if;
        if @tray_in_progress = 0 then
          if(select "count"() from "st_track_tray_move"
              where "c_doc_no" = @DocNo
              and "c_tray_code" = @CurrentTray
              and "c_stage_code" = @StageCode
              and "c_rack_grp_code" = "isnull"(@nextRackGrp,'-')) = 0 then
            //            update "st_track_tray_move" set "n_tray_flag" = 1 from "temp_rack_grp_list"
            update "st_track_tray_move" set "n_tray_flag" = 0 from "temp_rack_grp_list"
              where "temp_rack_grp_list"."c_rack_grp_code" = "st_track_tray_move"."c_rack_grp_code"
              and "st_track_tray_move"."c_doc_no" = @DocNo
              and "st_track_tray_move"."c_tray_code" = @CurrentTray
          else
            //DebugLog
            if @enable_log = 1 then
              insert into "st_log_ret"
                ( "c_doc_no","c_tray","c_stage","c_rg","n_flag","t_time" ) values
                ( @DocNo,@CurrentTray,@StageCode,'Tray alrdy moved',0,"getdate"() ) 
            end if;
            --select 'Tray & Document Already Moved/Processed '+@CurrentTray+' & '+@DocNo as c_message for xml raw,elements;
            select 'Success' as "c_message",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements;
            return
          //DebugLog
          end if
        else if @enable_log = 1 then
            insert into "st_log_ret"
              ( "c_doc_no","c_tray","c_stage","c_rg","n_flag","t_time" ) values
              ( @DocNo,@CurrentTray,@StageCode,'Tray in process',1,"getdate"() ) 
          end if;
          --select 'Tray & Document Already in inprogress '+@CurrentTray+' & '+@DocNo as c_message for xml raw,elements;
          select 'Success' as "c_message",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements;
          return
        end if;
        //****************************************************************************************************
        select "count"("c_tray_code")
          into @nTrayInCurrRG from "st_track_tray_move" as "tm"
            join "temp_rack_grp_list" as "rg" on "tm"."c_rack_grp_code" = "rg"."c_rack_grp_code"
          where "tm"."c_tray_code" = @CurrentTray;
        if(@nTrayInCurrRG) = 0 then
          -- INCASE OF DUPLICATE DOCUMENT DONE CALL
          --tray is already moved to next rack group or the tray being moved, is not present in tray move table
          select "max"("st_track_pick"."n_seq") as "n_max_seq"
            into @maxSeq from "st_track_pick"
              join "temp_rack_grp_list" on "st_track_pick"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
            where "st_track_pick"."c_doc_no" = @DocNo
            and "st_track_pick"."c_stage_code" = @StageCode
            and "st_track_pick"."c_godown_code" = @GodownCode
            and "st_track_pick"."n_inout" = @InOutFlag;
          select 'Success' as "c_message",@maxSeq as "n_max_seq",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements;
          return
        end if end if;
      ---------dout  gargee
      --11 RackCode
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @RackCode = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --12 CurrentGrp
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @CurrentGrp = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --vinay added to avoid blank and item merge issue  
      //    ****************************************************************************************************
      if @det_tray_code <> @hdr_tray_code and @hdr_tray_code <> '-nulltray-' then
        if @enable_log = 1 then
          insert into "st_log_ret"
            ( "c_doc_no","c_tray","c_stage","c_rg","n_flag","t_time" ) values
            ( @DocNo,@CurrentTray,@StageCode,'Det tray and Mst tray mismatch',6,"getdate"() ) 
        end if;
        return
      end if;
      //    ****************************************************************************************************
      --13 ItemNotFound
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @ItemNotFound = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --14 ItemNotFound
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @t_pick_time = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --print @t_pick_time;
      if "trim"(@t_pick_time) = '' or @t_pick_time is null then
        set @t_pick_time = "now"()
      end if;
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @non_pick_flag = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      select "Locate"(@DetData,@RowSep) into @RowPos;
      set @DetData = "SubString"(@DetData,@RowPos+@RowMaxLen);
      if(select "count"("c_doc_no") from "st_track_tray_move" where "c_tray_code" = @CurrentTray and "n_auto_complete_tray" = 1) > 0 then
        if @enable_log = 1 then
          insert into "st_log_ret"
            ( "c_doc_no","c_tray","c_stage","c_rg","n_flag","t_time" ) values
            ( @DocNo,@CurrentTray,@StageCode,'Emergency Bill',9,"getdate"() ) 
        end if;
        select 'Failure' as "c_message" for xml raw,elements;
        return
      end if;
      if @ItemNotFound = 1 and @TranPrefix = 'S' then
        select "uf_update_bounce_entry"(@ItemCode,@Qty,null,null,null,null,null,@cReason,@DocNo,'PICKING')
          into @RetString end if;
      select(if("n_bal_qty"-@Qty) < 0 then 0 else("n_bal_qty"-@Qty) endif)
        into @RemainingQty from "st_track_det"
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "c_item_code" = @ItemCode
        and "n_seq" = @OrgSeq
        and "st_track_det"."c_godown_code" = @GodownCode;
      if @ItemNotFound = 0 then
        if @non_pick_flag = 0 then
          set @d_item_pick_count = @d_item_pick_count+1
        end if;
        -- for parent_seq 
        select "n_parent_item_seq","n_from_ord_inv" into @parent_item_seq,@from_ord_inv
          from "st_track_det"
          where "st_track_det"."c_doc_no" = @DocNo
          and "st_track_det"."n_inout" = @InOutFlag
          and "st_track_det"."c_item_code" = @ItemCode
          and "st_track_det"."n_seq" = @OrgSeq;
        insert into "st_track_pick"
          ( "c_doc_no","n_inout","n_seq","n_org_seq","c_item_code","c_batch_no","n_qty","n_hold_flag","c_reason_code","c_note","c_user","t_time","c_tray_code","c_device_id","c_rack","c_rack_grp_code","c_stage_code",
          "c_godown_code","n_non_pick_flag","n_reject_qty","n_parent_item_seq","n_from_ord_inv","c_actual_batch_no","n_actual_seq" ) on existing update defaults off values
          ( @DocNo,@InOutFlag,@Seq,@OrgSeq,@ItemCode,@BatchNo,@Qty,@HoldFlag,@cReason,@cNote,@UserId,@t_pick_time,@CurrentTray,@devID,@RackCode,@CurrentGrp,@StageCode,@GodownCode,@non_pick_flag,
          if @non_pick_flag = 1 then @Qty else 0 endif,if @non_pick_flag = 1 then 0 else @parent_item_seq endif,if @non_pick_flag = 1 then 0 else @from_ord_inv endif,@BatchNo,@OrgSeq ) ;
        commit work;
        select "st_track_det"."c_batch_no","st_track_det"."n_ref_srno","st_track_det"."c_ref_doc_no" --vinay added to test on 20-01-2020
          into @inv_batch,@ref_srno,@ref_doc_no from "st_track_det"
          where "st_track_det"."c_doc_no" = @DocNo
          and "st_track_det"."c_item_code" = @ItemCode
          and "st_track_det"."n_seq" = @OrgSeq
          and "st_track_det"."n_inout" = 0;
        update "st_track_pick" set "st_track_pick"."n_ref_srno" = @ref_srno,"st_track_pick"."c_ref_doc_no" = @ref_doc_no --vinay added to test on 20-01-2020           
          where "st_track_pick"."c_doc_no" = @DocNo
          and "st_track_pick"."c_item_code" = @ItemCode
          and "st_track_pick"."n_org_seq" = @OrgSeq
          and "st_track_pick"."n_inout" = 0
          and "st_track_pick"."c_tray_code" = @CurrentTray;
        if @inv_batch <> @BatchNo then
          if @ItemCode <> '' then
            //            insert into "st_track_pick_adj"
            //              ( "n_srno","c_item_code","c_batch_no","n_qty","n_seq","c_tray_code","c_godown_code","c_rack_grp_code","c_stage_code","c_user","t_ltime","n_pick_seq","n_type" ) on existing update defaults off values
            //              ( "reverse"("left"("reverse"(@DocNo),"charindex"('/',("reverse"(@DocNo)))-1)),
            //              @ItemCode,@BatchNo,@Qty,@OrgSeq,@CurrentTray,
            //              @GodownCode,@CurrentGrp,@StageCode,@UserId,@t_ltime,@Seq,3 ) ;
            //            commit work
            //            update "st_track_pick" set "st_track_pick"."n_hold_flag" = 1
            //              where "st_track_pick"."c_doc_no" = @DocNo
            //              and "st_track_pick"."c_item_code" = @ItemCode
            //              and "st_track_pick"."c_batch_no" = @BatchNo
            //              and "st_track_pick"."c_tray_code" = @CurrentTray
            //              and "st_track_pick"."n_seq" = @Seq
          end if end if;
        update "st_track_det"
          set "n_complete" = (if "n_complete" = 2 then 2 else(if @RemainingQty = 0 then 1 else 0 endif) endif),
          "n_bal_qty" = @RemainingQty
          where "c_doc_no" = @DocNo
          and "n_inout" = @InOutFlag
          and "c_item_code" = @ItemCode
          and "n_seq" = @OrgSeq
          and "st_track_det"."c_godown_code" = @GodownCode;
        commit work
      else
        if @non_pick_flag = 0 then
          set @d_item_pick_count = @d_item_pick_count+1
        end if;
        update "st_track_det"
          set "n_complete" = 2, --item not found
          "c_reason_code" = @cReason
          where "c_doc_no" = @DocNo
          and "n_inout" = @InOutFlag
          and "c_item_code" = @ItemCode
          and "n_seq" = @OrgSeq
          and "st_track_det"."c_godown_code" = @GodownCode;
        commit work;
        --//Getting next rack group is controled by n_tray_movement flag 
        -- if @ItemNotFound = 1 and @TranPrefix = 'S' then gg
        insert into "lost_order_master"
          ( "c_item_code","d_date","n_qty","n_inv_no","n_shortsupply","c_ord_year","c_ord_prefix","n_ord_srno","c_inv_prefix","c_reason_code","n_block_stock","c_bounce_from" ) values
          ( @ItemCode,"uf_default_date"(),@Qty,"reverse"("left"("reverse"(@DocNo),"charindex"('/',("reverse"(@DocNo)))-1)),0,18,'',0,
          "left"("substr"("substring"("left"(@DocNo,("length"(@DocNo)-("charindex"('/',"reverse"(@DocNo))-1))),"charindex"('/',"left"(@DocNo,("length"(@DocNo)-("charindex"('/',"reverse"(@DocNo))-1))))+1),"charindex"('/',"substring"("left"(@DocNo,("length"(@DocNo)-("charindex"('/',"reverse"(@DocNo))-1))),"charindex"('/',"left"(@DocNo,("length"(@DocNo)-("charindex"('/',"reverse"(@DocNo))-1))))+1))+1),"charindex"('/',"substr"("substring"("left"(@DocNo,("length"(@DocNo)-("charindex"('/',"reverse"(@DocNo))-1))),"charindex"('/',"left"(@DocNo,("length"(@DocNo)-("charindex"('/',"reverse"(@DocNo))-1))))+1),"charindex"('/',"substring"("left"(@DocNo,("length"(@DocNo)-("charindex"('/',"reverse"(@DocNo))-1))),"charindex"('/',"left"(@DocNo,("length"(@DocNo)-("charindex"('/',"reverse"(@DocNo))-1))))+1))+1))-1),
          @cReason,0,'PICKING' ) ;
        commit work;
        if @ItemCode <> '' then
          //          insert into "st_track_pick_adj"
          //            ( "n_srno","c_item_code","c_batch_no","n_qty","n_seq","c_tray_code","c_godown_code","c_rack_grp_code","c_stage_code","c_user","t_ltime","n_pick_seq","n_type" ) on existing update defaults off values
          //            ( "reverse"("left"("reverse"(@DocNo),"charindex"('/',("reverse"(@DocNo)))-1)),@ItemCode,@BatchNo,@Qty,@OrgSeq,@CurrentTray,
          //            @GodownCode,@CurrentGrp,@StageCode,@UserId,@t_ltime,@Seq,1 ) ;
          //          insert into "st_track_pick_hold_ledger"
          //            ( "n_srno","c_item_code","c_batch_no","n_qty","t_ltime","n_type" ) on existing update defaults off values
          //            ( "reverse"("left"("reverse"(@DocNo),"charindex"('/',("reverse"(@DocNo)))-1)),@ItemCode,@BatchNo,@Qty,@t_ltime,1 ) ;
          //          commit work
        end if
      end if
    end loop;
    set @det_item_cnt = 0;
    set @det_item_n_f_cnt = 0;
    set @det_item_qty = 0;
    set @det_item_bal_qty = 0;
    select "count"("st_track_det"."c_item_code") as "det_item_cnt",
      "sum"(if "n_qty" = "n_bal_qty" and "n_complete" = 2 then 1 else 0 endif) as "det_item_n_f_cnt",
      "sum"("st_track_det"."n_qty") as "det_item_qty",
      "sum"(if "n_qty" = "n_bal_qty" and "n_complete" = 2 then "st_track_det"."n_bal_qty" else 0 endif) as "det_not_found_qty"
      into @det_item_cnt,@det_item_n_f_cnt,@det_item_qty,@det_item_bal_qty
      from "st_track_det"
      where "c_doc_no" = @DocNo
      and "n_inout" = 0
      and "n_non_pick_flag" <> 1;
    if("isnull"(@det_item_cnt,0) = "isnull"(@det_item_n_f_cnt,0)) and("isnull"(@det_item_qty,0)) = "isnull"(@det_item_bal_qty,0) then
      insert into "st_track_not_found_invoice"
        ( "n_inv_no","n_crnt_no","c_phase_code","d_date","c_user","t_time","c_luser","d_ldate","t_ltime" ) on existing update defaults off
        select "reverse"("left"("reverse"(@DocNo),"charindex"('/',("reverse"(@DocNo)))-1)),0,'PH0001',@d_ldate,@UserId,@t_ltime,@UserId,@d_ldate,@t_ltime;
      commit work;
      update "st_track_det" set "n_complete" = 2
        where "st_track_det"."c_doc_no" = @DocNo
        and "st_track_det"."n_non_pick_flag" = 1
        and "st_track_det"."n_inout" = 0;
      commit work
    end if;
    while @godown_item_detail <> '' loop
      set @nIter = @nIter+1;
      -- DocNo                
      --1 InOutFlag
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @InOutFlag = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      --2 Seq
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @Seq = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      --3 OrgSeq
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @OrgSeq = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      --4 ItemCode
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @ItemCode = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      --5 BatchNo
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @BatchNo = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      --6 Qty
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @Qty = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      --7 HoldFlag
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @HoldFlag = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      --8 cReason
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @cReason = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      --9 cNote
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @cNote = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      --10 @CurrentTray  
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @CurrentTray = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      --11 RackCode
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @RackCode = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      --12 CurrentGrp
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @CurrentGrp = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      --13 ItemNotFound
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @ItemNotFound = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      --14 ItemNotFound
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @t_pick_time = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      --15 print @t_pick_time;
      if "trim"(@t_pick_time) = '' or @t_pick_time is null then
        set @t_pick_time = "now"()
      end if;
      -- 16 non pick flag 
      select "Locate"(@godown_item_detail,@ColSep) into @ColPos;
      set @non_pick_flag = "Trim"("Left"(@godown_item_detail,@ColPos-1));
      set @godown_item_detail = "SubString"(@godown_item_detail,@ColPos+@ColMaxLen);
      select "Locate"(@godown_item_detail,@RowSep) into @RowPos;
      set @godown_item_detail = "SubString"(@godown_item_detail,@RowPos+@RowMaxLen);
      if @non_pick_flag is null then
        set @non_pick_flag = 0
      end if;
      if @partial_shift_to_godown = 0 then
        update "st_track_det"
          set "c_tray_code" = null,
          "c_godown_code" = @hold_godown_code,
          "c_stage_code" = @hold_stage_code,
          "c_rack_grp_code" = @hold_rack_grp_code,
          "c_rack" = @hold_rack,
          "c_user" = null
          where "c_doc_no" = @DocNo and "c_item_code" = @ItemCode and "c_batch_no" = @BatchNo and "n_seq" = @OrgSeq and "st_track_det"."n_non_pick_flag" = 0
      else
        select "max"("n_seq") into @shift_max_seq from "st_track_det" where "c_doc_no" = @DocNo;
        set @shift_max_seq = @shift_max_seq+1;
        select "n_qty" into @org_qty from "st_track_det" where "c_doc_no" = @DocNo and "c_item_code" = @ItemCode and "c_batch_no" = @BatchNo and "n_seq" = @OrgSeq;
        set @RemainingQty = "isnull"(@RemainingQty,0);
        set @shift_qty = @org_qty-@RemainingQty;
        insert into "st_track_det"
          ( "c_doc_no","n_inout","c_item_code","c_batch_no","n_seq","n_qty","n_sch_qty","n_bal_qty","c_note",
          "c_rack","c_rack_grp_code","c_stage_code","n_complete","c_reason_code","n_hold_flag","c_tray_code","c_user","c_godown_code",
          "c_stin_ref_no","c_user_2","d_ldate","t_ltime","n_sch_slab_qty","n_sch_slab_sch_qty","n_sch_disc_perc","n_scheme_disc","n_schm_qty_2_schm_disc",
          "n_non_pick_flag","n_parent_item_seq","n_from_ord_inv","n_ref_srno","c_ref_doc_no" ) 
          select "c_doc_no","n_inout","c_item_code","c_batch_no",@shift_max_seq,if(@RemainingQty <= 0 or @RemainingQty is null) then @shift_qty else @RemainingQty endif,0,
            if(@RemainingQty <= 0 or @RemainingQty is null) then @shift_qty else @RemainingQty endif,"c_note",
            @hold_rack,@hold_rack_grp_code,@hold_stage_code,0,'-',0,null,null,@hold_godown_code,
            "c_stin_ref_no","c_user_2","today"(),"now"(),"n_sch_slab_qty","n_sch_slab_sch_qty","n_sch_disc_perc","n_scheme_disc","n_schm_qty_2_schm_disc",
            "n_non_pick_flag","n_parent_item_seq","n_from_ord_inv","n_ref_srno","c_ref_doc_no"
            from "st_track_det"
            where "c_doc_no" = @DocNo and "c_item_code" = @ItemCode and "c_batch_no" = @BatchNo and "n_seq" = @OrgSeq and "st_track_det"."n_non_pick_flag" = 0;
        update "st_track_det" set "n_complete" = if @RemainingQty = 0 then 2 else 1 endif,"n_bal_qty" = 0,"n_qty" = if @RemainingQty = 0 then 0 else @shift_qty endif where "c_doc_no" = @DocNo and "c_item_code" = @ItemCode and "c_batch_no" = @BatchNo and "n_seq" = @OrgSeq
      end if;
      commit work
    end loop; //GODWN ITEM LOOP
    if(select "count"("c_tray_code") from "st_track_tray_move" where "c_tray_code" = @CurrentTray and "c_stage_code" = @StageCode and "c_godown_code" = @GodownCode) > 1 then
      //    print 'FTRACK_test3';
      --at the end of the stage(last RG) preserve 1 record for scanning process
      select top 1 "st_track_tray_move"."c_rack_grp_code"
        into @maxRackGrp from "st_track_tray_move"
          join "temp_rack_grp_list" on "st_track_tray_move"."c_stage_code" = "temp_rack_grp_list"."c_stage_code"
          and "st_track_tray_move"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
        where "st_track_tray_move"."c_godown_code" = @GodownCode and "st_track_tray_move"."c_stage_code" = @StageCode
        order by "n_seq" desc;
      //print '@maxRackGrp';
      //print @maxRackGrp;
      delete from "st_track_tray_move"
        where "c_tray_code" = @CurrentTray
        and "c_rack_grp_code" <> @maxRackGrp
        and "c_stage_code" = @StageCode
        and "st_track_tray_move"."c_godown_code" = @GodownCode;
      commit work
    end if;
    --sani
    -- Get the curr RackGroup code 
    select top 1 "c_rack_grp_code"
      into @rackGrp from "st_track_tray_move"
      where "c_doc_no" = @DocNo
      and "n_inout" = @InOutFlag
      and "c_tray_code" = @CurrentTray
      and "c_stage_code" = @StageCode
      and "c_user" = @UserId;
    --Check pend item count for tht doc stage 
    select "count"()
      into @d_pend_qty_to_pick_next_rg from "st_track_det"
      where "st_track_det"."c_stage_code" = @StageCode
      and "st_track_det"."c_rack_grp_code" <> @rackGrp
      and "st_track_det"."c_doc_no" = @DocNo
      and "st_track_det"."c_godown_code" = @GodownCode
      and "st_track_det"."n_complete" = 0
      and "st_track_det"."n_inout" = @InOutFlag;
    --Print @RackGrpCode              ;
    if(@d_pend_qty_to_pick_next_rg <= 0 or @nTrayFull = 1) and(@d_mark_as_complete_no_item_to_pick_next_rg = 1) and(@TranPrefix <> '02') then
      --check 
      set @nextRackGrp = null;
      set @d_auto_complete_tray = 1
    //      print @DocNo+'-'+@StageCode+'-'+@rackGrp+'-'+@CurrentTray+' Updated as Autocomplete'+"string"("now"())
    end if;
    --
    --print '@nextRackGrp5';
    --print @nextRackGrp;
    if @nextRackGrp is not null then //--a or b
      if @ItemsInDetail = 0 and @NextTray <> '1' then
        //check for pending items
        if(select "count"("c_item_code") from "st_track_det" join "temp_rack_grp_list"
              on "st_track_det"."c_stage_code" = "temp_rack_grp_list"."c_stage_code"
              and "st_track_det"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
            where "st_track_det"."n_complete" = 0
            and "st_track_det"."c_tray_code" = @CurrentTray
            and "st_track_det"."n_inout" = @InOutFlag
            and "st_track_det"."c_godown_code" = @GodownCode
            and "st_track_det"."c_doc_no" = @DocNo) > 0 then
          //DebugLog
          if @enable_log = 1 then
            insert into "st_log_ret"
              ( "c_doc_no","c_tray","c_stage","c_rg","n_flag","t_time" ) values
              ( @DocNo,@CurrentTray,@StageCode,'Blank Tray Move To '+"ISNULL"(@nextRackGrp,'N'),4,"getdate"() ) 
          end if;
          select 'Success' as "c_message",@maxSeq as "n_max_seq",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements;
          return
        end if end if;
      select top 1 "isnull"("t_time","now"())
        into @t_preserve_ltime from "st_track_tray_move"
        where "c_tray_code" = @CurrentTray
        and "st_track_tray_move"."c_godown_code" = @GodownCode;
      set @t_ltime = "now"();
      set @t_preserve_ltime = @t_preserve_ltime;
      --new tray insert
      select top 1 "c_rack_grp_code"
        into @rackGrp from "st_track_tray_move"
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "c_tray_code" = @CurrentTray
        and "c_stage_code" = @StageCode
        and "c_user" = @UserId;
      --print 'delete insert';
      //AUTO MOVE TRAY  ON 11/08/2020
      if(select "COUNT"("C_RACK_GRP_CODE") from "ST_TRACK_AUTO_MOVE_CONFIG" where "C_RACK_GRP_CODE" = @nextRackGrp and "N_ACTIVE" = 1) > 0 then
        if(select "count"("c_doc_no") from "st_track_det" where "c_doc_no" = @DocNo and "c_rack_grp_code" = @nextRackGrp and "c_tray_code" = @CurrentTray and "n_complete" = 0) = 0 then
          select "c_rack_grp_code"
            into @nextRackGrp_New from "st_store_stage_det"
            where "c_stage_code" = @StageCode
            and "n_pos_seq" = any(select top 1 "n_pos_seq"+1 as "n_seq" from "st_store_stage_det" as "sd" where "sd"."c_br_code" = @BrCode and "sd"."c_stage_code" = @StageCode
              and "sd"."c_rack_grp_code" = @nextRackGrp
              order by "sd"."n_pos_seq" desc)
            and "st_store_stage_det"."c_br_code" = @BrCode;
          //          print '@nextRackGrp_New;';
          //          print @nextRackGrp_New;
          set @nextRackGrp = @nextRackGrp_New
        end if end if;
      update "st_track_tray_move"
        set "c_rack_grp_code" = @nextRackGrp,
        "t_time" = @t_ltime,"c_user" = @UserId,"n_auto_complete_tray" = @d_auto_complete_tray,"n_inout" = @InOutFlag
        where "c_tray_code" = @CurrentTray
        and "c_doc_no" = @DocNo
        and "st_track_tray_move"."c_godown_code" = @GodownCode;
      commit work;
      update "st_track_det" set "n_complete" = 2
        where "c_doc_no" = @DocNo
        and "n_inout" = 0
        and "n_non_pick_flag" = 1
        and "c_stage_code" = @StageCode
        and "c_rack_grp_code" = @rackGrp;
      commit work;
      --gargee
      call "uf_update_tray_time"(@DocNo,@InOutFlag,@CurrentTray,'PICKING',@UserId,@rackGrp,@StageCode,2,@t_tray_move_time,@d_item_pick_count,@d_item_bounce_count);
      --gargee
      select "max"("c_user_id")
        into @next_rack_user from "st_store_login_det"
        where "c_rack_grp_code" = @nextRackGrp
        and "c_stage_code" = @StageCode
        and "t_login_time" is not null;
      if @next_rack_user is null or "trim"(@next_rack_user) = '' then
      else --ithum njan 
        if @enable_log = 1 then
          update
            "st_doc_done_log"
            set "n_tray_time" = 3
            where "n_seq" = @log_seq
        end if;
        call "uf_update_tray_time"(@DocNo,@InOutFlag,@CurrentTray,'PICKING',@UserId,@nextRackGrp,@StageCode,0,@t_tray_move_time,@d_item_pick_count,@d_item_bounce_count);
        if @enable_log = 1 then
          update
            "st_doc_done_log"
            set "n_tray_time" = 4
            where "n_seq" = @log_seq
        --Last rack grp 
        //################## Added On 04/12/16 for Vaoiding Blank Tray Move Which is not able to handle by Android Tab
        end if
      end if
    else if @ItemsInDetail = 0 and @NextTray <> '1' then
        --print 'item_indetail is 1';
        //check for pending items
        if(select "count"("c_item_code") from "st_track_det" join "temp_rack_grp_list"
              on "st_track_det"."c_stage_code" = "temp_rack_grp_list"."c_stage_code"
              and "st_track_det"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
            where "st_track_det"."n_complete" = 0
            and "st_track_det"."c_tray_code" = @CurrentTray
            and "st_track_det"."n_inout" = @InOutFlag
            and "st_track_det"."c_godown_code" = @GodownCode
            and "st_track_det"."c_doc_no" = @DocNo) > 0 then
          if @enable_log = 1 then
            insert into "st_log_ret"
              ( "c_doc_no","c_tray","c_stage","c_rg","n_flag","t_time" ) values
              ( @DocNo,@CurrentTray,@StageCode,'Blank Tray Move To '+"ISNULL"(@nextRackGrp,'N1'),5,"getdate"() ) 
          end if;
          select 'Success' as "c_message",@maxSeq as "n_max_seq",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements;
          return
        end if end if;
      select top 1 "t_time"
        into @t_preserve_ltime from "st_track_tray_move"
        where "c_tray_code" = @CurrentTray
        and "c_stage_code" = @StageCode
        and "st_track_tray_move"."c_godown_code" = @GodownCode;
      set @t_ltime = "now"();
      --print @t_ltime ;
      select top 1 "c_rack_grp_code"
        into @rackGrp from "st_track_tray_move"
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "c_stage_code" = @StageCode
        and "c_tray_code" = @CurrentTray
        and "c_user" = @UserId;
      if @enable_log = 1 then
        update
          "st_doc_done_log"
          set "n_tray_time" = 5
          where "n_seq" = @log_seq
      end if;
      --print 'gargee_@tmp';
      --print @tmp_rg;
      select top 1 "c_rack_grp_code" into @tmp_rg from "temp_rack_grp_list"; --changed
      --call uf_update_tray_time(@DocNo,@InOutFlag,@CurrentTray,'PICKING',@UserId,@tmp_rg,@StageCode,2,@t_tray_move_time,@d_item_pick_count,@d_item_bounce_count); --change by gargee
      if @enable_log = 1 then
        update "st_doc_done_log"
          set "n_tray_time" = 6
          where "n_seq" = @log_seq
      end if;
      update "st_track_tray_move"
        set "n_inout" = 9,"c_rack_grp_code" = '-',"t_time" = @t_ltime,"n_auto_complete_tray" = @d_auto_complete_tray
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "c_tray_code" = @CurrentTray
        and "c_stage_code" = @StageCode
        and "c_godown_code" = @GodownCode;
      /*Vinay_testing1*/
      if "uf_sys_para_setup"('S00211','-','0',1) = 1 then
        if(select "count"("c_doc_no") from "st_track_tray_move" where "c_doc_no" = @DocNo and "n_inout" = 0) = 0 then //check for Last Tray Move
          select "uf_sys_para_setup"('S00211','-','0',2) into @doc_stage_code;
          if(select "count"("c_item_code") from "st_track_det" where "c_doc_no" = @DocNo and "n_complete" = 0) = 0 then
            if(select "count"("c_code") from "doc_stage_mst" where "c_code" = @doc_stage_code) = 1 then
              insert into "DBA"."doc_track"( "c_stage_code","c_inv_prefix","n_inv_no","c_dman_code","n_errors","c_note","c_user","d_date","t_time","t_ltime" ) on existing skip values
                ( @doc_stage_code,@TranPrefix,@TranSrno,'-',0,null,@UserId,"today"(),"now"(),"now"() ) ;
              if @TranPrefix = 'IS' then
                insert into "DBA"."doc_track" on existing skip
                  select @doc_stage_code,"c_inv_prefix","n_inv_no",'-',0,null,@UserId,"today"(),"now"(),"now"()
                    from "inv_summary_list_det" where "n_srno" = @TranSrno
              end if end if end if end if end if;
      --added by vinay to test auto exit and doc_track_insert on 07-08-20
      commit work;
      -- new 19-02-19
      select "count"("st_track_det"."c_item_code")
        into @itemcount from "st_track_det" where "st_track_det"."c_doc_no" = @DocNo
        and "st_track_det"."n_inout" = @InOutFlag
        and "st_track_det"."n_complete" not in( 2,9,8 ) 
        and "st_track_det"."n_non_pick_flag" = 0;
      update "st_track_det" set "n_complete" = 2
        where "st_track_det"."c_doc_no" = @DocNo
        and "st_track_det"."n_inout" = 0
        and "st_track_det"."n_non_pick_flag" = 1
        and "c_stage_code" = @StageCode
        and "c_rack_grp_code" = @rackGrp;
      commit work;
      if @itemcount = 0 then
        update "st_track_mst" set "st_track_mst"."n_complete" = 9,"st_track_mst"."t_time_in" = "now"()
          where "st_track_mst"."c_doc_no" = @DocNo
          and "st_track_mst"."n_inout" = @InOutFlag;
        commit work
      end if;
      call "uf_update_tray_time"(@DocNo,@InOutFlag,@CurrentTray,'PICKING',@UserId,@tmp_rg,@StageCode,2,@t_tray_move_time,@d_item_pick_count,@d_item_bounce_count); --change by gargee
      //------------------------
      if @TranPrefix = '02' then --Godown transfer req 
        if @nextRackGrp is null then --@nextRackGrp is null 
          -- to handle exp stock removal  on 14-07-2016       
          ---------------------- GET details from request table.
          select "c_godown_from_code","c_godown_to_code","c_reason_code","c_note","n_eb_flag"
            into @godownFrom,@godownTo,@ReasonCode,@cNote,@n_eb_flag
            from "godown_tran_mst"
            where '000/'+"c_year"+'/'+"c_prefix"+'/'+"string"("n_srno") = @DocNo;
          if "trim"(@godownTo) = '' or @godownTo is null then
            set @godownTo = '-'
          end if;
          if @NewSrno is null then
            set @NewSrno = 1
          end if;
          select "count"("c_trans")
            into @nPrefixCount from "prefix_sr_numbers"
            where "c_trans" = 'GDTRE'
            and "c_prefix" = '03';
          if(@nPrefixCount) <= 0 then
            insert into "prefix_sr_numbers"( "c_prefix","n_sr_number","c_trans","n_lock_number","c_year","c_head1","c_head2","d_date" ) values
              ( '03',0,'GDTRE',0,'16',null,null,"today"() ) 
          else
            select "n_sr_number"
              into @NewSrno from "prefix_sr_numbers"
              where "c_trans" = 'GDTRE'
              and "c_prefix" = '03'
          end if;
          update "prefix_sr_numbers" set "n_sr_number" = "n_sr_number"+1
            where "c_trans" = 'GDTRE'
            and "c_prefix" = '03';
          set @cNote = 'Tray : '+"string"(@CurrentTray);
          insert into "godown_tran_mst"
            ( "c_year","c_prefix","n_srno","d_date",
            "t_time","c_godown_from_code","c_godown_to_code","c_reason_code","c_note",
            "c_lr_no","d_lr_date","d_stock_sent_date","n_cases","n_approved",
            "n_cnt_no","n_cancel_flag","d_ldate","t_ltime",
            "c_user","c_modiuser","n_store_track","c_computer_name","c_sys_user",
            "c_sys_ip",
            "n_eb_flag" ) 
            select @TranYear as "c_year",'03' as "c_prefix",
              @NewSrno as "n_srno","uf_default_date"() as "d_date","now"() as "t_time",@godownTo as "c_godown_from_code",
              @godownFrom as "c_godown_to_code",@ReasonCode as "c_reason_code",@cNote as "c_note",@DocNo as "c_lr_no",
              null as "d_lr_date",
              "uf_default_date"() as "d_stock_sent_date",
              0 as "n_cases",1 as "n_approved",0 as "n_cnt_no",
              0 as "n_cancel_flag","uf_default_date"() as "d_ldate","now"() as "t_ltime",
              @UserId as "c_user",@UserId as "c_modiuser",2 as "n_store_track",
              null as "c_computer_name",null as "c_sys_user",null as "c_sys_ip",@n_eb_flag;
          insert into "godown_tran_det"
            ( "c_prefix","n_srno","n_seq",
            "d_date","c_godown_from_code","c_godown_to_code",
            "c_item_code","c_batch_no","n_request_qty","n_qty",
            "n_approved","n_cancel_flag",
            "d_ldate","t_ltime","n_store_track","c_tray_code",
            "n_eb_flag" ) 
            select '03' as "c_prefix",
              @NewSrno as "n_srno","number"() as "n_seq","uf_default_date"() as "d_date",@godownTo as "c_godown_from_code",
              @godownFrom as "c_godown_to_code","c_item_code" as "c_item_code","c_batch_no" as "c_batch_no",
              0 as "n_request_qty","n_qty" as "n_qty",
              1 as "n_approved",0 as "n_cancel_flag","uf_default_date"() as "d_ldate","now"() as "t_ltime",
              2 as "n_store_track","c_tray_code" as "c_tray_code",@n_eb_flag as "n_eb_flag"
              from "st_track_pick"
              where "c_doc_no" = @DocNo
              and "c_tray_code" = @CurrentTray
              and "n_confirm_qty" = 0;
          update "st_track_pick" set "n_confirm_qty" = "n_qty"
            where "c_doc_no" = @DocNo
            and "c_tray_code" = @CurrentTray;
          commit work;
          update "st_track_det","st_track_pick"
            set "st_track_det"."n_complete" = 9
            where "st_track_det"."c_doc_no" = "st_track_pick"."c_doc_no"
            and "st_track_det"."n_seq" = "st_track_pick"."n_org_seq"
            and "st_track_pick"."c_doc_no" = @DocNo
            and "st_track_pick"."c_tray_code" = @CurrentTray;
          commit work
        end if; --@nextRackGrp is null 
        //    print 'FTRACK_test1';
        delete from "st_track_tray_move"
          where "c_doc_no" = @DocNo
          and "c_tray_code" = @CurrentTray
          and "c_stage_code" = @StageCode
          and "c_godown_code" = @GodownCode;
        commit work
      --godown request
      //------------------------                                      
      end if end if; --last rack grp 
    -- for tray release>>
    if @nextRackGrp is null then
      select "count"()
        into @n_pick_count from "st_track_pick"
        where "st_track_pick"."c_tray_code" = @CurrentTray
        and "st_track_pick"."c_doc_no" = @DocNo
        and "c_stage_code" = @StageCode
        and "st_track_pick"."c_godown_code" = @GodownCode
        and "n_inout" = @InOutFlag
        and "st_track_pick"."n_non_pick_flag" <> 1;
      --print '@nextRackGrp7';
      --print @nextRackGrp;
      if @n_pick_count is null then
        set @n_pick_count = 0
      end if;
      --print @n_pick_count ;
      if @n_pick_count = 0 then
        //    print 'FTRACK_test2';
        delete from "st_track_tray_move"
          where "c_tray_code" = @CurrentTray
          and "c_doc_no" = @DocNo
          and "c_stage_code" = @StageCode
          and "c_godown_code" = @GodownCode;
        commit work
      end if end if;
    if sqlstate = '00000' then
      commit work;
      set @DetSuccessFlag = 1
    else
      rollback work;
      set @DetSuccessFlag = 0
    end if;
    -- for tray release<<
    if(select "count"("c_doc_no") from "st_track_det" where("n_complete" = 0) and "c_doc_no" = @DocNo and "c_godown_code" = @GodownCode and "st_track_det"."n_inout" = 0) = 0 then
      --n_complete = 0
      update "st_track_mst"
        set "c_phase_code" = 'PH0002'
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag;
      commit work
    end if;
    if @ItemsInDetail <> 1 then
      set @DetSuccessFlag = 1 --no det data to batch success flag
    end if;
    --print('next tray doc done' + @NextTray);
    if @NextTray is null or "trim"(@NextTray) = '' then -- Normal doc Done 
      if @DetSuccessFlag = 1 then
        select "max"("st_track_pick"."n_seq") as "n_max_seq"
          into @maxSeq from "st_track_pick"
            join "temp_rack_grp_list"
            on "st_track_pick"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
          where "st_track_pick"."c_doc_no" = @DocNo
          and "st_track_pick"."c_stage_code" = @StageCode
          and "st_track_pick"."c_godown_code" = @GodownCode;
        //        select 'Success' as "c_message",@maxSeq as "n_max_seq",@d_auto_complete_tray as "n_auto_complete_tray" for xml raw,elements --vinay added on 16-11-20
        if(select "n_active" from "st_track_module_mst" where "c_code" = 'M00096') = 1 then
          if(select "count"("st_store_stage_det"."c_rack_grp_code") from "st_store_stage_det"
                join "temp_rack_grp_list" on "st_store_stage_det"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
                and "st_store_stage_det"."c_stage_code" = "temp_rack_grp_list"."c_stage_code"
              where "n_tray_exit_flag" = 1 and "st_store_stage_det"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
              and "st_store_stage_det"."c_stage_code" = @StageCode) = 1 then
            select "count"("st_track_det"."c_item_code")
              into @pending_item_cnt from "st_track_det"
                join "temp_rack_grp_list"
                on "st_track_det"."c_rack_grp_code" <> "temp_rack_grp_list"."c_rack_grp_code"
              where "st_track_det"."c_doc_no" = @DocNo
              and "st_track_det"."c_stage_code" = @StageCode
              and "st_track_det"."c_tray_code" = @CurrentTray
              and "st_track_det"."n_complete" = 0
              and "st_track_det"."c_godown_code" = @GodownCode;
            if @pending_item_cnt = 0 then
              update "st_track_tray_move"
                set "n_inout" = 9,
                "c_rack_grp_code" = '-',
                "t_time" = @t_ltime,
                "n_tray_flag" = 0
                where "c_doc_no" = @DocNo
                and "n_inout" = @InOutFlag
                and "c_tray_code" = @CurrentTray
                and "c_stage_code" = @StageCode
                and "c_godown_code" = @GodownCode;
              if "uf_sys_para_setup"('S00211','-','0',1) = 1 then
                if(select "count"("c_doc_no") from "st_track_tray_move" where "c_doc_no" = @DocNo and "n_inout" = 0) = 0 then //check for Last Tray Move
                  if(select "count"("c_doc_no") from "st_track_det" where "c_doc_no" = @DocNo and "n_complete" = 0) = 0 then
                    select "uf_sys_para_setup"('S00211','-','0',2) into @doc_stage_code;
                    if(select "count"("c_code") from "doc_stage_mst" where "c_code" = @doc_stage_code) = 1 then
                      insert into "DBA"."doc_track"( "c_stage_code","c_inv_prefix","n_inv_no","c_dman_code","n_errors","c_note","c_user","d_date","t_time","t_ltime" ) on existing skip values
                        ( @doc_stage_code,@TranPrefix,@TranSrno,'-',0,null,@UserId,"today"(),"now"(),"now"() ) ;
                      if @TranPrefix = 'IS' then
                        insert into "DBA"."doc_track" on existing skip
                          select @doc_stage_code,"c_inv_prefix","n_inv_no",'-',0,null,@UserId,"today"(),"now"(),"now"()
                            from "inv_summary_list_det" where "n_srno" = @TranSrno
                      end if end if end if end if end if;
              //              print 'test8';
              select "c_menu_id" into @stage_list from "ST_TRACK_MODULE_MST" where "C_CODE" = 'M00102' and "n_active" = 1;
              if((select "n_active" from "ST_TRACK_MODULE_MST" where "C_CODE" = 'M00102') = 1 and @StageCode = @stage_list) then
                if(select "count"(distinct "c_stage_code") from "st_track_det" where "c_doc_no" = @DocNo and "n_inout" = @InOutFlag and "c_godown_code" = @GodownCode) = 1 then
                  select 'Success' as "c_message",@maxSeq as "n_max_seq",@d_auto_complete_tray as "n_auto_complete_tray",
                    'Single Store Invoice Bill, Keep tray seperately.' as "c_message_1",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements
                else
                  select 'Success' as "c_message",@maxSeq as "n_max_seq",@d_auto_complete_tray as "n_auto_complete_tray",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements
                end if
              else select 'Success' as "c_message",@maxSeq as "n_max_seq",@d_auto_complete_tray as "n_auto_complete_tray",
                  'Exit Tray code: '+@CurrentTray+'. No items to pick in next RG(s).' as "c_message_1",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements
              end if
            else select 'Success' as "c_message",@maxSeq as "n_max_seq",@d_auto_complete_tray as "n_auto_complete_tray",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements
            end if
          else select 'Success' as "c_message",@maxSeq as "n_max_seq",@d_auto_complete_tray as "n_auto_complete_tray",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements
          end if
        else if @nextRackGrp = '-' then
            if "uf_sys_para_setup"('S00211','-','0',1) = 1 then
              if(select "count"("c_doc_no") from "st_track_tray_move" where "c_doc_no" = @DocNo and "n_inout" = 0) = 0 then //check for Last Tray Move
                if(select "count"("c_doc_no") from "st_track_det" where "c_doc_no" = @DocNo and "n_complete" = 0) = 0 then
                  select "uf_sys_para_setup"('S00211','-','0',2) into @doc_stage_code;
                  if(select "count"("c_code") from "doc_stage_mst" where "c_code" = @doc_stage_code) = 1 then
                    insert into "DBA"."doc_track"( "c_stage_code","c_inv_prefix","n_inv_no","c_dman_code","n_errors","c_note","c_user","d_date","t_time","t_ltime" ) on existing skip values
                      ( @doc_stage_code,@TranPrefix,@TranSrno,'-',0,null,@UserId,"today"(),"now"(),"now"() ) ;
                    if @TranPrefix = 'IS' then
                      insert into "DBA"."doc_track" on existing skip
                        select @doc_stage_code,"c_inv_prefix","n_inv_no",'-',0,null,@UserId,"today"(),"now"(),"now"()
                          from "inv_summary_list_det" where "n_srno" = @TranSrno
                    end if end if end if end if end if;
            select 'Success' as "c_message",@maxSeq as "n_max_seq",@d_auto_complete_tray as "n_auto_complete_tray",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements
          else
            if(select "COUNT"("C_RACK_GRP_CODE") from "ST_TRACK_AUTO_MOVE_CONFIG" where "C_RACK_GRP_CODE" = @nextRackGrp and "N_ACTIVE" = 1 and "n_last_rg_flag" = 1) > 0 then
              if(select "count"("c_doc_no") from "st_track_det" where "c_doc_no" = @DocNo and "c_rack_grp_code" = @nextRackGrp and "c_tray_code" = @CurrentTray and "n_complete" = 0) > 0 then
                select 'Success' as "c_message",@maxSeq as "n_max_seq",@d_auto_complete_tray as "n_auto_complete_tray",
                  'Move Tray Code: '+@CurrentTray+' to RG: '+@nextRackGrp as "c_message_1",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements
              else
                select 'Success' as "c_message",'' as "n_max_seq",@d_auto_complete_tray as "n_auto_complete_tray",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements
              end if end if end if;
          select 'Success' as "c_message",'' as "n_max_seq",@d_auto_complete_tray as "n_auto_complete_tray",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements
        end if
      else select 'Failure' as "c_message",@DocNo as "doc_no",@CurrentTray as "c_tray" for xml raw,elements
      end if
    else set @DetData = '1'+@ColSep+'2'+@ColSep+@RowSep;
      --Print('Det data frm  doc done ' + @DetData);
      --Saneesh For capture Tray Process time 
      call "usp_set_selected_tray"(@UserId,@HdrData_Set_Selected_Tray,@DetData,@RackGrpCode,@StageCode,@GodownCode,@gsBr,@t_preserve_ltime);
      return
    end if when 'item_done' then -----------------------------------------------------------------------
    --called when an item is picked or put back
    --@HdrData
    --1 Tranbrcode~2 TranYear~3 TranPrefix~4 TranSrno~5 ForwardFlag
    --@DetData
    --1 InOutFlag~2 ItemCode~3 BatchNo~4 Seq~5 Qty~6 ReasonCode
    -------HdrData
    --1 Tranbrcode
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @Tranbrcode = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --message 'Tranbrcode '+@Tranbrcode type warning to client;
    --2 TranYear
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @TranYear = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --message 'TranYear '+@TranYear type warning to client;     
    --3 TranPrefix
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @TranPrefix = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --message 'TranPrefix '+@TranPrefix type warning to client; 
    --4 TranSrno
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @TranSrno = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --message 'TranSrno '+string(@TranSrno ) type warning to client;                    
    --5 ForwardFlag
    /*          
0 - shift back, 
1 - item done, 
2 - item not found
3 - shift back when item not found 
*/
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @ForwardFlag = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --message 'ForwardFlag '+string(@ForwardFlag ) type warning to client;                      
    set @DocNo = @Tranbrcode+'/'+@TranYear+'/'+@TranPrefix+'/'+"string"(@TranSrno);
    --DetData--------------
    --1 InOutFlag~2 ItemCode~3 BatchNo~4 Seq~5 PickedQty~6 ReasonCode
    --1 InOutFlag
    select "Locate"(@DetData,@ColSep) into @ColPos;
    set @InOutFlag = "Trim"("Left"(@DetData,@ColPos-1));
    set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
    --message 'InOutFlag '+@InOutFlag type warning to client;
    --2 ItemCode
    select "Locate"(@DetData,@ColSep) into @ColPos;
    set @ItemCode = "Trim"("Left"(@DetData,@ColPos-1));
    set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
    --message 'ItemCode '+@ItemCode type warning to client;
    --3 BatchNo
    select "Locate"(@DetData,@ColSep) into @ColPos;
    set @BatchNo = "Trim"("Left"(@DetData,@ColPos-1));
    set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
    --message 'BatchNo '+@BatchNo type warning to client;       
    --4 Seq
    select "Locate"(@DetData,@ColSep) into @ColPos;
    set @Seq = "Trim"("Left"(@DetData,@ColPos-1));
    set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
    --message 'Seq '+@Seq type warning to client;       
    --5 PickedQty
    select "Locate"(@DetData,@ColSep) into @ColPos;
    set @PickedQty = "Trim"("Left"(@DetData,@ColPos-1));
    set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
    --message 'Seq '+@Seq type warning to client;       
    --6 ReasonCode              
    select "Locate"(@DetData,@ColSep) into @ColPos;
    set @ReasonCode = "Trim"("Left"(@DetData,@ColPos-1));
    set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
    --message 'ReasonCode '+@ReasonCode type warning to client; 
    if @ForwardFlag = 1 then -- item done
      select(if("n_bal_qty"-@PickedQty) < 0 then 0 else("n_bal_qty"-@PickedQty) endif)
        into @RemainingQty from "st_track_det"
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "c_item_code" = @ItemCode
        and "n_seq" = @Seq
        and "st_track_det"."c_godown_code" = @GodownCode;
      update "st_track_det"
        set "n_complete" = (if @RemainingQty = 0 then @ForwardFlag else 0 endif),
        "n_bal_qty" = @RemainingQty
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "c_item_code" = @ItemCode
        and "n_seq" = @Seq
        and "st_track_det"."c_godown_code" = @GodownCode
    --and c_batch_no = @BatchNo;                        
    elseif @ForwardFlag = 0 then -- shift back, 
      update "st_track_det"
        set "n_complete" = @ForwardFlag,
        "n_bal_qty" = ("n_bal_qty"+@PickedQty)
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "c_item_code" = @ItemCode
        and "n_seq" = @Seq
        and "st_track_det"."c_godown_code" = @GodownCode
    elseif @ForwardFlag = 2 then -- item not found
      update "st_track_det"
        set "n_complete" = @ForwardFlag,
        "c_reason_code" = @ReasonCode
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "c_item_code" = @ItemCode
        and "n_seq" = @Seq
        and "st_track_det"."c_godown_code" = @GodownCode
    elseif @ForwardFlag = 3 then -- shift back when item not found 
      update "st_track_det"
        set "n_complete" = 0
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "c_item_code" = @ItemCode
        and "n_seq" = @Seq
        and "st_track_det"."c_godown_code" = @GodownCode
    end if;
    if sqlstate = '00000' then
      commit work;
      select 'Success' as "c_message" for xml raw,elements
    else
      rollback work;
      select 'Failure' as "c_message" for xml raw,elements
    end if when 'free_trays' then -----------------------------------------------------------------------
    --http://192.168.7.12:13000/ws_st_stock_removal?gsbr=000&devID=GajananPC[192.168.7.12]&sKEY=KEY&UserId=MYBOSS&PhaseCode=PH0001&RackGrpcode=-**&StageCode=SS0001&cindex=free_trays&Hdrdata=&DetData=
    select distinct top 50 "a"."c_code" as "c_tray",
      "a"."c_name" as "c_tray_name"
      from "st_tray_mst" as "a"
        join "st_tray_type_mst" as "c" on "a"."c_tray_type_code" = "c"."c_code"
        left outer join "st_track_in" as "b" on "a"."c_code" = "b"."c_tray_code"
        left outer join "st_track_tray_move" as "d" on "a"."c_code" = "d"."c_tray_code"
      where "b"."c_tray_code" is null and "d"."c_tray_code" is null
      and "a"."n_in_out_flag" in( 1,2,3 ) 
      and "a"."n_cancel_flag" = 0
      and "c"."n_cancel_flag" = 0
      and "a"."c_code" like @HdrData+'%' for xml raw,elements
  when 'cache_items' then -----------------------------------------------------------------------
    set @RackGrpList = @RackGrpCode;
    while @RackGrpList <> '' loop
      --1 RackGrpList
      --RackGrpList = RG0001**RG0002**__
      select "Locate"(@RackGrpList,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@RackGrpList,@ColPos-1));
      set @RackGrpList = "SubString"(@RackGrpList,@ColPos+@ColMaxLen);
      if(select "COUNT"("C_CODE") from "RACK_GROUP_MST" where "C_CODE" = @tmp) > 0 then --valid rack group selection 
        select "n_pos_seq" into @Seq from "st_store_stage_det" where "c_rack_grp_code" = @tmp;
        insert into "temp_rack_grp_list"( "c_rack_grp_code","c_stage_code","n_seq" ) values( @tmp,@StageCode,@Seq ) 
      end if
    end loop;
    select "cache_list"."c_doc_no" as "c_doc_no",
      "cache_list"."n_inout" as "n_inout",
      "cache_list"."c_item_code" as "c_item_code",
      "cache_list"."c_batch_no" as "c_batch_no",
      "cache_list"."n_seq" as "n_seq",
      "cache_list"."n_qty" as "n_qty",
      "cache_list"."n_bal_qty" as "n_bal_qty",
      "cache_list"."c_note" as "c_note",
      "cache_list"."c_rack" as "c_rack",
      "cache_list"."c_rack_grp_code" as "c_rack_grp_code",
      "cache_list"."c_stage_code" as "c_stage_code",
      "cache_list"."n_complete" as "n_complete",
      "cache_list"."c_reason" as "c_reason",
      "cache_list"."n_hold_flag" as "n_hold_flag",
      "cache_list"."c_tray_code" as "c_tray_code",
      "cache_list"."c_item_name" as "c_item_name",
      "cache_list"."c_pack_name" as "c_pack_name",
      "cache_list"."c_rack_name" as "c_rack_name",
      "cache_list"."d_exp_dt" as "d_exp_dt",
      "cache_list"."n_mrp" as "n_mrp",
      "cache_list"."c_tray_name" as "c_tray_name",
      "cache_list"."n_qty_per_box" as "n_qty_per_box",
      "cache_list"."c_message" as "c_message",
      "cache_list"."n_inner_pack_lot" as "n_inner_pack_lot",
      "cache_list"."t_time",
      "cache_list"."n_urgent" as "n_urgent",
      "cache_list"."pack_indicator" as "pack_indicator"
      from(select "st_track_det"."c_doc_no" as "c_doc_no",
          "st_track_det"."n_inout" as "n_inout",
          "item_mst"."c_code" as "c_item_code",
          "isnull"("stock"."c_batch_no",'') as "c_batch_no",
          "st_track_det"."n_seq" as "n_seq",
          "TRIM"("STR"("TRUNCNUM"("st_track_det"."n_qty",3),10,0)) as "n_qty",
          "TRIM"("STR"("TRUNCNUM"("st_track_det"."n_bal_qty",3),10,0)) as "n_bal_qty",
          "st_track_det"."c_note" as "c_note",
          "st_track_det"."c_rack" as "c_rack",
          "st_track_det"."c_rack_grp_code" as "c_rack_grp_code",
          "st_track_det"."c_stage_code" as "c_stage_code",
          "st_track_det"."n_complete" as "n_complete",
          "st_track_det"."c_reason_code" as "c_reason",
          "st_track_det"."n_hold_flag" as "n_hold_flag",
          "st_track_det"."c_tray_code" as "c_tray_code",
          "item_mst"."c_name"+"uf_st_get_pack_name"("pack_mst"."c_name") as "c_item_name",
          "pack_mst"."c_name" as "c_pack_name",
          "rack_mst"."c_name" as "c_rack_name",
          "isnull"("stock"."d_expiry_date",'') as "d_exp_dt",
          "TRIM"("STR"("TRUNCNUM"("stock"."n_mrp",3),10,3)) as "n_mrp",
          "st_tray_mst"."c_name" as "c_tray_name",
          1 as "n_qty_per_box",
          '' as "c_message",
          0 as "n_inner_pack_lot",
          "st_track_tray_move"."t_time" as "t_time",
          "st_track_mst"."n_urgent" as "n_urgent",
          "isnull"((select "max"("WIN_MEET_TYPE"."C_SH_NAME")
            from "win_meet_type","win_meet_note"
            where "WIN_MEET_TYPE"."C_CODE" = "win_meet_note"."C_NOTE_TYPE" and "c_note" is not null
            and "win_meet_note"."c_win_name" = 'w_item_mst'
            and "win_meet_note"."C_NOTE_type" in( 'NTI001','NTI002','NTI003','NTI004' ) 
            and "trim"("win_meet_note"."C_KEY") = "st_track_det"."c_item_code"),'') as "pack_indicator"
          from "st_track_det"
            join "st_track_mst" on "st_track_det"."c_doc_no" = "st_track_mst"."c_doc_no"
            and "st_track_det"."n_inout" = "st_track_mst"."n_inout"
            join "item_mst" on "st_track_det"."c_item_code" = "item_mst"."c_code"
            join "pack_mst" on "pack_mst"."c_code" = "item_mst"."c_pack_code"
            join "rack_mst" on "rack_mst"."c_code" = "item_mst"."c_rack_code"
            join "stock" on "stock"."c_item_code" = "st_track_det"."c_item_code"
            and "stock"."c_batch_no" = "st_track_det"."c_batch_no"
            join "temp_rack_grp_list" as "user_grp" on "st_track_det"."c_rack_grp_code" = "user_grp"."c_rack_grp_code"
            left outer join "st_track_pick" on "st_track_det"."c_doc_no" = "st_track_pick"."c_doc_no"
            and "st_track_det"."n_inout" = "st_track_pick"."n_inout"
            and "st_track_det"."n_seq" = "st_track_pick"."n_org_seq"
            and "st_track_det"."c_rack_grp_code" = "st_track_pick"."c_rack_grp_code"
            and "st_track_det"."c_stage_code" = "st_track_pick"."c_stage_code"
            and "st_track_det"."c_godown_code" = "st_track_pick"."c_godown_code"
            left outer join "st_tray_mst" on "st_tray_mst"."c_code" = "st_track_det"."c_tray_code"
            left outer join "st_track_tray_move" on "st_track_tray_move"."c_doc_no" = "st_track_det"."c_doc_no"
            and "st_track_tray_move"."c_stage_code" = "st_track_det"."c_stage_code"
            and "st_track_tray_move"."c_rack_grp_code" = "st_track_det"."c_rack_grp_code"
            and "st_track_tray_move"."n_inout" = "st_track_det"."n_inout"
          where "st_track_det"."n_complete" = 0
          and "st_track_det"."c_godown_code" = @GodownCode
          and(select "count"("st_track_det"."c_item_code") from "st_track_det"
            where "st_track_det"."c_godown_code" = @GodownCode
            and "st_track_det"."c_rack_grp_code" = @tmp
            and "st_track_det"."n_complete" = 0) > 0
          and "st_track_mst"."n_complete" = 0 and "st_track_det"."n_non_pick_flag" = 0
          and "st_track_mst"."n_confirm" = 1
          and "st_track_pick"."c_doc_no" is null) as "cache_list"
      order by "cache_list"."t_time" asc,"cache_list"."n_urgent" desc,"cache_list"."t_time" asc,"cache_list"."c_doc_no" asc for xml raw,elements
  when 'change_tray' then -----------------------------------------------------------------------
    --@HdrData  : 1 OldTray~2 NewTray
    --1 OldTray
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @OldTray = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --2 NewTray
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @NewTray = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --set @DocNo = @Tranbrcode+'/'+@TranYear+'/'+@TranPrefix+'/'+string(@TranSrno);
    select top 1 "c_doc_no","c_stage_code","count"("a"."c_tray_code")
      into @AssignedDocNo,@AssignedStageCode,@TrayExistsInTrackMove
      from "st_track_det" as "a"
      where "a"."c_tray_code" = @NewTray
      and "a"."n_complete" not in( 2,9,8 ) 
      group by "c_doc_no","c_stage_code";
    if(select "count"("c_code") from "st_tray_mst" where "c_code" = @NewTray) = 0 then
      select 'Warning! : Tray '+@NewTray+' Not Found' as "c_message" for xml raw,elements;
      return
    end if;
    if @TrayExistsInTrackMove > 0 then
      select 'Warning ! : Tray already exists for Document '+@AssignedDocNo+', at stage : '+@AssignedStageCode as "c_message" for xml raw,elements;
      return
    end if;
    select top 1 "c_doc_no"
      into @DocNo from "st_track_tray_move"
      where "c_tray_code" = @OldTray
      and "n_flag" <= 3;
    if @DocNo is null or "trim"(@DocNo) = '' then
      select 'Tray cannot be Changed after barcoding stage !!' as "c_message" for xml raw,elements;
      return
    end if;
    if(select "count"() from "st_track_tray_move" where "c_tray_code" = @NewTray) > 0 then
      select 'Tray Code '+@CurrentTray+' is already Assigned to Document '+"c_doc_no" as "c_message" from "st_track_tray_move"
        where "c_tray_code" = @CurrentTray for xml raw,elements;
      return
    end if;
    if(select "count"() from "st_tray_mst" where "c_code" = @NewTray and "n_in_out_flag" = 0) > 0 then
      select 'External Tray cannot use for Picking !! ' as "c_message" for xml raw,elements;
      return
    end if;
    update "st_track_det"
      set "c_tray_code" = @NewTray
      where "c_doc_no" = @DocNo
      and "c_tray_code" = @OldTray
      and "c_godown_code" = @GodownCode;
    update "st_track_pick"
      set "c_tray_code" = @NewTray
      where "c_doc_no" = @DocNo
      and "c_tray_code" = @OldTray
      and "c_godown_code" = @GodownCode;
    update "st_track_tray_move"
      set "c_tray_code" = @NewTray
      where "c_doc_no" = @DocNo
      and "c_tray_code" = @OldTray
      and "c_godown_code" = @GodownCode;
    if sqlstate = '00000' then
      commit work;
      select 'Success' as "c_message" for xml raw,elements
    else
      rollback work;
      select 'Failure' as "c_message" for xml raw,elements
    end if when 'tray_full_validate' then -----------------------------------------------------------------------
    --@HdrData  : 1 Traycode~2 docno 3@StageCode
    --1 OldTray
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @OldTray = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --2 NewTray
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @DocNo = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --3 NewTray
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @StageCode = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    select "isnull"("count"(),0) as "pick_item_count" from "st_track_pick"
      where "c_doc_no" = @DocNo
      and "c_tray_code" = @OldTray
      and "c_stage_code" = @StageCode for xml raw,elements
  when 'reason_mst' then -----------------------------------------------------------------------
    --http://192.168.7.12:14013/ws_st_stock_removal?devID=DEVID&sKEY=KEY&UserId=MYBOSS&PhaseCode=PH0001&RackGrpcode=RG0001**__&StageCode=SS0001&cindex=reason_mst&Hdrdata=
    select "reason_mst"."c_name" as "c_name",
      "reason_mst"."c_code" as "c_code"
      from "reason_mst"
      where "reason_mst"."n_type" in( 11 ) for xml raw,elements
  when 'batch_reason' then -----------------------------------------------------------------------
    --http://192.168.7.12:14013/ws_st_stock_removal?devID=DEVID&sKEY=KEY&UserId=MYBOSS&PhaseCode=PH0001&RackGrpcode=RG0001**__&StageCode=SS0001&cindex=reason_mst&Hdrdata=
    select "reason_mst"."c_name" as "c_name",
      "reason_mst"."c_code" as "c_code"
      from "reason_mst"
      where "reason_mst"."n_type" in( 12 ) for xml raw,elements
  when 'set_tray_complete' then -----------------------------------------------------------------------
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @DocNo = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --2 @InOutFlag
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @InOutFlag = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --3 @StageCode
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @StageCode = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --4 @CurrentTray
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @CurrentTray = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    if @CurrentTray is null or "trim"(@CurrentTray) = '' then
      select 'Error!! ,Tray Code Required !!' as "c_message" for xml raw,elements;
      return
    end if;
    while @RackGrpCode <> '' loop
      --1 RackGrpList
      select "Locate"(@RackGrpCode,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@RackGrpCode,@ColPos-1));
      set @RackGrpCode = "SubString"(@RackGrpCode,@ColPos+@ColMaxLen);
      --message 'RackGrpList '+@tmp type warning to client;                     
      if(select "COUNT"("C_CODE") from "RACK_GROUP_MST" where "n_lock" = 0 and "C_CODE" = @tmp) > 0 then --valid rack group selection                             
        select "n_pos_seq" into @Seq from "st_store_stage_det" where "c_rack_grp_code" = @tmp;
        insert into "temp_rack_grp_list"( "c_rack_grp_code","c_stage_code","n_seq" ) values( @tmp,@StageCode,@Seq ) 
      end if
    end loop;
    select "c_rack_grp_code"
      into @nextRackGrp from "st_store_stage_det"
      where "c_stage_code" = @StageCode
      and "n_pos_seq"
       = any(select top 1 "n_seq"+1 as "n_seq" from "temp_rack_grp_list"
        order by "n_seq" desc);
    if @nextRackGrp is not null then
      select "Error!!,You can't Mark Tray "+@CurrentTray+" as Auto complete" as "c_message" for xml raw,elements;
      return
    end if;
    select top 1 "c_rack_grp_code"
      into @rackGrp from "st_track_tray_move"
      where "c_doc_no" = @DocNo
      and "n_inout" = @InOutFlag
      and "c_tray_code" = @CurrentTray
      and "c_stage_code" = @StageCode;
    set @t_ltime = "now"();
    set @d_auto_complete_tray = 1;
    update "st_track_tray_move"
      set "n_inout" = 9,"c_rack_grp_code" = '-',"t_time" = @t_ltime,"n_auto_complete_tray" = @d_auto_complete_tray
      where "c_doc_no" = @DocNo
      and "n_inout" = @InOutFlag
      and "c_tray_code" = @CurrentTray
      and "c_stage_code" = @StageCode
      and "c_godown_code" = @GodownCode;
    /*vinay_testing2*/
    if "uf_sys_para_setup"('S00211','-','0',1) = 1 then
      if(select "count"("c_doc_no") from "st_track_tray_move" where "c_doc_no" = @DocNo and "n_inout" = 0) = 0 then //check for Last Tray Move
        if(select "count"("c_doc_no") from "st_track_det" where "c_doc_no" = @DocNo and "n_complete" = 0) = 0 then
          select "uf_sys_para_setup"('S00211','-','0',2) into @doc_stage_code;
          if(select "count"("c_code") from "doc_stage_mst" where "c_code" = @doc_stage_code) = 1 then
            insert into "DBA"."doc_track"( "c_stage_code","c_inv_prefix","n_inv_no","c_dman_code","n_errors","c_note","c_user","d_date","t_time","t_ltime" ) on existing skip values
              ( @doc_stage_code,@TranPrefix,@TranSrno,'-',0,null,@UserId,"today"(),"now"(),"now"() ) ;
            if @TranPrefix = 'IS' then
              insert into "DBA"."doc_track" on existing skip
                select @doc_stage_code,"c_inv_prefix","n_inv_no",'-',0,null,@UserId,"today"(),"now"(),"now"()
                  from "inv_summary_list_det" where "n_srno" = @TranSrno
            end if end if end if end if end if;
    if @nextRackGrp is null then
      select "count"()
        into @n_pick_count from "st_track_pick"
        where "st_track_pick"."c_tray_code" = @CurrentTray
        and "st_track_pick"."c_doc_no" = @DocNo
        and "c_stage_code" = @StageCode
        and "st_track_pick"."c_godown_code" = @GodownCode;
      if @n_pick_count is null then
        set @n_pick_count = 0
      end if;
      if @n_pick_count = 0 then --Release Tray
        //    print 'FTRACK_test4';
        delete from "st_track_tray_move"
          where "c_tray_code" = @CurrentTray
          and "c_doc_no" = @DocNo
          and "c_stage_code" = @StageCode
          and "c_godown_code" = @GodownCode;
        commit work
      end if end if;
    if(select "count"("c_doc_no") from "st_track_det" where("n_complete" = 0) and "c_doc_no" = @DocNo and "c_godown_code" = @GodownCode) = 0 then
      update "st_track_mst"
        set "c_phase_code" = 'PH0002'
        where "c_doc_no" = @DocNo;
      commit work
    end if;
    select 'Success' as "c_message" for xml raw,elements
  when 'get_next_rack_grp' then
    --http://172.16.18.38:16152/ws_st_stock_removal?&cIndex=get_next_rack_grp&HdrData=1006&RackGrpCode=A^^&StageCode=A&GodownCode=-&gsbr=000&devID=ae2a9610228a94aa05012014104741461&sKEY=sKey&UserId=3DS&DocNo=000/16/I/239141
    set @DocNo = "http_variable"('DocNo'); --2
    while @RackGrpCode <> '' loop
      --1 RackGrpList
      select "Locate"(@RackGrpCode,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@RackGrpCode,@ColPos-1));
      set @RackGrpCode = "SubString"(@RackGrpCode,@ColPos+@ColMaxLen);
      --message 'RackGrpList '+@tmp type warning to client;                     
      if(select "COUNT"("C_CODE") from "RACK_GROUP_MST" where "n_lock" = 0 and "C_CODE" = @tmp) > 0 then --valid rack group selection                             
        select "n_pos_seq" into @Seq from "st_store_stage_det" where "c_rack_grp_code" = @tmp;
        insert into "temp_rack_grp_list"( "c_rack_grp_code","c_stage_code","n_seq" ) values( @tmp,@StageCode,@Seq ) 
      end if
    end loop;
    select top 1
      "st_track_det"."c_doc_no",
      "st_track_det"."c_tray_code",
      "st_track_det"."c_rack_grp_code"
      from "st_track_det"
        join "st_store_stage_det" on "st_store_stage_det"."c_rack_grp_code" = "st_track_det"."c_rack_grp_code"
      where "st_track_det"."c_doc_no" = @DocNo
      and "st_track_det"."c_stage_code" = @StageCode
      and "c_godown_code" = @GodownCode
      and if @HdrData is null or "trim"(@HdrData) = '' then
        @HdrData
      else
        "st_track_det"."c_tray_code"
      endif = @HdrData
      and "st_store_stage_det"."c_rack_grp_code" = any(select "c_rack_grp_code" from "temp_rack_grp_list")
      order by "st_store_stage_det"."n_pos_seq" asc for xml raw,elements
  when 'validate_check_id' then -----------------------------------------------------------------------
    --http://172.16.18.26:16201/ws_st_stock_removal?devID=DEVID&sKEY=KEY&UserId=MYBOSS&PhaseCode=PH0001&RackGrpcode=RG0001**__&StageCode=SS0001&cindex=validate_check_id&Hdrdata=100^^1^^
    --@HdrData  : 1 i_id ~2 c_val
    --1 @n_chk_id 
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @n_chk_id = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --2 c_val
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @c_val = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    while @RackGrpCode <> '' loop
      --1 RackGrpList
      select "Locate"(@RackGrpCode,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@RackGrpCode,@ColPos-1));
      set @RackGrpCode = "SubString"(@RackGrpCode,@ColPos+@ColMaxLen);
      --message 'RackGrpList '+@tmp type warning to client;                     
      if(select "COUNT"("C_CODE") from "RACK_GROUP_MST" where "n_lock" = 0 and "C_CODE" = @tmp) > 0 then --valid rack group selection                             
        select "n_pos_seq" into @Seq from "st_store_stage_det" where "c_rack_grp_code" = @tmp;
        insert into "temp_rack_grp_list"( "c_rack_grp_code","c_stage_code","n_seq" ) values( @tmp,@StageCode,@Seq ) 
      end if
    end loop;
    select "c_rack_grp_code"
      into @nextRackGrp from "st_store_stage_det"
      where "c_stage_code" = @StageCodeselect
      and "n_pos_seq"
       = any(select top 1 "n_seq"+1 as "n_seq" from "temp_rack_grp_list"
        order by "n_seq" desc);
    if @nextRackGrp is not null then
      select 'Error!!,You cannot Mark Tray as Auto complete' as "n_active" for xml raw,elements;
      return
    end if;
    select "uf_get_validate_check_id"(@n_chk_id,@c_val) as "n_active" for xml raw,elements
  when 'allow_request_for_godown_pick' then
    set @gdn_item_code = "http_variable"('item_code');
    set @gdn_batch_no = "http_variable"('batch');
    set @req_quantity = "http_variable"('qty');
    set @doc_no = "http_variable"('docno');
    select "n_balance_qty","n_godown_qty" into @bal_qty,@gdn_qty from "stock" where "c_item_code" = @gdn_item_code
      and "c_batch_no" = @gdn_batch_no;
    --print '@bal_qty';
    --print @bal_qty;
    -- if (200 < (200+200)-300 or 
    //if(@req_quantity < ((@bal_qty+@req_quantity)-@gdn_qty) or @req_quantity > @gdn_qty) or @GodownCode <> '-' or(select "count"() from "st_track_pick" where "c_doc_no" = @doc_no and "c_item_code" = @gdn_item_code and "c_batch_no" = @gdn_batch_no) > 0 then
    if(@req_quantity > ((@bal_qty+@req_quantity)-@gdn_qty) or @req_quantity > @gdn_qty) or @GodownCode <> '-' or(select "count"() from "st_track_pick" where "c_doc_no" = @doc_no and "c_item_code" = @gdn_item_code and "c_batch_no" = @gdn_batch_no) > 0 then
      select 0 as "ALLOW_REQUEST_FOR_GODOWN_PICK",'Warning!! : You dont have enough  stock to move' as "c_message" for xml raw,elements //NOT ALLOWED 
    else
      select 1 as "ALLOW_REQUEST_FOR_GODOWN_PICK",'Warning!! : Moving the document into Godown' as "c_message" for xml raw,elements
    --end if
    end if when 'get_hold_stage_items' then
    set @RackGrpList = @RackGrpCode;
    while @RackGrpList <> '' loop
      --1 RackGrpList
      --RackGrpList = RG0001**RG0002**__
      select "Locate"(@RackGrpList,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@RackGrpList,@ColPos-1));
      set @RackGrpList = "SubString"(@RackGrpList,@ColPos+@ColMaxLen);
      if(select "COUNT"("C_CODE") from "RACK_GROUP_MST" where "C_CODE" = @tmp) > 0 then --valid rack group selection 
        select "n_pos_seq" into @Seq from "st_store_stage_det" where "c_rack_grp_code" = @tmp;
        insert into "temp_rack_grp_list"( "c_rack_grp_code","c_stage_code","n_seq" ) values( @tmp,@StageCode,@Seq ) 
      end if
    end loop;
    select "st_track_det"."c_item_code" as "c_item_code",
      "item_mst"."c_name" as "item_name",
      "pack_mst"."c_name" as "pack",
      "st_track_det"."c_rack" as "c_rack_code",
      "st_track_det"."c_rack_grp_code" as "c_group",
      "reverse"("left"("reverse"("st_track_det"."c_doc_no"),"charindex"('/',"reverse"("st_track_det"."c_doc_no"))-1)) as "c_doc_no",
      "isnull"("st_track_det"."c_tray_code",'') as "c_tray_code",
      "st_track_det"."n_seq" as "n_seq",
      "st_track_det"."c_batch_no" as "c_batch_no",
      "st_track_det"."n_qty" as "n_qty",
      "stock"."n_mrp" as "n_mrp"
      from "st_track_det" join "temp_rack_grp_list" on "st_track_det"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
        and "st_track_det"."c_stage_code" = "temp_rack_grp_list"."c_stage_code"
        join "item_mst" on "st_track_det"."c_item_code" = "item_mst"."c_code"
        join "pack_mst" on "item_mst"."c_pack_code" = "pack_mst"."c_code"
        left outer join "stock" on "st_track_det"."c_item_code" = "stock"."c_item_code"
        and "st_track_det"."c_batch_no" = "stock"."c_batch_no"
      where "st_track_det"."n_complete" = 0 and "st_track_det"."n_inout" = 0 for xml raw,elements
  when 'Get_setup' then -----------------------------------------------------------------------
    call "uf_get_module_mst_value_multi"(@HdrData,@ColPos,@ColMaxLen,@ColSep);
    return
  end case
end;
COMMIT WORK;
GO
