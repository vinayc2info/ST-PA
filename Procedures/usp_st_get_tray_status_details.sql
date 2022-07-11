CREATE PROCEDURE "DBA"."usp_st_get_tray_status_details"( 
  in @gsBr char(6),
  in @devID char(200),
  in @UserId char(20),
  in @StageCode char(6),
  in @RackGrpCode char(300),
  in @cIndex char(30),
  in @tray_code char(6),
  in @GodownCode char(6) ) 
result( "is_xml_string" xml ) 
begin
  declare @temp_Doc char(25);
  declare @doc_no char(25);
  declare @associated_stage_item_cnt integer;
  declare @stage_code char(6);
  declare @ass_stage_code char(6);
  declare @mapped_stage char(6);
  declare @associated_tray_code char(100);
  set @gsBr = "http_variable"('gsBr'); --1
  set @devID = "http_variable"('devID'); --2
  set @UserId = "http_variable"('UserId'); --4
  set @StageCode = "http_variable"('StageCode'); --7
  set @RackGrpCode = "http_variable"('RackGrpCode'); --6	
  set @cIndex = "http_variable"('cIndex'); --8
  set @tray_code = "http_variable"('tray_code');
  set @GodownCode = "http_variable"('GodownCode'); --12	
  case @cIndex
  when 'get_tray_details' then
    set @temp_Doc = (select "stm"."c_doc_no" from "st_track_tray_move" as "stm" where "stm"."c_tray_code" = @tray_code);
    select "st_track_tray_move"."c_doc_no",
      "st_track_tray_move"."c_tray_code",
      "st_track_tray_move"."c_stage_code",
      if "st_track_tray_move"."c_rack_grp_code" = '-' then 'Completed'
      else
        "st_track_tray_move"."c_rack_grp_code"
      endif as "tray_status","invoice_mst"."c_sman_code" as "sman_code",
      "sman_mst"."c_name" as "sman_name",
      "invoice_mst"."c_cust_code" as "cust_code",
      "act_mst"."c_name" as "cust_name"
      from "st_track_tray_move"
        join "invoice_mst" on "invoice_mst"."n_srno" = "substr"("st_track_tray_move"."c_doc_no",10)
        join "sman_mst" on "sman_mst"."c_code" = "invoice_mst"."c_sman_code"
        join "act_mst" on "act_mst"."c_code" = "invoice_mst"."c_cust_code"
      where "st_track_tray_move"."c_doc_no" = @temp_Doc for xml raw,elements
  when 'exit_stage_message' then
    // http://172.16.18.19:19158/ws_st_get_tray_status_details?&cIndex=exit_stage_message&tray_code=10806&StageCode=PICK2&GodownCode=-&gsbr=000&devID=a3dcfdf75bc646d105092019064846055&sKEY=sKey&UserId=PUNEETH
    select "isnull"("max"("c_associated_stage_code"),@StageCode) into @mapped_stage from "st_associated_stage_mapping" where "c_stage_code" = @StageCode;
    select "max"("c_doc_no") into @doc_no from "st_track_tray_move" where "c_tray_code" = @tray_code;
    //    print '@mapped_stage';
    //    print @mapped_stage;
    //    print '@doc_no';
    //    print @doc_no;
    select "count"("c_doc_no") into @associated_stage_item_cnt from "st_track_det"
      where "st_track_det"."c_stage_code" = any(select distinct "c_associated_stage_code" from "st_associated_stage_mapping" where "c_associated_stage_code" = @mapped_stage) and "st_track_det"."c_doc_no" = @doc_no;
    select top 1 "st_associated_stage_mapping"."c_associated_stage_code","st_associated_stage_mapping"."c_stage_code" into @ass_stage_code,@stage_code
      from(select distinct "c_stage_code" from "st_track_det" where "c_doc_no" = @doc_no) as "st_stage_det"
        left outer join "st_associated_stage_mapping" on "st_stage_det"."c_stage_code" = "st_associated_stage_mapping"."c_stage_code"
      where "st_stage_det"."c_stage_code" <> any(select distinct "c_associated_stage_code" from "st_associated_stage_mapping" where "c_associated_stage_code" = @mapped_stage)
      order by "st_associated_stage_mapping"."n_seq" asc;
    select "list"("c_tray_code") into @associated_tray_code from "st_track_tray_move" where "c_doc_no" = @doc_no and "c_stage_code" = @ass_stage_code;
    //    print '@ass_stage_code';
    //    print @ass_stage_code;
    //    print '@stage_code';
    //    print @stage_code;
    //    print '@associated_stage_item_cnt';
    //    print @associated_stage_item_cnt;
    if @associated_stage_item_cnt > 0 then
      if((select "count"("c_doc_no") from "st_track_det" where "c_doc_no" = @doc_no and "c_stage_code" = @ass_stage_code and "n_complete" = 0) > 0) and @StageCode = @stage_code then
        select 0 as "c_status",
          'Item(s) not Picked from stage: '+@ass_stage_code as "c_message",
          @ass_stage_code as "n_associate_stage_code" for xml raw,elements
      else
        //        print '@stage_code1';
        //        print @stage_code;
        //        print '@StageCode3';
        //        print @StageCode;
        if @stage_code = @StageCode then
          select 1 as "c_status",
            'Tray code:'+@tray_code+' need to merge with tray code(s): '+@associated_tray_code as "c_message" for xml raw,elements
        else
          //          print '@ass_stage_code';
          //          print @ass_stage_code;
          //          print '@StageCode1';
          //          print @StageCode;
          if @ass_stage_code = @StageCode and((select "count"("c_item_code") from "st_track_det" where "c_stage_code" <> @StageCode) = 0) then
            select 1 as "c_status",
              'Success: Traycode:'+@tray_code+' should be given to conversion.' as "c_message" for xml raw,elements
          else
            //            print '@ass_stage_code';
            //            print @ass_stage_code;
            //            print '@StageCode2';
            //            print @StageCode;
            if @ass_stage_code = @StageCode and((select "count"("c_item_code") from "st_track_det" where "c_stage_code" <> @StageCode) > 0) then
              select 1 as "c_status",
                'Traycode:'+@tray_code+' should be given to stage:'+@stage_code as "c_message",
                @stage_code as "n_associate_stage_code" for xml raw,elements
            else
              select 1 as "c_status",
                'Success' as "c_message" for xml raw,elements
            end if
          end if
        end if
      end if
    else select 1 as "c_status",
        'Success' as "c_message" for xml raw,elements
    end if
  end case
end;