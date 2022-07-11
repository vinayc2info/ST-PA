CREATE PROCEDURE "DBA"."usp_st_dashboard"( 
  -------------------------------------------------------------------------------------------------------------------------------
  in @gsBr char(6),
  in @devID char(200),
  in @sKey char(20),
  in @UserId char(20),
  in @StageList char(1000),
  in @RackGrpCode char(300),
  in @cIndex char(30),
  in @HdrData char(7000),
  in @DetData char(7000),
  in @GodownCode char(6) ) 
result( "is_xml_string" xml ) 
begin
  /*
Author 		: Anup 
Procedure	: usp_st_dashboard
SERVICE		: ws_st_dashboard
Date 		: 23-12-2014
Modified By : Saneesh C G 
Ldate 		: 20-06-2015
Purpose		: Store Track Dashboard to TAB
Input		: gsBr~devID~sKey~UserId~PhaseCode~RackGrpCode~StageList~cIndex~HdrData~DetData
StageList= stage1**Stage2**__RackGrpCode= rg1**rg2**__
IndexDetails: user_details,header,get_bounced_list
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
  declare @cUser char(20);
  --common <<
  declare @nAllStage integer;
  declare @tmp char(6);
  declare local temporary table "temp_stage_list"(
    "c_stage_code" char(6) null,) on commit preserve rows;
  declare @t_time_in char(25);
  --change_rack>>
  declare @nValidRack integer;
  declare @toGodown char(6);
  declare @toRack char(6);
  declare @ItemCode char(6);
  declare @detItemCount integer;
  --change_rack<<
  --get_item_status >>
  declare @cMessage char(7000);
  declare @cStoreOutPending char(500);
  declare @cStoreInPending char(500);
  --get_item_status <<
  --get_item_stock>>
  declare @nTraysOnly bit;
  --get_item_stock<<
  if @devID = '' or @devID is null then
    set @gsBr = "http_variable"('gsBr'); --1
    set @devID = "http_variable"('devID'); --2
    set @sKey = "http_variable"('sKey'); --3
    set @UserId = "http_variable"('UserId'); --4		
    set @RackGrpCode = "http_variable"('RackGrpCode'); --5	
    set @StageList = "http_variable"('StageList'); --6
    set @cIndex = "http_variable"('cIndex'); --7
    set @HdrData = "http_variable"('HdrData'); --8
    set @DetData = "http_variable"('DetData'); --9
    set @GodownCode = "http_variable"('GodownCode') --10		
  end if;
  select "c_delim" into @ColSep from "ps_tab_delimiter" where "n_seq" = 0;
  select "c_delim" into @RowSep from "ps_tab_delimiter" where "n_seq" = 1;
  set @ColMaxLen = "Length"(@ColSep);
  set @RowMaxLen = "Length"(@RowSep);
  set @BrCode = "uf_get_br_code"(@gsBr);
  set @t_ltime = "left"("now"(),19);
  set @d_ldate = "uf_default_date"();
  set @nAllStage = 1;
  if @StageList <> '' then
    --1 StageList
    set @nAllStage = 0;
    while @StageList <> '' loop
      select "Locate"(@StageList,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@StageList,@ColPos-1));
      set @StageList = "SubString"(@StageList,@ColPos+@ColMaxLen);
      insert into "temp_stage_list"( "c_stage_code" ) values( @tmp ) 
    end loop
  else
    set @nAllStage = 1
  end if;
  --Print  @nAllStage  ;
  case @cIndex
  when 'get_dashboard_summary' then
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @t_time_in = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    if @t_time_in = '' or @t_time_in is null then
      set @t_time_in = '1900-01-01'
    end if;
    if @nAllStage = 1 then
      select "isnull"("msg_mst"."c_stage_code",'-') as "c_stage_code",
        "isnull"("msg_mst"."c_rack_grp_code",'-') as "c_rack_grp_code",
        "msg_mst"."c_from_user" as "c_user_id",
        '' as "c_note",
        "count"(distinct "c_item_code") as "n_bounce_count",
        "count"() as "n_msg_count",
        2 as "n_status"
        from "msg_mst"
        where "msg_mst"."t_ltime" >= @t_time_in
        and "msg_mst"."c_godown_code" = @GodownCode
        group by "msg_mst"."c_stage_code","msg_mst"."c_rack_grp_code","msg_mst"."c_from_user","n_status"
        order by "c_stage_code" asc,"c_rack_grp_code" asc,"c_from_user" asc for xml raw,elements
    else --//Selected stage 	
      select "isnull"("msg_mst"."c_stage_code",'-') as "c_stage_code",
        "isnull"("msg_mst"."c_rack_grp_code",'-') as "c_rack_grp_code",
        "msg_mst"."c_from_user" as "c_user_id",
        '' as "c_note",
        "count"(distinct "c_item_code") as "n_bounce_count",
        "count"() as "n_msg_count",
        2 as "n_status"
        from "msg_mst" join "temp_stage_list" on "msg_mst"."c_stage_code" = "temp_stage_list"."c_stage_code"
        where "msg_mst"."t_ltime" >= @t_time_in
        and "msg_mst"."c_godown_code" = @GodownCode
        group by "msg_mst"."c_stage_code","msg_mst"."c_rack_grp_code","msg_mst"."c_from_user","n_status"
        order by "c_stage_code" asc,"c_rack_grp_code" asc,"c_from_user" asc for xml raw,elements
    end if when 'header' then
    --http://192.168.7.12:14109/ws_st_dashboard?gsBr=109&devID=devID&sKey=KEY&UserId=MYBOSS&PhaseCode=&RackGrpCode=&StageCode=&cIndex=header&HdrData=&DetData=	
    select "dheader"."c_desc" as "c_desc",
      "dheader"."n_doc_count" as "n_doc_count",
      "dheader"."n_racks_handling" as "n_item_count"
      from(select distinct 'Rack Wise User Details' as "c_desc",
          (select "count"("c_user_id") from "st_store_login" where "t_login_time" is not null) as "n_doc_count",
          (select "count"("sb"."c_code")
            from "st_store_login_det" as "sa" join "rack_mst" as "sb" on "sa"."c_rack_grp_code" = "sb"."c_group"
            where "sa"."c_br_code" = "a"."c_br_code"
            and "a"."c_user_id" = "sa"."c_user_id"
            and "a"."c_device_id" = "sa"."c_device_id") as "n_racks",
          (select "count"(distinct "sc"."c_tray_code")
            from "st_track_det" as "sc"
            where "sc"."c_user" = "a"."c_user_id"
            and "sc"."c_godown_code" = @GodownCode) as "n_tray_in_process",
          (select "count"("sb"."c_rack_code")
            from "st_store_login_det" as "sa" join "rack_group_det" as "sb" on "sa"."c_rack_grp_code" = "sb"."c_rack_grp_code"
            where "sa"."c_br_code" = "a"."c_br_code"
            and "a"."c_user_id" = "sa"."c_user_id"
            and "a"."c_device_id" = "sa"."c_device_id") as "n_temp_racks",
          ("n_racks"+"n_temp_racks") as "n_racks_handling",
          0 as "n_item_count",
          '' as "t_last_tran_time",
          1 as "n_seq"
          from "st_store_login" as "a"
            join "st_store_login_det" as "b" on "a"."c_br_code" = "b"."c_br_code"
            and "a"."c_user_id" = "b"."c_user_id"
            and "a"."c_device_id" = "b"."c_device_id"
          where "a"."t_login_time" is not null
          and "a"."c_godown_code" = @GodownCode) as "dheader" for xml raw,elements
  when 'get_bounced_list' then
    --http://192.168.7.12:14109/ws_st_dashboard?gsBr=109&devID=devID&sKey=KEY&UserId=MYBOSS&PhaseCode=&RackGrpCode=&StageCode=&cIndex=get_bounced_list&HdrData=&DetData=1900-01-01**
    --1 t_time_in
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @t_time_in = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --message 't_time_in '+@t_time_in type warning to client;
    if @t_time_in = '' or @t_time_in is null then
      set @t_time_in = '1900-01-01'
    end if;
    select "b"."c_doc_no" as "c_doc_no",
      "b"."c_item_code" as "c_item_code",
      "c"."c_name"+"uf_st_get_pack_name"("pack_mst"."c_name") as "c_item_name",
      "b"."c_batch_no" as "c_batch_no",
      "TRIM"("STR"("TRUNCNUM"("b"."n_bal_qty",3),10,0)) as "n_bounced_qty",
      "b"."c_rack" as "c_rack",
      "b"."c_rack_grp_code" as "c_rack_grp_code",
      "b"."c_stage_code" as "c_stage_code"
      from "st_track_det" as "b" join "msg_mst" on "msg_mst"."c_item_code" = "b"."c_item_code"
        and "msg_mst"."c_rack" = "b"."c_rack"
        and "msg_mst"."c_stage_Code" = "b"."c_stage_Code"
        and "msg_mst"."c_doc_no" = "b"."c_doc_no"
        join "item_mst" as "c" on "c"."c_code" = "b"."c_item_code"
        join "pack_mst" on "pack_mst"."c_code" = "c"."c_pack_code"
      where "msg_mst"."t_ltime" >= @t_time_in
      and "b"."n_complete" in( 2 ) 
      and "b"."n_bal_qty" > 0
      and "b"."c_godown_code" = @GodownCode for xml raw,elements
  when 'get_pending_doc' then
    --http://192.168.7.11:14109/ws_st_dashboard?gsBr=109&devID=devID&sKey=KEY&UserId=MYBOSS&PhaseCode=&RackGrpCode=&StageCode=&cIndex=get_pending_doc&HdrData=&DetData=1900-01-01**
    select "st_track_mst"."c_doc_no" as "c_doc_no",
      "st_track_mst"."c_cust_code" as "c_cust_code",
      "act_mst"."c_name" as "c_cust_name",
      "item_mst"."c_code" as "c_item_code",
      "item_mst"."c_name"+"uf_st_get_pack_name"("pack_mst"."c_name") as "c_item_name",
      "st_track_det"."n_inout" as "n_inout",
      "st_track_det"."c_rack_grp_code" as "c_rack_grp_code",
      "st_track_det"."c_rack" as "c_rack",
      "st_track_det"."c_stage_code" as "c_stage_code"
      from "st_track_det"
        ,"st_track_mst" left outer join "act_mst" on "st_track_mst"."c_cust_code" = "act_mst"."c_code"
        ,"item_mst" join "pack_mst" on "pack_mst"."c_code" = "item_mst"."c_pack_code"
      where "st_track_mst"."c_doc_no" = "st_track_det"."c_doc_no"
      and "st_track_mst"."n_inout" = "st_track_det"."n_inout"
      and "item_mst"."c_code" = "st_track_det"."c_item_code"
      and "st_track_det"."c_tray_code" is null
      and "st_track_det"."c_godown_code" = @GodownCode for xml raw,elements
  when 'get_rackwise_stock' then
    --http://192.168.250.162:14153/ws_st_dashboard?gsBr=503&devID=devID&sKey=KEY&UserId=MYBOSS&PhaseCode=&RackGrpCode=&StageCode=&cIndex=get_rackwise_stock&HdrData=20186&DetData=1900-01-01**
    --i/p : @HdrData,@gsBr
    if(select "count"("c_code") from "rack_mst" where "c_code" = @HdrData) = 0 then
      select 'Warning : Rack '+"string"(@HdrData)+' not found!' as "c_message" for xml raw,elements;
      return
    end if;
    if(select "count"("c_code") from "rack_mst" where "c_code" = @HdrData and "n_lock" = 0) = 0 then
      select 'Warning : Rack '+"string"(@HdrData)+' Locked!' as "c_message" for xml raw,elements;
      return
    end if;
    select "rack_stock"."c_item_code" as "c_item_code",
      "rack_stock"."c_item_name" as "c_item_name",
      "rack_stock"."n_qty_per_box" as "n_qty_per_box",
      "TRIM"("STR"("TRUNCNUM"("rack_stock"."n_rack_qty"-"n_inprocess",3),10,0)) as "n_rack_qty",
      "TRIM"("STR"("TRUNCNUM"("rack_stock"."n_inprocess",3),10,0)) as "n_inprocess",
      "TRIM"("STR"("TRUNCNUM"("rack_stock"."n_hold_qty"-"rack_stock"."n_inprocess",3),10,0)) as "n_hold_qty",
      "TRIM"("STR"("TRUNCNUM"("rack_stock"."n_tot_qty",3),10,0)) as "n_tot_qty",
      "rack_stock"."n_inner_pack_lot" as "n_inner_pack_lot",
      "rack_stock"."c_message" as "c_message",
      "rack_stock"."c_rack_group" as "c_rack_group"
      from(select "Item_mst"."c_code" as "c_item_code",
          "Item_mst"."c_name"+"uf_st_get_pack_name"("pack_mst"."c_name") as "c_item_name",
          "Item_mst"."n_qty_per_box" as "n_qty_per_box",
          "sum"("stock"."n_balance_qty"-"isnull"("stock"."n_godown_qty",0)) as "n_rack_qty",
          "TRIM"("STR"("TRUNCNUM"("isnull"("isnull"((select "sum"("n_store_track_qty") from "stock" where "stock"."c_item_code" = "item_mst"."c_code"),0),0),3),10,0)) as "n_inprocess",
          "TRIM"("STR"("TRUNCNUM"("isnull"("isnull"((select "sum"("n_hold_qty") from "stock" where "stock"."c_item_code" = "item_mst"."c_code"),0),0),3),10,0)) as "n_hold_qty",
          "TRIM"("STR"("TRUNCNUM"("isnull"((select "sum"("n_balance_qty") from "stock" where "stock"."c_item_code" = "item_mst"."c_code"),0),3),10,0)) as "n_tot_qty",
          1 as "n_inner_pack_lot",
          '' as "c_message",
          "rack_mst"."c_group" as "c_rack_group"
          from "Item_mst"
            join "pack_mst" on "pack_mst"."c_code" = "item_mst"."c_pack_code"
            join "rack_mst" on "rack_mst"."c_code" = "item_mst"."c_rack_code"
            join "stock" on "item_mst"."c_code" = "stock"."c_item_code"
          where "item_mst"."c_rack_code" = (if @GodownCode = '-' then @HdrData else '-' endif) and @GodownCode = '-'
          group by "Item_mst"."c_code","c_item_name","n_qty_per_box","n_inner_pack_lot","c_message","c_rack_group") as "rack_stock"
      order by 2 asc for xml raw,elements
  when 'get_item_stock' then
    --i/p @HdrData : ItemCode, @GodownCode, @gsBr, @DetData(nTraysOnly)
    set @nTraysOnly = 0;
    if @DetData is not null and @DetData <> '' then
      set @nTraysOnly = @DetData
    end if;
    if @nTraysOnly = 0 then
      select '-' as "c_godown_code",
        "i"."c_rack_code" as "c_rack",
        "i"."c_code" as "c_item_code",
        "i"."c_name"+"uf_st_get_pack_name"("pack_mst"."c_name") as "c_item_name",
        "s"."c_batch_no" as "c_batch_no",
        "s"."n_mrp" as "n_mrp",
        "s"."d_expiry_date" as "d_exp_dt",
        "TRIM"("STR"("TRUNCNUM"("s"."n_balance_qty"
        -(if "s"."n_hold_qty" = "s"."n_godown_qty" then 0 else "s"."n_hold_qty" endif)-"s"."n_godown_qty",3),10,0)) as "n_qty",
        '' as "c_note",
        "TRIM"("STR"("TRUNCNUM"("i"."n_qty_per_box",3),10,0)) as "n_qty_per_box",
        "rack_mst"."c_group" as "c_rack_group"
        from "item_mst" as "i"
          join "pack_mst" on "pack_mst"."c_code" = "i"."c_pack_code"
          join "rack_mst" on "i"."c_rack_code" = "rack_mst"."c_code"
          left outer join "stock" as "s" on "s"."c_item_code" = "i"."c_code"
        where "i"."c_code" = @HdrData and "n_qty" <> 0 union all
      select 'In Process(Out Tray)' as "c_godown_code",
        '#'+"string"("count"(distinct "c_tray_Code")) as "c_rack",
        "itemcode" as "c_item_code",
        "itemname" as "c_item_name",
        "c_batch_no" as "c_batch_no",
        "n_mrp" as "n_mrp",
        "d_expiry_date" as "d_exp_dt",
        "TRIM"("STR"("TRUNCNUM"("sum"("n_qty"),3),10,0)) as "n_qty",
        '' as "c_note",
        "TRIM"("STR"("TRUNCNUM"("n_qty_per_box",3),10,0)) as "n_qty_per_box",
        "c_rack_group" as "c_rack_group"
        from(select "p"."c_tray_code",
            "i"."c_code" as "itemcode",
            "i"."c_name" as "itemname",
            "p"."c_batch_no",
            "s"."n_mrp",
            "s"."d_expiry_date",
            "p"."n_qty" as "n_qty",
            "i"."n_qty_per_box" as "n_qty_per_box",
            "rack_mst"."c_group" as "c_rack_group"
            from "st_track_pick" as "p"
              join "st_track_det" as "d" on "p"."c_doc_no" = "d"."c_doc_no"
              and "p"."n_org_seq" = "d"."n_seq"
              join "st_track_tray_move" on "st_track_tray_move"."c_doc_no" = "p"."c_doc_no"
              and "st_track_tray_move"."n_inout" = "p"."n_inout"
              and "st_track_tray_move"."c_tray_code" = "p"."c_tray_code"
              join "item_mst" as "i" on "p"."c_item_Code" = "i"."c_code"
              join "rack_mst" on "i"."c_rack_code" = "rack_mst"."c_code"
              join "stock" as "s" on "s"."c_item_code" = "i"."c_code"
              and "s"."c_batch_no" = "p"."c_batch_no"
            where "d"."n_complete" not in( 9,2 ) 
            and "d"."n_inout" = 0
            and "i"."c_code" = @HdrData) as "t"
        group by "t"."itemcode","t"."itemname","t"."c_batch_no","n_mrp","d_exp_dt","n_qty_per_box","c_rack_group"
        having "n_qty" <> 0 union
      select 'In Process(In Tray)' as "c_godown_code",
        '#'+"string"("count"(distinct "c_tray_Code")) as "c_rack",
        "itemcode" as "c_item_code",
        "itemname" as "c_item_name",
        "c_batch_no" as "c_batch_no",
        "n_mrp" as "n_mrp",
        "d_expiry_date" as "d_exp_dt",
        "TRIM"("STR"("TRUNCNUM"("sum"("n_qty"),3),10,0)) as "n_qty",
        '' as "c_note",
        "TRIM"("STR"("TRUNCNUM"("n_qty_per_box",3),10,0)) as "n_qty_per_box",
        "c_rack_group" as "c_rack_group"
        from(select "p"."c_tray_code",
            "i"."c_code" as "itemcode",
            "i"."c_name" as "itemname",
            "p"."c_batch_no",
            "s"."n_mrp",
            "s"."d_expiry_date",
            "p"."n_qty" as "n_qty",
            "i"."n_qty_per_box" as "n_qty_per_box",
            "rack_mst"."c_group" as "c_rack_group"
            from "st_track_in" as "p"
              join "item_mst" as "i" on "p"."c_item_Code" = "i"."c_code"
              join "rack_mst" on "i"."c_rack_code" = "rack_mst"."c_code"
              join "stock" as "s" on "s"."c_item_code" = "i"."c_code"
              and "s"."c_batch_no" = "p"."c_batch_no"
              and "i"."c_code" = @HdrData) as "t"
        group by "t"."itemcode","t"."itemname","c_batch_no","n_mrp","d_exp_dt","n_qty_per_box","c_rack_group"
        having "n_qty" <> 0 for xml raw,elements
    else
      select 'In Process(Out Tray)' as "c_godown_code",
        "c_tray_Code" as "c_rack",
        "t"."itemcode" as "c_item_code",
        "t"."itemname" as "c_item_name",
        "t"."c_batch_no" as "c_batch_no",
        "n_mrp" as "n_mrp",
        "d_expiry_date" as "d_exp_dt",
        "TRIM"("STR"("TRUNCNUM"("sum"("n_qty"),3),10,0)) as "n_qty",
        '' as "c_note",
        "TRIM"("STR"("TRUNCNUM"("n_qty_per_box",3),10,0)) as "n_qty_per_box",
        "rack_mst"."c_code" as "c_actual_rack",
        "rack_mst"."c_group" as "c_rack_group"
        from(select "p"."c_tray_code",
            "i"."c_code" as "itemcode",
            "i"."c_name" as "itemname",
            "p"."c_batch_no",
            "s"."n_mrp",
            "s"."d_expiry_date",
            "p"."n_qty" as "n_qty",
            "i"."n_qty_per_box" as "n_qty_per_box",
            "p"."c_godown_code" as "c_godown_code",
            "p"."c_doc_no" as "c_doc_no"
            from "st_track_pick" as "p"
              join "st_track_det" as "d" on "p"."c_doc_no" = "d"."c_doc_no"
              and "p"."n_org_seq" = "d"."n_seq"
              join "item_mst" as "i" on "p"."c_item_Code" = "i"."c_code"
              join "stock" as "s" on "s"."c_item_code" = "i"."c_code"
              and "s"."c_batch_no" = "p"."c_batch_no"
            where "d"."n_complete" not in( 9,2 ) 
            and "d"."n_inout" = 0
            and "i"."c_code" = @HdrData) as "t"
          ,"rack_mst"
        where "c_actual_rack" = "rack_mst"."c_code"
        group by "t"."itemcode","t"."itemname","t"."c_batch_no","n_mrp","d_exp_dt","n_qty_per_box","c_tray_Code","c_rack_group","c_actual_rack","c_godown_code"
        having "n_qty" <> 0 for xml raw,elements
    end if when 'item_filter' then
    select top 50 "a"."c_code" as "c_item_code",
      "a"."c_name" as "c_item_name",
      "isnull"("a"."c_rack_code",'') as "c_rack"
      from "item_mst" as "a"
      where("a"."c_code" = @HdrData or "a"."c_name" like @HdrData+'%') for xml raw,elements
  when 'change_rack' then
    --HdrData = ItemCode
    --DetData : @toRack
    set @toGodown = @GodownCode;
    set @toRack = @DetData;
    select "count"("c_code") into @nValidRack from "rack_mst" where "c_br_code" = @BrCode and "c_code" = @toRack;
    if @nValidRack <= 0 then
      select ' Error : Invalid Rack '+"string"(@toRack)+' for '+"c_name"+'' as "c_message"
        from "godown_mst" where "c_code" = @toGodown for xml raw,elements;
      return
    else
      select "count"("c_item_code") into @detItemCount from "st_track_det" where "c_item_code" = @HdrData and "n_complete" = 0 and "c_godown_code" = @toGodown;
      if @toGodown = '-' then
        update "item_mst_br_info"
          set "c_rack" = @toRack,"t_ltime" = @t_ltime,"d_ldate" = @d_ldate
          where "c_code" = @HdrData
          and "c_br_code" = @BrCode
      else
        update "item_mst_br_info_godown"
          set "c_rack" = @toRack,"t_ltime" = @t_ltime,"d_ldate" = @d_ldate
          where "c_code" = @HdrData
          and "c_br_code" = @BrCode
      end if; --GODOWN				
      if sqlstate = '00000' then
        if @detItemCount > 0 then
          update "st_track_det"
            set "c_rack" = @toRack
            where "c_item_code" = @HdrData
            and "n_complete" = 0
            and "c_godown_code" = @toGodown
        end if;
        commit work;
        select 'Success' as "c_message" for xml raw,elements;
        return
      else
        rollback work;
        select 'Failure' as "c_message" for xml raw,elements;
        return
      -- VALID RACK
      end if end if when 'get_item_status' then
    --http://192.168.250.183:14153/ws_st_dashboard?cIndex=get_item_status&HdrData=319787&DetData=5031&GodownCode=5031&gsbr=503
    set @toGodown = @GodownCode;
    select "c_item_code",
      "TRIM"("STR"("TRUNCNUM"("sum"("n_bal_qty"),3),10,0)) as "n_pend_qty",
      "string"("n_pend_qty")+' items are left to be picked from this Rack' as "c_message"
      into @cMessage,@cMessage,@cStoreOutPending
      from "st_track_det"
      where "n_complete" = 0
      and "n_inout" = 0
      and "c_godown_code" = @toGodown
      and "c_item_code" = @HdrData
      group by "c_item_Code";
    select "c_item_code",
      "TRIM"("STR"("TRUNCNUM"("sum"("n_qty"),3),10,0)) as "n_pend_qty",
      'Tray Nos. '+"string"("list"("c_tray_code"))+' have items to be put in this rack' as "c_message"
      into @cMessage,@cMessage,@cStoreInPending
      from "st_track_in"
      where "n_complete" = 9
      and "c_godown_code" = @toGodown
      and "c_item_code" = @HdrData
      group by "c_item_Code";
    if "length"(@cStoreOutPending+@cStoreInPending) > 1 and(@cStoreOutPending+@cStoreInPending) is not null then
      select @cStoreOutPending+@ColSep+@cStoreInPending+@ColSep as "c_message" for xml raw,elements
    else
      select 'Success' as "c_message" for xml raw,elements
    end if
  end case
end;