CREATE PROCEDURE "DBA"."usp_st_tray_pickup"( 
  -------------------------------------------------------------------------------------------------------------------------------
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
  /*
Author          : Anup 
Procedure       : usp_st_tray_pickup
SERVICE         : ws_storetrack
Date            : 25-09-2014
Service Call (Format): http://192.168.7.12:13000/ws_st_tray_pickup?devID=devID&sKey=KEY&UserId=MYBOSS&PhaseCode=&RackGrpCode=&StageCode=&cIndex=&HdrData=&DetData=
---------------------------------------------------------------------------------------------------------------------------------------------------------------
modified by             Ldate               Purpose                                         Input  / ticketno                             IndexDetails
---------------------------------------------------------------------------------------------------------------------------------------------------------------
Saneesh C G             15-06-2015          Store Track TRANSACTION to TAB/DESKTOP      devID~sKey~UserId~PhaseCode~RackGrpCode~        get_store_stage, get_rack_group StageCode~cIndex~HdrData~DetData
Pratheesh P             18-11-2021          Added n_flag and c_user                                                                     get_cust_tray_list
Pratheesh P             30-11-2021          changed tray_last_time from doc_track                                                       get_cust_tray_list
Pratheesh P             06-12-2021          ERROR showing tray_last_time from doc_track fixed                                           get_cust_tray_list
Pratheesh P             20-04-2022          Added new index get_stock_trfer_ack and showed minus stock     D24915                       get_stock_trfer_ack
Pratheesh P             27-04-2022          removed zero stocks only minus figure                          D24915                       get_stock_trfer_ack
Pratheesh P             28-04-2022          removed duplicate records                                      D24915                       get_stock_trfer_ack
---------------------------------------------------------------------------------------------------------------------------------------------------------------

*/
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
    "c_rack_grp_code" char(6) null,) on commit delete rows;
  --cIndex get_doc_list <<
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
  --cIndex set_selected_tray <<
  --cIndex get_batch_list <<
  declare @ItemCode char(6);
  declare @BatchNo char(20);
  --cIndex get_batch_list <<
  --cIndex setCounter >>
  declare @Counter char(100);
  --cIndex setCounter <<
  declare @doc_stage_code char(6);
  declare @enable_trayStatustime_change char(6);
  declare local temporary table "last_rack_grp"(
    "c_stage_code" char(6) null, --get_tray_items>>       
    "c_rack_grp_code" char(6) null,) on commit preserve rows;
  declare @Tray char(6);
  declare @nPickCount integer;
  declare @nInOutFlag integer;
  declare @nTrayType integer;
  declare @nCarton integer;
  declare @n_active integer;
  --get_tray_items<<
  --assign_to_counter>>
  declare "i" bigint;
  declare @nState integer;
  declare local temporary table "get_doc"(
    "c_sman_code" char(6) null,
    "sman_name" char(40) null,
    "c_cust_code" char(6) null,
    "c_doc_no" char(25) not null,
    "d_recv_date" date null,
    "c_route_sort" char(20) null,
    "n_urgent" numeric(4) null,
    "tray_last_time" time null,
    primary key("c_doc_no" asc),
    ) on commit preserve rows;
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
  --select top 1 c_user into @cUser from logon_det order by n_srno desc;
  case @cIndex
  when 'get_cust_tray_list' then
    --http://192.168.7.12:13000/ws_st_tray_pickup?devID=devID&sKey=KEY&UserId=MYBOSS&PhaseCode=PH0003&RackGrpCode=&StageCode=&cIndex=get_cust_tray_list&HdrData=&DetData=
    select "uf_sys_para_setup"('S00211','-','0',1) into @enable_trayStatustime_change;
    set @enable_trayStatustime_change = "isnull"(@enable_trayStatustime_change,0);
    if @enable_trayStatustime_change = 1 then
      select "uf_sys_para_setup"('S00211','-','0',2)
        into @doc_stage_code
    end if;
    select "n_active"
      into @n_active from "st_track_module_mst"
      where "st_track_module_mst"."c_code" = 'M00041'
      and "st_track_module_mst"."c_br_code" = @gsBr;
    if @n_active = 1 then
      --print 'active';
      insert into "get_doc"
        select "invoice_mst"."c_sman_code" as "c_sman_code",
          "sman_mst"."c_name" as "sman_name",
          "st_track_mst"."c_cust_code" as "c_cust_code",
          "st_track_mst"."c_doc_no" as "c_doc_no",
          "st_track_mst"."d_date" as "d_recv_date",
          "st_track_mst"."c_sort" as "c_route_sort",
          "st_track_mst"."n_urgent" as "n_urgent",
          "now"() as "tray_last_time"
          from "st_track_mst" join "invoice_mst" on "invoice_mst"."c_prefix" = "left"("substr"("substring"("left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))),"charindex"('/',"left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))))+1),"charindex"('/',"substring"("left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))),"charindex"('/',"left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))))+1))+1),"charindex"('/',"substr"("substring"("left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))),"charindex"('/',"left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))))+1),"charindex"('/',"substring"("left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))),"charindex"('/',"left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))))+1))+1))-1)
            and "invoice_mst"."n_srno" = cast("reverse"("left"("reverse"("st_track_mst"."c_doc_no"),"charindex"('/',("reverse"("st_track_mst"."c_doc_no")))-1)) as numeric(18))
            join "sman_mst" on "sman_mst"."c_code" = "invoice_mst"."c_sman_code"
          where "st_track_mst"."n_confirm" in( 1,2 ) union all
        select "ord_mst"."c_rep_code" as "c_sman_code",
          "sman_mst"."c_name" as "sman_name",
          "st_track_mst"."c_cust_code" as "c_cust_code",
          "st_track_mst"."c_doc_no" as "c_doc_no",
          "st_track_mst"."d_date" as "d_recv_date",
          "st_track_mst"."c_sort" as "c_route_sort",
          "st_track_mst"."n_urgent" as "n_urgent","now"()
          from "st_track_mst" join "ord_mst" on "ord_mst"."c_prefix" = "left"("substr"("substring"("left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))),"charindex"('/',"left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))))+1),"charindex"('/',"substring"("left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))),"charindex"('/',"left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))))+1))+1),"charindex"('/',"substr"("substring"("left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))),"charindex"('/',"left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))))+1),"charindex"('/',"substring"("left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))),"charindex"('/',"left"("st_track_mst"."c_doc_no",("length"("st_track_mst"."c_doc_no")-("charindex"('/',"reverse"("st_track_mst"."c_doc_no"))-1))))+1))+1))-1)
            and "ord_mst"."n_srno" = cast("reverse"("left"("reverse"("st_track_mst"."c_doc_no"),"charindex"('/',("reverse"("st_track_mst"."c_doc_no")))-1)) as numeric(18))
            join "sman_mst" on "sman_mst"."c_code" = "ord_mst"."c_rep_code"
          where "ord_mst"."n_invno" = 0 and "st_track_mst"."n_confirm" in( 1,2 ) ;
      --select * from get_doc;
      select "get_doc"."c_doc_no",
        "get_doc"."c_sman_code" as "c_sman_code",
        "get_doc"."sman_name" as "sman_name",
        "get_doc"."c_cust_code" as "c_cust_code",
        "act_mst"."c_name" as "c_cust_name",
        '' as "c_area_name",
        (select "count"(distinct "c_tray_code") from "st_track_tray_move" where "c_doc_no" = "tray_move"."c_doc_no") as "n_total_trays", -- excluding Unassigned trays
        (if "tray_move"."n_inout" = 9 then 1 else 0 endif) as "n_completed",
        "tray_move"."c_tray_code" as "c_tray",
        (select "c_name"+'['+"c_code"+']' as "c_stage" from "st_store_stage_mst" where "c_code" = "tray_move"."c_stage_code") as "c_stage",
        '' as "c_route",
        "tray_move"."n_flag" as "n_tray_state",
        '' as "c_counter",
        "d_recv_date",
        "c_route_sort",
        "get_doc"."n_urgent",
        if @enable_trayStatustime_change = 1 then
          (select "t_time" from "doc_track"
            where "doc_track"."c_inv_prefix" = "left"("substring"("substring"("get_doc"."c_doc_no","charindex"('/',"get_doc"."c_doc_no")+1),"charindex"('/',"substring"("get_doc"."c_doc_no","charindex"('/',"get_doc"."c_doc_no")+1))+1),"charindex"('/',"substring"("substring"("get_doc"."c_doc_no","charindex"('/',"get_doc"."c_doc_no")+1),"charindex"('/',"substring"("get_doc"."c_doc_no","charindex"('/',"get_doc"."c_doc_no")+1))+1))-1)
            and "doc_track"."n_inv_no" = "reverse"("left"("reverse"("get_doc"."c_doc_no"),"charindex"('/',"reverse"("get_doc"."c_doc_no"))-1))
            and "doc_track"."c_stage_code" = @doc_stage_code)
        else
          (if "tray_move"."n_flag" >= 0 and("tray_move"."n_inout" = 9 and "tray_move"."c_rack_grp_code" = '-') then "t_time" else "now"() endif)
        endif as "tray_last_time",
        "tray_move"."n_flag" as "n_tray_status","tray_move"."c_user"
        from "get_doc"
          join "st_track_tray_move" as "tray_move" on "get_doc"."c_doc_no" = "tray_move"."c_doc_no"
          and "isnull"("tray_move"."c_godown_code",'-') = @GodownCode
          and "tray_move"."n_inout" not in( 1,8 ) 
          join "act_mst" on "act_mst"."c_code" = "c_cust_code" union all //changes
      select "uas_list"."c_doc_no",
        "get_doc"."c_sman_code",
        "get_doc"."sman_name",
        "uas_list"."c_cust_code",
        "uas_list"."c_cust_name" as "c_cust_name",
        "uas_list"."c_area_name" as "c_area_name",
        "uas_list"."n_total_trays" as "n_total_trays", -- excluding Unassigned trays
        "uas_list"."n_completed" as "n_completed",
        "uas_list"."c_tray" as "c_tray",
        (select "c_name"+'['+"c_code"+']' as "c_stage" from "st_store_stage_mst" where "c_code" = "uas_list"."c_stage_code") as "c_stage",
        "isnull"("uas_list"."c_route",'') as "c_route",
        0 as "n_tray_state",
        "uas_list"."c_counter" as "c_counter",
        "uas_list"."d_date" as "d_recv_date",
        "uas_list"."c_sort" as "c_route_sort",
        "uas_list"."n_urgent" as "n_urgent",
        "now"() as "tray_last_time",
        "uas_list"."n_tray_status","uas_list"."c_user"
        --            (if "tray_move"."n_flag" > 0 and("tray_move"."n_inout" = 9 and "tray_move"."c_rack_grp_code" = '-') then "t_time" else "now"() endif) as "tray_last_time",
        from(select distinct "st_track_det"."c_stage_code" as "c_stage_code",
            "st_track_mst"."c_doc_no" as "c_doc_no",
            "cust"."c_code" as "c_cust_code",
            "cust"."c_name" as "c_cust_name",
            "area_mst"."c_name" as "c_area_name",
            (select "count"(distinct "c_tray_code") from "st_track_tray_move" where "c_doc_no" = "tray_move"."c_doc_no") as "n_total_trays",
            0 as "n_completed",
            'UA-'+"isnull"("c_stage_code",'NULL') as "c_tray",
            ("route_mst"."c_name") as "c_route",
            "isnull"("st_track_mst"."c_system_name",'') as "c_counter",
            "st_track_mst"."d_date" as "d_date",
            "st_track_mst"."c_sort" as "c_sort",
            "st_track_mst"."n_urgent" as "n_urgent",
            "tray_move"."n_flag" as "n_tray_status","tray_move"."c_user"
            from "st_track_mst"
              left outer join "st_track_tray_move" as "tray_move" on "tray_move"."c_doc_no" = "st_track_mst"."c_doc_no"
              join "act_mst" as "cust" on "cust"."c_code" = "isnull"("st_track_mst"."c_cust_code",'GC01')
              left outer join "route_mst" on "isnull"("cust"."c_route_code",'-') = "route_mst"."c_code"
              join "area_mst" on "area_mst"."c_code" = "cust"."c_area_code"
              join "DBA"."st_track_det" on "st_track_det"."c_doc_no" = "st_track_mst"."c_doc_no"
              and "st_track_det"."n_inout" = "st_track_mst"."n_inout"
            where "route_mst"."c_code" = (if '' = '' then "route_mst"."c_code" else '' endif)
            and "st_track_det"."c_tray_code" is null
            and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode
            and "st_track_mst"."n_confirm" = 1
            and "st_track_mst"."n_inout" not in( 1,8 ) ) as "uas_list" join "get_doc" on "get_doc"."c_doc_no" = "uas_list"."c_doc_no"
        --  order by c_route_sort asc,n_urgent asc,n_completed desc,c_tray asc for xml raw,elements
        order by "n_total_trays" asc for xml raw,elements
    else if @GodownCode = '-' then
        select "tray_move"."c_doc_no" as "c_doc_no",
          "cust"."c_code" as "c_cust_code",
          "cust"."c_name" as "c_cust_name",
          "area_mst"."c_name" as "c_area_name",
          (select "count"(distinct "c_tray_code") from "st_track_tray_move" where "c_doc_no" = "tray_move"."c_doc_no") as "n_total_trays", -- excluding Unassigned trays
          (if "tray_move"."n_inout" = 9 then 1 else 0 endif) as "n_completed",
          "tray_move"."c_tray_code" as "c_tray",
          (select "c_name"+'['+"c_code"+']' as "c_stage" from "st_store_stage_mst" where "c_code" = "tray_move"."c_stage_code") as "c_stage",
          "isnull"("route_mst"."c_name",'') as "c_route",
          "tray_move"."n_flag" as "n_tray_state",
          "isnull"("st_track_mst"."c_system_name",'') as "c_counter",
          "st_track_mst"."d_date" as "d_recv_date",
          "st_track_mst"."c_sort" as "c_route_sort",
          "st_track_mst"."n_urgent" as "n_urgent",
          if @enable_trayStatustime_change = 1 then
            (select "t_time" from "doc_track"
              where "doc_track"."c_inv_prefix" = "left"("substring"("substring"("get_doc"."c_doc_no","charindex"('/',"get_doc"."c_doc_no")+1),"charindex"('/',"substring"("get_doc"."c_doc_no","charindex"('/',"get_doc"."c_doc_no")+1))+1),"charindex"('/',"substring"("substring"("get_doc"."c_doc_no","charindex"('/',"get_doc"."c_doc_no")+1),"charindex"('/',"substring"("get_doc"."c_doc_no","charindex"('/',"get_doc"."c_doc_no")+1))+1))-1)
              and "doc_track"."n_inv_no" = "reverse"("left"("reverse"("get_doc"."c_doc_no"),"charindex"('/',"reverse"("get_doc"."c_doc_no"))-1))
              and "doc_track"."c_stage_code" = @doc_stage_code)
          else
            (if "tray_move"."n_flag" > 0 then "t_time" else "now"() endif)
          endif as "tray_last_time",
          "tray_move"."n_flag" as "n_tray_status","tray_move"."c_user"
          from "st_track_tray_move" as "tray_move"
            join "st_track_mst" on "tray_move"."c_doc_no" = "st_track_mst"."c_doc_no" --AND st_track_mst.n_complete <> 9
            join "act_mst" as "cust" on "cust"."c_code" = "isnull"("st_track_mst"."c_cust_code",'GC01')
            left outer join "route_mst" on "isnull"("cust"."c_route_code",'-') = "route_mst"."c_code"
            join "area_mst" on "area_mst"."c_code" = "cust"."c_area_code"
          where "route_mst"."c_code" = (if @HdrData = '' then "route_mst"."c_code" else @HdrData endif)
          and "isnull"("tray_move"."c_godown_code",'-') = @GodownCode
          and "tray_move"."n_inout" not in( 1,8 ) union --and  st_track_mst.c_doc_no='000/18/I/1800073001203046' 
        -- tray unassigned documents
        select "uas_list"."c_doc_no",
          "uas_list"."c_cust_code",
          "uas_list"."c_cust_name" as "c_cust_name",
          "uas_list"."c_area_name" as "c_area_name",
          "uas_list"."n_total_trays" as "n_total_trays", -- excluding Unassigned trays
          "uas_list"."n_completed" as "n_completed",
          "uas_list"."c_tray" as "c_tray",
          (select "c_name"+'['+"c_code"+']' as "c_stage" from "st_store_stage_mst" where "c_code" = "uas_list"."c_stage_code") as "c_stage",
          "isnull"("uas_list"."c_route",'') as "c_route",
          0 as "n_tray_state",
          "uas_list"."c_counter" as "c_counter",
          "uas_list"."d_date" as "d_recv_date",
          "uas_list"."c_sort" as "c_route_sort",
          "uas_list"."n_urgent" as "n_urgent",
          "now"() as "tray_last_time",
          "uas_list"."n_tray_status","uas_list"."c_user"
          --(if "tray_move"."n_flag" >= 0 then "t_time" else "now"() endif) as "tray_last_time",
          from(select distinct "st_track_det"."c_stage_code" as "c_stage_code",
              "st_track_mst"."c_doc_no" as "c_doc_no",
              "cust"."c_code" as "c_cust_code",
              "cust"."c_name" as "c_cust_name",
              "area_mst"."c_name" as "c_area_name",
              (select "count"(distinct "c_tray_code") from "st_track_tray_move" where "c_doc_no" = "tray_move"."c_doc_no") as "n_total_trays",
              0 as "n_completed",
              'UA-'+"isnull"("c_stage_code",'NULL') as "c_tray",
              ("route_mst"."c_name") as "c_route",
              "isnull"("st_track_mst"."c_system_name",'') as "c_counter",
              "st_track_mst"."d_date" as "d_date",
              "st_track_mst"."c_sort" as "c_sort",
              "st_track_mst"."n_urgent" as "n_urgent",
              "tray_move"."n_flag" as "n_tray_status","tray_move"."c_user"
              from "st_track_mst"
                left outer join "st_track_tray_move" as "tray_move" on "tray_move"."c_doc_no" = "st_track_mst"."c_doc_no"
                join "act_mst" as "cust" on "cust"."c_code" = "isnull"("st_track_mst"."c_cust_code",'GC01')
                left outer join "route_mst" on "isnull"("cust"."c_route_code",'-') = "route_mst"."c_code"
                join "area_mst" on "area_mst"."c_code" = "cust"."c_area_code"
                join "DBA"."st_track_det" on "st_track_det"."c_doc_no" = "st_track_mst"."c_doc_no"
                and "st_track_det"."n_inout" = "st_track_mst"."n_inout"
              where "route_mst"."c_code" = (if @HdrData = '' then "route_mst"."c_code" else @HdrData endif)
              and "st_track_det"."c_tray_code" is null
              and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode
              and "st_track_mst"."n_confirm" = 1
              and "st_track_mst"."n_inout" not in( 1,8 ) ) as "uas_list"
          order by 13 asc,14 asc,11 desc,6 desc,7 asc for xml raw,elements /*date*/ /*c_route_sort*/ /*n_tray_state*/ /*n_completed*/ /*c_tray*/
      else
        --union godown assigned trays
        --print 'gdwn_assin';
        select distinct "tray_move"."c_doc_no" as "c_doc_no",
          "cust"."c_code" as "c_cust_code",
          "cust"."c_name" as "c_cust_name",
          '' as "c_area_name",
          (select "count"(distinct "c_tray_code") from "st_track_tray_move" where "c_doc_no" = "tray_move"."c_doc_no") as "n_total_trays", -- excluding Unassigned trays
          (if "tray_move"."n_inout" = 9 then 1 else 0 endif) as "n_completed",
          "tray_move"."c_tray_code" as "c_tray",
          (select "c_name"+'['+"c_code"+']' as "c_stage" from "st_store_stage_mst" where "c_code" = "tray_move"."c_stage_code") as "c_stage",
          '' as "c_route",
          "tray_move"."n_flag" as "n_tray_state",
          "isnull"("st_track_mst"."c_system_name",'') as "c_counter",
          "st_track_mst"."d_date" as "d_recv_date",
          "st_track_mst"."c_sort" as "c_route_sort",
          "st_track_mst"."n_urgent" as "n_urgent",
          if @enable_trayStatustime_change = 1 then
            (select "t_time" from "doc_track"
              where "doc_track"."c_inv_prefix" = "left"("substring"("substring"("get_doc"."c_doc_no","charindex"('/',"get_doc"."c_doc_no")+1),"charindex"('/',"substring"("get_doc"."c_doc_no","charindex"('/',"get_doc"."c_doc_no")+1))+1),"charindex"('/',"substring"("substring"("get_doc"."c_doc_no","charindex"('/',"get_doc"."c_doc_no")+1),"charindex"('/',"substring"("get_doc"."c_doc_no","charindex"('/',"get_doc"."c_doc_no")+1))+1))-1)
              and "doc_track"."n_inv_no" = "reverse"("left"("reverse"("get_doc"."c_doc_no"),"charindex"('/',"reverse"("get_doc"."c_doc_no"))-1))
              and "doc_track"."c_stage_code" = @doc_stage_code)
          else
            (if "tray_move"."n_flag" > 0 then "t_time" else "now"() endif)
          endif as "tray_last_time",
          "tray_move"."n_flag" as "n_tray_status","tray_move"."c_user"
          from "st_track_tray_move" as "tray_move"
            join "st_track_mst" on "tray_move"."c_doc_no" = "st_track_mst"."c_doc_no"
            join "godown_mst" as "cust" on "cust"."c_code" = "isnull"("tray_move"."c_godown_code",'-') and "cust"."c_ref_br_code" in( '000',@gsBr ) 
          where "isnull"("tray_move"."c_godown_code",'-') = @GodownCode
          and "tray_move"."n_inout" not in( 1,8 ) union
        -- godown unassigned trays
        select "uas_list"."c_doc_no", --1
          "uas_list"."c_cust_code", --2
          "uas_list"."c_cust_name" as "c_cust_name", --3
          "uas_list"."c_area_name" as "c_area_name", --4
          "uas_list"."n_total_trays" as "n_total_trays", -- 5 excluding Unassigned trays
          "uas_list"."n_completed" as "n_completed", --6
          "uas_list"."c_tray" as "c_tray", --7
          (select "c_name"+'['+"c_code"+']' as "c_stage" from "st_store_stage_mst" where "c_code" = "uas_list"."c_stage_code") as "c_stage", --8
          "isnull"("uas_list"."c_route",'') as "c_route", --9
          0 as "n_tray_state", --10
          "uas_list"."c_counter" as "c_counter", --11
          "uas_list"."d_date" as "d_recv_date", --12
          "uas_list"."c_sort" as "c_route_sort", --13
          "uas_list"."n_urgent" as "n_urgent", --14
          "now" as "tray_last_time",
          "uas_list"."n_tray_status","uas_list"."c_user"
          from(select distinct "st_track_det"."c_stage_code" as "c_stage_code",
              "st_track_mst"."c_doc_no" as "c_doc_no",
              "cust"."c_code" as "c_cust_code",
              "cust"."c_name" as "c_cust_name",
              '' as "c_area_name",
              0 as "n_total_trays",
              0 as "n_completed",
              'UA-'+"c_stage_code" as "c_tray",
              '-' as "c_route",
              "isnull"("st_track_mst"."c_system_name",'') as "c_counter",
              "st_track_mst"."d_date" as "d_date",
              "st_track_mst"."c_sort" as "c_sort",
              "st_track_mst"."n_urgent" as "n_urgent",
              0 as "n_tray_status","st_track_mst"."c_user"
              from "st_track_mst"
                join "DBA"."st_track_det" on "st_track_det"."c_doc_no" = "st_track_mst"."c_doc_no"
                and "st_track_det"."n_inout" = "st_track_mst"."n_inout"
                and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode
                join "godown_mst" as "cust" on "cust"."c_code" = "isnull"("st_track_det"."c_godown_code",'-') and "cust"."c_ref_br_code" in( '000',@gsBr ) 
              where "st_track_det"."c_tray_code" is null
              and "isnull"("st_track_det"."c_godown_code",'-') = @GodownCode
              and "st_track_mst"."n_confirm" = 1
              and "st_track_mst"."n_inout" not in( 1,8 ) ) as "uas_list"
          order by 13 asc,14 asc,11 desc,6 desc,7 asc for xml raw,elements
      end if end if when 'search_tray' then
    --http://192.168.7.12:13000/ws_st_tray_pickup?devID=devID&sKey=KEY&UserId=MYBOSS&PhaseCode=PH0003&RackGrpCode=&StageCode=&cIndex=search_tray&HdrData=&DetData=T00001
    --i/p : @DetData = Tray code, nStoreIn = 1 - store in tray , 0 - other 
    if @nStoreIn = 0 then
      select top 1 "tm"."c_tray_code" as "c_tray_no",
        (select(if "n_in_out_flag" = 1 then 'INTERNAL' else(if "n_in_out_flag" = 0 then 'EXTERNAL' else(if "n_in_out_flag" = 2 then 'INTERNAL/EXTERNAL' else 'TEMPORARY TRAY' endif) endif) endif) from "st_tray_mst" where "c_code" = "tm"."c_tray_code") as "c_tray_type",
        (select "list"("c_rack_grp_code") from "st_track_tray_move" where "c_tray_code" = "tm"."c_tray_code") as "rack_grp_code",
        --tm.c_user as curr_user,
        "isnull"("ddds_user_mst"."c_used_by",'AUTO') as "curr_user",
        (if "tm"."n_inout" = 9 then 1 else 0 endif) as "n_completed",
        "tm"."c_doc_no" as "c_doc_no",
        "tm"."c_stage_code" as "c_stage_code"
        from "st_track_tray_move" as "tm" join "ddds_user_mst" on "ddds_user_mst"."c_user_id" = "tm"."c_user"
        where "tm"."c_tray_code" = @DetData
        order by "n_completed" desc for xml raw,elements
    else
      if(select "count"() from "st_track_tray_move" as "tm" where "c_tray_code" = @DetData) > 0 then
        select top 1 "tm"."c_tray_code" as "c_tray_no",
          (select(if "n_in_out_flag" = 1 then 'INTERNAL' else(if "n_in_out_flag" = 0 then 'EXTERNAL' else(if "n_in_out_flag" = 2 then 'INTERNAL/EXTERNAL' else 'TEMPORARY TRAY' endif) endif) endif) from "st_tray_mst" where "c_code" = "tm"."c_tray_code") as "c_tray_type",
          (select "list"("c_rack_grp_code") from "st_track_tray_move" where "c_tray_code" = "tm"."c_tray_code") as "rack_grp_code",
          --isnull(tm.c_user,'') as curr_user,
          "isnull"("ddds_user_mst"."c_used_by",'') as "curr_user",
          (if "tm"."n_inout" = 9 then 1 else 0 endif) as "n_completed",
          "tm"."c_doc_no" as "c_doc_no",
          "tm"."c_stage_code" as "c_stage_code"
          from "st_track_tray_move" as "tm" join "ddds_user_mst" on "ddds_user_mst"."c_user_id" = "tm"."c_user"
          where "tm"."c_tray_code" = @DetData
          order by "n_completed" desc for xml raw,elements
      else
        select top 1 "tm"."c_tray_code" as "c_tray_no",
          (select(if "n_in_out_flag" = 1 then 'INTERNAL' else(if "n_in_out_flag" = 0 then 'EXTERNAL' else(if "n_in_out_flag" = 2 then 'INTERNAL/EXTERNAL' else 'TEMPORARY TRAY' endif) endif) endif) from "st_tray_mst" where "c_code" = "tm"."c_tray_code") as "c_tray_type",
          "list"(distinct "c_rack_grp_code") as "rack_grp_code",
          --isnull(tm.c_user,'') as curr_user,
          "isnull"("ddds_user_mst"."c_used_by",'') as "curr_user",
          "tm"."n_complete" as "n_completed",
          "tm"."c_doc_no" as "c_doc_no",
          "tm"."c_stage_code" as "c_stage_code"
          from "st_track_det" as "tm" join "ddds_user_mst" on "ddds_user_mst"."c_user_id" = "curr_user"
          where "tm"."c_tray_code" = @DetData and "n_complete" = 0
          group by "c_doc_no","c_tray_no","c_tray_type","curr_user","c_stage_code","n_completed"
          order by "n_completed" desc for xml raw,elements
      end if end if when 'route_mst' then
    select "c_name",
      "c_code",
      0 as "n_route_no"
      from "route_mst" for xml raw,elements
  when 'get_doc_tray_list' then
    --http://192.168.7.12:14109/ws_st_tray_pickup?GodownCode=-devID=devID&sKey=KEY&UserId=MYBOSS&PhaseCode=PH0003&RackGrpCode=&StageCode=&cIndex=get_doc_tray_list&HdrData=109**14**S**146127**&DetData=
    --@HdrData  : 1 Tranbrcode~2 TranYear~3 TranPrefix~4 TranSrno
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
    set @DocNo = @Tranbrcode+'/'+@TranYear+'/'+@TranPrefix+'/'+"string"(@TranSrno);
    select "tray_move"."c_doc_no" as "c_doc_no",
      "cust"."c_code" as "c_cust_code",
      "cust"."c_name" as "c_cust_name",
      "area_mst"."c_name" as "c_area_name",
      (select "count"(distinct "c_tray_code") from "st_track_tray_move" where "c_doc_no" = "tray_move"."c_doc_no") as "n_total_trays",
      (if "tray_move"."n_inout" = 9 then 1 else 0 endif) as "n_completed",
      "tray_move"."c_tray_code" as "c_tray",
      '-' as "c_region_name",
      '-' as "c_zone_name",
      (select "c_name"+'['+"c_code"+']' as "c_stage" from "st_store_stage_mst" where "c_code" = "tray_move"."c_stage_code") as "c_stage",
      (if "st_track_mst"."n_complete" = 9 then 1 else 0 endif) as "n_packing_completed"
      from "st_track_tray_move" as "tray_move"
        join "st_track_mst" on "tray_move"."c_doc_no" = "st_track_mst"."c_doc_no" --AND st_track_mst.n_complete <> 9
        join "act_mst" as "cust" on "cust"."c_code" = "isnull"("st_track_mst"."c_cust_code",'GC01')
        join "area_mst" on "area_mst"."c_code" = "cust"."c_area_code"
      --join region_mst on area_mst.c_region_code = region_mst.c_code
      --join zone_mst on zone_mst.c_code = region_mst.c_zone_code
      where "st_track_mst"."c_doc_no" = @DocNo
      and "tray_move"."c_godown_code" = @GodownCode for xml raw,elements
  when 'get_route' then
    update "st_track_tray_move" set "n_flag" = 4,"t_time" = "now"() where "c_tray_code" = @HdrData;
    commit work;
    select "isnull"("route_mst"."n_route_no",0) as "n_route_no"
      from "st_track_mst"
        join "st_track_tray_move" as "tray_move" on "tray_move"."c_doc_no" = "st_track_mst"."c_doc_no"
        and "c_tray_code" = @HdrData
        left outer join "act_mst" as "route" on "route"."c_route_code" = "st_track_mst"."c_br_code"
        and "route"."c_code" = "st_track_mst"."c_cust_code"
        left outer join "route_mst" on "isnull"("route"."c_route_code",'-') = "route_mst"."c_code" for xml raw,elements
  when 'storein_tray_status' then
    --http://192.168.250.162:14153/ws_st_tray_pickup?GodownCode=-&devID=devID&sKey=KEY&UserId=MYBOSS&PhaseCode=PH0003&RackGrpCode=&StageCode=&cIndex=storein_tray_status&HdrData=&DetData=
    select distinct "det"."c_doc_no" as "c_doc_no",
      "det"."c_tray_code" as "c_tray_code",
      "det"."c_stage_code" as "c_stage_code",
      (select "count"("c_item_code") from "st_track_det" where "c_doc_no" = "det"."c_doc_no" and "n_inout" = "det"."n_inout") as "n_item_count",
      (select "count"("c_item_code") from "st_track_det" where "c_doc_no" = "det"."c_doc_no" and "n_inout" = "det"."n_inout" and "det"."n_complete" = 1) as "n_item_processed_count"
      from "st_track_det" as "det"
        left outer join "st_track_tray_move" as "tray_move" on "tray_move"."c_doc_no" = "det"."c_doc_no"
        and "tray_move"."n_inout" = "det"."n_inout"
      where "isnull"("det"."c_godown_code",'-') = @GodownCode
      and "det"."n_inout" = 1
      and "det"."n_complete" not in( 8,2 ) 
      order by "c_stage_code" asc for xml raw,elements
  when 'set_counter' then
    --@HdrData  : 1 DocNo~4 TranSrno
    --1 DocNo
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @DocNo = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --message 'DocNo '+@DocNo type warning to client;
    --2 Counter
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @Counter = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --message 'Counter '+string(@Counter ) type warning to client;
    --set @DocNo = @Tranbrcode+'/'+@TranYear+'/'+@TranPrefix+'/'+string(@TranSrno);
    if(select "count"("c_doc_no") from "st_track_mst" where "c_doc_no" = @DocNo) > 0 then
      update "st_track_mst" set "c_system_name" = @Counter where "c_doc_no" = @DocNo;
      commit work;
      select 'Success' as "c_message" for xml raw,elements
    else
      select 'Warning!! : Invalid Doc No.' as "c_message" for xml raw,elements
    end if when 'get_tray_items' then
    --@HdrData : Tray 
    --@DetData : Carton flag (0/1)
    set @Tray = @HdrData;
    set @nCarton = @DetData;
    if(select "count"("c_code") from "st_tray_mst" where "c_code" = @Tray and "n_cancel_flag" = 0) = 0 and @nCarton = 0 then
      select 'Invalid Tray!!' as "c_message" for xml raw,elements;
      return
    else
      if @nCarton = 1 then
        set @nTrayType = 0
      else
        select "n_in_out_flag" -- 1- internal , 0 - external, 2 - temporary
          into @nTrayType from "st_tray_mst" where "c_code" = @Tray
      end if;
      if @nTrayType = 0 then --external tray
        if @nCarton = 1 then --CARTON
          select top 1 "c_br_code"+'/'+"c_year"+'/'+"c_prefix"+'/'+"string"("n_srno") as "c_doc_no"
            into @DocNo from "carton_mst" where "n_carton_no" <> 0 order by "t_ltime" desc;
          select "c_br_code"+'/'+"c_year"+'/'+"c_prefix"+'/'+"string"("n_srno") as "c_doc_no",
            "c_item_code" as "c_item_code",
            "c_batch_no" as "c_batch_no",
            "n_qty" as "n_qty",
            "n_qty_per_box" as "n_qty_per_box",
            "item_mst"."c_name"+"uf_st_get_pack_name"("pack_mst"."c_name") as "c_item_name",
            'CARTON' as "c_tray_type"
            from "carton_mst"
              join "item_mst" on "c_item_code" = "item_mst"."c_code"
              join "pack_mst" on "pack_mst"."c_code" = "item_mst"."c_pack_code"
            where "n_carton_no" = @Tray
            and "c_br_code"+'/'+"c_year"+'/'+"c_prefix"+'/'+"string"("n_srno") = @DocNo for xml raw,elements
        else
          -- EXTERNAL TRAY
          select top 1 "c_br_code"+'/'+"c_year"+'/'+"c_prefix"+'/'+"string"("n_srno") as "c_doc_no"
            into @DocNo from "carton_mst" order by "t_ltime" desc;
          select "c_br_code"+'/'+"c_year"+'/'+"c_prefix"+'/'+"string"("n_srno") as "c_doc_no",
            "c_item_code" as "c_item_code",
            "c_batch_no" as "c_batch_no",
            "n_qty" as "n_qty",
            "n_qty_per_box" as "n_qty_per_box",
            "item_mst"."c_name"+"uf_st_get_pack_name"("pack_mst"."c_name") as "c_item_name",
            'EXTERNAL' as "c_tray_type"
            from "carton_mst"
              join "item_mst" on "c_item_code" = "item_mst"."c_code"
              join "pack_mst" on "pack_mst"."c_code" = "item_mst"."c_pack_code"
            where "c_tray_code" = @Tray
            and "c_br_code"+'/'+"c_year"+'/'+"c_prefix"+'/'+"string"("n_srno") = @DocNo for xml raw,elements
        --internal  tray
        end if
      else select top 1 "c_doc_no" into @DocNo from "st_track_tray_move" where "c_tray_code" = @Tray order by "t_time" desc;
        select top 1 "n_inout" into @nInOutFlag from "st_track_tray_move" where "c_tray_code" = @Tray order by "t_time" desc;
        if @nInOutFlag is null and(select "count"() from "st_track_in" where "c_tray_code" = @Tray) > 0 then
          set @nInOutFlag = 1
        end if;
        select "count"("c_doc_no") into @nPickCount from "st_track_pick" where "c_doc_no" = @DocNo and "c_tray_code" = @Tray;
        if @nPickCount = 0 and @nInOutFlag = 1 then --store in tray
          if @DocNo is null then
            select "st_track_in"."c_doc_no" as "c_doc_no",
              1 as "n_inout",
              "item_mst"."c_code" as "c_item_code",
              "isnull"("st_track_in"."c_batch_no",'') as "c_batch_no",
              "st_track_in"."n_seq" as "n_seq",
              "TRIM"("STR"("TRUNCNUM"("st_track_in"."n_qty",3),10,0)) as "n_qty",
              "TRIM"("STR"("TRUNCNUM"("st_track_in"."n_qty",3),10,0)) as "n_bal_qty",
              "st_track_in"."c_rack_code" as "c_rack",
              "st_track_in"."c_rack_grp_code" as "c_rack_grp_code",
              (select "max"("c_stage_code") from "st_store_stage_det" where "c_rack_grp_code" = "c_rack_grp_code") as "c_stage_code",
              0 as "n_completed",
              "st_track_in"."c_tray_code" as "c_tray_code",
              "item_mst"."c_name"+"uf_st_get_pack_name"("pack_mst"."c_name") as "c_item_name",
              '' as "d_exp_dt",
              0 as "n_mrp",
              "item_mst"."n_qty_per_box" as "n_qty_per_box",
              '' as "c_message",
              '' as "c_mov_user",
              "st_track_in"."c_user" as "c_picked_user",
              'INTERNAL' as "c_tray_type"
              from "st_track_in"
                join "item_mst" on "st_track_in"."c_item_code" = "item_mst"."c_code"
                join "pack_mst" on "pack_mst"."c_code" = "item_mst"."c_pack_code"
              where "st_track_in"."c_tray_code" = @Tray
              order by "c_rack" asc for xml raw,elements
          else --if @DocNo is null then
            select "st_track_det"."c_doc_no" as "c_doc_no",
              "st_track_det"."n_inout" as "n_inout",
              "item_mst"."c_code" as "c_item_code",
              "isnull"("st_track_det"."c_batch_no",'') as "c_batch_no",
              "st_track_det"."n_seq" as "n_seq",
              "TRIM"("STR"("TRUNCNUM"("st_track_det"."n_qty",3),10,0)) as "n_qty",
              "TRIM"("STR"("TRUNCNUM"("st_track_det"."n_bal_qty",3),10,0)) as "n_bal_qty",
              "st_track_det"."c_rack" as "c_rack",
              "st_track_det"."c_rack_grp_code" as "c_rack_grp_code",
              "st_track_det"."c_stage_code" as "c_stage_code",
              0 as "n_completed",
              "st_track_det"."c_tray_code" as "c_tray_code",
              "item_mst"."c_name"+"uf_st_get_pack_name"("pack_mst"."c_name") as "c_item_name",
              '' as "d_exp_dt",
              0 as "n_mrp",
              "item_mst"."n_qty_per_box" as "n_qty_per_box",
              '' as "c_message",
              '' as "c_mov_user",
              -- st_track_det.c_user as c_picked_user,
              "ddds_user_mst"."c_used_by" as "c_picked_user",
              'INTERNAL' as "c_tray_type"
              from "st_track_det" join "ddds_user_mst" on "ddds_user_mst"."c_user_id" = "st_track_det"."c_user"
                join "item_mst" on "st_track_det"."c_item_code" = "item_mst"."c_code"
                join "pack_mst" on "pack_mst"."c_code" = "item_mst"."c_pack_code"
              where "st_track_det"."c_doc_no" = @DocNo
              and "st_track_det"."c_tray_code" = @Tray
              and "st_track_det"."n_non_pick_flag" = 0
              order by "c_rack" asc for xml raw,elements
          --store out tray 
          --if @DocNo is null then
          end if
        elseif @nPickCount > 0 then
          select "st_track_pick"."c_doc_no" as "c_doc_no",
            "st_track_pick"."n_inout" as "n_inout",
            "item_mst"."c_code" as "c_item_code",
            "isnull"("st_track_pick"."c_batch_no",'') as "c_batch_no",
            "st_track_pick"."n_seq" as "n_seq",
            "TRIM"("STR"("TRUNCNUM"("st_track_pick"."n_qty",3),10,0)) as "n_qty",
            "st_track_pick"."c_rack" as "c_rack",
            "st_track_pick"."c_rack_grp_code" as "c_rack_grp_code",
            "st_track_pick"."c_stage_code" as "c_stage_code",
            (if "tray_move"."n_inout" = 9 then 1 else 0 endif) as "n_completed",
            "st_track_pick"."c_tray_code" as "c_tray_code",
            "item_mst"."c_name"+"uf_st_get_pack_name"("pack_mst"."c_name") as "c_item_name",
            "date"("isnull"("stock"."d_expiry_date",'')) as "d_exp_dt",
            "TRIM"("STR"("TRUNCNUM"("stock"."n_mrp",3),10,3)) as "n_mrp",
            "item_mst"."n_qty_per_box" as "n_qty_per_box",
            '' as "c_message",
            "tray_move"."c_user" as "c_mov_user",
            -- st_track_pick.c_user as c_picked_user,
            "ddds_user_mst"."c_used_by" as "c_picked_user",
            'INTERNAL' as "c_tray_type"
            from "st_track_pick" join "ddds_user_mst" on "ddds_user_mst"."c_user_id" = "st_track_pick"."c_user"
              join "item_mst" on "st_track_pick"."c_item_code" = "item_mst"."c_code"
              join "pack_mst" on "pack_mst"."c_code" = "item_mst"."c_pack_code"
              join "stock" on "st_track_pick"."c_item_code" = "stock"."c_item_code"
              and "st_track_pick"."c_batch_no" = "stock"."c_batch_no"
              join "st_track_tray_move" as "tray_move" on "tray_move"."c_tray_code" = "st_track_pick"."c_tray_code"
              and "tray_move"."c_doc_no" = "st_track_pick"."c_doc_no"
              and "tray_move"."c_stage_code" = "st_track_pick"."c_stage_code"
            where "st_track_pick"."c_doc_no" = @DocNo
            and "st_track_pick"."c_tray_code" = @Tray
            and "st_track_pick"."n_non_pick_flag" = 0
            order by "c_rack" asc for xml raw,elements
        else
          select 'No items are confirmed for the tray : '+@Tray as "c_message" for xml raw,elements
        end if end if end if when 'assign_to_counter' then
    set "i" = 1;
    while "HTTP_VARIABLE"('HdrData',"i") is not null or "HTTP_VARIABLE"('HdrData',"i") <> '' loop
      set @Tray = "HTTP_VARIABLE"('HdrData',"i");
      set @nState = "HTTP_VARIABLE"('nState',"i");
      update "st_track_tray_move"
        set "n_flag" = @nState,
        "t_time" = "now"(),
        "c_user" = @UserId
        where "c_tray_code" = @Tray;
      set "i" = "i"+1
    end loop;
    if sqlstate = '00000' then
      commit work;
      select 'SUCCESS' as "c_message" for xml raw,elements
    else
      rollback work;
      select 'FAILURE' as "c_message" for xml raw,elements
    end if when 'get_stock_trfer_ack' then
    select "rack_group","rack","mfac_name","item_name","batchs","minus_qty","rack_transfer_lot"
      -- join stock_tran_det as stock_trans on stock_trans.c_item_code=stock.c_item_code and stock_trans.c_batch_no=stock.c_batch_no
      from(select "rack_mst"."c_group" as "rack_group",
          "rack_mst"."c_name" as "rack",
          "mfac_mst"."c_name" as "mfac_name",
          "item"."c_name" as "item_name",
          "stock"."c_batch_no" as "batchs",
          ("stock"."n_balance_qty"-"stock"."n_godown_qty") as "minus_qty","item"."n_rack_transfer_lot" as "rack_transfer_lot"
          from "stock"
            join "Item_mst" as "item" on "stock"."c_item_code" = "item"."c_code"
            left outer join "pack_mst" on "pack_mst"."c_code" = "item"."c_pack_code"
            left outer join "mfac_mst" on "mfac_mst"."c_code" = "item"."c_mfac_code"
            left outer join "rack_mst" on "rack_mst"."c_code" = "item"."c_rack_code"
          where "stock"."d_expiry_date" >= "today"() and "minus_qty" < 0) as "tt" group by "rack_group","rack","mfac_name","item_name","batchs","minus_qty","rack_transfer_lot" for xml raw,elements
  end case
end;