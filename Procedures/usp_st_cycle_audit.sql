CREATE PROCEDURE "DBA"."usp_st_cycle_audit"( 
  in @gsBr char(6),
  in @devID char(200),
  in @sKey char(20),
  in @cIndex char(30),
  in @grp_code char(6) ) 
result( "is_xml_string" xml ) 
begin
  --get item 
  declare @item char(6);
  declare @mfcode char(6);
  declare @chk numeric(1);
  declare @srno numeric(18);
  declare @tran_no numeric(18);
  declare @hdr_data char(500);
  declare @hdrdata char(500);
  declare @bath char(15);
  declare @rack char(6);
  declare @bal_qty numeric(10);
  declare @adj_qty numeric(10);
  declare @ttime timestamp;
  declare @check_flag numeric(1);
  declare @c_user char(10);
  declare @ColSep char(6);
  declare @RowSep char(6);
  declare @Pos integer;
  declare @ColPos integer;
  declare @RowPos integer;
  declare @ColMaxLen numeric(4);
  declare @RowMaxLen numeric(4);
  declare @bal_qty_diplay char(100);
  declare @enable_log numeric(1);
  if @devID = '' or @devID is null then
    set @gsBr = "http_variable"('gsBr'); --1
    set @devID = "http_variable"('devID'); --2
    set @sKey = "http_variable"('sKey'); --3
    set @cIndex = "http_variable"('cIndex'); --4
    set @grp_code = "http_variable"('grp_code') --5
  end if;
  set @c_user = "http_variable"('userid');
  set @HdrData = "http_variable"('HdrData');
  select "c_delim" into @ColSep from "ps_tab_delimiter" where "n_seq" = 0;
  select "c_delim" into @RowSep from "ps_tab_delimiter" where "n_seq" = 1;
  if @ColSep is null or @ColSep = '' then
    select '--------------------\x0D\x0ASQL error: usp_st_cycle_audit No Delimiter Defined';
    return
  end if;
  set @ColMaxLen = "Length"(@ColSep);
  set @RowMaxLen = "Length"(@RowSep);
  --Vinay added module_mst to enable and disable the bal qty in Stock Audit
  select "n_active" into @enable_log from "st_track_module_mst" where "st_track_module_mst"."c_code" = 'M00057';
  if @enable_log is null then
    set @enable_log = 0
  end if;
  if @enable_log = 1 then
    select "c_menu_id" into @bal_qty_diplay from "st_track_module_mst" where "c_code" = 'M00057';
    if @bal_qty_diplay is null then
      set @bal_qty_diplay = 0
    end if end if;
  --Vinay added module_mst to enable and disable the bal qty in Stock Audit
  case @cIndex
  when 'get_item' then
    select top 1 "cycle_audit_count_det"."c_item_code" as "item_code",
      "mfac_mst"."c_short_nm" as "Mfcode",
      "cycle_audit_count_det"."n_check" as "n_check",
      "cycle_audit_count_det"."n_srno" as "srno",
      "cycle_audit_count_mst"."c_audited_doc_no" as "tran_no"
      into @item,@mfcode,@chk,@srno,@tran_no
      from "cycle_audit_count_det" join "cycle_audit_count_mst" on "cycle_audit_count_mst"."n_srno" = "cycle_audit_count_det"."n_srno"
        and "cycle_audit_count_mst"."c_rack_grp_code" = "cycle_audit_count_det"."c_rack_grp_code"
        join "mfac_mst" on "mfac_mst"."c_code" = "cycle_audit_count_det"."c_mf_code"
      where "cycle_audit_count_det"."c_rack_grp_code" = @grp_code
      and "cycle_audit_count_det"."n_check" = 0;
    if(select "count"("stock"."c_item_code")
        from "stock" join "ITEM_MST" on "item_mst"."c_code" = "stock"."c_item_code"
          join "rack_mst" on "rack_mst"."c_code" = "item_mst"."c_rack_code"
          join "pack_mst" on "item_mst"."c_pack_code" = "pack_mst"."c_code"
          join "st_store_stage_det" on "st_store_stage_det"."c_rack_grp_code" = "rack_mst"."c_group"
        where "stock"."c_item_code" = @item
        and "stock"."d_expiry_date" > "uf_default_date"()
        and "st_store_stage_det"."n_tray_in_exit" = 0) = 0 then
      delete from "cycle_audit_count_det" where "c_item_code" = @item and "n_check" = 0 and "n_srno" = @srno;
      commit work
    end if;
    select @bal_qty_diplay as "bal_qty_diplay",
      @srno as "sr_no",
      @item as "item_code",
      "item_mst"."c_name" as "item_name",
      "stock"."c_batch_no",
      "stock"."d_expiry_date" as "exp_date",
      "stock"."n_mrp" as "n_mrp",
      "n_balance_qty" as "n_bal_qty",
      "stock"."n_balance_qty"-"stock"."n_godown_qty" as "n_rack_bal_qty",
      "stock"."n_godown_qty" as "n_godown_bal_qty",
      "rack_mst"."c_code" as "rack",
      "rack_mst"."c_group" as "c_rack_grp_code",
      "st_store_stage_det"."c_stage_code" as "c_stage_code",
      @mfcode as "mfac_code",
      @tran_no as "tran_no",
      "pack_mst"."c_name" as "c_pack_name"
      from "stock" join "ITEM_MST" on "item_mst"."c_code" = "stock"."c_item_code"
        join "rack_mst" on "rack_mst"."c_code" = "item_mst"."c_rack_code"
        join "pack_mst" on "item_mst"."c_pack_code" = "pack_mst"."c_code"
        join "st_store_stage_det" on "st_store_stage_det"."c_rack_grp_code" = "rack_mst"."c_group"
      where "stock"."c_item_code" = @item
      and "stock"."d_expiry_date" > "uf_default_date"()
      and "st_store_stage_det"."n_tray_in_exit" = 0 for xml raw,elements
  end case
end;