CREATE PROCEDURE "DBA"."usp_st_multi_doc_done"( 
  in @gsBr char(6),
  in @devID char(200),
  in @sKey char(20),
  in @UserId char(20),
  in @StageCode char(6),
  in @RackGrpCode char(300),
  in @cIndex char(30),
  in @iplink char(50),
  in @HdrData char(7000),
  in @DetData char(32767),
  in @GodownCode char(6) ) 
result( "is_xml_string" xml ) 
begin
  declare @hdr_data char(500);
  declare @ColSep char(6);
  declare @RowSep char(6);
  declare @Pos integer;
  declare @ColPos integer;
  declare @RowPos integer;
  declare @ColMaxLen numeric(4);
  declare @RowMaxLen numeric(4);
  declare @hd char(500);
  declare @ip char(50);
  declare @RackGrp char(300);
  declare @rg char(300);
  declare @Ps integer;
  declare @stg_code char(6);
  declare @gdwn_code char(6);
  declare @brcode char(6);
  declare @dv char(200);
  declare @usr char(20);
  declare @return_xml xml;
  declare "stats" char(100);
  declare @sts char(100);
  declare @log_seq numeric(30);
  declare @ItemsInDetail integer;
  declare @Tranbrcode char(6);
  declare @TranYear char(2);
  declare @TranPrefix char(6);
  declare @TranSrno numeric(18);
  declare @CurrentTray char(20);
  declare @InOutFlag numeric(1);
  declare @nTrayFull integer;
  declare @set_tray char(10);
  declare @DocNo char(30);
  declare @t_ltime char(25);
  declare @tray_mov_time timestamp;
  declare @mov_time timestamp;
  declare local temporary table "temp_move_doc"(
    "n_seq" integer null,
    "c_doc_no" char(25) not null,
    "n_inout" numeric(1) not null,
    "c_tray_code" char(6) not null,
    "c_user" char(10) not null,
    "c_rack_grp_code" char(6) not null,
    "c_stage_code" char(6) not null,
    "t_curr_time" timestamp null,
    "t_tray_move_time" timestamp null,
    "t_action_start_time" timestamp null,
    "t_action_end_time" timestamp null,
    "t_status" char(100) null,
    primary key("c_doc_no" asc,"n_inout" asc,"c_tray_code" asc,"c_user" asc,"c_rack_grp_code" asc,"c_stage_code" asc),
    ) on commit preserve rows;
  if @devID = '' or @devID is null then
    set @gsBr = "http_variable"('gsBr'); --1
    set @devID = "http_variable"('devID'); --2
    set @sKey = "http_variable"('sKey'); --3
    set @UserId = "http_variable"('UserId'); --4
    set @RackGrpCode = "http_variable"('RackGrpCode'); --6        
    set @StageCode = "http_variable"('StageCode'); --7
    set @cIndex = "http_variable"('cIndex'); --8
    set @iplink = "http_variable"('iplink');
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
  when 'get_multi_doc_done' then
    //http://172.16.18.201:18266/ws_st_multi_doc_done?&cIndex=get_multi_doc_done&iplink=http://172.16.18.201:18266&HdrData=0^^000^^18^^I^^180007300557149^^10142^^0^^0^^~~^^||&DetData=&ExpBatch=&godown_item_detail=&excess_rack_list=&RackGrpCode=B1^^&StageCode=PICK&GodownCode=-&gsbr=000&devID=382c44a03958e04310112018124422873&sKEY=sKey&UserId=PUNEETH
    //call usp_st_multi_doc_done('000','2414354564343433243','skey','3DS','PICK','A1','get_multi_doc_done','http://172.16.18.201:18266','3^^000^^18^^I^^180007300557148^^10223^^0^^0^^~~^^||5^^000^^18^^I^^180007300557149^^10224^^0^^0^^~~^^||','','-')
    set @ip = @iplink;
    set @RackGrp = @RackGrpCode;
    set @stg_code = @StageCode;
    set @gdwn_code = @GodownCode;
    set @dv = @devID;
    set @usr = @UserId;
    set @hdr_data = @HdrData;
    set @log_seq = 0;
    select "Locate"(@RackGrp,@ColSep) into @Ps;
    set @rg = "Trim"("Left"(@RackGrp,@Ps-1));
    while @hdr_data <> '' loop
      set @log_seq = @log_seq+1;
      --1 ItemsInDetail
      select "Locate"(@hdr_data,@ColSep) into @ColPos;
      set @ItemsInDetail = "Trim"("Left"(@hdr_data,@ColPos-1));
      set @hdr_data = "SubString"(@hdr_data,@ColPos+@ColMaxLen);
      --2 Tranbrcode
      select "Locate"(@hdr_data,@ColSep) into @ColPos;
      set @Tranbrcode = "Trim"("Left"(@hdr_data,@ColPos-1));
      set @hdr_data = "SubString"(@hdr_data,@ColPos+@ColMaxLen);
      --print @Tranbrcode;
      select "Locate"(@hdr_data,@ColSep) into @ColPos;
      set @TranYear = "Trim"("Left"(@hdr_data,@ColPos-1));
      set @hdr_data = "SubString"(@hdr_data,@ColPos+@ColMaxLen);
      --print @TranYear;
      --4 TranPrefix
      select "Locate"(@hdr_data,@ColSep) into @ColPos;
      set @TranPrefix = "Trim"("Left"(@hdr_data,@ColPos-1));
      set @hdr_data = "SubString"(@hdr_data,@ColPos+@ColMaxLen);
      --print @TranPrefix;
      --5 TranSrno
      select "Locate"(@hdr_data,@ColSep) into @ColPos;
      set @TranSrno = "string"("Trim"("Left"(@hdr_data,@ColPos-1)));
      set @hdr_data = "SubString"(@hdr_data,@ColPos+@ColMaxLen);
      --print @TranSrno;
      --6 CurrentTray(= -nulltray- if FirstInStage = 1 )
      select "Locate"(@hdr_data,@ColSep) into @ColPos;
      set @CurrentTray = "Trim"("Left"(@hdr_data,@ColPos-1));
      set @hdr_data = "SubString"(@hdr_data,@ColPos+@ColMaxLen);
      --print @CurrentTray;
      --7 InOutFlag
      select "Locate"(@hdr_data,@ColSep) into @ColPos;
      set @InOutFlag = "Trim"("Left"(@hdr_data,@ColPos-1));
      set @hdr_data = "SubString"(@hdr_data,@ColPos+@ColMaxLen);
      --print '@InOutFlag';
      --print @InOutFlag;
      --8 nTrayFull
      select "Locate"(@hdr_data,@ColSep) into @ColPos;
      set @nTrayFull = "Trim"("Left"(@hdr_data,@ColPos-1));
      set @hdr_data = "SubString"(@hdr_data,@ColPos+@ColMaxLen);
      --print '@nTrayFull';
      --print @nTrayFull;
      --9
      --select Locate(@hdr_data,@ColSep) into @ColPos;
      set @set_tray = "Trim"("Left"(@hdr_data,@ColPos-1));
      set @hdr_data = "SubString"(@hdr_data,@ColPos+@ColMaxLen);
      --print '@set_tray';
      --print @set_tray;
      select "Locate"(@hdr_data,@RowSep) into @RowPos;
      set @hdr_data = "SubString"(@hdr_data,@RowPos+@RowMaxLen);
      set @DocNo = @Tranbrcode+'/'+@TranYear+'/'+@TranPrefix+'/'+"string"(@TranSrno);
      select "max"("t_time") into @tray_mov_time from "st_track_tray_move" where "c_doc_no" = @DocNo and "c_tray_code" = @CurrentTray;
      if @DocNo <> '' then
        insert into "st_tray_movement_time"
          ( "n_seq","c_doc_no","n_inout","c_tray_code","c_user","c_rack_grp_code","c_stage_code","t_curr_time","t_tray_move_time","t_action_start_time","t_action_end_time","t_status" ) on existing update defaults off
          select @log_seq,@DocNo,0,@CurrentTray,@usr,@rg,@stg_code,@t_ltime,@tray_mov_time,@t_ltime,null,'';
        commit work
      end if;
      select "uf_ecogreen_process_request"(@ip+'/ws_st_stock_removal?&cIndex=document_done&HdrData='+"string"(@ItemsInDetail)+'^^'
        +@Tranbrcode+'^^'+@TranYear+'^^'+@TranPrefix+'^^'+"string"(@TranSrno)+'^^'+@CurrentTray+'^^'+"string"(@InOutFlag)+'^^'
        +"string"(@nTrayFull)+'^^'+@set_tray+'^^||'
        +'^^&DetData=&ExpBatch=&godown_item_detail=&excess_rack_list=&RackGrpCode='+@RackGrp+'^^&StageCode='+@stg_code+'&GodownCode='+@gdwn_code+'&gsbr='+@brcode+'&devID='+@dv+'&sKEY=sKey&UserId='+@usr)
        into @return_xml;
      --print @return_xml;
      select "c_message"
        into @sts from openxml(@return_xml,'/root/row') with("c_message" char(10) 'c_message');
      select "max"("t_time") into @mov_time from "st_track_tray_move" where "c_doc_no" = @DocNo and "c_tray_code" = @CurrentTray;
      update "st_tray_movement_time" set "t_tray_move_time" = @mov_time,
        "t_action_end_time" = "now"(),
        "t_status" = @sts
        where "st_tray_movement_time"."c_doc_no" = @DocNo
        and "st_tray_movement_time"."c_tray_code" = @CurrentTray
        and "st_tray_movement_time"."n_seq" = @log_seq
        and "st_tray_movement_time"."c_rack_grp_code" = @rg
        and "st_tray_movement_time"."c_stage_code" = @stg_code
        and "st_tray_movement_time"."c_user" = @usr;
      commit work;
      insert into "temp_move_doc"
        ( "n_seq","c_doc_no","n_inout","c_tray_code","c_user","c_rack_grp_code","c_stage_code","t_curr_time","t_tray_move_time","t_action_start_time","t_action_end_time","t_status" ) values
        ( @log_seq,@DocNo,0,@CurrentTray,@usr,@rg,@stg_code,@t_ltime,@tray_mov_time,@t_ltime,null,@sts ) ;
      commit work
    end loop;
    select "c_doc_no","c_tray_code","t_status" from "temp_move_doc" for xml raw,elements
  end case
end;