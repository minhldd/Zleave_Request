REPORT z_check_dcl.

DATA lv_ts TYPE timestampl.
GET TIME STAMP FIELD lv_ts.

UPDATE zquota
  SET last_updated_at = @lv_ts
  WHERE last_updated_at < '20000101000000.0000000'.

COMMIT WORK.
WRITE: / 'Fixed:', sy-dbcnt, 'records'.
