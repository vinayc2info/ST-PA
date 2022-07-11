
CREATE PROCEDURE "DBA"."usp_set_selected_tray_exit"( 
  ---------------------------------set_selected_tray----------------------------------------------
  in @UserId char(20),
  in @HdrData char(8000),
  in @DetData char(32767),
  in @RackGrpCode char(8000),
  in @StageCode char(10),
  in @GodownCode char(10),
  in @gsBr char(10),
  in @t_preserve_ltime char(25) ) 
result( "is_xml_string" xml ) 
/*
Author  : Vinay Kumar S
Date    : 
Purpose: set_selected_tray
Input   : @UserId ,@HdrData,@DetData , @RackGrpCode , @StageCode , @GodownCode , @gsBr 
Output  : if TrayUpdate  --> 1 ,Item List for that Tray  
: if TrayUpdate --> 0 ,success flag  
Used In : usp_st_stock_removal 
:
*/
begin
  --TrayUpdate --> 1 Update Traymove ,det .. 
  --TrayUpdate --> 0 Just Validate the Tray in case of TrayFull
  --common >>
  declare @urgent_flag_checking numeric(4);
  declare @urg_tray_cnt numeric(6);
  declare @urnt_tray_exist numeric(6);
  declare @mapped_tray_count numeric(6);
  declare @next_stage char(6);
  declare @enable_log numeric(1);
  declare @nextRackGrp char(6);
  declare @cnt integer;
  declare @BrCode char(6);
  declare @t_ltime char(25);
  declare @t_tray_move_time char(25);
  declare @d_ldate char(20);
  declare @nSingleUser integer;
  declare @nUserValid integer;
  declare @RackGrpList char(7000);
  declare @InOutFlag numeric(1);
  declare @ColSep char(6);
  declare @RowSep char(6);
  declare @Pos integer;
  declare @ColPos integer;
  declare @RowPos integer;
  declare @ColMaxLen numeric(4);
  declare @RowMaxLen numeric(4);
  declare @FirstInStage numeric(1);
  declare @TrayUpdate numeric(1);
  declare @tmp char(20);
  declare @tmp_rg char(20);
  declare @Seq numeric(6);
  declare local temporary table "temp_rack_grp_list"(
    "c_rack_grp_code" char(6) null, --common <<
    "c_stage_code" char(6) null, --cIndex set_selected_tray >>
    "n_seq" numeric(6) null,) on commit preserve rows;
  declare @LoginTime timestamp;
  declare @ActionStart timestamp;
  declare @cUser char(20);
  declare @DocNo char(32);
  declare @StartGrp char(6);
  declare @CurrentGrp char(6);
  declare @EndGrp char(6);
  declare @TranBrCode char(6);
  declare @TranPrefix char(4);
  declare @TranYear char(2);
  declare @TranSrno numeric(18);
  declare @CurrentTray char(20);
  declare @ValidateTray numeric(1);
  declare @TrayExistsInRackGrp integer;
  declare @TrayExistsInTrackMove integer;
  declare @Tray_in_pick_list char(5000);
  declare @DocInTrackMove char(32);
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
  declare @nTrayFull integer;
  declare @preserve_tray_full numeric(1);
  declare @hdr_data varchar(32767);
  declare @hdr_det varchar(32767);
  declare @log_seq numeric(30);
  declare @stage_seq numeric(5);
  set @hdr_data = @HdrData;
  set @hdr_det = @DetData;
  --cIndex set_selected_tray <<
  set @nTrayFull = 0;
  --gargee 
  --set @enable_log = 0;
  select "n_active" into @enable_log from "st_track_module_mst" where "st_track_module_mst"."c_code" = 'M00039' and "st_track_module_mst"."c_br_code" = @gsBr;
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
  set @d_ldate = "uf_default_date"();
  select "n_flag" into @nSingleUser from "st_store_stage_mst" where "c_code" = @StageCode;
  select top 1 "t_login_time","t_action_start" into @LoginTime,@ActionStart from "st_store_login" where "c_user_id" = @UserId order by "t_login_time" desc;
  if(@LoginTime is not null) and(@ActionStart is null) then
    update "st_store_login" set "t_action_start" = @t_ltime
      where "c_user_id" = @UserId
      and "t_login_time" = @LoginTime;
    commit work
  end if;
  --HdrData
  --1 Tranbrcode~2 TranYear~3 TranPrefix~4 TranSrno~5 CurrentTray~6 FirstInStage~7 OldTray
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
  --5 CurrentTray
  select "Locate"(@HdrData,@ColSep) into @ColPos;
  set @CurrentTray = "Trim"("Left"(@HdrData,@ColPos-1));
  set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
  --message 'CurrentTray '+@CurrentTray type warning to client
  --6 FirstInStage (1/0)
  select "Locate"(@HdrData,@ColSep) into @ColPos;
  set @FirstInStage = "Trim"("Left"(@HdrData,@ColPos-1));
  set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
  --message 'FirstInStage '+@FirstInStage type warning to client
  --7 OldTray
  select "Locate"(@HdrData,@ColSep) into @ColPos;
  set @OldTray = "Trim"("Left"(@HdrData,@ColPos-1));
  set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
  --message 'OldTray '+@OldTray type warning to client
  --8 nVerifyDocUser
  select "Locate"(@HdrData,@ColSep) into @ColPos;
  set @nVerifyDocUser = "Trim"("Left"(@HdrData,@ColPos-1));
  set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
  --message 'nVerifyDocUser '+@nVerifyDocUser type warning to client
  --9 nFilterNoBatchItems
  select "Locate"(@HdrData,@ColSep) into @ColPos;
  set @nFilterNoBatchItems = "Trim"("Left"(@HdrData,@ColPos-1));
  set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
  --message 'nFilterNoBatchItems '+@nFilterNoBatchItems type warning to client
  --@DetData : ValidateTray**TrayUpdate**@nTrayFull**__
  --1 ValidateTray
  select "Locate"(@DetData,@ColSep) into @ColPos;
  set @ValidateTray = "Trim"("Left"(@DetData,@ColPos-1));
  set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
  --1 TrayUpdate
  select "Locate"(@DetData,@ColSep) into @ColPos;
  set @TrayUpdate = cast("Trim"("Left"(@DetData,@ColPos-1)) as numeric(1));
  set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
  set @DocNo = @Tranbrcode+'/'+@TranYear+'/'+@TranPrefix+'/'+"string"(@TranSrno);
  --message @DocNo type warning to client;
  if @enable_log = 1 then
    insert into "st_doc_done_log"
      ( "c_doc","c_tray","c_stage","c_hdr","c_det","c_rg","n_item_det_flag","t_s_time" ) values
      ( @DocNo,@CurrentTray,@StageCode,@hdr_data,@hdr_det,@RackGrpCode,8,"getdate"() ) ;
    commit work;
    set @log_seq = @@identity
  end if;
  set @RackGrpList = @RackGrpCode;
  while @RackGrpList <> '' loop
    --RackGrpList = RG0001**RG0002**__
    select "Locate"(@RackGrpList,@ColSep) into @ColPos;
    set @tmp = "Trim"("Left"(@RackGrpList,@ColPos-1));
    set @RackGrpList = "SubString"(@RackGrpList,@ColPos+@ColMaxLen);
    if(select "COUNT"("C_CODE") from "RACK_GROUP_MST" where "C_CODE" = @tmp) > 0 then --valid rack group selection 
      select "n_pos_seq" into @Seq from "st_store_stage_det" where "c_rack_grp_code" = @tmp and "st_store_stage_det"."c_stage_code" = @StageCode;
      insert into "temp_rack_grp_list"( "c_rack_grp_code","c_stage_code","n_seq" ) values( @tmp,@StageCode,@Seq ) 
    end if
  end loop;
  if @nSingleUser = 0 then
    select top 1 "st_track_det"."c_tray_code","c_user"
      into @cTrayAssigned,@cDocAlreadyAssignedToUser
      from "st_track_det"
        join "temp_rack_grp_list" --(select 'A' as c_rack_grp_code, 'S00002' as c_stage_code, 1 as n_seq )
        on "temp_rack_grp_list"."c_rack_grp_code" = "st_track_det"."c_rack_grp_code"
        and "temp_rack_grp_list"."c_stage_code" = "st_track_det"."c_stage_code"
      where "c_doc_no" = @DocNo --'109/14/S/146117'--
      and "st_track_det"."c_stage_code" = @StageCode --'s00002'--
      and "st_track_det"."c_godown_code" = @GodownCode;
    select top 1 "c_tray_code","c_doc_no"
      into @UnprocessedTray,@UnprocessedDoc
      from "st_track_det"
      where "c_user" = @UserId
      and "n_complete" = 0
      and "c_stage_code" = @StageCode
      and "st_track_det"."c_godown_code" = @GodownCode
      and "n_inout" = 0;
    if @UnprocessedTray is not null and @UnprocessedDoc <> @DocNo then
      select 'Warning! : Please Process the Pending document : '+@UnprocessedDoc+' with Tray : '+"string"(@UnprocessedTray) as "c_message" for xml raw,elements;
      return
    end if;
    select top 1 "c_tray_code","c_doc_no"
      into @UnmovedTray,@UnprocessedDoc
      from "st_track_tray_move"
        join "temp_rack_grp_list" on "st_track_tray_move"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
        and "st_track_tray_move"."c_stage_code" = "temp_rack_grp_list"."c_stage_code"
      where "c_user" = @UserId
      and "n_inout" <> 9
      and "st_track_tray_move"."c_godown_code" = @GodownCode
      order by "t_time" desc;
    if @UnmovedTray is not null and @UnprocessedDoc <> @DocNo then
      select 'Warning! : Please Process the Pending document : '+@UnprocessedDoc+' with Tray : '+"string"(@UnmovedTray) as "c_message" for xml raw,elements;
      return
    end if;
    if @cTrayAssigned is not null and @UserId <> @cDocAlreadyAssignedToUser then
      select 'Warning! : Document '+"string"(@DocNo)+' Already assigned to : '+"string"(@cDocAlreadyAssignedToUser)+' with Tray : '+"string"(@cTrayAssigned) as "c_message" for xml raw,elements;
      return
    elseif @nVerifyDocUser = 1 then
      select 'Success' as "c_message" for xml raw,elements;
      return
    end if end if;
  if(select "count"("c_code") from "st_tray_mst" where "c_code" = @CurrentTray) = 0 then
    select 'Warning! : Tray Not Found' as "c_message" for xml raw,elements;
    return
  end if;
  if(select "count"() from "st_tray_mst" where "c_code" = @CurrentTray and "n_in_out_flag" = 0) > 0 then
    select 'External Tray cannot use for Picking !! ' as "c_message" for xml raw,elements;
    return
  end if;
  --gargee 
  select "count"("c_tray_code") into @mapped_tray_count from "st_track_tray_stage_mapping" where "c_tray_code" = @CurrentTray and "c_stage_code" = @StageCode;
  select "n_urgent" into @urgent_flag_checking from "st_track_mst" where "c_doc_no" = @DocNo and "n_inout" = 0;
  if @mapped_tray_count > 0 then --'allow to assign'
  else
    if(select "count"("c_tray_code") from "st_track_tray_stage_mapping" where "c_stage_code" = @StageCode) > 0 then
      select 'Warning! : Tray Not Allowed To Assign 2 ' as "c_message" for xml raw,elements;
      return
    else
      if(select "count"("c_tray_code") from "st_track_tray_stage_mapping" where "c_tray_code" = @CurrentTray and "c_stage_code" <> @StageCode) > 0 then
        select 'Warning! : Tray Not Allowed To Assign' as "c_message" for xml raw,elements;
        return
      end if end if end if;
  if @urgent_flag_checking = 2 then
    select "count"("c_tray_code") into @urg_tray_cnt from "st_urgent_tray_mapping";
    if @urg_tray_cnt >= 1 then
      select "count"("c_tray_code") into @urnt_tray_exist from "st_urgent_tray_mapping" where "c_tray_code" = @CurrentTray and "n_active" = 1;
      if @urnt_tray_exist <> 1 then
        select 'Warning! : Please use Urgent Tray' as "c_message" for xml raw,elements;
        return
      end if end if end if; --urgent_flag_checking done 
  if(select "count"("st_tray_mst"."c_code") from "st_tray_mst" join "st_tray_type_mst" on "st_tray_mst"."c_tray_type_code" = "st_tray_type_mst"."c_code" where "st_tray_mst"."c_code" = @CurrentTray and "st_tray_mst"."n_cancel_flag" = 0 and "st_tray_type_mst"."n_cancel_flag" = 0) = 0 then
    select '' as "c_doc_no",'' as "n_inout",'' as "c_item_code",'' as "c_batch_no",'' as "n_seq",'' as "n_qty",'' as "n_bal_qty",'' as "c_note",
      '' as "c_rack",'' as "c_rack_grp_code",'' as "c_stage_code",'' as "n_complete",'' as "c_reason",'' as "n_hold_flag",'' as "c_tray_code",
      '' as "c_item_name",'' as "c_pack_name",'' as "c_rack_name",'' as "d_exp_dt",'' as "n_mrp",'' as "c_tray_name",
      'Warning! : Tray '+"string"("st_tray_mst"."c_name"+'['+"st_tray_mst"."c_code"+']')+' is  Locked' as "c_message"
      from "st_tray_mst"
      where "st_tray_mst"."c_code" = @CurrentTray
      and "n_cancel_flag" = 1 union
    select '' as "c_doc_no",'' as "n_inout",'' as "c_item_code",'' as "c_batch_no",'' as "n_seq",'' as "n_qty",'' as "n_bal_qty",'' as "c_note",'' as "c_rack",
      '' as "c_rack_grp_code",'' as "c_stage_code",'' as "n_complete",'' as "c_reason",'' as "n_hold_flag",'' as "c_tray_code",'' as "c_item_name",
      '' as "c_pack_name",'' as "c_rack_name",'' as "d_exp_dt",'' as "n_mrp",'' as "c_tray_name",
      "string"('Warning! : Tray Type '+"string"("st_tray_type_mst"."c_code")+'for Tray '+"string"("st_tray_mst"."c_name"+'['+"st_tray_mst"."c_code"+']')+' is  Locked') as "c_message"
      from "st_tray_mst"
        join "st_tray_type_mst" on "st_tray_mst"."c_tray_type_code" = "st_tray_type_mst"."c_code"
      where "st_tray_mst"."c_code" = @CurrentTray
      and "st_tray_type_mst"."n_cancel_flag" = 1
      and "st_tray_mst"."n_cancel_flag" = 0 for xml raw,elements;
    return
  end if;
  set @InOutFlag = 0;
  select "count"("a"."c_tray_code")
    into @nTrayAssigned from "st_track_det" as "a"
      join "temp_rack_grp_list" as "b" on "a"."c_rack_grp_code" = "b"."c_rack_grp_code" and "a"."c_stage_code" = "b"."c_stage_code"
    where "a"."c_tray_code" = @CurrentTray
    and "a"."n_complete" not in( 2,9,8 ) 
    and "a"."c_doc_no" = @DocNo;
  if @nTrayAssigned > 0 then
    set @ValidateTray = 0
  end if;
  if @ValidateTray = 1 then
    select "count"("a"."c_tray_code")
      into @TrayExistsInTrackMove from "st_track_det" as "a"
      where "a"."c_tray_code" = @CurrentTray
      and "a"."n_complete" not in( 2,9,8 ) 
  else
    select "count"("a"."c_tray_code")
      into @TrayExistsInTrackMove from "st_track_det" as "a"
      where "a"."c_doc_no" <> @DocNo
      and "a"."c_tray_code" = @CurrentTray
      and "a"."n_complete" not in( 2,9,8 ) 
  end if;
  if @ValidateTray = 1 then
    if(select "count"() from "st_track_tray_move" where "c_tray_code" = @CurrentTray) > 0 then
      select 'Tray Code '+@CurrentTray+' is already Assigned to Document '+"c_doc_no" as "c_message" from "st_track_tray_move"
        where "c_tray_code" = @CurrentTray for xml raw,elements;
      return
    end if end if;
  if(@Tray_in_pick_list) is null or "trim"(@Tray_in_pick_list) = '' then
    set @Tray_in_pick_list = ''
  end if;
  if @Tray_in_pick_list <> '' then
    select '' as "c_doc_no",
      '' as "n_inout",
      '' as "c_item_code",
      '' as "c_batch_no",
      '' as "n_seq",
      '' as "n_qty",
      '' as "n_bal_qty",
      '' as "c_note",
      '' as "c_rack",
      '' as "c_rack_grp_code",
      '' as "c_stage_code",
      '' as "n_complete",
      '' as "c_reason",
      '' as "n_hold_flag",
      '' as "c_tray_code",
      '' as "c_item_name",
      '' as "c_pack_name",
      '' as "c_rack_name",
      '' as "d_exp_dt",
      '' as "n_mrp",
      '' as "c_tray_name",
      '' as "n_qty_per_box",
      '' as "pack_indicator",
      '' as "n_non_pick_flag",
      '' as "n_allow_not_found",
      'Warning! : TrayCode '+@CurrentTray+' Already exists for Document '+@Tray_in_pick_list+'!! ' as "c_message" for xml raw,elements;
    return
  end if;
  if @FirstInStage = 1 or @ValidateTray = 1 then
    if @TrayExistsInTrackMove = 0 then
      update "st_track_det" set "c_tray_code" = @CurrentTray,"c_user" = @UserId
        where("n_complete" = 0 or("n_complete" = 2 and "c_note" = 'AUTO ITEM NOT FOUND'))
        and "c_doc_no" = @DocNo
        and "c_stage_code" = @StageCode
        and "st_track_det"."c_godown_code" = @GodownCode;
      commit work;
      -- select * from st_log_ret
      if @enable_log = 1 then
        insert into "st_log_ret"
          ( "c_doc_no","c_tray","c_stage","c_rg","n_flag","t_time" ) values
          ( @DocNo,@CurrentTray,@StageCode,'set_selected_blank',1,"getdate"() ) ;
        commit work
      end if
    else select top 1 "a"."c_doc_no"
        into @DocInTrackMove from "st_track_det" as "a"
        where "a"."n_inout" = @InOutFlag
        and "a"."c_tray_code" = @CurrentTray
        order by "a"."n_complete" asc;
      --blank return format to match the datawindow
      select '' as "c_doc_no",
        '' as "n_inout",
        '' as "c_item_code",
        '' as "c_batch_no",
        '' as "n_seq",
        '' as "n_qty",
        '' as "n_bal_qty",
        '' as "c_note",
        '' as "c_rack",
        '' as "c_rack_grp_code",
        '' as "c_stage_code",
        '' as "n_complete",
        '' as "c_reason",
        '' as "n_hold_flag",
        '' as "c_tray_code",
        '' as "c_item_name",
        '' as "c_pack_name",
        '' as "c_rack_name",
        '' as "d_exp_dt",
        '' as "n_mrp",
        '' as "c_tray_name",
        '' as "n_qty_per_box",
        '' as "pack_indicator",
        '' as "n_non_pick_flag",
        '' as "n_allow_not_found",
        'Warning! : Tray Already 123 exists for Document '+@DocInTrackMove as "c_message" for xml raw,elements;
      return
    end if end if;
  --TrayUpdate --> 1 Update Traymove ,det .. 
  --TrayUpdate --> 0 Just Validate the Tray in case of TrayFull
  --TrayUpdate --> 2 updt db ,true ret 
  if @TrayUpdate = 0 then
    if(select "count"() from "st_track_tray_move" where "c_tray_code" = @CurrentTray) > 0 then
      if @enable_log = 1 then
        insert into "st_log_ret"
          ( "c_doc_no","c_tray","c_stage","c_rg","n_flag","t_time" ) values
          ( @DocNo,@CurrentTray,@StageCode,'DBL TRAY',3,"getdate"() ) ;
        commit work
      end if;
      select 'Tray Code '+@CurrentTray+' is already Assigned to Document '+"c_doc_no" as "c_message" from "st_track_tray_move"
        where "c_tray_code" = @CurrentTray for xml raw,elements;
      return
    end if;
    --select 'Success'as c_message FOR XML RAW, ELEMENTS;       
    --gargee
    if(select "count"("c_doc_no") from "st_track_tray_move" where "c_tray_code" = @CurrentTray and "n_auto_complete_tray" = 1) > 0 then
      if @enable_log = 1 then
        insert into "st_log_ret"
          ( "c_doc_no","c_tray","c_stage","c_rg","n_flag","t_time" ) values
          ( @DocNo,@CurrentTray,@StageCode,'Emergency Bill',8,"getdate"() ) ;
        commit work
      end if;
      select 'Warning 0 ! : No Items To Remove for Tray '+@CurrentTray as "c_message" for xml raw,elements;
      return
    end if
  elseif @TrayUpdate = 2 then
    select top 1 "t_time"
      into @t_ltime from "st_track_tray_move"
      where "c_tray_code" = @OldTray
      and "st_track_tray_move"."c_godown_code" = @GodownCode;
    //keeep the tay full flag for re inserting 
    select top 1 "n_tray_full_flag"
      into @preserve_tray_full from "st_track_tray_move"
      where "c_tray_code" = @CurrentTray
      and "st_track_tray_move"."c_godown_code" = @GodownCode;
    if(select "count"() from "st_track_tray_move" where "c_tray_code" = @CurrentTray and "st_track_tray_move"."c_godown_code" = @GodownCode) > 0 then
      delete from "st_track_tray_move" where "c_tray_code" = @CurrentTray and "st_track_tray_move"."c_godown_code" = @GodownCode
    end if;
    insert into "st_track_tray_move"
      ( "c_doc_no","n_inout","c_tray_code","c_rack_grp_code","c_stage_code","t_time","c_user",
      "c_godown_code","n_tray_full_flag" ) on existing skip
      select @DocNo,@InOutFlag,@CurrentTray,"c_rack_grp_code",@StageCode,@t_preserve_ltime,@UserId,@GodownCode,@preserve_tray_full
        from "temp_rack_grp_list";
    commit work;
    if sqlstate = '00000' then
      commit work;
      select 'Success' as "c_message" for xml raw,elements;
      return
    else
      rollback work;
      select 'Err' as "c_message" for xml raw,elements;
      return
    end if
  else select top 1 "t_time","n_tray_full_flag"
      into @t_ltime,@preserve_tray_full from "st_track_tray_move"
      where "c_tray_code" = @CurrentTray
      and "st_track_tray_move"."c_godown_code" = @GodownCode;
    select top 1 "c_rack_grp_code" into @tmp_rg from "temp_rack_grp_list";
    call "uf_update_tray_time"(@DocNo,@InOutFlag,@CurrentTray,'PICKING',@UserId,@tmp_rg,@StageCode,1,@t_tray_move_time,0,0);
    if(select "count"() from "st_track_tray_move" where "c_tray_code" = @CurrentTray and "st_track_tray_move"."c_godown_code" = @GodownCode) > 0 then
      delete from "st_track_tray_move" where "c_tray_code" = @CurrentTray and "st_track_tray_move"."c_godown_code" = @GodownCode
    end if;
    select "n_pos_seq" into @stage_seq from "st_store_stage_det" where "c_rack_grp_code" = @tmp and "st_store_stage_det"."c_stage_code" = @StageCode;
    select top 1
      "st_store_stage_mst"."c_code",
      "st_store_stage_det"."c_rack_grp_code"
      into @next_stage,@nextRackGrp
      from "st_store_stage_mst","st_store_stage_det"
      where "st_store_stage_mst"."c_code" = "st_store_stage_det"."c_stage_code" and "st_store_stage_det"."n_pos_seq" > @stage_seq
      and "st_store_stage_mst"."c_godown_code" = @godowncode
      and "st_store_stage_det"."c_stage_code" = @StageCode
      order by "st_store_stage_det"."n_pos_seq" asc;
    -- http://172.16.16.37:18263/ws_st_stock_removal_rkgrp_in_exit?&cIndex=set_selected_tray_exit&HdrData=000^^18^^I^^180007300556698^^10104^^1^^^^0^^1^^&DetData=1^^1^^&RackGrpCode=F0^^&StageCode=PICK&GodownCode=-&gsbr=000&devID=6ab09d3dda14cfb01092018123729784&sKEY=sKey&UserId=C2
    insert into "st_track_tray_move"
      ( "c_doc_no","n_inout","c_tray_code","c_rack_grp_code","c_stage_code","t_time","c_user",
      "c_godown_code","n_tray_full_flag" ) on existing skip
      select @DocNo,@InOutFlag,@CurrentTray,"c_rack_grp_code",@StageCode,@t_ltime,@UserId,@GodownCode,@preserve_tray_full
        from "temp_rack_grp_list";
    commit work;
    update "st_track_tray_move" set "c_rack_grp_code" = @nextRackGrp where "c_doc_no" = @DocNo and "c_tray_code" = @CurrentTray;
    commit work;
    update "st_track_det" set "n_complete" = 2 where "c_doc_no" = @DocNo and "c_tray_code" = @CurrentTray and "c_rack_grp_code" = @tmp and "n_non_pick_flag" = 1;
    commit work;
    call "uf_update_tray_time"(@DocNo,@InOutFlag,@CurrentTray,'PICKING',@UserId,@tmp_rg,@StageCode,2,@t_tray_move_time,0,0); --change by gargee
    select 'Success' as "c_message" for xml raw,elements;
    if sqlstate = '00000' then
      commit work
    else
      rollback work
    end if
  end if
end;