*----------------------------------------------------------------------*
*  Include          LZCROSS_WEB_SQL_EDITORI01                          *
*  PAI module of dynpro 0100 - delegates the OK code to the class.     *
*  All meaningful interaction comes back via SAPEVENT, not via PAI.    *
*----------------------------------------------------------------------*

MODULE user_command_0100 INPUT.

  zcl_cross_web_sql_editor=>on_pai( iv_okcode = ok_code ).
  CLEAR ok_code.

ENDMODULE.
