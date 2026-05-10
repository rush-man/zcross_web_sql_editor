CLASS zcl_cross_web_sql_editor DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

*----------------------------------------------------------------------*
* Identification                                                       *
* Author           : Danyl Ivanov                                      *
* Creation date    : 10.05.2026 00:00:00                               *
* Owner            : Danyl Ivanov                                      *
* Development No.  :                                                   *
* Short Description: Web-style HANA SQL editor popup, hosted in        *
*                    cl_gui_html_viewer with client-side syntax        *
*                    highlighting.                                     *
*----------------------------------------------------------------------*
* Changes                                                              *
* Chg. date   Developer    Owner    CRT-Ref    Description             *
*----------------------------------------------------------------------*

  PUBLIC SECTION.
    CONSTANTS:
      mc_mode_edit    TYPE char1 VALUE 'E' ##NO_TEXT,
      mc_mode_display TYPE char1 VALUE 'D' ##NO_TEXT.

    TYPES:
      BEGIN OF ty_s_result,
        confirmed TYPE abap_bool,
        sql       TYPE string,
      END OF ty_s_result.

    "----------------------------------------------------------------------*
    " Static Facade
    "----------------------------------------------------------------------*
    CLASS-METHODS show
      IMPORTING
        !iv_sql    TYPE string
        !iv_mode   TYPE char1   DEFAULT mc_mode_edit
        !iv_title  TYPE string  DEFAULT `SQL Editor`
        !iv_width  TYPE i       DEFAULT 150
        !iv_height TYPE i       DEFAULT 30
      RETURNING
        VALUE(rs_result) TYPE ty_s_result
      RAISING
        zcx_cross_util.

    "----------------------------------------------------------------------*
    " Hooks for Dynpro Modules in Function Group ZCROSS_WEB_SQL_EDITOR
    "----------------------------------------------------------------------*
    CLASS-METHODS on_pbo
      RAISING zcx_cross_util.

    CLASS-METHODS on_pai
      IMPORTING !iv_okcode TYPE sy-ucomm.

  PRIVATE SECTION.
    TYPES:
      ty_t_post TYPE TABLE OF cnht_post_data_line WITH DEFAULT KEY.

    CLASS-DATA mso_active TYPE REF TO zcl_cross_web_sql_editor.

    DATA:
      mv_sql       TYPE string,
      mv_mode      TYPE char1,
      mv_title     TYPE string,
      mv_done      TYPE abap_bool,
      ms_result    TYPE ty_s_result,
      mo_container TYPE REF TO cl_gui_custom_container,
      mo_html      TYPE REF TO cl_gui_html_viewer.

    METHODS constructor
      IMPORTING
        !iv_sql   TYPE string
        !iv_mode  TYPE char1
        !iv_title TYPE string.

    METHODS set_up_html_viewer
      RAISING zcx_cross_util.

    METHODS build_html
      RETURNING VALUE(rv_html) TYPE string.

    METHODS build_keyword_list
      RETURNING VALUE(rv_csv) TYPE string.

    METHODS escape_for_html
      IMPORTING !iv_text TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    METHODS on_sapevent
      FOR EVENT sapevent OF cl_gui_html_viewer
      IMPORTING action getdata postdata.

    METHODS extract_sql_from_post
      IMPORTING !it_post TYPE ty_t_post
      RETURNING VALUE(rv_sql) TYPE string.

    METHODS finish
      IMPORTING
        !iv_confirmed TYPE abap_bool
        !iv_sql       TYPE string.

ENDCLASS.



CLASS zcl_cross_web_sql_editor IMPLEMENTATION.

  METHOD show.

