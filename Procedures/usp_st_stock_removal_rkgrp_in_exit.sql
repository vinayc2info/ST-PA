CREATE PROCEDURE "DBA"."usp_st_stock_removal_rkgrp_in_exit"( 
  -------------------------------stock_removal------------------------------------------
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
  declare @doc_stage_code char(6);
  declare @associated_priority_stage_code char(6);
  declare @TrayList char(1000);
  declare @TrayCode char(1000);
  declare @max_seq numeric(11);
  declare @associate_tray_code char(6);
  declare @associated_stage_code char(6);
  declare @det_item_cnt numeric(8);
  declare @d_item_pick_count numeric(8);
  declare @d_item_bounce_count numeric(8);
  declare @n_pick_count numeric(10);
  declare @check_in_insertion char(40);
  declare @BrCode char(6);
  declare @t_ltime char(25);
  declare @t_tray_move_time char(25);
  declare @d_mark_as_complete_no_item_to_pick_next_rg numeric(1);
  declare @d_auto_complete_tray numeric(1);
  declare @d_ldate char(20);
  declare @nSingleUser integer;
  declare @DocNo char(25);
  declare @ColSep char(6);
  declare @RowSep char(6);
  declare @Pos integer;
  declare @ColPos integer;
  declare @RowPos integer;
  declare @ColMaxLen numeric(4);
  declare @RowMaxLen numeric(4);
  declare @non_pick_hdr char(2000);
  declare @ItemsInDetail integer;
  declare @TranBrCode char(6);
  declare @TranPrefix char(4);
  declare @TranYear char(2);
  declare @TranSrno numeric(18);
  declare @CurrentTray char(20);
  declare @InOutFlag numeric(1);
  declare @nTrayFull integer;
  declare @HdrData_Set_Selected_Tray char(7000);
  declare @NextTray char(20);
  declare @godown_item_detail char(32767);
  declare @non_pick_tray char(6);
  declare @pos_seq numeric(4);
  declare @tmp char(20);
  declare @LoginFlag char(1);
  declare @LoginStatus char(5000);
  declare @Seq numeric(6);
  declare @rgCount integer;
  declare @stage_seq numeric(3);
  declare @nitemcount numeric(5);
  declare @next_stage char(6);
  declare @next_rack_grp char(6);
  declare @t_preserve_ltime char(25);
  declare @n_cnt_tray_assignment char(3);
  declare @n_cnt_doc_assignment char(3);
  declare local temporary table "temp_tray_list"(
    "c_tray_code" char(6) null,) on commit preserve rows;
  declare local temporary table "temp_rack_grp_list"(
    "c_rack_grp_code" char(6) null,
    "c_stage_code" char(6) null,
    "n_seq" numeric(6) null,) on commit preserve rows;
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
    set @GodownCode = "http_variable"('GodownCode'); --11  
    set @TrayCode = "http_variable"('TrayCode')
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
  set @d_item_pick_count = 0;
  set @d_item_bounce_count = 0;
  case @cIndex
  when 'get_rack_group' then
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
        and "rack_group_mst"."n_lock" = 0
        and "n_tray_in_exit" = 1;
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
        and "manual_rack_group"."c_rack_code" is null
        and "n_tray_in_exit" = 1
        order by "st_store_stage_det"."n_pos_seq" asc for xml raw,elements
    else
      select '' as "c_rack_grp_code",
        '' as "c_rack_grp_name",
        'Warning!! : Stage - '+"string"(@StageCode)+' not found' as "c_message" for xml raw,elements
    end if when 'get_rack_doc_list' then
    while @RackGrpCode <> '' loop
      --1 RackGrpList
      select "Locate"(@RackGrpCode,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@RackGrpCode,@ColPos-1));
      set @RackGrpCode = "SubString"(@RackGrpCode,@ColPos+@ColMaxLen);
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
    select "n_pos_seq" into @pos_seq from "st_store_stage_det" where "c_stage_code" = @StageCode and "c_rack_grp_code" = @tmp;
    select "c_doc_no","n_urgent"
      from(select distinct "st_track_det"."c_doc_no","st_track_mst"."t_time_in","st_track_mst"."n_urgent" as "n_urgent" from "st_track_det"
            join "st_store_stage_det" on "st_store_stage_det"."c_stage_code" = "st_track_det"."c_stage_code"
            and "st_store_stage_det"."c_rack_grp_code" = "st_track_det"."c_rack_grp_code"
            join "st_track_mst" on "st_track_mst"."c_doc_no" = "st_track_det"."c_doc_no"
            and "st_track_mst"."n_inout" = "st_track_det"."n_inout"
          where "st_track_det"."n_complete" = 0
          and "st_track_det"."c_rack_grp_code" = any(select "st_store_stage_det"."c_rack_grp_code" from "st_store_stage_det" where "st_store_stage_det"."n_pos_seq" >= @pos_seq and "st_store_stage_det"."c_stage_code" = @StageCode)
          and "st_track_det"."c_rack_grp_code" = any(select "st_store_stage_det"."c_rack_grp_code" from "st_store_stage_det" where "st_store_stage_det"."n_pos_seq" <= @pos_seq and "st_store_stage_det"."c_stage_code" = @StageCode)) as "tem"
      order by "n_urgent" desc,"t_time_in" asc for xml raw,elements
  when 'get_tray_list' then
    --set @RackGrpCode = @RackGrpCode;
    while @RackGrpCode <> '' loop
      --1 RackGrpList
      select "Locate"(@RackGrpCode,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@RackGrpCode,@ColPos-1));
      set @RackGrpCode = "SubString"(@RackGrpCode,@ColPos+@ColMaxLen);
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
    select "n_pos_seq" into @pos_seq from "st_store_stage_det" where "c_stage_code" = @StageCode and "c_rack_grp_code" = @tmp;
    select "c_associated_stage_code" into @associated_stage_code from "st_associated_stage_mapping" where "c_stage_code" = @StageCode;
    select top 1 "c_stage_code" into @associated_priority_stage_code from "st_associated_stage_mapping" order by "n_seq" asc;
    select distinct "st_track_tray_move"."c_tray_code" as "c_tray_code",
      "st_track_tray_move"."c_doc_no" as "c_doc_no",
      "st_track_tray_move"."t_time" as "t_time",
      "st_track_tray_move"."c_rack_grp_code",
      "isnull"((select "count"("b"."c_item_code") from "st_track_det" as "b" join "st_store_stage_det"
          on "st_store_stage_det"."c_stage_code" = "b"."c_stage_code"
          and "st_store_stage_det"."c_rack_grp_code" = "b"."c_rack_grp_code"
        where "b"."n_complete" = 0 and "st_track_tray_move"."c_doc_no" = "b"."c_doc_no"
        and "b"."c_stage_code" = @StageCode and "st_store_stage_det"."n_pos_seq" > @pos_seq),0) as "next_rack_item_count",
      "invoice_mst"."c_sman_code" as "sman_code",
      "sman_mst"."c_name" as "sman_name",
      "invoice_mst"."c_cust_code" as "cust_code",
      "act_mst"."c_name" as "cust_name",
      "isnull"("st_track_mst"."n_urgent",0) as "n_urgent",
      if @associated_priority_stage_code = @StageCode then
        (select "list"("tm"."c_tray_code") from "st_track_tray_move" as "tm"
          where "tm"."n_inout" = 9 and "tm"."c_doc_no" = "st_track_tray_move"."c_doc_no"
          and "tm"."c_stage_code" = @associated_stage_code)
      else
        if(select "count"("std"."c_item_code") from "st_track_det" as "std" where "c_doc_no" = "st_track_det"."c_doc_no" and "std"."c_stage_code" <> @StageCode
          and not "std"."c_stage_code" = any(select distinct "c_associated_stage_code" from "st_associated_stage_mapping")) = 0 then
          (select "list"("tm"."c_tray_code") from "st_track_tray_move" as "tm"
            where "tm"."n_inout" = 9 and "tm"."c_doc_no" = "st_track_tray_move"."c_doc_no"
            and "tm"."c_stage_code" = @associated_stage_code)
        else null
        endif
      endif as "associated_trays"
      from "st_track_tray_move"
        left outer join "st_track_det" on "st_track_tray_move"."c_doc_no" = "st_track_det"."c_doc_no"
        and "st_track_tray_move"."n_inout" = "st_track_det"."n_inout"
        and "st_track_tray_move"."c_tray_code" = "st_track_det"."c_tray_code"
        and "st_track_tray_move"."c_godown_code" = "st_track_det"."c_godown_code"
        join "temp_rack_grp_list" on "st_track_tray_move"."c_rack_grp_code" = "temp_rack_grp_list"."c_rack_grp_code"
        join "st_track_mst" on "st_track_mst"."c_doc_no" = "st_track_tray_move"."c_doc_no"
        and "st_track_mst"."n_inout" = "st_track_tray_move"."n_inout"
        left outer join "invoice_mst" on "invoice_mst"."n_srno" = "reverse"("left"("reverse"("st_track_mst"."c_doc_no"),"charindex"('/',("reverse"("st_track_mst"."c_doc_no")))-1))
        and "invoice_mst"."c_cust_code" = "st_track_mst"."c_cust_code"
        left outer join "sman_mst" on "invoice_mst"."c_sman_code" = "sman_mst"."c_code"
        left outer join "act_mst" on "act_mst"."c_code" = "invoice_mst"."c_cust_code"
      where "st_track_tray_move"."n_inout" not in( 8,9,1 ) 
      and "st_track_tray_move"."c_godown_code" = '-'
      order by "t_time" asc for xml raw,elements
  when 'document_exit' then -----------------------------------------------------------------------
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
    --8 nitemcount
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @nitemcount = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    set @DocNo = @Tranbrcode+'/'+@TranYear+'/'+@TranPrefix+'/'+"string"(@TranSrno);
    if @nitemcount = 0 then
      set @TrayList = @TrayCode;
      //    vinay added to show the associated tray list in exit screen
      //      if @TrayList is not null or @TrayList <> '' then
      if "isnull"((select "n_active" from "st_track_module_mst" where "c_code" = 'M00092' and "c_menu_id" = '1'),0) = 1 then
        //        print '1';
        if(select "count"("c_stage_code") from "st_associated_stage_mapping" where "c_stage_code" = @StageCode) > 0 then
          //          print '2';
          //check is it the last tary of the docment for the stage (to handle Add on Trays)
          if(select "count"("c_doc_no") from "st_track_tray_move" where "c_doc_no" = @DocNo and "c_stage_code" = @StageCode and "n_inout" = 0) = 1 then
            //            print '3';
            //            print 'P1';
            //            print now();
            while @TrayList <> '' loop
              //              print '4';
              select "Locate"(@TrayList,@ColSep) into @ColPos;
              set @associate_tray_code = "Trim"("Left"(@TrayList,@ColPos-1));
              set @TrayList = "SubString"(@TrayList,@ColPos+@ColMaxLen);
              insert into "temp_tray_list"( "c_tray_code" ) values( @associate_tray_code ) 
            end loop;
            //            print 'P3';
            //            print now();
            if(select "count"("c_tray_code") from "temp_tray_list") <> 0 then
              //                    print 'P5';
              //                    print now();
              select "max"("n_seq") into @max_seq from "st_track_pick" where "c_doc_no" = @DocNo and "c_stage_code" = @StageCode
                and "n_inout" = 0 and "n_qty"-("n_confirm_qty"+"n_reject_qty") > 0;
              update "st_track_pick" set "st_track_pick"."n_seq" = @max_seq+"number"(),"st_track_pick"."c_tray_code" = @CurrentTray
                where "st_track_pick"."c_tray_code" = any(select "c_tray_code" from "temp_tray_list")
                and "st_track_pick"."c_doc_no" = @DocNo and "n_inout" = 0 and "n_qty"-("n_confirm_qty"+"n_reject_qty") > 0;
              update "st_track_det" set "st_track_det"."c_tray_code" = @CurrentTray
                where "st_track_det"."c_tray_code" = any(select "c_tray_code" from "temp_tray_list")
                and "st_track_det"."c_doc_no" = @DocNo and "n_inout" = 0;
              delete from "st_track_tray_move" where "c_doc_no" = @DocNo and "c_tray_code" = any(select "c_tray_code" from "temp_tray_list") and "n_inout" = 9
            //                    print 'P2';
            //                    print now();
            end if end if end if end if;
      update "st_track_tray_move" set "n_inout" = 9,"c_rack_grp_code" = '-',"t_time" = "now"() where "c_doc_no" = @DocNo and "c_tray_code" = @CurrentTray;
      //print 'test';
      /* Vinay Testing 15-12-21 */
      if "uf_sys_para_setup"('S00211','-','0',1) = 1 then
        //print 'test-a';
        if(select "count"("c_doc_no") from "st_track_tray_move" where "c_doc_no" = @DocNo and "n_inout" = 0) = 0 then //check for Last Tray Move
          //print 'test-b';
          if(select "count"("c_doc_no") from "st_track_det" where "c_doc_no" = @DocNo and "n_complete" = 0) = 0 then
            //print 'test-c';
            select "uf_sys_para_setup"('S00211','-','0',2) into @doc_stage_code;
            //print 'test-d';
            if(select "count"("c_code") from "doc_stage_mst" where "c_code" = @doc_stage_code) = 1 then
              //print 'test-e';
              insert into "DBA"."doc_track"( "c_stage_code","c_inv_prefix","n_inv_no","c_dman_code","n_errors","c_note","c_user","d_date","t_time","t_ltime" ) on existing skip values
                ( @doc_stage_code,@TranPrefix,@TranSrno,'-',0,null,@UserId,"today"(),"now"(),"now"() ) ;
              if @TranPrefix = 'IS' then
                insert into "DBA"."doc_track" on existing skip
                  select @doc_stage_code,"c_inv_prefix","n_inv_no",'-',0,null,@UserId,"today"(),"now"(),"now"()
                    from "inv_summary_list_det" where "n_srno" = @TranSrno
              end if
            end if
          end if end if end if;
      //print 'test-1';
      commit work;
      if @next_rack_grp is null then
        select "count"()
          into @n_pick_count from "st_track_pick"
          where "st_track_pick"."c_tray_code" = @CurrentTray
          and "st_track_pick"."c_doc_no" = @DocNo
          and "c_stage_code" = @StageCode
          and "st_track_pick"."c_godown_code" = @GodownCode
          and "st_track_pick"."n_non_pick_flag" <> 1;
        if @n_pick_count is null then
          set @n_pick_count = 0
        end if;
        if @n_pick_count = 0 then --Release Tray
          delete from "st_track_tray_move"
            where "c_tray_code" = @CurrentTray
            and "c_doc_no" = @DocNo
            and "c_stage_code" = @StageCode
            and "c_godown_code" = @GodownCode;
          commit work;
          select "count"("st_track_det"."c_item_code") into @det_item_cnt from "st_track_det" where "c_doc_no" = @DocNo and "n_inout" = 0 and "n_complete" in( 0,1 ) ;
          if @det_item_cnt = 0 then
            update "st_track_mst" set "n_complete" = 9
              where "c_doc_no" = @DocNo
              and "n_inout" = 0
              and "n_confirm" = 1;
            commit work
          end if end if end if;
      --gargee
      call "uf_update_tray_time"(@DocNo,@InOutFlag,@CurrentTray,'PICKING',@UserId,@RackGrpCode,@StageCode,2,@t_tray_move_time,@d_item_pick_count,@d_item_bounce_count);
      --gargee
      --For Auto Check-in trays
      select "sys_para_setup"."c_defa_val" into @check_in_insertion from "para_val_mst" join "sys_para_setup" on "sys_para_setup"."c_para_val_code" = "para_val_mst"."c_code"
        where "para_val_mst"."c_code" = 'S00130' and "para_val_mst"."n_enabled" = 1;
      insert into "doc_track"( "c_stage_code","c_inv_prefix","n_inv_no","c_dman_code","n_errors","c_note","c_user","d_date","t_time","t_ltime" ) on existing update defaults off values
        ( @check_in_insertion,@TranPrefix,@TranSrno,null,0,null,null,"uf_default_date"(),"now"(),"now"() ) ;
      commit work;
      select 'Success' as "c_message" for xml raw,elements
    else -- select 'Success' as c_message for xml raw,elements;
      select "Locate"(@RackGrpCode,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@RackGrpCode,@ColPos-1));
      --set @RackGrpCode = SubString(@RackGrpCode,@ColPos+@ColMaxLen);
      --select * from st_store_stage_det
      select "n_pos_seq" into @stage_seq from "st_store_stage_det" where "c_rack_grp_code" = @tmp and "st_store_stage_det"."c_stage_code" = @StageCode;
      select top 1
        "st_store_stage_mst"."c_code",
        "st_store_stage_det"."c_rack_grp_code"
        into @next_stage,@next_rack_grp
        from "st_store_stage_mst","st_store_stage_det"
        where "st_store_stage_mst"."c_code" = "st_store_stage_det"."c_stage_code"
        and "st_store_stage_det"."n_pos_seq" > @stage_seq
        and "st_store_stage_mst"."c_godown_code" = @godowncode
        and "st_store_stage_det"."c_stage_code" = @StageCode
        -- and n_tray_in_exit=0
        order by "st_store_stage_det"."n_pos_seq" asc;
      update "st_track_tray_move" set "c_rack_grp_code" = @next_rack_grp,"t_time" = "now"() where "c_doc_no" = @DocNo and "c_tray_code" = @CurrentTray;
      //        print 'test-p';
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
              end if
            end if
          end if end if end if;
      //print 'test-p1';
      commit work;
      call "uf_update_tray_time"(@DocNo,@InOutFlag,@CurrentTray,'PICKING',@UserId,@next_rack_grp,@StageCode,0,@t_tray_move_time,@d_item_pick_count,@d_item_bounce_count);
      select 'Success' as "c_message" for xml raw,elements
    end if when 'set_selected_tray_exit' then -----------------------------------------------------------------------
    call "usp_set_selected_tray_exit"(@UserId,@HdrData,@DetData,@RackGrpCode,@StageCode,@GodownCode,@gsBr,@t_preserve_ltime);
    return
  when 'Get_setup' then -----------------------------------------------------------------------
    --HdrData ==M00033^^
    set @HdrData = "http_variable"('HdrData');
    --call uf_get_module_mst_value_multi(@HdrData,@ColPos,@ColMaxLen,@ColSep);
    select "isnull"("c_menu_id",'') as "c_menu_id","c_module_name" from "st_track_module_mst" where "c_code" in( 'M00048','M00049','M00050' ) for xml raw,elements;
    -- select c_menu_id  from st_track_module_mst where c_code IN  ('M00049') for xml raw,elements;
    return
  end case
end;