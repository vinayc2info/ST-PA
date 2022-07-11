CREATE PROCEDURE "DBA"."usp_st_get_tray_details"( 
  in @gsBr char(6),
  in @devID char(200),
  in @UserId char(20),
  in @StageCode char(6),
  in @RackGrpCode char(300),
  in @cIndex char(30),
  in @tray_code char(6),
  in @GodownCode char(6) ) 
//result( "is_xml_string" xml ) 
begin
  declare @doc_no char(25);
  declare @li_tray_qty integer;
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
    //http://172.16.18.19:19158/ws_st_get_tray_details?&cIndex=get_tray_details&tray_code=40530
    if "len"(@tray_code) <= 6 then
      select "sum"("n_qty") into @li_tray_qty from "tray_ledger" where "c_tray_code" = @tray_code;
      if @li_tray_qty = 0 then
        select top 1 "n_srno"
          into @doc_no
          from "tray_ledger" where "c_tray_code" = @tray_code
          and "n_qty" < 0 and "c_prefix" <> 'OT' order by "t_ltime" desc
      end if end if;
    //finding trays from inv no 
    select "replace"("list"(distinct if "left"("carton_mst"."c_tray_code",6) = '000000' then
        "carton_mst"."c_tray_code"+"string"("carton_mst"."n_carton_no")
      else
        "carton_mst"."c_tray_code"
      endif),',',';')+';' as "c_tray_code"
      from "carton_mst"
        join "item_mst" on "carton_mst"."c_item_code" = "Item_mst"."c_code"
        join "rack_mst" on "item_mst"."c_rack_code" = "rack_mst"."c_code"
        join "rack_group_mst" on "rack_mst"."c_group" = "rack_group_mst"."c_code"
        left outer join "store_mst" on "rack_group_mst"."c_store_code" = "store_mst"."c_code"
      where "n_srno" = @doc_no
  end case
end;