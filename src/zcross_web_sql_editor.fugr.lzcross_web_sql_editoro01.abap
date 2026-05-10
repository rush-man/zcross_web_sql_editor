*----------------------------------------------------------------------*
*  Include          LZCROSS_WEB_SQL_EDITORO01                          *
*  PBO module of dynpro 0100 - delegates straight to the editor class. *
*----------------------------------------------------------------------*

MODULE status_0100 OUTPUT.

  "----------------------------------------------------------------------*
  "Set GUI Status (Standard Popup Status With BACK / EXIT / CANC)
  "----------------------------------------------------------------------*
  SET PF-STATUS 'STATUS_0100'.
  SET TITLEBAR  'TITLE_0100'.

  "----------------------------------------------------------------------*
  "Hand Off to the Editor Class - It Does HTML Setup On First PBO and
  "Closes the Popup Once the User Has Confirmed or Cancelled.
  "----------------------------------------------------------------------*
  TRY.
      zcl_cross_web_sql_editor=>on_pbo( ).
    CATCH zcx_cross_util INTO DATA(lo_ex).
      lo_ex->display( ).
      LEAVE TO SCREEN 0.
  ENDTRY.

ENDMODULE.
