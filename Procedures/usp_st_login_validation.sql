CREATE PROCEDURE "DBA"."usp_st_login_validation"( 
  -------------------------------------------------------------------------------------------------------------------------------
  ---------------------usp_st_login_validation------------------------------------------------------
  in @gsBr char(6),
  in @devID char(200),
  in @UserId char(20),
  in @UserPass char(1000),
  in @cIndex char(30),
  in @PhaseCode char(6),
  in @StageCode char(6),
  in @RackGrpCode char(300),
  in @cNote char(75),
  in @GodownCode char(6) ) 
result( "is_xml_string" xml ) 
begin
  /*
Author 		:  Anup
Procedure	: usp_st_login_validation
SERVICE		: ws_st_login_validation
Date 		: 20-10-2016
--------------------------------------------------------------------------------------------------------------------------------
Modified By                 Ldate               Index           tickets                    Changes
--------------------------------------------------------------------------------------------------------------------------------
Pratheesh.P                 18-05-2022                             D41653                   for reporting purpose added function uf_update_login_time
--------------------------------------------------------------------------------------------------------------------------------
*/
  declare @BrCode char(6);
  declare @nUserValid integer;
  declare @HdrData char(1000);
  --login>>
  declare @nDevLocked integer;
  declare @enableTrayStatus integer;
  declare @enableDashboard integer;
  declare @enableStockAudit integer;
  declare @enablestorein integer;
  declare @cMenuID char(250);
  declare @sApplicationID char(6);
  declare "ENABLED_DEFAULT" numeric(1);
  declare "DISABLED_DEFAULT" numeric(1);
  declare @li_add numeric(1);
  declare @li_modi numeric(1);
  declare @li_del numeric(1);
  declare @LDate date;
  declare @RestrictFlag integer;
  declare @smanwise_tray_status integer;
  declare @c2code char(8);
  declare local temporary table "temp_rack_grp_list"(
    "c_rack_grp_code" char(6) null,
    "c_stage_code" char(6) null, --login<<
    "n_seq" numeric(6) null,) on commit preserve rows;declare @Seq integer;
  --logout>>
  declare @RackGrpList char(7000);
  declare @tmp char(20);
  --logout<<
  --common >>
  declare @ColSep char(6);
  declare @RowSep char(6);
  declare @Pos integer;
  declare @ColPos integer;
  declare @RowPos integer;
  declare @ColMaxLen numeric(4);
  declare @RowMaxLen numeric(4);
  --common <<
  --dev_reg>>
  declare @iDevNo integer;
  declare @cDevID char(50);
  declare @RegDate date;
  declare @CancelFlag integer;
  declare @ADate date;
  declare @LDateTime timestamp;
  declare @nPendingApproval integer;
  declare @nDevExists integer;
  --dev_reg<<
  --cIndex login_status>>
  declare @loginRGCount integer;
  declare @tmRGcount integer;
  declare @stageRGcount integer;
  declare @seltmRGcount integer;
  declare @DocNo char(25);
  declare @CurrentTray char(20);
  --cIndex login_status<<
  --cIndex set_login>>
  declare @LoginStatus char(500);
  --cIndex set_login<<
  --cIndex util_login>>
  declare @loginMode char(100);
  declare @doc_no_msg char(100);
  declare @n_allow_store_track integer;
  declare @Eg_db integer;
  declare @enable_log numeric(1);
  --cIndex util_login<<
  if @devID = '' or @devID is null then
    set @gsBr = "http_variable"('gsBr'); --1
    set @devID = "http_variable"('devID'); --2
    set @UserId = "http_variable"('UserId'); --3
    set @UserPass = "http_variable"('UserPass'); --4
    set @cIndex = "http_variable"('cIndex'); --5
    set @PhaseCode = "http_variable"('PhaseCode'); --6            
    set @RackGrpCode = "http_variable"('RackGrpCode'); --7        
    set @StageCode = "http_variable"('StageCode'); --8
    set @cNote = "http_variable"('cNote'); --9
    set @GodownCode = "http_variable"('GodownCode') --10                          
  end if;
  select "n_active" into @enable_log from "st_track_module_mst" where "st_track_module_mst"."c_code" = 'M00039';
  set @sApplicationID = '006';
  select "c_delim" into @ColSep from "ps_tab_delimiter" where "n_seq" = 0;
  select "c_delim" into @RowSep from "ps_tab_delimiter" where "n_seq" = 1;
  set @ColMaxLen = "Length"(@ColSep);
  set @RowMaxLen = "Length"(@RowSep);
  --devid
  set "ENABLED_DEFAULT" = 1;
  set "DISABLED_DEFAULT" = 0;
  --//set @cMenuID = '000017';
  set @cMenuID = 'm_dashboard';
  select "uf_get_menu_rights"(@sApplicationID,@cMenuID,@UserId,"ENABLED_DEFAULT")
    into @enableDashboard;
  --set @cMenuID = '000030';
  set @cMenuID = 'm_storeinutility';
  select "uf_get_menu_rights"(@sApplicationID,@cMenuID,@UserId,"ENABLED_DEFAULT")
    into @enablestorein;
  set @enablestorein = 1;
  set @enableDashboard = 1;
  set @LDateTime = "left"("now"(),19);
  set @LDate = "uf_default_date"();
  set @BrCode = '000';
  if(select "count"() from "systable" where "table_name" = 'ddds_user_mst' and "creator" = 1) = 1 then
    --Pa db
    set @Eg_db = 0
  else
    --Eg Db
    set @Eg_db = 1
  end if;
  case @cIndex
  when 'tray_is_numeric' then
    select '1' as "n_flag" for xml raw,elements
  when 'get_latest_version' then
    --http://172.16.18.26:16201/ws_st_login_validation?&cIndex=get_latest_version&GodownCode=&gsbr=000&devID=3c824667f4396fc729062016041357979&sKEY=sKey&UserId=C2
    select "c_br_Code","c_app_code","n_cur_ver_no","c_cur_ver_name","c_apk_location","n_download_flag","c_log_location","n_log_flag","c_log_server_user_id","c_log_server_user_pwd","c_apk_server_user_id","c_apk_server_user_pwd","isnull"("download_link_from_server",'http://liveorder.in/apkdownload/123_1/storetrack.apk') as "download_link_from_server"
      from "apk_info"
      where "c_app_code" = 'STRACK' for xml raw,elements
  when 'login' then
    --http://172.16.18.26:16201/ws_st_login_validation?&cIndex=login&UserPass=1&GodownCode=&gsbr=000&devID=3c824667f4396fc729062016041357979&sKEY=sKey&UserId=C2
    /*
n_success_flag :
0 - failure
1 - success
2 - Unregistered
3 - Approval Pending      
4 - Device Locked 
*/
    select "count"("c_device_id") into @nDevExists from "st_device_mst" where "c_device_id" = @devID and "c_br_code" = @BrCode;
    if @nDevExists = 0 then
      select '2' as "n_success_flag", --unregistered
        '' as "c_mode",
        @LDateTime as "t_timestamp" for xml raw,elements;
      return
    end if;
    --Approval Pending
    select "count"("c_device_id")
      into @nPendingApproval from "st_device_mst"
      where "c_device_id" = @devID
      and "n_cancel_flag" = 9
      and "c_br_code" = @BrCode;
    if @nPendingApproval >= 1 then
      select '3' as "n_success_flag",
        '' as "c_mode",
        @LDateTime as "t_timestamp" for xml raw,elements;
      return
    end if;
    --Approval Pending
    select "count"("c_device_id")
      into @nDevLocked from "st_device_mst"
      where "c_device_id" = @devID
      and "n_cancel_flag" = 1
      and "c_br_code" = @BrCode;
    if @nDevLocked >= 1 then
      select '4' as "n_success_flag",
        '' as "c_mode",
        @LDateTime as "t_timestamp" for xml raw,elements;
      return
    end if;
    select "c_c2code" into @c2code from "system_parameter";
    select "hash"(@userId)+"hash"(@c2code)+"hash"(@UserPass) into @UserPass from "ddds_user_mst" where "c_user_id" = @userId;
    select "count"("c_user_id") into @nUserValid from "ddds_user_mst" where "c_user_id" = @userId and "c_user_pass" = @UserPass;
    if @nUserValid = 0 then
      select '0' as "n_success_flag",
        'Invalid User Id or Password !!' as "c_mode",
        @LDateTime as "t_timestamp" for xml raw,elements;
      return
    end if;
    select "isnull"("n_allow_store_track",1) into @n_allow_store_track from "ddds_user_mst" where "c_user_id" = @userId and "c_user_pass" = @UserPass;
    if @nUserValid > 0 then
      if @n_allow_store_track = 0 then
        select '0' as "n_success_flag",
          'StoreTrack Module Is Not Eanbled for User '+@userId+'; Please Contact Supervisor !!  ' as "c_mode",
          @LDateTime as "t_timestamp" for xml raw,elements
      else
        select "mode_list"."n_success_flag" as "n_success_flag",
          "mode_list"."c_mode" as "c_mode",
          @LDateTime as "t_timestamp",
          "isnull"("st_track_setup"."n_max_tray_items",40) as "n_max_tray_items",
          0 as "n_auto_bounce",
          0 as "n_idle_timeout",
          "isnull"("st_track_setup"."n_get_notif_refresh_time",120) as "n_get_notif_refresh_time",
          "isnull"("st_track_setup"."n_tray_status_refresh_time",120) as "n_tray_status_refresh_time",
          if "charindex"('\\UAT\\',"DB_PROPERTY"('file')) > 0 then 1 else 0 endif as "uat_flag",
          @Eg_db as "Eg_db",
          "isnull"("st_track_setup"."n_max_tray_item_exp",50) as "n_max_tray_item_exp",
          "isnull"("st_track_setup"."n_max_tray_items_inward",50) as "n_max_tray_items_inward",
          1 as "allow_shift_to_godown"
          from(select '1' as "n_success_flag",
              "c_module_name" as "c_mode",
              if "n_validate_user_right" = 0 then
                "n_active"
              else
                if "c_module_name" = 'Stock Audit' then
                  "uf_get_menu_rights"('001',"c_menu_id",@UserId,"ENABLED_DEFAULT")
                else
                  "uf_get_menu_rights"(@sApplicationID,"c_menu_id",@UserId,"ENABLED_DEFAULT")
                endif
              endif as "n_enable",
              "n_seq" as "n_ord",
              "c_br_code"
              from "st_track_module_mst" where "st_track_module_mst"."n_hide" = 0) as "mode_list"
            left outer join "st_track_setup" on "st_track_setup"."c_br_Code" = "mode_list"."c_br_code"
          where "mode_list"."n_enable" = 1
          order by "mode_list"."n_ord" asc for xml raw,elements
      end if
    else select '0' as "n_success_flag",
        'Invalid User Id or Password !!' as "c_mode",
        @LDateTime as "t_timestamp" for xml raw,elements
    end if when 'dev_reg' then
    select "ISNULL"("max"("n_device_no")+1,1)
      into @iDevNo from "st_device_mst" where "c_br_code" = @BrCode;
    set @cDevID = @devID;
    set @RegDate = "uf_default_date"();
    set @CancelFlag = 9;
    set @ADate = "uf_default_date"();
    set @LDateTime = "left"("now"(),19);
    insert into "st_device_mst"
      ( "c_br_code","n_device_no","c_device_id","d_registered_date","c_note","n_cancel_flag","d_adate",
      "t_ltime" ) values
      ( @BrCode,@iDevNo,@DevID,@RegDate,@cNote,@CancelFlag,@ADate,@LDateTime ) ;
    if sqlstate = '00000' then
      commit work;
      select 'Success : Request Sucessfully placed for Device ID : '+@DevID+@ColSep+'Server Generated Serial No : '+"string"(@iDevNo)+@ColSep+'Details : '+@cNote as "c_message" for xml raw,elements
    else
      select 'Failure : Request for Device ID : '+@DevID+' Failed '+@ColSep+'Please try again later' as "c_message" for xml raw,elements;
      rollback work
    end if when 'set_login' then
    set @RackGrpList = @RackGrpCode;
    while @RackGrpList <> '' loop
      select "Locate"(@RackGrpList,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@RackGrpList,@ColPos-1));
      set @RackGrpList = "SubString"(@RackGrpList,@ColPos+@ColMaxLen);
      --message 'RackGrpList '+@tmp type warning to client;                     
      if(select "count"("c_code") from "rack_group_mst" where "n_lock" = 0 and "c_code" = @tmp) > 0 then
        --valid rack group selection                            
        select "n_pos_seq" into @Seq from "st_store_stage_det" where "c_rack_grp_code" = @tmp;
        insert into "temp_rack_grp_list"( "c_rack_grp_code","c_stage_code","n_seq" ) values( @tmp,@StageCode,@Seq ) 
      end if
    end loop;
    select "count"() into @loginRGCount from "temp_rack_grp_list";
    --vinay 18-09-19 to avoid the wrong selection of rg and stage
    if(select "count"() from "st_store_stage_det" join "st_store_stage_mst" on "st_store_stage_mst"."c_br_code" = "st_store_stage_det"."c_br_code"
          and "st_store_stage_det"."c_stage_code" = "st_store_stage_mst"."c_code"
          join "temp_rack_grp_list" on "temp_rack_grp_list"."c_stage_code" = "st_store_stage_det"."c_stage_code"
          and "temp_rack_grp_list"."c_rack_grp_code" = "st_store_stage_det"."c_rack_grp_code"
        where "st_store_stage_det"."c_stage_code" = @StageCode) = 0 then
      select 'Wrong Selection of Rack Group and Stage' as "c_message" for xml raw,elements;
      if @enable_log = 1 then
        insert into "st_log_ret"
          ( "c_doc_no","c_tray","c_stage","c_rg","n_flag","t_time" ) values
          ( '',@tmp,@StageCode,'Wrong Selection of Rack Group and Stage',4,"getdate"() ) 
      end if;
      return
    end if;
    --vinay 18-09-19 to avoid the wrong selection of rg and stage
    if(select "count"("c_rack_grp_code") from "st_track_tray_move" where "c_stage_code" = @StageCode and "n_inout" = 0) > 0 then
      select top 1 "c_doc_no",
        "c_tray_code",
        "count"("c_rack_grp_code") as "rg_cnt"
        into @DocNo,@CurrentTray,@tmRGcount
        from "st_track_tray_move"
        where "n_inout" = 0
        and "c_stage_code" = @StageCode
        group by "c_doc_no","c_tray_code"
        having "rg_cnt" <> @loginRGCount;
      if @tmRGcount is null and @loginRGCount > 1 then
        select top 1 "count"("tm"."c_rack_grp_code")
          into @seltmRGcount from "st_track_tray_move" as "tm"
            join "temp_rack_grp_list" as "rg" on "tm"."c_rack_grp_code" = "rg"."c_rack_grp_code"
            and "tm"."c_stage_code" = "rg"."c_stage_code"
          where "tm"."c_stage_code" = @StageCode
          and "tm"."n_inout" = 0
          group by "tm"."c_doc_no","c_tray_code";
        select top 1 "count"("tm"."c_rack_grp_code")
          into @stageRGcount from "st_track_tray_move" as "tm"
          where "tm"."c_stage_code" = @StageCode
          and "tm"."n_inout" = 0
          group by "tm"."c_doc_no","c_tray_code"
      end if end if;
    if @loginRGCount > 1 and(@seltmRGcount <> @stageRGcount or @tmRGcount is not null) then
      select 'Error! : Cannot login to the selected rack groups '+@ColSep+' Please process the pending documents' as "c_message" for xml raw,elements;
      return
    end if;
    set @RackGrpList = @RackGrpCode;
    while @RackGrpList <> '' loop
      --1 RackGrpList
      select "Locate"(@RackGrpList,@ColSep) into @ColPos;
      set @tmp = "Trim"("Left"(@RackGrpList,@ColPos-1));
      set @RackGrpList = "SubString"(@RackGrpList,@ColPos+@ColMaxLen);
      --message 'RackGrpList '+@tmp type warning to client;                     
      select "uf_st_login_status"(@BrCode,@tmp,1,@UserId,@devID) into @LoginStatus;
      if "length"(@LoginStatus) > 1 then
        select @LoginStatus as "c_message" for xml raw,elements;
        return
      end if
    end loop;
    select "count"("a"."c_user_id")
      into @RestrictFlag from "st_store_login_restriction" as "a" join "temp_rack_grp_list" as "b" on "a"."c_rack_grp_code" = "b"."c_rack_grp_code"
      where "a"."c_user_id" = @UserId;
    if(select "count"("c_user_id") from "st_store_login_det" where "c_br_code" = @BrCode and "c_user_id" = @UserId and "c_device_id" = @devID) > 0 then
      delete from "st_store_login_det"
        where "c_br_code" = @BrCode
        and "c_user_id" = @UserId
        and "c_device_id" = @devID;
      if sqlstate = '00000' then
        commit work
      else
        rollback work
      end if end if;
    insert into "st_store_login"
      ( "c_br_code","c_user_id","c_phase_code","c_device_id","t_login_time","t_action_start","c_godown_code","c_user_2",
      "c_note" ) on existing update defaults off values
      ( @BrCode,@UserId,'PH0001',@devID,@LDateTime,@LDateTime,@GodownCode,null,'RACK OPERATIONS' ) ;
    insert into "st_store_login_det"
      ( "c_br_code","c_user_id","c_stage_code","c_rack_grp_code","c_device_id","t_login_time","d_adate","t_ltime",
      "c_user_2" ) 
      select @BrCode,@UserId,"c_stage_code","c_rack_grp_code",@devID,@LDateTime,@LDate,@LDateTime,null
        from "temp_rack_grp_list";
    call "uf_update_login_time"(@BrCode,@devID,@UserId,'PH0001',"isnull"(@loginMode,'RACK OPERATIONS'),@GodownCode,1);
    if sqlstate = '00000' then
      select '' as "c_message" for xml raw,elements;
      commit work
    else
      select 'FAILURE' as "c_message" for xml raw,elements;
      rollback work
    end if when 'util_login' then
    set @loginMode = "HTTP_VARIABLE"('loginMode');
    insert into "st_store_login"
      ( "c_br_code","c_user_id","c_phase_code","c_device_id","t_login_time","t_action_start","c_godown_code","c_user_2",
      "c_note" ) on existing update defaults off values
      ( @BrCode,@UserId,'PH0001',@devID,@LDateTime,@LDateTime,@GodownCode,null,@loginMode ) ;
    call "uf_update_login_time"(@BrCode,@devID,@UserId,'PH0001',@loginMode,@GodownCode,1);
    if sqlstate = '00000' then
      select '' as "c_message" for xml raw,elements;
      commit work
    else
      select 'FAILURE' as "c_message" for xml raw,elements;
      rollback work
    end if when 'logout' then
    update "st_store_login"
      set "t_login_time" = null
      where "c_phase_code" = 'PH0001'
      and "c_user_id" = @UserId
      and "c_device_id" = @devID;
    update "st_store_login_det"
      set "t_login_time" = null
      where "c_stage_code" = @StageCode
      and "c_user_id" = @UserId
      and "c_device_id" = @devID;
    call "uf_update_login_time"(@BrCode,@devID,@UserId,'PH0001','',@GodownCode,0);
    commit work;
    select '1' as "c_message" for xml raw,elements
  when 'dashboard_login' then
    select '1' as "n_success_flag",
      "c_module_name" as "c_mode",
      "n_active" as "n_enable",
      "n_seq" as "n_ord",
      "c_br_code"
      from "st_track_dashboard_module_mst"
      where "n_enable" = 1 order by "n_ord" asc for xml raw,elements
  when 'Get_setup' then -----------------------------------------------------------------------
    --HdrData ==M00033^^
    set @HdrData = "http_variable"('HdrData');
    call "uf_get_module_mst_value_multi"(@HdrData,@ColPos,@ColMaxLen,@ColSep);
    select "n_active" into @smanwise_tray_status from "st_track_module_mst" where "c_code" = 'M00041';
    return
  end case
end;