*----------------------------------------------------------------------*
* Identification                                                       *
* Author           : Danyl Ivanov                                      *
* Creation date    : 10.05.2026 00:00:00                               *
* Owner            : Danyl Ivanov                                      *
* Short Description: Build the editor instance, open the popup dynpro, *
*                    return the (possibly edited) SQL.                 *
*----------------------------------------------------------------------*

    "----------------------------------------------------------------------*
    "Build the Editor Instance and Stash It For the Dynpro Modules
    "----------------------------------------------------------------------*
    CREATE OBJECT mso_active
      EXPORTING
        iv_sql   = iv_sql
        iv_mode  = iv_mode
        iv_title = iv_title.

    "----------------------------------------------------------------------*
    "Run the Popup Dynpro via the Function-Group Wrapper
    "----------------------------------------------------------------------*
    TRY.
        CALL FUNCTION 'ZCROSS_WEB_SQL_EDITOR_SHOW'
          EXPORTING
            iv_width  = iv_width
            iv_height = iv_height.

      CATCH cx_root INTO DATA(lo_root).
        CLEAR mso_active.
        zcx_cross_util=>raise_root( io_root = lo_root ).
    ENDTRY.

    "----------------------------------------------------------------------*
    "Read Result and Release Active Reference
    "----------------------------------------------------------------------*
    IF mso_active IS BOUND.
      rs_result = mso_active->ms_result.
      CLEAR mso_active.
    ENDIF.

  ENDMETHOD.


  METHOD constructor.

*----------------------------------------------------------------------*
* Short Description: Initialise instance state. Default result is      *
*                    'cancelled, original SQL'.                        *
*----------------------------------------------------------------------*

    mv_sql    = iv_sql.
    mv_mode   = iv_mode.
    mv_title  = iv_title.
    ms_result = VALUE #( confirmed = abap_false sql = iv_sql ).

  ENDMETHOD.


  METHOD on_pbo.

*----------------------------------------------------------------------*
* Short Description: Set up the HTML viewer on first PBO call, leave   *
*                    the screen on subsequent ones if event handler    *
*                    has signalled completion.                         *
*----------------------------------------------------------------------*

    "----------------------------------------------------------------------*
    "Defensive: No Active Instance Means Caller Routed Wrong - Just Leave
    "----------------------------------------------------------------------*
    IF mso_active IS NOT BOUND.
      LEAVE TO SCREEN 0.
      RETURN.
    ENDIF.

    "----------------------------------------------------------------------*
    "First-Time Setup of the HTML Viewer
    "----------------------------------------------------------------------*
    IF mso_active->mo_html IS NOT BOUND.
      mso_active->set_up_html_viewer( ).
    ENDIF.

    "----------------------------------------------------------------------*
    "Auto-Leave When Event Handler Has Marked Done
    "----------------------------------------------------------------------*
    IF mso_active->mv_done = abap_true.
      LEAVE TO SCREEN 0.
    ENDIF.

  ENDMETHOD.


  METHOD on_pai.

*----------------------------------------------------------------------*
* Short Description: Map standard window-close ok-codes to 'cancel'.   *
*                    All other interaction comes back via SAPEVENT.    *
*----------------------------------------------------------------------*

    CASE iv_okcode.
      WHEN 'BACK' OR 'EXIT' OR 'CANC'.

        "----------------------------------------------------------------------*
        "Treat F3/F12/F15 as Cancel
        "----------------------------------------------------------------------*
        IF mso_active IS BOUND.
          mso_active->finish( iv_confirmed = abap_false
                              iv_sql       = mso_active->mv_sql ).
        ENDIF.
        LEAVE TO SCREEN 0.
    ENDCASE.

  ENDMETHOD.


  METHOD finish.

*----------------------------------------------------------------------*
* Short Description: Capture result and mark as done so the next PBO   *
*                    cycle closes the popup.                           *
*----------------------------------------------------------------------*

    ms_result = VALUE #( confirmed = iv_confirmed sql = iv_sql ).
    mv_done   = abap_true.

  ENDMETHOD.


  METHOD set_up_html_viewer.

