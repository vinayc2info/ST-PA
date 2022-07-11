CREATE PROCEDURE "DBA"."usp_st_store_in_assignment"()
result(  -------------------------------------------------------------------------------------------------------------------------------
  "is_xml_string" xml ) 
begin
  /*
Author          : Saneesh C G
Procedure       : usp_update_item_details
SERVICE         : ws_update_item_details
Date            : 
Modified By : Saneesh C G 
Ldate           : 27-04-2016
Purpose         : 
Input           : 
Note            :Added New Index  'Item_click' ,pending_trays^6 Added Godown code
*/
  declare @DocList char(32767);
  declare @stage_missing_item_list char(32767);
  declare @Seq numeric(9);
  declare @d_cnt numeric(9);
  declare local temporary table "doc_list"(
    "c_doc_no" char(30) null,
    "c_user" char(20) null,) on commit delete rows;
  declare local temporary table "doc_seq_list"(
    "c_doc_seq_no" char(40) null,
    "c_user" char(10) null,) on commit delete rows;
  declare @cIndex char(100);
  declare @TrayCode char(6);
  declare @DocSeqList char(32767);
  declare "i" bigint;
  declare @lDate char(30);
  declare @lTime char(30);
  declare @RackGrpCode char(6);
  declare @HdrData char(32767);
  declare @cgodownlist char(8000);
  --get_items>>
  declare @nAllDoc bit;
  --get_items<<
  --tray_full>>
  declare @gsBr char(6);
  declare @UserId char(20);
  declare @IpAdd char(40);
  declare @devName char(200);
  --tray_full<<
  --assign_tray>>
  declare @nValidTray integer;
  --assign_tray<<
  declare @cMessageBuilder char(32767);
  --common >>
  declare @ColSep char(6);
  declare @RowSep char(6);
  declare @Pos integer;
  declare @ColPos integer;
  declare @RowPos integer;
  declare @ColMaxLen numeric(4);
  declare @RowMaxLen numeric(4);
  --common <<
  --change_tray>>
  declare @AssignedDocNo char(20);
  declare @AssignedStageCode char(6);
  declare @TrayExistsInTrackMove numeric(6);
  declare @NewTray char(6);
  declare @OldTray char(6);
  declare @s_exp_godown_code char(6);
  --change_tray<<
  --Validate_tray>>
  declare @li_ext_tray_cnt numeric(6);
  declare @li_temp_tray_cnt numeric(6);
  declare @ls_doc_no char(25);
  declare @Traytype numeric(6);
  declare @Validate_Tray_With_Color numeric(6);
  declare @StageCode char(6);
  declare @BrCode char(6);
  declare @n_gate_pass_no numeric(9);
  --Get_bin_info>>
  declare @c_gre_br_code char(6);
  declare @c_gre_year char(6);
  declare @c_gre_prefix char(6);
  declare @n_gre_srno numeric(9);
  declare @GodownCode char(10);
  declare @ItemGodownCode char(10);
  --    Get_bin_info <<
  declare @Inward_Assignment_Expiry numeric(9);
  declare @Inward_Assignment_Expiry_godown_code char(10);
  --Validate_tray<<
  declare @qpb integer;
  set @lDate = "uf_default_date"();
  set @lTime = "now"();
  --@gsBr,@UserId,@IpAdd,@devName
  set @DocList = "HTTP_VARIABLE"('DocList');
  set @TrayCode = "HTTP_VARIABLE"('TrayCode');
  set @DocSeqList = "HTTP_VARIABLE"('DocSeqList');
  set @cIndex = "HTTP_VARIABLE"('cIndex');
  set @gsBr = "HTTP_VARIABLE"('gsBr');
  set @UserId = "HTTP_VARIABLE"('UserId');
  set @IpAdd = "HTTP_VARIABLE"('IpAdd');
  set @devName = "HTTP_VARIABLE"('devName');
  set @RackGrpCode = "HTTP_VARIABLE"('RackGrpCode');
  set @HdrData = "HTTP_VARIABLE"('HdrData');
  set @BrCode = "uf_get_br_code"(@gsBr);
  set @GodownCode = "HTTP_VARIABLE"('GodownCode');
  set @ItemGodownCode = "HTTP_VARIABLE"('item_gdncode');
  select "n_active" into @Inward_Assignment_Expiry from "st_track_module_mst" where "c_code" = 'M00028';
  if @Inward_Assignment_Expiry is null then
    set @Inward_Assignment_Expiry = 0
  end if;
  if @Inward_Assignment_Expiry = 1 then
    select top 1 "c_godown_code" into @Inward_Assignment_Expiry_godown_code from "storein_setup" where "n_cancel_flag" = 0
  else
    set @Inward_Assignment_Expiry_godown_code = ''
  end if;
  select "max"("c_godown_code") into @s_exp_godown_code from "storein_setup" where "c_br_code" = @BrCode;
  select "c_delim" into @ColSep from "ps_tab_delimiter" where "n_seq" = 0;
  select "c_delim" into @RowSep from "ps_tab_delimiter" where "n_seq" = 1;
  set @ColMaxLen = "Length"(@ColSep);
  set @RowMaxLen = "Length"(@RowSep);
  select "c_br_code" into @BrCode from "system_parameter";
  case @cIndex
  when 'item_search' then
    select "n_qty_per_box"
      into @qpb from "item_mst"
      where "c_code" = @HdrData;
    select "c_doc_no","trans"."c_bill_no","c_batch_no","n_qty"/@qpb as "n_qty",
      "isnull"("c_tray_code",'-') as "c_tray_code",
      "c_rack_code",
      "c_rack_grp_code",
      "trans"."c_supp_code"
      from "st_Track_in"
        --select "c_br_code","c_year","c_prefix","n_srno","string"("n_ref_srno"),"c_ref_br_code" as "c_supp_code" from "grn_mst" where "n_post" = 1 union
        join(select @BrCode as "c_br_code","c_year","c_prefix","n_srno","c_bill_no","c_supp_code" as "c_supp_code" from "purchase_mst" where "n_post" = 1 union
        select @BrCode as "c_br_code","c_year","c_prefix","n_srno","c_ref_no","c_cust_code" as "c_supp_code" from "crnt_mst") as "trans"
        on "trans"."c_br_code"+'/'+"trans"."c_year"+'/'+"trans"."c_prefix"+'/'+"string"("trans"."n_srno") = "st_track_in"."c_doc_no"
      where "c_item_code" = @HdrData for xml raw,elements;
    return
  when 'doc_list' then
    --http://192.168.7.12:155/ws_st_store_in_assignment?cIndex=doc_list&UserId=MYBOSS
    select "c_doc_no",
      "count"("st_track_in"."c_item_code") as "n_item_count",
      "list"(distinct "st_track_in"."c_user") as "c_user_list",
      "sum"(if "st_track_in"."c_tray_code" is null then 0 else 1 endif) as "n_assigned_count",
      "isnull"("purchase_mst"."c_purchase_bill_no",'-') as "c_bill_no",
      "prefix_sr_numbers"."c_trans" as "c_trans",
      if "charindex"('/160/',"c_doc_no") > 0 then
        1
      else
        0
      endif as "n_exp_doc"
      from "st_track_in"
        left outer join "purchase_mst" on '000'+'/'+"purchase_mst"."c_year"+'/'+"purchase_mst"."c_prefix"+'/'+"string"("purchase_mst"."n_srno") = "st_track_in"."c_doc_no" and "purchase_mst"."n_post" = 1
        left outer join "crnt_mst" on '000'+'/'+"crnt_mst"."c_year"+'/'+"crnt_mst"."c_prefix"+'/'+"string"("crnt_mst"."n_srno") = "st_track_in"."c_doc_no"
        left outer join "godown_tran_mst" on '000'+'/'+"godown_tran_mst"."c_year"+'/'+"godown_tran_mst"."c_prefix"+'/'+"string"("godown_tran_mst"."n_srno") = "st_track_in"."c_doc_no" and "godown_tran_mst"."n_approved" = 1
        left outer join "dbnt_mst" on '000'+'/'+"dbnt_mst"."c_year"+'/'+"dbnt_mst"."c_prefix"+'/'+"string"("dbnt_mst"."n_srno") = "st_track_in"."c_doc_no" and "dbnt_mst"."n_approved" = 1
        left outer join "prefix_sr_numbers" on '000'+'/'+"prefix_sr_numbers"."c_year"+'/'+"prefix_sr_numbers"."c_prefix" = "left"("st_track_in"."c_doc_no",8)
      where "n_complete" <> 9 and "st_track_in"."c_godown_code" <> @Inward_Assignment_Expiry_godown_code
      group by "c_doc_no","c_bill_no","c_trans"
      order by "n_assigned_count" asc,"n_item_count"/(if "n_assigned_count" = 0 then 1 else "n_assigned_count" endif) asc for xml raw,elements
  when 'get_items' then
    if "length"("isnull"(@DocList,'')) < 10 then
      set @nAllDoc = 1
    else
      set @nAllDoc = 0;
      execute immediate with result set on 'insert into doc_list select distinct c_doc_no,c_user From st_track_in where c_doc_no in ('+@DocList+')' --
    end if;
    --print '@DocList';
    --print @DocList;
    --select c_doc_no from doc_list;
    --return;
    select "c_doc_no" as "c_doc_no",
      "n_seq" as "n_seq",
      "st_track_in"."c_item_code" as "c_item_code",
      "st_track_in"."c_batch_no" as "c_batch_no",
      "trim"("str"("truncnum"("n_qty",3),10,0)) as "n_qty",
      "c_tray_code" as "c_tray_code",
      "n_complete" as "n_complete",
      "st_track_in"."c_godown_code",
      (if "isnull"("st_track_in"."c_godown_code",'-') = '-' then "item_mst"."c_rack_code" endif) as "c_rack_code",
      "rack_group_mst"."c_code" as "c_rack_grp_code",
      "st_track_in"."c_user" as "usr",
      (select "max"("c_stage_code") from "st_store_stage_det" where "c_rack_grp_code" = "st_track_in"."c_rack_grp_code") as "c_stage_code",
      "item_mst"."c_name"+"uf_st_get_pack_name"("pack_mst"."c_name") as "c_item_name",
      "item_mst"."n_qty_per_box" as "n_qty_per_box",
      "stock"."d_expiry_date",
      "stock"."n_mrp",
      (select "c_name" from "godown_mst" where "c_code" = "st_track_in"."c_godown_code") as "c_godown_name",
      '' as "c_message",
      "st_track_in"."c_user","trans"."c_bill_no",
      '' as "c_bin_code",
      "n_confirm" as "n_picked_flag"
      from "st_track_in"
        left outer join "rack_mst" on "rack_mst"."c_code" = "st_track_in"."c_rack_code"
        left outer join "rack_group_mst" on "rack_mst"."c_group" = "rack_group_mst"."c_code"
        left outer join "item_mst" on "st_track_in"."c_item_code" = "item_mst"."c_code"
        left outer join "pack_mst" on "pack_mst"."c_code" = "item_mst"."c_pack_code"
        left outer join "stock" on "st_track_in"."c_item_code" = "stock"."c_item_code" and "st_track_in"."c_batch_no" = "stock"."c_batch_no"
        left outer join(select @BrCode as "c_br_code","c_year","c_prefix","n_srno","c_purchase_bill_no" as "c_bill_no" from "purchase_mst" where "n_post" = 1 union
        select @BrCode as "c_br_code","c_year","c_prefix","n_srno",'' as "c_bill_no" from "crnt_mst" union
        select @BrCode as "c_br_code","c_year","c_prefix","n_srno",'' as "c_bill_no" from "godown_tran_mst" where "godown_tran_mst"."n_approved" = 1 union
        select @BrCode as "c_br_code","c_year","c_prefix","n_srno",'' as "c_bill_no" from "dbnt_mst" where "dbnt_mst"."n_approved" = 1) as "trans"
        on "trans"."c_br_code"+'/'+"trans"."c_year"+'/'+"trans"."c_prefix"+'/'+"string"("trans"."n_srno") = "st_track_in"."c_doc_no"
      --((@nAllDoc = 0 and c_doc_no = any(select c_doc_no from doc_list)) or(@nAllDoc = 1 and c_doc_no = c_doc_no)) and
      where((@nAllDoc = 0 and "c_doc_no" = any(select "c_doc_no" from "doc_list")) or(@nAllDoc = 1 and "c_doc_no" = "c_doc_no"))
      and "n_complete" <> 9
      order by "c_tray_code" asc,"st_track_in"."c_godown_code" asc,"c_rack_code" asc for xml raw,elements
  when 'Get_bin_info' then
    --sani
    --@HdrData -- Doc no 
    --find the gate pass no for tht doc no
    --find the GRE no for tht gate pass 
    --find  list of bin code for tht GRE
    select "n_gate_pass_no" into @n_gate_pass_no from "purchase_mst"
      where "purchase_mst"."c_br_code"+'/'+"purchase_mst"."c_year"+'/'+"purchase_mst"."c_prefix"+'/'+"string"("purchase_mst"."n_srno") = @HdrData;
    select "c_br_code","c_year","c_prefix","max"("n_srno")
      into @c_gre_br_code,@c_gre_year,@c_gre_prefix,@n_gre_srno
      from "item_bin_info"
      where "n_gate_pass_no" = @n_gate_pass_no
      group by "c_br_code","c_year","c_prefix";
    select distinct "c_bin_code"+'-'+"c_tray_code"+'-'+"string"("n_carton_no") as "bin_list"
      from "item_bin_info"
      where "item_bin_info"."c_br_code" = @c_gre_br_code
      and "item_bin_info"."c_year" = @c_gre_year
      and "item_bin_info"."c_prefix" = @c_gre_prefix
      and "item_bin_info"."n_srno" = @n_gre_srno for xml raw,elements
  when 'Item_click' then
    --Code Added By Sani On 22-02-2016  for validate Tray with color 
    set @RackGrpCode = "HTTP_VARIABLE"('RackGrpCode');
    select "n_active" into @Validate_Tray_With_Color from "st_track_module_mst" where "c_code" = 'M00009';
    if @Validate_Tray_With_Color = 1 then
      select "c_stage_code" into @StageCode from "st_store_stage_det" where "st_store_stage_det"."c_rack_grp_code" = @RackGrpCode;
      --print @StageCode;
      if @StageCode is null or "ltrim"("rtrim"(@StageCode)) = '' then
        select 'Error code (100) !! Invalid Stage Code !!' as "c_message" for xml raw,elements;
        return
      else
        select "count"()
          into @d_cnt from "st_track_tray_stage_mapping"
          where "st_track_tray_stage_mapping"."c_stage_code" = @StageCode
          and "c_tray_code" = @TrayCode
          and "n_active" = 1;
        if @d_cnt <= 0 then
          select 'Error (101) ,Tray '+@TrayCode+' Not Assigned for Stage Code '+@StageCode+'.!!' as "c_message" for xml raw,elements
        else
          select '' as "c_message" for xml raw,elements
        //--No Need to validate  
        end if
      end if
    else select '' as "c_message" for xml raw,elements
    end if when 'assign_tray' then
    --HdrData -- contain Godowncode
    --ItemGodownCode will contain the Godwon code for tht particular item 
    select "c_doc_no"
      into @ls_doc_no
      from(select distinct "a"."c_code" as "c_tray",
          "a"."c_name" as "c_tray_name",
          "isnull"("st_track_tray_move"."c_doc_no",'') as "c_doc_no"
          from "st_tray_mst" as "a"
            join "st_tray_type_mst" as "c" on "a"."c_tray_type_code" = "c"."c_code"
            join "st_track_tray_move" on "st_track_tray_move"."c_tray_code" = "a"."c_code"
            and "c_rack_grp_code" <> @RackGrpCode union
        select distinct "a"."c_code" as "c_tray",
          "a"."c_name" as "c_tray_name",
          "isnull"("st_track_tray_move"."c_doc_no",'') as "c_doc_no"
          from "st_tray_mst" as "a"
            join "st_tray_type_mst" as "c" on "a"."c_tray_type_code" = "c"."c_code"
            join "st_Track_in" as "st_track_tray_move" on "st_track_tray_move"."c_tray_code" = "a"."c_code"
          where "a"."c_code" <> @TrayCode and "c_rack_grp_code" <> @RackGrpCode) as "t"
      where "t"."c_tray" = @TrayCode;
    if @ls_doc_no is null or "ltrim"("rtrim"(@ls_doc_no)) = '' then --tray is available 
      set @nValidTray = 0
    else
      select 'Error (102): Tray '+@TrayCode+' in use for Document  .'+@ls_doc_no+'.' as "c_message" for xml raw,elements;
      return
    end if;
    --//Temp Tray validation 
    if(select "count"() from "st_track_in"
          join "st_tray_mst" on "st_tray_mst"."c_code" = "st_track_in"."c_tray_code" and "st_tray_mst"."n_in_out_flag" = 3
        where "c_tray_code" = @TrayCode and "c_user" <> @UserId) > 0 then
      select 'Error(118) TrayCode '+@TrayCode+' is already Taken By Other User  ' as "c_message" for xml raw,elements;
      return
    end if;
    --Saneesh 21-06-2015 for validating temp tray 
    if @ItemGodownCode = @s_exp_godown_code then
      select "count"() into @Traytype from "st_tray_mst" where "n_in_out_flag" = 3 and "c_code" = @TrayCode;
      if @Traytype > 0 then
        select 'Error(116) :Temp Tray is not allowed for Expiry document ' as "c_message" for xml raw,elements;
        return
      end if end if;
    set @Traytype = 0;
    if @nValidTray > 0 then
      select 'Error(103) : Tray '+@TrayCode+' in use for Document  .'+@ls_doc_no+'.' as "c_message" for xml raw,elements;
      return
    else
      if(select "count"() from "st_track_in" where "c_tray_code" = @TrayCode and "c_godown_code" <> @ItemGodownCode) > 0 then
        select 'Error(104) :Tray code '+@TrayCode+' has assigned with other Godown item'+@cgodownlist as "c_message" for xml raw,elements;
        return
      end if;
      if @ItemGodownCode <> @s_exp_godown_code then
        if(select "count"() from "st_track_in"
            where "c_tray_code" = @TrayCode and "c_godown_code" = @ItemGodownCode and "c_rack_grp_code" <> @RackGrpCode) > 0 then
          select 'Error(105) :Tray code '+@TrayCode+' has assigned with other Rack Group item ' as "c_message" for xml raw,elements;
          return
        end if end if end if;
    --Saneesh 08-02-2017 to validate multi usre send tray 
    if(select "count"() from "st_track_in" where "n_complete" = 9 and "c_tray_code" = @TrayCode) > 0 then
      select 'Error(106) TrayCode '+@TrayCode+' is already Send to Rack ' as "c_message" for xml raw,elements;
      return
    end if;
    execute immediate with result set on 'insert into doc_seq_list select distinct c_doc_no+''/''+string(n_seq),c_user From st_track_in where c_doc_no+''/''+STRING(n_seq) in ('+@DocSeqList+')';
    if
      (select "count"("c_user")
        from "st_track_in"
        where "c_user" <> @UserId and "isnull"("c_user",'') <> ''
        and "c_doc_no"+'/'+"string"("n_seq") = any(select "c_doc_seq_no" from "doc_seq_list"))
       > 0 then
      select 'Error(107) :Following items are already assigned by other users : '+@ColSep+"err_msg" as "c_message"
        from(select "replace"("list"((select "replace"("c_name"+'['+"c_code"+']',',','') from "item_mst" where "c_code" = "c_item_code")),',',@ColSep) as "err_msg" from "st_track_in"
            where "c_user" <> @UserId and "c_user" is not null
            and "c_doc_no"+'/'+"string"("n_seq") = any(select "c_doc_seq_no" from "doc_seq_list")) as "t" for xml raw,elements;
      return
    end if;
    update "st_track_in"
      set "c_tray_code" = @TrayCode,"c_user" = @UserId,"t_time" = "now"(),"n_confirm" = 1
      where "c_doc_no"+'/'+"string"("n_seq") = any(select "c_doc_seq_no" from "doc_seq_list");
    if sqlstate = '00000' then
      commit work;
      select 'SUCCESS' as "c_message" for xml raw,elements
    else
      rollback work;
      select 'FAILURE' as "c_message" for xml raw,elements
    end if when 'send_tray' then
    --//Added By Saneesh to track items with Rack /Rack Grp/Stage code as null 
    set @stage_missing_item_list = '';
    select "list"("tem"."c_item_code"+'-'+"tem"."c_godown_code")
      into @stage_missing_item_list
      from(select "st_track_in"."c_item_code","st_track_in"."c_godown_code",
          if "st_track_in"."c_godown_code" = '-' then
            (select "c_rack_code" into "c_rak" from "item_mst" where "item_mst"."c_code" = "st_track_in"."c_item_code")
          endif as "c_rk_code",
          (select "c_group" into "rack_grp_code" from "rack_mst" where "rack_mst"."c_code" = "c_rk_code") as "c_rk_grp_code",
          (select top 1 "c_stage_code" from "st_store_stage_det" where "st_store_stage_det"."c_rack_grp_code" = "c_rk_grp_code") as "c_stage_code"
          from "st_track_in"
          where "c_tray_code" = @TrayCode
          and(("c_rk_code" is null or "trim"("c_rk_code") = '') or("c_rk_grp_code" is null or "trim"("c_rk_grp_code") = '') or("c_stage_code" is null or "trim"("c_stage_code") = ''))) as "tem";
    if @stage_missing_item_list is null or "ltrim"("rtrim"(@stage_missing_item_list)) = '' then
    else
      select 'Error(108): Stage/RackGroup/Rack Code Null  !!'+@stage_missing_item_list as "c_message" for xml raw,elements;
      return
    end if;
    if(select "count"() from "st_track_in" where "c_tray_code" = @TrayCode and "n_complete" = 9) > 0 then
      select 'Error(120): Tray code '+@TrayCode+' Already Moved to Rack ' as "c_message" for xml raw,elements;
      return
    end if;
    select "uf_st_generate_indoc"(@TrayCode,@gsBr,@UserId,@IpAdd,@devName) as "c_message" for xml raw,elements;
    --sani to update login_time
    --call uf_update_login_time(@BrCode,@devName,@UserId,'-','','-',0);
    //--delete  frm tray move for doc no = 999999999999
    --//Added by Saneesh 
    delete from "st_track_tray_move" where "c_doc_no" = '999999999999' and "c_tray_code" = @TrayCode
  when 'unassign_tray' then
    if
      (select "count"("c_user")
        from "st_track_in"
        where "isnull"("c_user",@UserId) <> @UserId
        and "c_doc_no"+'/'+"string"("n_seq") = @DocSeqList)
       > 0 then
      select 'Error(109) :Following items are already assigned by other users : '+"err_msg" as "c_message"
        from(select "list"((select "replace"("c_name"+'['+"c_code"+']',',','')
              from "item_mst" where "c_code" = "c_item_code")) as "err_msg"
            from "st_track_in"
            where "c_user" <> @UserId
            and "c_user" is not null
            and "c_doc_no"+'/'+"string"("n_seq") = @DocSeqList) as "t" for xml raw,elements;
      return
    end if;
    update "st_track_in"
      set "c_tray_code" = null,"c_user" = null,"n_confirm" = 0
      where "c_doc_no"+'/'+"string"("n_seq") = @DocSeqList;
    if sqlstate = '00000' then
      commit work;
      select 'SUCCESS' as "c_message" for xml raw,elements
    else
      rollback work;
      select 'FAILURE' as "c_message" for xml raw,elements
    end if when 'pending_trays' then --get data for send tray page 
    select "t"."c_tray_code" as "c_tray_code",
      "sum"("n_item_count") as "n_item_count",
      "c_rack_grp_list",
      "c_rack_grp_code",
      "max"("t"."t_last_modi_time") as "t_last_modi_time",
      "c_godown_code"
      --and c_tray_code = '15547'
      from(select "c_tray_code",
          "count"("c_item_code") as "n_item_count",
          "list"(distinct "c_rack_grp_code") as "c_rack_grp_list",
          "st_track_in"."c_rack_code" as "c_rack",
          "rack_group_mst"."c_code" as "c_rack_grp_code",
          "max"("t_time") as "t_last_modi_time",
          "st_track_in"."c_godown_code"
          from "DBA"."st_track_in"
            left outer join "rack_mst" on "rack_mst"."c_code" = "c_rack"
            left outer join "rack_group_mst" on "rack_mst"."c_group" = "rack_group_mst"."c_code"
          where "n_complete" not in( 9 ) and "c_tray_code" is not null
          group by "c_tray_code","c_rack","st_track_in"."c_godown_code","c_rack_grp_code") as "T"
      group by "t"."c_tray_code","c_rack_grp_list","c_rack_grp_code","c_godown_code"
      order by "c_tray_code" asc for xml raw,elements
  when 'get_tray_items' then
    select "c_doc_no" as "c_doc_no",
      "n_seq" as "n_seq",
      "st_track_in"."c_item_code" as "c_item_code",
      "st_track_in"."c_batch_no" as "c_batch_no",
      "TRIM"("STR"("TRUNCNUM"("n_qty",3),10,0)) as "n_qty",
      "c_tray_code" as "c_tray_code",
      "n_complete" as "n_complete",
      "st_track_in"."c_godown_code",
      (if "isnull"("st_track_in"."c_godown_code",'-') = '-' then "item_mst_br_info"."c_rack" else "item_mst_br_info_godown"."c_rack" endif) as "c_rack",
      "rack_group_mst"."c_code" as "c_rack_grp_code",
      "c_user" as "c_picked_user",
      (select "max"("c_stage_code") from "st_store_stage_det" where "c_rack_grp_code" = "st_track_in"."c_rack_grp_code") as "c_stage_code",
      "item_mst"."c_name" as "c_item_name",
      "item_mst"."n_qty_per_box" as "n_qty_per_box",
      "stock_mst"."d_exp_dt",
      "stock_mst"."n_mrp",
      (select "c_name" from "godown_mst" where "c_code" = "st_track_in"."c_godown_code") as "c_godown_name",
      '' as "c_message"
      from "st_track_in"
        left outer join "item_mst_br_info" on "item_mst_br_info"."c_br_code" = ("left"("st_track_in"."c_doc_no","locate"("st_track_in"."c_doc_no",'/')-1))
        and "item_mst_br_info"."c_code" = "st_track_in"."c_item_code"
        left outer join "item_mst_br_info_godown" on "item_mst_br_info_godown"."c_br_code" = ("left"("st_track_in"."c_doc_no","locate"("st_track_in"."c_doc_no",'/')-1))
        and "item_mst_br_info_godown"."c_code" = "st_track_in"."c_item_code"
        and "item_mst_br_info_godown"."c_godown_code" = "isnull"("st_track_in"."c_godown_code",'-')
        left outer join "rack_mst" on "rack_mst"."c_br_code" = "left"("st_track_in"."c_doc_no",3)
        and "rack_mst"."c_code" = "c_rack"
        left outer join "rack_group_mst" on "rack_mst"."c_br_code" = "rack_group_mst"."c_br_code"
        and "rack_mst"."c_rack_grp_code" = "rack_group_mst"."c_code"
        join "item_mst" on "st_track_in"."c_item_code" = "item_mst"."c_code"
        join "stock_mst" on "st_track_in"."c_item_code" = "stock_mst"."c_item_code" and "st_track_in"."c_batch_no" = "stock_mst"."c_batch_no"
      where "n_complete" <> 9
      and "c_tray_code" = @TrayCode
      order by "c_tray_code" asc,"st_track_in"."c_godown_code" asc,"c_rack_code" asc for xml raw,elements
  when 'Validate_tray' then
    --Index added By Saneesh on 18-06-2015 
    select "COUNT"() into @li_ext_tray_cnt from "st_tray_mst" where "c_code" = @TrayCode;
    if @li_ext_tray_cnt = 0 then
      select 'Error(117) : Tray '+@TrayCode+' is not a Valid Tray !.' as "c_message" for xml raw,elements;
      return
    end if;
    set @li_ext_tray_cnt = 0;
    select "COUNT"() into @li_ext_tray_cnt from "st_tray_mst" where "c_code" = @TrayCode and "n_in_out_flag" = 0;
    select "count"() into @li_temp_tray_cnt from "st_tray_mst" where "n_in_out_flag" = 3 and "c_code" = @TrayCode;
    if @li_ext_tray_cnt > 0 then
      select 'Error(110) : Tray '+@TrayCode+' is an external Tray code.' as "c_message" for xml raw,elements;
      return
    end if;
    --//Temp Tray validation 
    if(select "count"() from "st_track_in"
          join "st_tray_mst" on "st_tray_mst"."c_code" = "st_track_in"."c_tray_code" and "st_tray_mst"."n_in_out_flag" = 3
        where "c_tray_code" = @TrayCode and "c_user" <> @UserId) > 0 then
      select 'Error(119) TrayCode '+@TrayCode+' is already Taken By Other User  ' as "c_message" for xml raw,elements;
      return
    end if;
    select top 1 "c_doc_no"
      into @ls_doc_no
      from(select distinct "a"."c_code" as "c_tray",
          "a"."c_name" as "c_tray_name",
          "isnull"("st_track_tray_move"."c_doc_no",'') as "c_doc_no"
          from "st_tray_mst" as "a"
            join "st_tray_type_mst" as "c" on "a"."c_tray_type_code" = "c"."c_code"
            join "st_track_tray_move" on "st_track_tray_move"."c_tray_code" = "a"."c_code" union
        select distinct "a"."c_code" as "c_tray",
          "a"."c_name" as "c_tray_name",
          "isnull"("st_track_tray_move"."c_doc_no",'') as "c_doc_no"
          from "st_tray_mst" as "a"
            join "st_tray_type_mst" as "c" on "a"."c_tray_type_code" = "c"."c_code"
            join "st_Track_in" as "st_track_tray_move" on "st_track_tray_move"."c_tray_code" = "a"."c_code"
          where "a"."c_code" <> @TrayCode) as "t"
      where "t"."c_tray" = @TrayCode;
    if @ls_doc_no is not null or "ltrim"("rtrim"(@ls_doc_no)) <> '' then --Store out
      select 'Error(111) : Tray '+@TrayCode+' in use for Document  .'+@ls_doc_no+'.' as "c_message" for xml raw,elements;
      return
    end if;
    --store in 
    select top 1 "c_doc_no"
      into @ls_doc_no from "st_track_det" where "c_tray_code" = @TrayCode and "n_complete" not in( 9,8,2 ) ;
    if @ls_doc_no is not null or "ltrim"("rtrim"(@ls_doc_no)) <> '' then --Store out
      select 'Error(112) : Tray '+@TrayCode+' in use for Document  .'+@ls_doc_no+'.' as "c_message" for xml raw,elements;
      return
    end if;
    if(select "count"() from "st_track_in" where "c_tray_code" = @TrayCode) > 0 then --present track in 
      if @s_exp_godown_code = @GodownCode then --exp doc , no need to validate rack grp 
      else
        if
          (select "count"()
            from "st_track_in"
            where "c_tray_code" = @TrayCode -- get item count 
            and "st_track_in"."c_rack_grp_code" = @RackGrpCode)
           = 0 then
        end if end if end if;
    /*  if(select count() from st_track_branch_return where c_tray_code = @TrayCode and n_qty > 0) > 0 then
select 'Error(120) : Tray '+@TrayCode+' already Used .' as c_message for xml raw,elements;
return
end if;*/
    select '' as "c_message" for xml raw,elements;
    return
  when 'get_assigned_tray' then
    --Index added By Saneesh on 23-06-2015 
    select distinct "c_tray_code" as "c_tray"
      from "st_track_in" left outer join "st_tray_mst" on "st_track_in"."c_tray_code" = "st_tray_mst"."c_code"
      where "c_rack_grp_code" = @HdrData
      and "n_complete" <> 9
      and "c_godown_code" = @GodownCode
      and "c_tray_code" is not null
      and "st_tray_mst"."n_in_out_flag" <> 3 for xml raw,elements;
    return
  when 'get_temp_tray' then
    --Index added By Saneesh on 18-06-2015 
    select top 50 "a"."c_code" as "c_tray"
      from "st_tray_mst" as "a"
        join "st_tray_type_mst" as "c" on "a"."c_tray_type_code" = "c"."c_code"
        left outer join "st_track_in" as "b" on "a"."c_code" = "b"."c_tray_code"
        left outer join "st_track_tray_move" as "d" on "a"."c_code" = "d"."c_tray_code"
        left outer join(select "m"."c_doc_no","m"."d_date","d"."c_tray_code"
          from "st_track_det" as "d" join "st_track_mst" as "m" on "m"."c_doc_no" = "d"."c_doc_no" and "m"."n_inout" = "d"."n_inout" and "date"("m"."t_time_in") = "today"()) as "st"
        on "st"."c_tray_code" = "b"."c_tray_code"
      where "b"."c_tray_code" is null and "d"."c_tray_code" is null and "st"."c_tray_code" is null
      and "a"."n_in_out_flag" = 3 order by 1 asc for xml raw,elements;
    return
  when 'get_post_info' then
    --Index added By Saneesh on 20-06-2015 
    select "isnull"("c_post_user",'') as "c_post_user",
      "isnull"("t_post_time","now"()) as "t_time"
      from "purchase_mst" where "n_post" = 1 and "c_br_code"+'/'+"c_year"+'/'+"c_prefix"+'/'+"string"("n_srno") = @HdrData union
    select "isnull"("c_post_user",'') as "c_post_user",
      "isnull"("t_post_time","now"()) as "t_time"
      from "grn_mst" where "n_post" = 1 and "c_br_code"+'/'+"c_year"+'/'+"c_prefix"+'/'+"string"("n_srno") = @HdrData for xml raw,elements;
    return
  when 'change_tray' then
    --@HdrData  : 1 OldTray~2 NewTray
    --1 OldTray
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @OldTray = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --message 'OldTray '+@OldTray type warning to client
    --2 NewTray
    select "Locate"(@HdrData,@ColSep) into @ColPos;
    set @NewTray = "Trim"("Left"(@HdrData,@ColPos-1));
    set @HdrData = "SubString"(@HdrData,@ColPos+@ColMaxLen);
    --message 'NewTray '+string(@NewTray ) type warning to client;
    --set @DocNo = @Tranbrcode+'/'+@TranYear+'/'+@TranPrefix+'/'+string(@TranSrno);
    if(select "count"("c_code") from "st_tray_mst" where "c_code" = @NewTray) = 0 then
      select 'Error(113) : Tray '+@NewTray+' Not Found' as "c_message" for xml raw,elements;
      return
    end if;
    select top 1 "c_doc_no","c_stage_code","count"("a"."c_tray_code")
      into @AssignedDocNo,@AssignedStageCode,@TrayExistsInTrackMove
      from "st_track_det" as "a"
      where "a"."c_tray_code" = @NewTray
      and "a"."n_complete" not in( 2,9,8 ) 
      group by "c_doc_no","c_stage_code";
    if @TrayExistsInTrackMove > 0 then
      select 'Error(114)  : Tray already exists for Document '+@AssignedDocNo+', at stage : '+@AssignedStageCode as "c_message" for xml raw,elements;
      return
    end if;
    --Need to validate the tray is present in st_track_in with partial assignmnet 
    set @AssignedDocNo = '';
    select top 1 "c_doc_no"
      into @AssignedDocNo from "st_track_in" as "a"
      where "a"."c_tray_code" = @NewTray
      and "a"."n_confirm" = 1;
    if @AssignedDocNo is null or "trim"(@AssignedDocNo) = '' then
    else
      select 'Error(115) : Tray already exists for Document '+@AssignedDocNo+';' as "c_message" for xml raw,elements;
      return
    end if;
    update "st_track_in"
      set "c_tray_code" = @NewTray
      where "c_tray_code" = @OldTray;
    if sqlstate = '00000' then
      commit work;
      select 'Success' as "c_message" for xml raw,elements
    else
      rollback work;
      select 'Failure' as "c_message" for xml raw,elements
    end if else
    select 'YOU HAVE NO BUSINESS HERE' as "c_message" for xml raw,elements
  end case
end;