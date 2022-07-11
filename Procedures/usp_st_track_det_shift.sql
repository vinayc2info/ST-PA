CREATE PROCEDURE "DBA"."usp_st_track_det_shift"()
begin
  /*
Author 		: Gargee
Procedure	: usp_update_st_track_det_log_from_st_track_det
SERVICE		: CALL usp_st_track_det_shift()
Date 		: 13-08-2018
Modified By     : 13-08-2019
Ldate 		: 
Purpose		: Move the data from st_track_det to st_track_log on dayend/week end /month end 
Input		: 
IndexDetails    : 
Tags		: 
Note		:
*/
  insert into "st_track_det_log"
    ( "c_doc_no","n_inout","c_item_code","c_batch_no","n_seq",
    "n_qty","n_sch_qty","n_bal_qty","c_note","c_rack","c_rack_grp_code",
    "c_stage_code","n_complete","c_reason_code","n_hold_flag","c_tray_code",
    "c_user","c_godown_code","c_stin_ref_no",
    "c_user_2","d_ldate","t_ltime","n_sch_slab_qty","n_sch_slab_sch_qty","n_sch_disc_perc",
    "n_non_pick_flag","n_scheme_disc","n_schm_qty_2_schm_disc" ) on existing skip
    select "d"."c_doc_no","d"."n_inout","d"."c_item_code","d"."c_batch_no","d"."n_seq",
      "d"."n_qty","d"."n_sch_qty","d"."n_bal_qty","d"."c_note","d"."c_rack","d"."c_rack_grp_code",
      "d"."c_stage_code","d"."n_complete","d"."c_reason_code","d"."n_hold_flag","d"."c_tray_code",
      "d"."c_user","d"."c_godown_code","d"."c_stin_ref_no","d"."c_user_2",
      "d"."d_ldate","d"."t_ltime","d"."n_sch_slab_qty","d"."n_sch_slab_sch_qty",
      "d"."n_sch_disc_perc","d"."n_non_pick_flag","d"."n_scheme_disc","d"."n_schm_qty_2_schm_disc"
      from "st_track_mst" as "m" join "st_track_det" as "d"
        on "m"."c_doc_no" = "d"."c_doc_no" and "m"."n_inout" = "d"."n_inout"
      where "m"."n_complete" in( 9,2 ) and "m"."n_inout" = 0 union --and d.c_doc_no='000/18/I/180007300438256'
    select "d"."c_doc_no","d"."n_inout","d"."c_item_code","d"."c_batch_no","d"."n_seq",
      "d"."n_qty","d"."n_sch_qty","d"."n_bal_qty","d"."c_note","d"."c_rack","d"."c_rack_grp_code",
      "d"."c_stage_code","d"."n_complete","d"."c_reason_code","d"."n_hold_flag","d"."c_tray_code",
      "d"."c_user","d"."c_godown_code","d"."c_stin_ref_no","d"."c_user_2",
      "d"."d_ldate","d"."t_ltime","d"."n_sch_slab_qty","d"."n_sch_slab_sch_qty",
      "d"."n_sch_disc_perc","d"."n_non_pick_flag","d"."n_scheme_disc","d"."n_schm_qty_2_schm_disc"
      from "st_track_mst" as "m" join "st_track_det" as "d"
        on "m"."c_doc_no" = "d"."c_doc_no" and "m"."n_inout" = "d"."n_inout"
      where "m"."n_complete" in( 8,2,9 ) and "m"."n_inout" = 1;
  insert into "st_track_not_found_invoice_log"
    ( "n_inv_no","n_crnt_no","c_phase_code","d_date","c_user","t_time","c_luser","d_ldate","t_ltime" ) on existing skip
    select "n_inv_no","n_crnt_no","c_phase_code","d_date","c_user","t_time","c_luser","d_ldate","t_ltime"
      from "st_track_not_found_invoice" where "n_crnt_no" <> 0;
  insert into "carton_mst_log"
    ( "n_srno","c_item_code","c_batch_no","c_tray_code","n_carton_no","n_qty","n_seq1",
    "n_lot","n_month","n_flag","d_ldate","t_ltime","c_dispatch_ref_no","n_pk",
    "c_ref_br_code","c_ref_year","c_ref_prefix","n_ref_srno","n_pick_seq","c_pick_tray","c_doc_no",
    "n_ref_seq","c_user","n_hold","n_check_seq" ) on existing skip
    select "carton_mst"."n_srno","carton_mst"."c_item_code","carton_mst"."c_batch_no","carton_mst"."c_tray_code","carton_mst"."n_carton_no","carton_mst"."n_qty","carton_mst"."n_seq1",
      "carton_mst"."n_lot","carton_mst"."n_month","carton_mst"."n_flag","carton_mst"."d_ldate","carton_mst"."t_ltime","carton_mst"."c_dispatch_ref_no","carton_mst"."n_pk",
      "carton_mst"."c_ref_br_code","carton_mst"."c_ref_year","carton_mst"."c_ref_prefix","carton_mst"."n_ref_srno","carton_mst"."n_pick_seq","carton_mst"."c_pick_tray","carton_mst"."c_doc_no",
      "carton_mst"."n_ref_seq","carton_mst"."c_user","carton_mst"."n_hold","carton_mst"."n_check_seq"
      from "carton_mst" where "d_ldate" < "days"("uf_default_date"(),-7);
  -- DELETING FROM st_track_not_found_invoice
  delete from "st_track_not_found_invoice" where "n_crnt_no" <> 0;
  -- DELETING STORE OUT ST_TRACK_DET_DATA
  delete from "st_track_det" as "d" from "st_track_mst" as "m"
    where "m"."c_doc_no" = "d"."c_doc_no" and "m"."n_inout" = "d"."n_inout"
    and "m"."n_complete" in( 9,2 ) and "m"."n_inout" = 0;
  -- DELETING STORE IN ST_TRACK_DET_DATA 
  delete from "st_track_det" as "d" from "st_track_mst" as "m"
    where "m"."c_doc_no" = "d"."c_doc_no" and "m"."n_inout" = "d"."n_inout"
    and "m"."n_complete" in( 8,2,9 ) and "m"."n_inout" = 1;
  -- DELETING LOGIN DATA  
  delete from "st_store_login" where "t_login_time" is null;
  delete from "st_store_login_det" where "t_login_time" is null;
  -- DELETING carton_mst more than 7 days
  delete from "carton_mst" where "d_ldate" < "days"("uf_default_date"(),-7);
  -- DELETING THE OLD 2 DAYS UNRELEASED PACK TRAYS FROM CHECK OUT
  delete from "tray_ledger" as "tm" from "tray_ledger" as "tm"
    join(select "c_tray_code","c_br_code","c_year","sum"("n_qty") as "ss" from "tray_ledger" group by "c_tray_code","c_br_code","c_year" having "ss" = 0) as "tl"
    on "tl"."c_tray_code" = "tm"."c_tray_code"
    and "tl"."c_br_code" = "tm"."c_br_code"
    and "tl"."c_year" = "tm"."c_year"
    and "tm"."c_prefix" <> 'OT'
    and cast("tm"."t_ltime" as date) <= "today"()-2;
  return
end;