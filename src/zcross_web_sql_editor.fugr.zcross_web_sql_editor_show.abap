FUNCTION zcross_web_sql_editor_show.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IV_WIDTH) TYPE  I DEFAULT 150
*"     REFERENCE(IV_HEIGHT) TYPE  I DEFAULT 30
*"----------------------------------------------------------------------

*----------------------------------------------------------------------*
* Identification                                                       *
* Author           : Danyl Ivanov                                      *
* Creation date    : 10.05.2026 00:00:00                               *
* Owner            : Danyl Ivanov                                      *
* Short Description: Pop up dynpro 0100 sized to the caller's request. *
*                    The dynpro hosts the cl_gui_html_viewer that the  *
*                    editor class drives.                              *
*----------------------------------------------------------------------*

  DATA:
    lv_col1  TYPE i VALUE 5,
    lv_line1 TYPE i VALUE 2,
    lv_col2  TYPE i,
    lv_line2 TYPE i.

  "----------------------------------------------------------------------*
  "Translate (width, height) Into Absolute Popup Coordinates
  "----------------------------------------------------------------------*
  lv_col2  = lv_col1  + iv_width.
  lv_line2 = lv_line1 + iv_height.

  "----------------------------------------------------------------------*
  "Open the Modal Popup
  "----------------------------------------------------------------------*
  CALL SCREEN 100
    STARTING AT lv_col1  lv_line1
    ENDING   AT lv_col2  lv_line2.

ENDFUNCTION.