*----------------------------------------------------------------------*
* Short Description: Instantiate the custom container + HTML viewer,   *
*                    register the SAPEVENT handler, and load the       *
*                    generated HTML page into the viewer.              *
*----------------------------------------------------------------------*

    DATA:
      lv_html TYPE string,
      lv_url  TYPE c LENGTH 1024,
      lv_xstr TYPE xstring,
      lv_size TYPE i,
      lt_data TYPE solix_tab.

    "----------------------------------------------------------------------*
    "Custom Container 'CC_HTML' Must Exist on Dynpro 0100
    "----------------------------------------------------------------------*
    CREATE OBJECT mo_container
      EXPORTING
        container_name              = 'CC_HTML'
      EXCEPTIONS
        cntl_error                  = 1
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5
        OTHERS                      = 6.
    IF sy-subrc <> 0.
      zcx_cross_util=>raise_sy( ).
    ENDIF.

    "----------------------------------------------------------------------*
    "Build the HTML Viewer Inside the Container
    "----------------------------------------------------------------------*
    CREATE OBJECT mo_html
      EXPORTING
        parent             = mo_container
      EXCEPTIONS
        cntl_error         = 1
        cntl_install_error = 2
        dp_install_error   = 3
        dp_error           = 4
        OTHERS             = 5.
    IF sy-subrc <> 0.
      zcx_cross_util=>raise_sy( ).
    ENDIF.

    "----------------------------------------------------------------------*
    "Subscribe to SAPEVENT - This Is the Channel From the Page Back to ABAP
    "----------------------------------------------------------------------*
    SET HANDLER on_sapevent FOR mo_html.
    mo_html->set_registered_events(
      events = VALUE cntl_simple_events(
        ( eventid = cl_gui_html_viewer=>m_id_sapevent appl_event = 'X' ) ) ).

    "----------------------------------------------------------------------*
    "Build the HTML Page and Convert to Binary for load_data
    "----------------------------------------------------------------------*
    lv_html = build_html( ).

    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text     = lv_html
        mimetype = 'text/html; charset=utf-8'
      IMPORTING
        buffer   = lv_xstr
      EXCEPTIONS
        failed   = 1
        OTHERS   = 2.
    IF sy-subrc <> 0.
      zcx_cross_util=>raise_sy( ).
    ENDIF.

    CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
      EXPORTING
        buffer        = lv_xstr
      IMPORTING
        output_length = lv_size
      TABLES
        binary_tab    = lt_data.

    "----------------------------------------------------------------------*
    "Push the Page Into the In-Memory File Cache and Show It
    "----------------------------------------------------------------------*
    mo_html->load_data(
      EXPORTING
        type         = 'text'
        subtype      = 'html'
        size         = lv_size
      IMPORTING
        assigned_url = lv_url
      CHANGING
        data_table   = lt_data
      EXCEPTIONS
        OTHERS       = 1 ).
    IF sy-subrc <> 0.
      zcx_cross_util=>raise_sy( ).
    ENDIF.

    mo_html->show_url( url = lv_url ).

  ENDMETHOD.


  METHOD on_sapevent.

*----------------------------------------------------------------------*
* Short Description: Dispatch sapevent: callbacks coming from clicks   *
*                    or form submits inside the HTML page.             *
*----------------------------------------------------------------------*

    CASE action.

      WHEN 'ok'.

        "----------------------------------------------------------------------*
        "OK: Read Edited SQL From Form Post and Confirm
        "----------------------------------------------------------------------*
        finish(
          iv_confirmed = abap_true
          iv_sql       = extract_sql_from_post( postdata ) ).

      WHEN 'cancel'.

        "----------------------------------------------------------------------*
        "Cancel: Keep Original SQL, Confirmed = false
        "----------------------------------------------------------------------*
        finish( iv_confirmed = abap_false iv_sql = mv_sql ).

    ENDCASE.

  ENDMETHOD.


  METHOD extract_sql_from_post.

