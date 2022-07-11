CREATE PROCEDURE "DBA"."usp_st_store_in"( 
  in @gsBr char(6),
  in @devID char(200),
  in @sKey char(20),
  in @UserId char(20),
  in @PhaseCode char(6),
  in @StageCode char(6),
  in @RackGrpCode char(300),
  in @cIndex char(30),
  in @HdrData char(7000),
  in @DetData char(7000),
  in @DocNo char(25),
  in @GodownCode char(6) ) 
result( "is_xml_string" xml ) 
begin
  /*
Author 		: Anup 
Procedure	: usp_st_store_in
SERVICE		: ws_st_store_in
Date 		: 09-12-2014
Modified by :Saneesh C G
Ldate 		: 25-10-2016
Purpose		: Store Track store in for TAB
Input		: gsBr~devID~sKey~UserId~PhaseCode~RackGrpCode~StageCode~cIndex~HdrData~DetData~DocNo
RackGrpCode= rg1**rg2**__
IndexDetails: get_doc_list,get_items
Tags		: if <c_message> contains "Error" then force logout (android)
Note		:
Service Call (Format): http://192.168.7.12:13000/ws_st_dashboard?gsBr=003&devID=devID&sKey=KEY&UserId=MYBOSS&PhaseCode=&RackGrpCode=&StageCode=&cIndex=&HdrData=&DetData=	
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
  --common <<
  --cIndex get_doc_list >>
  declare @tmp char(20);
  declare @LoginFlag char(1);
  declare @FirstRackGroup char(6);
  declare @FirstEmpInStage char(10);
  declare local temporary table "temp_rack_grp_list"(
    "c_rack_grp_code" char(6) null,
    "c_stage_code" char(6) null,
    "n_seq" numeric(6) null,) on commit preserve rows;
  declare @LastRGSeq integer;
  declare @CurrentRGSeq integer;
  declare @PrevRackGrp char(6);
  declare @RestrictFlag integer;
  declare @ValidateDevId char(50);
  declare @isLoggedOut integer;
  declare @LoginStatus char(5000);
  declare @Seq integer;
  --cIndex get_doc_list <<
  --cIndex get_items>>
  declare @cDocAlreadyAssignedToUser char(20);
  declare @cTrayAssigned char(6);
  declare @UnprocessedTray char(6);
  declare @UnprocessedDoc char(15);
  declare @UnmovedTray char(6);
  declare @nTrayAssigned integer;
  declare @nSingleUser integer;
  --cIndex get_items<<
  declare @cUser char(20);
  --move_tray>>
  declare @nextRackGrp char(20);
  declare @maxRackGrp char(20);
  declare @CurrentTray char(20);
  declare @nDocItemCount integer;
  declare @nDocItemNotFoundCount integer;
  declare @ItemsInDetail integer;
  declare @DetSuccessFlag integer;
  declare @OrgSeq integer;
  declare @Qty numeric(12);
  declare @HoldFlag integer;
  declare @cReason char(6);
  declare @cNote char(40);
  declare @RackCode char(6);
  declare @CurrentGrp char(6);
  declare @ItemNotFound integer;
  declare @maxSeq integer;
  declare @nItemsInStage integer;
  declare @cStinRefNo char(25);
  declare @RefSep char(5);
  declare @ColMaxLenRef numeric(4);
  declare @TranSeq numeric(6);
  declare @TranBrCode char(6);
  declare @TranPrefix char(4);
  declare @TranYear char(2);
  declare @TranSrno numeric(6);
  --move_tray<<
  --item_done>>
  declare @ForwardFlag integer;
  declare @InOutFlag integer;
  declare @ItemCode char(6);
  declare @PickedQty numeric(12);
  declare @ReasonCode char(6);
  declare @RemainingQty numeric(12);
  declare @BatchNo char(15);
  --item_done<<
  --get_doc_count
  declare @DocCount integer;
  --message @RackGrpCode type warning to client;
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
    set @DocNo = "http_variable"('DocNo'); --11
    set @GodownCode = "http_variable"('GodownCode') --12		
  end if;
  select "c_delim" into @ColSep from "ps_tab_delimiter" where "n_seq" = 0;
  select "c_delim" into @RowSep from "ps_tab_delimiter" where "n_seq" = 1;
  if @ColSep is null or @ColSep = '' then
    select '--------------------\x0D\x0ASQL error: usp_st_store_in No Delimiter Defined';
    return
  end if;
  set @ColMaxLen = "Length"(@ColSep);
  set @RowMaxLen = "Length"(@RowSep);
  --devid
  set @BrCode = "uf_get_br_code"(@gsBr);
  set @t_ltime = "left"("now"(),19);
  set @d_ldate = "uf_default_date"();
  --select top 1 c_user  into @cUser from logon_det order by n_srno desc;
  set @RackGrpList = @RackGrpCode;
  select "n_flag" into @nSingleUser from "st_store_stage_mst" where "c_code" = @StageCode;
  case @cIndex
  when 'release_doc' then
    update "st_track_det" set "c_user" = null
      where "n_complete" = 0 and "c_doc_no" = @DocNo and "c_stage_code" = @StageCode
      and "st_track_det"."c_godown_code" = @GodownCode
      and "c_user" = @UserId;
    if
      (select "count"() from "st_track_tray_move" where "c_doc_no" = @DocNo
        and "c_stage_code" = @StageCode
        and "c_godown_code" = @GodownCode
        and "c_user" = @UserId)
       > 0 then
      update "st_track_tray_move"
        set "c_user" = null
        where "c_doc_no" = @DocNo
        and "c_stage_code" = @StageCode
        and "c_godown_code" = @GodownCode
        and "c_user" = @UserId
    end if;
    if sqlstate = '00000' then
      commit work;
      select 'SUCCESS' as "c_message" for xml raw,elements;
      return
    else
      select 'FAILURE' as "c_message" for xml raw,elements;
      rollback work
    end if when 'get_doc_list' then -----------------------------------------------------------------------
    --http://192.168.7.11:14109/ws_st_store_in?gsbr=109&devID=81410bfc5f09330019122014060518912&sKEY=sKey&UserId=MYBOSS&cIndex=get_doc_list&DetData=1**&RackGrpCode=A**&StageCode=S00002
    while @RackGrpList <> '' loop
      --1 RackGrpList
      select "Locate"(@RackGrpList,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@RackGrpList,@ColPos-1));
      set @RackGrpList = "SubString"(@RackGrpList,@ColPos+@ColMaxLen);
      --message 'RackGrpList '+@tmp type warning to client;			
      select "uf_st_login_status"(@BrCode,@tmp,@LoginFlag,@UserId,@devID)
        into @LoginStatus;
      if "length"(@LoginStatus) > 1 then
        select '' as "c_doc_no",
          '' as "n_first_in_stage",
          '' as "c_doc_name",
          '' as "c_ref_no",
          '' as "n_inout",
          @LoginStatus as "c_message" for xml raw,elements;
        --select 'Error!!: Rack Group : '+@tmp+' already assigned to User : '+@ValidRGUser;
        return
      end if;
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
    if(select "count"("c_rack_grp_code") from "temp_rack_grp_list" where "c_rack_grp_code" = @FirstRackGroup) > 0 then
      print 'sani1';
      select "c_tray_code",
        "n_first_in_stage",
        "c_doc_no",
        "n_inout",
        "c_message",
        "n_item_count",
        0 as "n_max_seq",
        0 as "n_exp_doc"
        from(select "st_track_det"."c_doc_no" as "c_doc_no",
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
            order by "st_track_mst"."t_time_in" asc) as "doc_list"
        where(select "count"("sd"."c_doc_no")
          from "st_track_det" as "sd"
          where "sd"."c_doc_no" = "doc_list"."c_doc_no"
          and("sd"."c_rack" is null or "sd"."c_stage_code" is null or "sd"."c_rack_grp_code" is null))
         = 0
        and "isnull"("doc_list"."c_user",'-') = (if @nSingleUser = 0 then(if "doc_list"."c_user" is null then "isnull"("doc_list"."c_user",'-') else @UserId endif) else "isnull"("doc_list"."c_user",'-') endif)
        and "doc_list"."n_inout" = 1
        and("n_item_count" > 0 or(("n_items_in_stage"-"n_item_count") > 0 and "tray_count" = 0))
        and "n_items_in_stage" > 0 for xml raw,elements
    else
      print 'sani2';
      select "c_tray_code" as "c_tray_code",
        "n_first_in_stage",
        "c_doc_no",
        "n_inout",
        "c_message",
        "max"("n_item_count") as "n_item_count",
        "n_max_seq",
        "t_time",
        0 as "n_exp_doc"
        from(select distinct "st_track_tray_move"."c_tray_code" as "c_tray_code",
            0 as "n_first_in_stage",
            "st_track_tray_move"."c_doc_no" as "c_doc_no",
            "st_track_tray_move"."n_inout" as "n_inout",
            "st_track_tray_move"."t_time" as "t_time",
            '' as "c_message",
            (select "count"("b"."c_item_code") from "st_track_det" as "b" join "temp_rack_grp_list" on "b"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code" where "b"."c_doc_no" = "st_track_det"."c_doc_no" and "b"."c_tray_code" = "st_track_det"."c_tray_code" and "b"."n_complete" = 0 and "isnull"("b"."c_godown_code",'-') = @GodownCode) as "n_item_count",
            0 as "n_max_seq",
            "st_track_mst"."n_confirm" as "n_confirm",
            "st_track_mst"."n_urgent" as "n_urgent",
            "st_track_mst"."c_sort" as "c_sort",
            "st_track_det"."c_user" as "c_user"
            from "st_track_tray_move"
              left outer join "st_track_det" on "st_track_tray_move"."c_doc_no" = "st_track_det"."c_doc_no"
              and "st_track_tray_move"."n_inout" = "st_track_det"."n_inout"
              and "st_track_tray_move"."c_tray_code" = "st_track_det"."c_tray_code"
              and "isnull"("st_track_tray_move"."c_godown_code",'') = "isnull"("st_track_det"."c_godown_code",'-')
              join "temp_rack_grp_list"
              on "st_track_tray_move"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
              join "st_track_mst" on "st_track_mst"."c_doc_no" = "st_track_tray_move"."c_doc_no"
              and "st_track_mst"."n_inout" = "st_track_tray_move"."n_inout"
            where "st_track_tray_move"."n_inout" not in( 9,8,0 ) 
            and "isnull"("st_track_tray_move"."c_godown_code",'-') = @GodownCode) as "tray_list"
        group by "c_tray_code","n_first_in_stage","c_doc_no","n_inout","c_message","n_max_seq","t_time"
        order by "t_time" asc for xml raw,elements
    end if when 'get_items' then
    --http://192.168.7.11:14109/ws_st_store_in?gsbr=109&devID=81410bfc5f09330019122014060518912&sKEY=sKey&UserId=MYBOSS&cIndex=get_items&HdrData=**&DetData=**&RackGrpCode=A**&StageCode=S00002&DocNo=1321661140
    --HdrData : CurrentTray**
    --1 CurrentTray
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @CurrentTray = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --message 'CurrentTray '+@CurrentTray type warning to client
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
    if @nSingleUser = 0 then
      select top 1 "st_track_det"."c_tray_code","c_user"
        into @cTrayAssigned,@cDocAlreadyAssignedToUser
        from "st_track_det"
          join "temp_rack_grp_list" --(select 'A' as c_rack_grp_code, 'S00002' as c_stage_code, 1 as n_seq )
          on "temp_rack_grp_list"."c_rack_grp_code" = "st_track_det"."c_rack_grp_code"
          and "temp_rack_grp_list"."c_stage_code" = "st_track_det"."c_stage_code"
        where "c_doc_no" = @DocNo --'109/14/S/146117'--
        and "st_track_det"."c_stage_code" = @StageCode
        and "st_track_det"."c_godown_code" = @GodownCode;
      select top 1 "c_tray_code","c_doc_no"
        into @UnprocessedTray,@UnprocessedDoc
        from "st_track_det"
        where "c_user" = @UserId
        and "n_complete" = 0
        and "c_stage_code" = @StageCode
        and "st_track_det"."c_godown_code" = @GodownCode;
      if @UnprocessedTray is not null and "isnull"(@UnprocessedDoc,'') <> "isnull"(@DocNo,'') then
        select 'Warning! : Please Process the Pending document : '+@UnprocessedDoc+' with Tray : '+"string"(@UnprocessedTray) as "c_message" for xml raw,elements;
        return
      end if;
      select top 1 "c_tray_code","c_doc_no"
        into @UnmovedTray,@UnprocessedDoc
        from "st_track_tray_move"
          join "temp_rack_grp_list"
          on "st_track_tray_move"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
        where "c_user" = @UserId
        and "n_inout" not in( 8,9 ) 
        and "st_track_tray_move"."c_godown_code" = @GodownCode
        order by "t_time" desc;
      if @UnmovedTray is not null and @UnprocessedDoc <> @DocNo then
        select 'Warning! : Please Process the Pending document : '+@UnprocessedDoc+' with Tray : '+"string"(@UnmovedTray) as "c_message" for xml raw,elements;
        return
      end if;
      if @cTrayAssigned is not null and @UserId <> @cDocAlreadyAssignedToUser then
        select 'Warning! : Document '+"string"(@DocNo)+' Already assigned to : '+"string"(@cDocAlreadyAssignedToUser)+' with Tray : '+"string"(@cTrayAssigned) as "c_message" for xml raw,elements;
        return
      end if end if;
    update "st_track_det"
      set "c_user" = @UserId
      where "n_complete" = 0 and "c_doc_no" = @DocNo and "c_stage_code" = @StageCode
      and "st_track_det"."c_godown_code" = @GodownCode;
    commit work;
    if
      (select "count"("c_doc_no")
        from "st_track_det"
          join "temp_rack_grp_list" as "user_grp"
          on "st_track_det"."c_rack_grp_code" = "user_grp"."c_rack_grp_code"
        where "st_track_det"."c_doc_no" = @DocNo
        and "st_track_det"."n_complete" = 0
        and "c_tray_code" = @CurrentTray)
       > 0 then
      select "st_track_det"."c_doc_no" as "c_doc_no",
        "st_track_det"."n_inout" as "n_inout",
        "item_mst"."c_code" as "c_item_code",
        "isnull"("st_track_det"."c_batch_no",'') as "c_batch_no",
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
        "date"("isnull"("stock"."d_expiry_date",'')) as "d_exp_dt",
        "TRIM"("STR"("TRUNCNUM"("stock"."n_mrp",3),10,3)) as "n_mrp",
        "st_tray_mst"."c_name" as "c_tray_name",
        "item_mst"."n_qty_per_box" as "n_qty_per_box",
        '' as "c_message",
        "isnull"("item_mst"."c_barcode"+',','') as "c_barcode_list",
        0 as "n_inner_pack_lot",
        0 as "n_exp_doc"
        from "st_track_det"
          join "item_mst" on "st_track_det"."c_item_code" = "item_mst"."c_code"
          join "rack_mst" on "rack_mst"."c_code" = "item_mst"."c_rack_code"
          join "pack_mst" on "pack_mst"."c_code" = "item_mst"."c_pack_code"
          join "stock" on "stock"."c_item_code" = "st_track_det"."c_item_code"
          and "stock"."c_batch_no" = "st_track_det"."c_batch_no"
          join "temp_rack_grp_list" as "user_grp"
          on "st_track_det"."c_rack_grp_code" = "user_grp"."c_rack_grp_code" --024					
          left outer join "st_tray_mst" on "st_tray_mst"."c_code" = "st_track_det"."c_tray_code"
        where "st_track_det"."c_doc_no" = @DocNo
        and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode
        order by "c_rack" asc for xml raw,elements
    else
      select 'Warning! : No Items To Remove for Tray '+@CurrentTray as "c_message" for xml raw,elements -- Changes in data of this <c_message> tag affects the working of tab
    end if when 'get_storein_reason' then
    select "reason_mst"."c_name" as "c_name",
      "reason_mst"."c_code" as "c_code"
      from "reason_mst"
      where "reason_mst"."n_type" in( 12 ) for xml raw,elements
  when 'item_done' then --called when an item is picked or put back
    --@HdrData
    --1 ForwardFlag
    --@DetData
    --1 InOutFlag~2 ItemCode~3 BatchNo~4 Seq~5 Qty~6 ReasonCode
    -------HdrData				
    --1 ForwardFlag
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
    --4 Seq(OrgSeq)
    select "Locate"(@DetData,@ColSep) into @ColPos;
    set @Seq = "Trim"("Left"(@DetData,@ColPos-1));
    set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
    --message 'Seq '+string(@Seq) type warning to client;	
    --5 PickedQty
    select "Locate"(@DetData,@ColSep) into @ColPos;
    set @PickedQty = "Trim"("Left"(@DetData,@ColPos-1));
    set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
    --message 'PickedQty '+@PickedQty type warning to client;	
    --6 ReasonCode		
    select "Locate"(@DetData,@ColSep) into @ColPos;
    set @ReasonCode = "Trim"("Left"(@DetData,@ColPos-1));
    set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
    --message 'ReasonCode '+@ReasonCode type warning to client;	
    --print 'ReasonCode '+@ReasonCode ;	
    if @ForwardFlag = 1 then -- item done
      select("n_bal_qty"-@PickedQty)
        into @RemainingQty from "st_track_det"
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "c_item_code" = @ItemCode
        and "n_seq" = @Seq
        and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode;
      update "st_track_det"
        set "n_complete" = (if @RemainingQty = 0 then @ForwardFlag else 0 endif),
        "n_bal_qty" = ("n_bal_qty"-@PickedQty)
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "c_item_code" = @ItemCode
        and "n_seq" = @Seq
        and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode
    elseif @ForwardFlag = 0 then -- shift back, 
      update "st_track_det"
        set "n_complete" = @ForwardFlag,
        "n_bal_qty" = ("n_bal_qty"+@PickedQty)
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "c_item_code" = @ItemCode
        and "n_seq" = @Seq
        and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode
    elseif @ForwardFlag = 2 then -- item not found
      update "st_track_det"
        set "n_complete" = @ForwardFlag,
        "c_reason_code" = @ReasonCode
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "c_item_code" = @ItemCode
        and "n_seq" = @Seq
        and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode
    elseif @ForwardFlag = 3 then -- shift back when item not found 
      update "st_track_det"
        set "n_complete" = 0
        where "c_doc_no" = @DocNo
        and "n_inout" = @InOutFlag
        and "c_item_code" = @ItemCode
        and "n_seq" = @Seq
        and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode
    end if;
    if sqlstate = '00000' then
      commit work;
      select 'Success' as "c_message" for xml raw,elements
    else
      rollback work;
      select 'Failure' as "c_message" for xml raw,elements
    end if when 'move_tray' then
    /*
@HdrData :  1 ItemsInDetail~2 @CurrentTray~3 InOutFlag
*/
    --1 ItemsInDetail
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @ItemsInDetail = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --message 'ItemsInDetail '+@ItemsInDetail type warning to client;
    --2 CurrentTray
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @CurrentTray = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --message 'CurrentTray '+string(@CurrentTray ) type warning to client;	
    --3 InOutFlag
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @InOutFlag = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --message 'InOutFlag '+string(@InOutFlag ) type warning to client;				
    set @DetSuccessFlag = 0;
    while @DetData <> '' and @ItemsInDetail >= 1 loop
      /*
@DetData : 1 InOutFlag~2 Seq~3 OrgSeq~4 ItemCode~5 BatchNo
~6 Qty~7 HoldFlag~8 cReason~9 cNote~10 CurrentTray
~11 RackCode~12 CurrentGrp~13 ItemNotFound
*/
      -- DocNo		
      --1 InOutFlag
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @InOutFlag = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --message 'InOutFlag '+string(@InOutFlag) type warning to client;
      --2 Seq
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @Seq = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --message 'Seq '+string(@Seq) type warning to client;
      --3 OrgSeq
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @OrgSeq = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --message 'OrgSeq '+String(@OrgSeq) type warning to client;
      --4 ItemCode
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @ItemCode = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --message 'ItemCode '+@ItemCode type warning to client;
      --5 BatchNo
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @BatchNo = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --message 'BatchNo '+@BatchNo type warning to client;
      --6 Qty
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @Qty = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --message 'Qty '+string(@Qty) type warning to client;
      --7 HoldFlag
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @HoldFlag = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --message 'HoldFlag '+string(@HoldFlag) type warning to client;
      --8 cReason
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @cReason = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --message 'cReason '+string(@cReason) type warning to client;
      --9 cNote
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @cNote = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --message 'cNote '+@cNote type warning to client;
      --10 CurrentTray
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @CurrentTray = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --message 'CurrentTray '+string(@CurrentTray) type warning to client;
      --print 'CurrentTray : '+string(@CurrentTray);
      --@devID
      --11 RackCode
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @RackCode = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --message 'RackCode '+@RackCode type warning to client;
      --12 CurrentGrp
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @CurrentGrp = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --message 'CurrentGrp '+@CurrentGrp type warning to client;
      --13 ItemNotFound
      select "Locate"(@DetData,@ColSep) into @ColPos;
      set @ItemNotFound = "Trim"("Left"(@DetData,@ColPos-1));
      set @DetData = "SubString"(@DetData,@ColPos+@ColMaxLen);
      --message 'ItemNotFound '+@ItemNotFound type warning to client;
      select "Locate"(@DetData,@RowSep) into @RowPos;
      set @DetData = "SubString"(@DetData,@RowPos+@RowMaxLen);
      --@StageCode								
      --message 'DetData '+@DetData type warning to client;
      select "c_stin_ref_no"
        into @cStinRefNo from "st_track_det"
        where "c_tray_code" = @CurrentTray
        and "c_doc_no" = @DocNo
        and "n_seq" = @OrgSeq;
      if @ItemNotFound = 0 then
        delete from "st_track_in"
          where "c_doc_no"+'/'+"string"("n_seq") = @cStinRefNo
          and "n_complete" = 9;
        select(if("n_bal_qty"-@Qty) < 0 then 0 else("n_bal_qty"-@Qty) endif)
          into @RemainingQty from "st_track_det"
          where "c_doc_no" = @DocNo
          and "n_inout" = @InOutFlag
          and "c_item_code" = @ItemCode
          and "n_seq" = @OrgSeq
          and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode;
        update "st_track_det"
          set "n_complete" = (if @RemainingQty = 0 then 8 else 0 endif),
          "n_bal_qty" = @RemainingQty
          where "c_doc_no" = @DocNo
          and "n_inout" = @InOutFlag
          and "c_item_code" = @ItemCode
          and "n_seq" = @OrgSeq
          and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode
      else
        update "st_track_in"
          set "n_complete" = 8,"c_tray_code" = null
          where "c_doc_no"+'/'+"string"("n_seq") = @cStinRefNo
          and "n_complete" = 9;
        update "st_track_det"
          set "n_complete" = 2 --item not found
          where "c_doc_no" = @DocNo
          and "n_inout" = @InOutFlag
          and "c_item_code" = @ItemCode
          and "n_seq" = @OrgSeq
          and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode
      end if;
      if sqlstate = '00000' then
        commit work;
        set @DetSuccessFlag = 1
      else
        rollback work;
        set @DetSuccessFlag = 0
      end if;
      set @DetSuccessFlag = 1
    end loop;
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
    select "c_rack_grp_code"
      into @nextRackGrp from "st_store_stage_det"
      where "c_stage_code" = @StageCode
      and "n_pos_seq"
       = any(select top 1 "n_seq"+1 as "n_seq" from "temp_rack_grp_list" order by "n_seq" desc);
    if(select "count"("c_tray_code") from "st_track_tray_move" where "c_tray_code" = @CurrentTray) > 1 then
      select top 1 "st_track_tray_move"."c_rack_grp_code"
        into @maxRackGrp from "st_track_tray_move"
          join "temp_rack_grp_list" on "st_track_tray_move"."c_stage_code" = "temp_rack_grp_list"."c_stage_code"
          and "st_track_tray_move"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
        where "isnull"("st_track_tray_move"."c_godown_code",'-') = @GodownCode
        order by "n_seq" desc;
      delete from "st_track_tray_move" where "c_tray_code" = @CurrentTray and "c_rack_grp_code" <> @maxRackGrp and "isnull"("c_godown_code",'-') = @GodownCode;
      if sqlstate = '00000' then
        commit work
      else
        rollback work
      end if end if;
    select "count"("b"."c_item_code")
      into @nItemsInStage from "st_track_det" as "b"
      where "b"."c_doc_no" = @DocNo
      and "b"."n_complete" = 0
      and "b"."c_stage_code" = @StageCode
      and "isnull"("b"."c_godown_code",'-') = @GodownCode;
    if @nextRackGrp is not null and @nItemsInStage > 0 then
      delete from "st_track_tray_move" where "c_tray_code" = @CurrentTray;
      if sqlstate = '00000' then
        commit work
      else
        rollback work
      end if;
      insert into "st_track_tray_move"
        ( "c_doc_no","n_inout","c_tray_code","c_rack_grp_code","c_stage_code","t_time","c_user",
        "c_godown_code" ) on existing update defaults off
        select @DocNo,@InOutFlag,@CurrentTray,@nextRackGrp,@StageCode,@t_ltime,@UserId,@GodownCode;
      if sqlstate = '00000' then
        commit work
      else
        rollback work
      end if
    else if @nItemsInStage <= 0 then
        --/updating st_trck_tray_move for getting record n history table 
        insert into "st_track_tray_move"
          ( "c_doc_no","n_inout","c_tray_code","c_rack_grp_code","c_stage_code","t_time","c_user",
          "c_godown_code" ) on existing update defaults off
          select @DocNo,@InOutFlag,@CurrentTray,(if @nextRackGrp is not null then @nextRackGrp else '-' endif),@StageCode,"now"(),@UserId,@GodownCode;
        delete from "st_track_tray_move" where "c_tray_code" = @CurrentTray and "isnull"("st_track_tray_move"."c_godown_code",'-') = @GodownCode
      end if;
      if sqlstate = '00000' then
        commit work
      else
        rollback work
      end if;
      set @nDocItemCount = 0;
      set @nDocItemNotFoundCount = 0;
      select "count"("c_tray_code")
        into @nDocItemNotFoundCount from "st_track_det"
        where "c_tray_code" = @CurrentTray
        and "n_complete" not in( 0,1 ) 
        and "n_qty" = "n_bal_qty"
        and "c_doc_no" = @DocNo
        and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode;
      select "count"("c_tray_code")
        into @nDocItemCount from "st_track_det"
        where "c_tray_code" = @CurrentTray
        and "c_doc_no" = @DocNo
        and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode;
      if @nDocItemNotFoundCount = @nDocItemCount and @nDocItemCount <> 0 and @nDocItemNotFoundCount <> 0 then -- for tray release 
        delete from "st_track_tray_move"
          where "c_tray_code" = @CurrentTray
          and "c_doc_no" = @DocNo
          and "isnull"("st_track_tray_move"."c_godown_code",'-') = @GodownCode;
        commit work
      end if;
      if sqlstate = '00000' then
        commit work
      else
        rollback work
      end if end if;
    if(select "count"("c_doc_no") from "st_track_det" where("n_complete" = 0) and "c_doc_no" = @DocNo) = 0 then
      update "st_track_mst"
        set "c_phase_code" = 'PH0002'
        where "c_doc_no" = @DocNo;
      commit work
    end if;
    if @ItemsInDetail <> 1 then
      set @DetSuccessFlag = 1 --no det data to batch success flag
    end if;
    if @DetSuccessFlag = 1 then
      select 'Success' as "c_message",
        @maxSeq as "n_max_seq" for xml raw,elements
    else
      select 'Failure' as "c_message" for xml raw,elements
    end if
  end case
end;