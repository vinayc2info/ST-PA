/*Query to clear all the records from ST tables.*/

delete from st_track_tray_move; 
update st_track_det set n_complete=2 where n_complete in (0,1);
update st_track_pick set n_reject_qty=n_qty where n_qty-(n_reject_qty+n_confirm_qty)>0;
update st_track_mst set n_complete=9 where n_confirm=1 and n_complete=0; 
delete from tray_ledger where c_prefix<>'OT'; 
delete from st_tray_lock; 
delete from st_pick_backup;
delete from st_track_in;
update stock set n_hold_qty = 0, n_store_track_qty = 0 where n_hold_qty<>0;
update stock_godown set n_hold_qty = 0, n_store_track_qty = 0 where  n_hold_qty<>0;