*----------------------------------------------------------------------*
* Short Description: Pull the 'sql' field out of the                   *
*                    application/x-www-form-urlencoded POST body.      *
*----------------------------------------------------------------------*

    DATA:
      lv_all     TYPE string,
      lv_encoded TYPE string.

    "----------------------------------------------------------------------*
    "Concatenate Post-Data Lines Into a Single Buffer
    "----------------------------------------------------------------------*
    LOOP AT it_post INTO DATA(lv_line).
      lv_all = lv_all && lv_line.
    ENDLOOP.

    "----------------------------------------------------------------------*
    "Pull the Field Out and Decode
    "----------------------------------------------------------------------*
    FIND REGEX `(?:^|&)sql=([^&]*)` IN lv_all SUBMATCHES lv_encoded.
    IF sy-subrc = 0.

      "----------------------------------------------------------------------*
      "x-www-form-urlencoded Uses '+' for Space; Convert First, Then Decode
      "----------------------------------------------------------------------*
      REPLACE ALL OCCURRENCES OF `+` IN lv_encoded WITH ` `.
      rv_sql = cl_http_utility=>unescape_url( lv_encoded ).

    ENDIF.

  ENDMETHOD.


  METHOD escape_for_html.

*----------------------------------------------------------------------*
* Short Description: Minimal HTML escape (text contexts only - not for *
*                    attribute values that contain quotes).            *
*----------------------------------------------------------------------*

    rv_text = iv_text.
    REPLACE ALL OCCURRENCES OF `&` IN rv_text WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN rv_text WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN rv_text WITH `&gt;`.

  ENDMETHOD.


  METHOD build_keyword_list.

*----------------------------------------------------------------------*
* Short Description: Comma-separated, single-quoted list of HANA SQL   *
*                    keywords - emitted into the JS source as a literal*
*                    used to populate the KEYWORDS lookup map.         *
*----------------------------------------------------------------------*

    rv_csv =
      `'SELECT','FROM','WHERE','GROUP','BY','HAVING','ORDER','ASC','DESC',`     &&
      `'LIMIT','OFFSET','TOP','UNION','INTERSECT','EXCEPT','ALL','DISTINCT',`   &&
      `'AS','ON','USING','JOIN','INNER','LEFT','RIGHT','OUTER','FULL','CROSS',` &&
      `'LATERAL','NATURAL','AND','OR','NOT','IN','BETWEEN','LIKE','IS','NULL',` &&
      `'EXISTS','ANY','SOME','CASE','WHEN','THEN','ELSE','END','IF','ELSIF',`   &&
      `'INSERT','INTO','VALUES','UPDATE','SET','DELETE','MERGE','UPSERT',`      &&
      `'RETURNING','TRUNCATE','WITH','RECURSIVE','CREATE','DROP','ALTER',`      &&
      `'TABLE','VIEW','INDEX','SEQUENCE','SCHEMA','USER','ROLE','FUNCTION',`    &&
      `'PROCEDURE','TRIGGER','SYNONYM','TYPE','ADD','COLUMN','RENAME','TO',`    &&
      `'REPLACE','PRIMARY','KEY','FOREIGN','REFERENCES','UNIQUE','CONSTRAINT',` &&
      `'CHECK','DEFAULT','GENERATED','ALWAYS','IDENTITY','AUTOINCREMENT',`      &&
      `'BEGIN','COMMIT','ROLLBACK','SAVEPOINT','TRANSACTION','LOCK','UNLOCK',`  &&
      `'GRANT','REVOKE','PRIVILEGES','EXECUTE','CALL','DECLARE','CURSOR',`      &&
      `'OPEN','CLOSE','FETCH','LOOP','WHILE','FOR','EXIT','CONTINUE',`          &&
      `'RAISE','SIGNAL','EXCEPTION','HANDLER','CONTINUES','STOP',`              &&
      `'COLUMN','ROW','STORE','COLUMNAR','TENANT','TEMPORARY','GLOBAL','LOCAL',`&&
      `'SESSION','CURRENT_USER','CURRENT_SCHEMA','CURRENT_DATE',`               &&
      `'CURRENT_TIME','CURRENT_TIMESTAMP','CURRENT_UTCTIMESTAMP','SYSDATE',`    &&
      `'SYSUUID','SYSTEM_TIME','OF','BEFORE','AFTER','EACH','STATEMENT',`       &&
      `'CONTAINS','FUZZY','SCORE','LANGUAGE','LINGUISTIC','EXACT','SIMILAR',`   &&
      `'SERIES_GENERATE','GENERATE','PERIOD','GAP','SPLIT','UNNEST','TABLESAMPLE',`&&
      `'PARTITION','RANGE','HASH','ROUNDROBIN','OVER','WINDOW','PARTITIONED',`  &&
      `'BUCKETS','LOAD','UNLOAD','PARALLEL','SERIAL','CACHE','NOCACHE',`        &&
      `'INVALIDATE','REORG','MERGE','DELTA','TRUNCATE','ENABLE','DISABLE',`     &&
      `'FORCE','VALIDATE','EXPLAIN','PLAN','PLANVIZ','HINT'`.

  ENDMETHOD.


  METHOD build_html.

