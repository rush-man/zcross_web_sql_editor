# zcross_web_sql_editor

A small reusable utility that pops up a **web-style HANA SQL editor** inside
the SAP GUI window — syntax-highlighted, dark theme, a single static API call.

**GitHub:** https://github.com/rush-man/zcross_web_sql_editor — pull straight
from there with abapGit (`ZABAPGIT` → New Online → paste URL).

```abap
DATA(ls) = zcl_cross_web_sql_editor=>show(
             iv_sql   = lv_sql_in
             iv_mode  = zcl_cross_web_sql_editor=>mc_mode_edit ).

IF ls-confirmed = abap_true.
  lv_sql_out = ls-sql.
ENDIF.
```

## How it works (same pattern as abapGit)

A static façade class hosts a popup dynpro that hosts a single
`cl_gui_html_viewer`. The class generates an HTML/CSS/JS page in ABAP, pushes
it into the viewer, and listens to `SAPEVENT`. Inside the page, a small JS
tokeniser highlights HANA-SQL keywords, strings, numbers, comments, function
names — fully client-side, no roundtrip per keystroke. The OK button submits
the edited text back via a `<form action="sapevent:ok">` POST; the ABAP
event handler URL-decodes the `sql` field and stores it as the result.

```
caller ─▶ zcl_cross_web_sql_editor=>show( sql, mode, w, h )
              │
              │  CALL FUNCTION 'ZCROSS_WEB_SQL_EDITOR_SHOW'
              ▼
        dynpro 0100  ──── PBO ────▶ on_pbo  ──▶  build & load HTML into viewer
              │
              │  user types / presses OK
              ▼
        cl_gui_html_viewer fires SAPEVENT 'ok' with form post-data
              │
              ▼
        on_sapevent → finish → mv_done = abap_true
              │
              │  next PBO sees mv_done and LEAVE TO SCREEN 0
              ▼
        function module returns; show( ) reads ms_result and returns it
```

## API

```abap
CLASS-METHODS show
  IMPORTING
    !iv_sql    TYPE string                                       " SQL going in
    !iv_mode   TYPE char1   DEFAULT mc_mode_edit                 " 'E' / 'D'
    !iv_title  TYPE string  DEFAULT `SQL Editor`                 " window title
    !iv_width  TYPE i       DEFAULT 150                          " GUI columns
    !iv_height TYPE i       DEFAULT  30                          " GUI rows
  RETURNING VALUE(rs_result) TYPE ty_s_result                    " confirmed + sql
  RAISING   zcx_cross_util.
```

`mc_mode_edit` opens an editable textarea with OK + Cancel; `mc_mode_display`
opens a read-only view with a single Close button (and `confirmed` is always
`abap_false`). `iv_width` / `iv_height` are dynpro character cells, fed
straight into `CALL SCREEN ... ENDING AT iv_width iv_height`, so the caller
controls the popup size.

## Files

```
src/zcl_cross_web_sql_editor.clas.abap                                ← public façade + HTML viewer + JS template
src/zcross_web_sql_editor.fugr.abap                                   ← function-pool stub
src/zcross_web_sql_editor.fugr.lzcross_web_sql_editortop.abap         ← TOP include
src/zcross_web_sql_editor.fugr.lzcross_web_sql_editoro01.abap         ← PBO module
src/zcross_web_sql_editor.fugr.lzcross_web_sql_editori01.abap         ← PAI module
src/zcross_web_sql_editor.fugr.zcross_web_sql_editor_show.abap        ← function module wrapping CALL SCREEN
INSTALL.md                                                            ← dynpro 0100 layout + GUI status, end-to-end install steps
```

## Dependencies

- `zcl_cross_util` / `zcx_cross_util` from `zcross_abap` — for the canonical
  exception class and the cross-library style of error wrapping.
- Standard SAP: `cl_gui_html_viewer`, `cl_gui_custom_container`,
  `cl_http_utility`, `SCMS_STRING_TO_XSTRING`, `SCMS_XSTRING_TO_BINARY`.

## Usage examples

```abap
" ---- 1. Edit
DATA(ls) = zcl_cross_web_sql_editor=>show(
             iv_sql = `SELECT * FROM mara WHERE matnr LIKE 'A%'` ).

IF ls-confirmed = abap_true.
  WRITE: / 'Edited:', ls-sql.
ENDIF.

" ---- 2. Display (read-only) with custom size
zcl_cross_web_sql_editor=>show(
  iv_sql    = lv_long_sql
  iv_mode   = zcl_cross_web_sql_editor=>mc_mode_display
  iv_title  = `Final SQL`
  iv_width  = 200
  iv_height = 50 ).
```

## Customising the keyword list

The HANA SQL keyword set is built in `build_keyword_list( )`. Edit that one
method to add/remove keywords (e.g. for a project-specific dialect or to
narrow down to ANSI SQL). The CSS theme is in `build_html( )` next to the
`<style>` block — `.kw`, `.str`, `.num`, `.cmt`, `.fn` are the five token
classes the JS highlighter applies.
