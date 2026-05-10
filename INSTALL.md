# Installation

The project is split into two parts: the public class
`zcl_cross_web_sql_editor` and a tiny function group `zcross_web_sql_editor`
that hosts the popup dynpro. The whole repo is shaped as an abapGit working
copy.

## Option A — abapGit pull (recommended)

Open transaction **`ZABAPGIT`** → **+ New Online** → paste the GitHub repo
URL → choose / create a target package (`ZCROSS_WEB_SQL_EDITOR` or wherever
you keep cross utilities) → **Pull**. abapGit recreates:

- the class `ZCL_CROSS_WEB_SQL_EDITOR`
- the function group `ZCROSS_WEB_SQL_EDITOR` with all four standard
  includes (TOP / O01 / I01 / SAPL)
- the function module `ZCROSS_WEB_SQL_EDITOR_SHOW`
- **dynpro 0100** including the custom container `CC_HTML`, the OK code
  field and the modal-popup attributes — these are serialised in
  `zcross_web_sql_editor.fugr.xml` under the `<DYNPROS>` block

The only piece that still has to be created by hand is the **GUI status
`STATUS_0100`** — see step 4 below.

## Option B — manual creation

If you prefer to create everything by hand instead of using abapGit, follow
all the steps below — they describe the exact same artefacts that abapGit
would otherwise recreate.

## 1. Create the function group

In SE80 → Repository Browser → Function group → name `ZCROSS_WEB_SQL_EDITOR`.
Activate.

abapGit will then place the four `*.fugr.*` includes from `src/` into the
group:

- `lzcross_web_sql_editortop.abap` → TOP include.
- `lzcross_web_sql_editoro01.abap` → PBO module include.
- `lzcross_web_sql_editori01.abap` → PAI module include.
- `zcross_web_sql_editor_show.abap` → function module body.

If you are creating things by hand instead of via abapGit, copy each file's
contents into the corresponding include.

## 2. Function module

Create function module **`ZCROSS_WEB_SQL_EDITOR_SHOW`** in the group. Make it
**remote-enabled = No, normal function module**.

Import parameters:

| Parameter   | Type | Default | Pass value | Optional |
|-------------|------|---------|------------|----------|
| `IV_WIDTH`  | `I`  | `150`   | yes        | yes      |
| `IV_HEIGHT` | `I`  | `30`    | yes        | yes      |

Source: contents of `zcross_web_sql_editor.fugr.zcross_web_sql_editor_show.abap`.

## 3. Dynpro 0100

Create dynpro **`100`** in the function group. Type: **Modal Dialog Box**
(this matters — sets the right window chrome on `CALL SCREEN ... STARTING AT
... ENDING AT ...`).

### Layout (SE51 Layout editor)

One element on the screen, sized to fill it:

| Element        | Type             | Name      | Size                   |
|----------------|------------------|-----------|------------------------|
| Custom Control | Custom Container | `CC_HTML` | full screen, anchored on all four sides |

The container name **must be `CC_HTML`** — `set_up_html_viewer( )` looks for
that exact name.

### Element list

Add the OK code field:

| Field name | Type     | Length |
|------------|----------|--------|
| `OK_CODE`  | `SY-UCOMM` | 20   |

(SE80 will normally add this automatically when you tick the OK code field
on the screen attributes.)

### Flow logic

```
PROCESS BEFORE OUTPUT.
  MODULE status_0100.

PROCESS AFTER INPUT.
  MODULE user_command_0100.
```

(That's all. PBO/PAI just delegate to the class — see the includes.)

## 4. GUI status `STATUS_0100`

In SE80 inside the function group → GUI Status → create `STATUS_0100` of type
**Dialog Box**. Function keys to wire:

| Key   | Function code |
|-------|---------------|
| F3    | `BACK`        |
| F12   | `CANC`        |
| Shift+F3 | `EXIT`     |

You don't need any application toolbar buttons — OK / Cancel come from the
HTML page, not from the dynpro toolbar.

## 5. Title bar `TITLE_0100`

In SE80 inside the function group → Title bar → create `TITLE_0100` with text
`SQL Editor` (or whatever you like — the class also writes a styled title
into the HTML page itself).

## 6. The class

Activate `zcl_cross_web_sql_editor.clas.abap`. It depends on
`zcl_cross_util` / `zcx_cross_util` from `zcross_abap` (for the canonical
`raise_sy` / `raise_root` exception pattern). If you don't have those,
either:

- install `zcross_abap` first (recommended — the rest of your codebase
  already uses it), or
- swap `zcx_cross_util=>raise_sy( )` / `raise_root( )` for plain `RAISE
  EXCEPTION TYPE` against your own exception class.

## 7. Smoke test

Run something like this in a small test report:

```abap
REPORT zsql_editor_test.

START-OF-SELECTION.
  DATA(ls) = zcl_cross_web_sql_editor=>show(
               iv_sql = `SELECT m.matnr, m.ersda` && cl_abap_char_utilities=>newline &&
                        `  FROM mara AS m` && cl_abap_char_utilities=>newline &&
                        ` WHERE m.matnr LIKE 'A%'` && cl_abap_char_utilities=>newline &&
                        `   AND m.mtart = 'FERT'` ).

  IF ls-confirmed = abap_true.
    cl_demo_output=>display( ls-sql ).
  ENDIF.
```

Edit the SQL, hit OK, and the report should show your edited version.
Hit Cancel (or Esc, or F12) and `ls-confirmed` will be `abap_false`.

## Troubleshooting

- **Popup opens, viewer shows blank page** — usually the `parent` container
  was not found. Check the custom-container name on dynpro 0100 is exactly
  `CC_HTML` (uppercase, no whitespace).
- **Highlighting works but OK does nothing** — most likely the SAPEVENT is
  not registered. Check `set_registered_events` is being called in
  `set_up_html_viewer` and the event handler is registered for the same
  viewer instance.
- **Popup ignores `iv_width` / `iv_height`** — those are passed to
  `STARTING AT … ENDING AT` of `CALL SCREEN`. The screen still has to be
  defined as **Modal Dialog Box** in SE51, otherwise SAP GUI ignores the
  size hint.
- **Garbled characters in the loaded HTML** — `SCMS_STRING_TO_XSTRING` is
  called with `mimetype = 'text/html; charset=utf-8'`. If your system's
  default codepage isn't Unicode-capable, use `cl_abap_conv_out_ce` instead
  to force UTF-8 directly.

## Note on the `_archives/` convention

Once this is working in your dev system, export the package via abapGit and
drop the `.zip` into `MyInfo/abap-projects/_archives/` like the other
projects.