*----------------------------------------------------------------------*
* Short Description: Build the full HTML page (CSS + JS + textarea)    *
*                    that is loaded into cl_gui_html_viewer. The JS    *
*                    layer tokenises the textarea contents on every    *
*                    keystroke and renders highlighted spans into a    *
*                    <pre> overlay positioned exactly behind it.       *
*----------------------------------------------------------------------*

    DATA:
      lv_nl       TYPE string,
      lv_sql_html TYPE string,
      lv_kw       TYPE string,
      lv_readonly TYPE string,
      lv_buttons  TYPE string,
      lv_h        TYPE string.

    lv_nl       = cl_abap_char_utilities=>newline.
    lv_sql_html = escape_for_html( mv_sql ).
    lv_kw       = build_keyword_list( ).

    "----------------------------------------------------------------------*
    "Mode-Dependent Toolbar / Textarea Attributes
    "----------------------------------------------------------------------*
    IF mv_mode = mc_mode_display.
      lv_readonly = ` readonly`.
      lv_buttons  = `<button class="btn cancel" onclick="cancelClick()">Close</button>`.
    ELSE.
      lv_readonly = ``.
      lv_buttons  =
        `<button class="btn cancel" onclick="cancelClick()">Cancel</button>` &&
        `<button class="btn ok" onclick="okClick()">OK</button>`.
    ENDIF.

    "----------------------------------------------------------------------*
    "Document Header + CSS (HANA Studio Dark)
    "----------------------------------------------------------------------*
    lv_h =
      `<!DOCTYPE html>` && lv_nl &&
      `<html><head>` && lv_nl &&
      `<meta http-equiv="X-UA-Compatible" content="IE=edge">` && lv_nl &&
      `<meta charset="utf-8">` && lv_nl &&
      `<title>` && escape_for_html( mv_title ) && `</title>` && lv_nl &&
      `<style>` && lv_nl &&
      `* { box-sizing: border-box; }` && lv_nl &&
      `html, body { height: 100%; margin: 0; padding: 0; overflow: hidden;` && lv_nl &&
      `  font-family: Consolas, "Courier New", monospace;` && lv_nl &&
      `  background: #1e1e1e; color: #d4d4d4; }` && lv_nl &&
      `#toolbar { height: 38px; background: #2d2d30; border-bottom: 1px solid #3e3e42;` && lv_nl &&
      `  display: flex; align-items: center; padding: 0 10px; gap: 8px; }` && lv_nl &&
      `#title { flex: 1; font-size: 13px; color: #cccccc; font-weight: bold; }` && lv_nl &&
      `#meta  { font-size: 11px; color: #888; margin-right: 12px; }` && lv_nl &&
      `.btn { background: #0e639c; color: #ffffff; border: 0; padding: 6px 16px;` && lv_nl &&
      `  font-size: 12px; font-family: inherit; cursor: pointer; border-radius: 2px; }` && lv_nl &&
      `.btn:hover { background: #1177bb; }` && lv_nl &&
      `.btn.cancel { background: #3c3c3c; }` && lv_nl &&
      `.btn.cancel:hover { background: #505050; }` && lv_nl &&
      `#editor { position: absolute; top: 38px; left: 0; right: 0; bottom: 0; }` && lv_nl &&
      `#hl, #ed { position: absolute; top: 0; left: 0; right: 0; bottom: 0;` && lv_nl &&
      `  font-family: inherit; font-size: 13px; line-height: 1.45;` && lv_nl &&
      `  padding: 8px 12px; margin: 0; border: 0;` && lv_nl &&
      `  white-space: pre; word-wrap: normal; overflow: auto;` && lv_nl &&
      `  tab-size: 2; -moz-tab-size: 2; }` && lv_nl &&
      `#hl { pointer-events: none; color: #d4d4d4; z-index: 1; background: #1e1e1e; }` && lv_nl &&
      `#ed { background: transparent; color: transparent; caret-color: #ffffff;` && lv_nl &&
      `  resize: none; outline: none; z-index: 2; }` && lv_nl &&
      `#ed::selection { background: rgba(38, 79, 120, 0.7); color: transparent; }` && lv_nl &&
      `.kw  { color: #569cd6; font-weight: bold; }` && lv_nl &&
      `.str { color: #ce9178; }` && lv_nl &&
      `.num { color: #b5cea8; }` && lv_nl &&
      `.cmt { color: #6a9955; font-style: italic; }` && lv_nl &&
      `.fn  { color: #dcdcaa; }` && lv_nl &&
      `</style></head>` && lv_nl.

    "----------------------------------------------------------------------*
    "Body: Toolbar + Editor (Pre Overlay + Textarea) + Hidden Form
    "----------------------------------------------------------------------*
    lv_h = lv_h &&
      `<body>` && lv_nl &&
      `<div id="toolbar">` && lv_nl &&
      `  <span id="title">` && escape_for_html( mv_title ) && `</span>` && lv_nl &&
      `  <span id="meta"></span>` && lv_nl &&
      `  ` && lv_buttons && lv_nl &&
      `</div>` && lv_nl &&
      `<div id="editor">` && lv_nl &&
      `  <pre id="hl"></pre>` && lv_nl &&
      `  <textarea id="ed" spellcheck="false" autocomplete="off"` && lv_readonly && `>` &&
                lv_sql_html && `</textarea>` && lv_nl &&
      `</div>` && lv_nl.

    "----------------------------------------------------------------------*
    "JavaScript: Tokeniser + Highlighter + Sapevent Bridge
    "----------------------------------------------------------------------*
    lv_h = lv_h &&
      `<script>` && lv_nl &&
      `(function () {` && lv_nl &&
      `  var KW_LIST = [` && lv_kw && `];` && lv_nl &&
      `  var KEYWORDS = {};` && lv_nl &&
      `  for (var k = 0; k < KW_LIST.length; k++) { KEYWORDS[KW_LIST[k]] = 1; }` && lv_nl &&
      `  var FN_LIST = ['COUNT','SUM','MIN','MAX','AVG','COALESCE','IFNULL','NULLIF',` && lv_nl &&
      `    'CAST','CONVERT','TO_CHAR','TO_DATE','TO_TIMESTAMP','TO_NUMBER','TO_DECIMAL',` && lv_nl &&
      `    'SUBSTR','SUBSTRING','LENGTH','LPAD','RPAD','TRIM','LTRIM','RTRIM','REPLACE',` && lv_nl &&
      `    'UPPER','LOWER','INSTR','CONCAT','ROUND','FLOOR','CEIL','MOD','ABS','POWER',` && lv_nl &&
      `    'ROW_NUMBER','RANK','DENSE_RANK','LAG','LEAD','NTILE','FIRST_VALUE','LAST_VALUE',` && lv_nl &&
      `    'DAYS_BETWEEN','SECONDS_BETWEEN','ADD_DAYS','ADD_MONTHS','ADD_YEARS',` && lv_nl &&
      `    'EXTRACT','YEAR','MONTH','DAY','HOUR','MINUTE','SECOND','LOCATE','GREATEST','LEAST'];` && lv_nl &&
      `  var FUNCTIONS = {};` && lv_nl &&
      `  for (var f = 0; f < FN_LIST.length; f++) { FUNCTIONS[FN_LIST[f]] = 1; }` && lv_nl &&
      lv_nl &&
      `  function isAlpha(c)  { return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c === '_'; }` && lv_nl &&
      `  function isAlnum(c)  { return isAlpha(c) || (c >= '0' && c <= '9'); }` && lv_nl &&
      `  function isDigit(c)  { return c >= '0' && c <= '9'; }` && lv_nl &&
      `  function escHtml(s)  { return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }` && lv_nl &&
      lv_nl &&
      `  function highlight(code) {` && lv_nl &&
      `    var out = ''; var i = 0; var n = code.length;` && lv_nl &&
      `    while (i < n) {` && lv_nl &&
      `      var c = code.charAt(i);` && lv_nl &&
      `      if (c === '-' && code.charAt(i + 1) === '-') {` && lv_nl &&
      `        var j = code.indexOf('\n', i); if (j < 0) j = n;` && lv_nl &&
      `        out += '<span class="cmt">' + escHtml(code.substring(i, j)) + '</span>';` && lv_nl &&
      `        i = j;` && lv_nl &&
      `      } else if (c === '/' && code.charAt(i + 1) === '*') {` && lv_nl &&
      `        var j2 = code.indexOf('*/', i + 2); if (j2 < 0) j2 = n; else j2 += 2;` && lv_nl &&
      `        out += '<span class="cmt">' + escHtml(code.substring(i, j2)) + '</span>';` && lv_nl &&
      `        i = j2;` && lv_nl &&
      `      } else if (c === '\'' || c === '"') {` && lv_nl &&
      `        var q = c; var j3 = i + 1;` && lv_nl &&
      `        while (j3 < n) {` && lv_nl &&
      `          if (code.charAt(j3) === q) {` && lv_nl &&
      `            if (code.charAt(j3 + 1) === q) { j3 += 2; continue; }` && lv_nl &&
      `            j3++; break;` && lv_nl &&
      `          }` && lv_nl &&
      `          j3++;` && lv_nl &&
      `        }` && lv_nl &&
      `        out += '<span class="str">' + escHtml(code.substring(i, j3)) + '</span>';` && lv_nl &&
      `        i = j3;` && lv_nl &&
      `      } else if (isDigit(c)) {` && lv_nl &&
      `        var j4 = i;` && lv_nl &&
      `        while (j4 < n) {` && lv_nl &&
      `          var cc = code.charAt(j4);` && lv_nl &&
      `          if (isDigit(cc) || cc === '.') { j4++; continue; }` && lv_nl &&
      `          break;` && lv_nl &&
      `        }` && lv_nl &&
      `        out += '<span class="num">' + escHtml(code.substring(i, j4)) + '</span>';` && lv_nl &&
      `        i = j4;` && lv_nl &&
      `      } else if (isAlpha(c)) {` && lv_nl &&
      `        var j5 = i;` && lv_nl &&
      `        while (j5 < n && isAlnum(code.charAt(j5))) { j5++; }` && lv_nl &&
      `        var word = code.substring(i, j5);` && lv_nl &&
      `        var upper = word.toUpperCase();` && lv_nl &&
      `        if (KEYWORDS[upper]) {` && lv_nl &&
      `          out += '<span class="kw">' + escHtml(word) + '</span>';` && lv_nl &&
      `        } else if (FUNCTIONS[upper] && code.charAt(j5) === '(') {` && lv_nl &&
      `          out += '<span class="fn">' + escHtml(word) + '</span>';` && lv_nl &&
      `        } else {` && lv_nl &&
      `          out += escHtml(word);` && lv_nl &&
      `        }` && lv_nl &&
      `        i = j5;` && lv_nl &&
      `      } else {` && lv_nl &&
      `        out += escHtml(c); i++;` && lv_nl &&
      `      }` && lv_nl &&
      `    }` && lv_nl &&
      `    return out;` && lv_nl &&
      `  }` && lv_nl &&
      lv_nl &&
      `  function syncHl() {` && lv_nl &&
      `    var ed = document.getElementById('ed');` && lv_nl &&
      `    var hl = document.getElementById('hl');` && lv_nl &&
      `    var meta = document.getElementById('meta');` && lv_nl &&
      `    var code = ed.value;` && lv_nl &&
      `    if (code.length === 0 || code.charAt(code.length - 1) === '\n') { code += ' '; }` && lv_nl &&
      `    hl.innerHTML = highlight(code);` && lv_nl &&
      `    hl.scrollTop = ed.scrollTop;` && lv_nl &&
      `    hl.scrollLeft = ed.scrollLeft;` && lv_nl &&
      `    var lines = ed.value.split('\n').length;` && lv_nl &&
      `    meta.innerHTML = ed.value.length + ' chars &middot; ' + lines + ' lines';` && lv_nl &&
      `  }` && lv_nl &&
      lv_nl &&
      `  function postAction(action) {` && lv_nl &&
      `    var ed = document.getElementById('ed');` && lv_nl &&
      `    var f = document.createElement('form');` && lv_nl &&
      `    f.method = 'POST';` && lv_nl &&
      `    f.action = 'sapevent:' + action;` && lv_nl &&
      `    var ta = document.createElement('textarea');` && lv_nl &&
      `    ta.name = 'sql';` && lv_nl &&
      `    ta.value = ed ? ed.value : '';` && lv_nl &&
      `    f.appendChild(ta);` && lv_nl &&
      `    document.body.appendChild(f);` && lv_nl &&
      `    f.submit();` && lv_nl &&
      `  }` && lv_nl &&
      `  window.okClick     = function () { postAction('ok'); };` && lv_nl &&
      `  window.cancelClick = function () { postAction('cancel'); };` && lv_nl &&
      lv_nl &&
      `  function init() {` && lv_nl &&
      `    var ed = document.getElementById('ed');` && lv_nl &&
      `    if (!ed) { return; }` && lv_nl &&
      `    if (ed.addEventListener) {` && lv_nl &&
      `      ed.addEventListener('input', syncHl);` && lv_nl &&
      `      ed.addEventListener('scroll', syncHl);` && lv_nl &&
      `      ed.addEventListener('keydown', onKey);` && lv_nl &&
      `    } else if (ed.attachEvent) {` && lv_nl &&
      `      ed.attachEvent('onkeyup', syncHl);` && lv_nl &&
      `      ed.attachEvent('onscroll', syncHl);` && lv_nl &&
      `      ed.attachEvent('onkeydown', onKey);` && lv_nl &&
      `    }` && lv_nl &&
      `    syncHl();` && lv_nl &&
      `    ed.focus();` && lv_nl &&
      `  }` && lv_nl &&
      lv_nl &&
      `  function onKey(e) {` && lv_nl &&
      `    e = e || window.event;` && lv_nl &&
      `    var key = e.keyCode || e.which;` && lv_nl &&
      `    var ed  = document.getElementById('ed');` && lv_nl &&
      `    if (key === 9) {` && lv_nl &&
      `      if (e.preventDefault) { e.preventDefault(); } else { e.returnValue = false; }` && lv_nl &&
      `      var s = ed.selectionStart, t = ed.selectionEnd;` && lv_nl &&
      `      ed.value = ed.value.substring(0, s) + '  ' + ed.value.substring(t);` && lv_nl &&
      `      ed.selectionStart = ed.selectionEnd = s + 2;` && lv_nl &&
      `      syncHl();` && lv_nl &&
      `    } else if (e.ctrlKey && key === 13) {` && lv_nl &&
      `      if (e.preventDefault) { e.preventDefault(); }` && lv_nl &&
      `      postAction('ok');` && lv_nl &&
      `    } else if (key === 27) {` && lv_nl &&
      `      if (e.preventDefault) { e.preventDefault(); }` && lv_nl &&
      `      postAction('cancel');` && lv_nl &&
      `    }` && lv_nl &&
      `  }` && lv_nl &&
      lv_nl &&
      `  if (document.readyState === 'complete' || document.readyState === 'interactive') {` && lv_nl &&
      `    init();` && lv_nl &&
      `  } else if (document.addEventListener) {` && lv_nl &&
      `    document.addEventListener('DOMContentLoaded', init);` && lv_nl &&
      `  } else {` && lv_nl &&
      `    window.onload = init;` && lv_nl &&
      `  }` && lv_nl &&
      `})();` && lv_nl &&
      `</script></body></html>`.

    rv_html = lv_h.

  ENDMETHOD.

ENDCLASS.
