CREATE PROCEDURE "DBA"."usp_st_storein_quarantine"( 
  in @gsBr char(6),
  in @devID char(200),
  in @sKey char(20),
  in @UserId char(20),
  in @PhaseCode char(6),
  in @StageCode char(6),
  in @RackGrpCode char(300),
  in @cIndex char(30),
  in @HdrData char(8000),
  in @DetData char(8000),
  in @DocNo char(25),
  in @GodownCode char(6) ) 
result( "is_xml_string" xml ) 
begin
  /*
Author 		: Saneesh  
Procedure	: usp_st_storein_quarantine
SERVICE		: ws_st_storein_quarantine
Date 		: 27-12-2015
Modified by :
Ldate 		: 
Purpose		: Quarantine Stock Storein 
Input		: gsBr~devID~sKey~UserId~PhaseCode~RackGrpCode~StageCode~cIndex~HdrData~DetData~DocNo
RackGrpCode= rg1**rg2**__
IndexDetails: get_doc_list,get_items
Tags		: if <c_message> contains "Error" then force logout (android)
Note		:


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
  declare @RetStr char(100);
  declare @DetData_for_stk_adj char(8000);
  --get_items >>
  declare @UnprocessedTray char(6);
  declare @UnprocessedDoc char(15);
  declare @cDocAlreadyAssignedToUser char(20);
  declare @cTrayAssigned char(6);
  declare @CurrentTray char(6);
  --get_items <<
  --item_done>>
  declare @ForwardFlag integer;
  declare @InOutFlag integer;
  declare @ItemCode char(6);
  declare @PickedQty numeric(12);
  declare @ReasonCode char(6);
  declare @RemainingQty numeric(12);
  declare @Qtp numeric(12);
  declare @storein_tray_code char(6);
  declare @BatchNo char(15);
  --item_done<<
  --get_tray_list>>
  declare @SuppCode char(6);
  declare @n_exp_ret_flag numeric(1);
  declare @c_exp_ret_SuppCode char(6);
  declare @c_MfacCode char(6);
  declare @c_item_code char(6);
  --get_tray_list<<
  declare @validate_mode numeric(1);
  declare @new_tary_flag numeric(1);
  declare @cnt numeric(10);
  declare @new_tray_code char(15);
  declare @tray_assigned_doc_no char(25);
  declare @allocated_to char(15);
  declare @suppname char(100);
  --get_tray_list>>
  --documnet_done>>
  declare @nextRackGrp char(20);
  declare @maxRackGrp char(20);
  declare @nDocItemCount integer;
  declare @nDocItemNotFoundCount integer;
  declare @ItemsInDetail integer;
  declare @DetSuccessFlag integer;
  declare @OrgSeq integer;
  declare @Seq integer;
  declare @Qty numeric(12);
  declare @HoldFlag integer;
  declare @cReason char(6);
  declare @cNote char(40);
  declare @RackCode char(6);
  declare @CurrentGrp char(6);
  declare @ItemSuppCode char(6);
  declare @Godown_Tray_Code char(6);
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
  declare @s_pick_user char(10);
  --documnet_done<<
  --shift_tarys>>
  declare @flag_val numeric(1);
  declare @OldTrayCode char(6);
  declare @NewTrayCode char(6);
  --shift_tarys<<
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
    select '--------------------\x0D\x0ASQL error: usp_st_storein_quarantine  No Delimiter Defined';
    return
  end if;
  set @ColMaxLen = "Length"(@ColSep);
  set @RowMaxLen = "Length"(@RowSep);
  set @BrCode = "uf_get_br_code"(@gsBr);
  set @t_ltime = "left"("now"(),19);
  set @d_ldate = "uf_default_date"();
  case @cIndex
  when 'get_godown_code' then -----------------------------------------------------------------------
    --http://192.168.7.12:15503/ws_st_storein_quarantine?&cIndex=get_godown_code
    select '-' as "c_godown_code" for xml raw,elements
  else
    select 'Invalid Index !!' as "c_message" for xml raw,elements
  end case
end;