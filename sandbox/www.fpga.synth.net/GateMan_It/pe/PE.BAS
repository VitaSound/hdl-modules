DECLARE SUB getncastruct ()
DIM SHARED desc(25) AS STRING
DIM SHARED addr(25, 4) AS INTEGER
DIM SHARED size(25) AS INTEGER
DIM SHARED dat(25, 4) AS INTEGER
DIM SHARED datmax(25) AS INTEGER
DIM SHARED offset(25) AS INTEGER
DIM SHARED esc AS STRING
DIM SHARED cx, cy AS INTEGER
DIM SHARED header AS STRING
DIM mi, mo, un AS INTEGER

DECLARE SUB getncostruct ()
DECLARE SUB getncfstruct ()
DECLARE SUB getncfstruct ()
DECLARE SUB getglbstruct ()
DECLARE SUB ncorefresh ()
DECLARE SUB ncfrefresh ()
DECLARE SUB ncarefresh ()
DECLARE SUB glbrefresh ()
DECLARE SUB ncogrid ()
DECLARE SUB ncfgrid ()
DECLARE SUB ncagrid ()
DECLARE SUB glbgrid ()
DECLARE FUNCTION hi! (word AS INTEGER)
DECLARE FUNCTION lo! (word AS INTEGER)
DECLARE SUB sendtty (addrMSB AS INTEGER, addrLSB AS INTEGER, datum AS INTEGER)

mi = &H7F: mo = 0: un = 0
header = CHR$(&HF0) + CHR$(mi) + CHR$(mo) + CHR$(un)

maxparam = 24
bottom = 48

OPEN "COM1:19200,N,8,1,CD0,CS0,DS0" FOR RANDOM AS 2

SCREEN 0

CLS
COLOR 14
LOCATE 50, 1: PRINT " ------------- GateMan I Patch Editor  (c) 2007 Scott Gravenhorst -------------";
COLOR 12
LOCATE bottom, 1: PRINT "h for help   esc to exit";
CALL getncostruct
CALL getncfstruct
CALL getncastruct
CALL getglbstruct

CALL ncogrid
CALL ncfgrid
CALL ncagrid
CALL glbgrid
CALL ncorefresh
CALL ncfrefresh
CALL ncarefresh
CALL glbrefresh

cx = 0
cy = 0

esc = CHR$(27)

' key command interpreter
DO UNTIL k$ = esc$
  k$ = INKEY$
  IF k$ <> "" THEN
    IF LEN(k$) = 2 THEN
      k = ASC(MID$(k$, 2, 1))
      IF k = 71 THEN cy = 0: cx = 0
      IF k = 80 THEN cy = cy + 1
      IF k = 72 THEN cy = cy - 1
      IF k = 77 THEN cx = cx + 1
      IF k = 75 THEN cx = cx - 1
      cx = cx MOD 4
      cy = cy MOD (maxparam + 1)
      IF cx = -1 THEN cx = 3
      IF cy = -1 THEN cy = maxparam
    
      IF cy > 8 THEN cx = 0
     
      CALL ncogrid
      CALL ncfgrid
      CALL ncagrid
      CALL glbgrid
      CALL ncorefresh
      CALL ncfrefresh
      CALL ncarefresh
      CALL glbrefresh
    ELSE
      k = ASC(k$)
       
      IF k$ = "h" THEN
        k$ = ""
        CLS
        PRINT "h for help"
        PRINT "esc to exit"
        PRINT "enter key to enter a value"
        PRINT "cursor keys to navigate"
        PRINT "+ key, no shift to increase by one"
        PRINT "- key, no shift to decrease by one"
        PRINT "+ key with shift to increase by ten"
        PRINT "- key with shift to decrease by ten"
        PRINT "u [update] to send all data to GateMan I"
        PRINT "s [save]   to save data to disk"
        PRINT "l [load]   to load data from disk"
        PRINT
        PRINT "Press enter to return to patch editor"
        x$ = INPUT$(1)
        CLS
        LOCATE bottom, 1
        PRINT "h for help   esc to exit";
        CALL ncogrid
        CALL ncfgrid
        CALL ncagrid
        CALL glbgrid
        CALL ncorefresh
        CALL ncfrefresh
        CALL ncarefresh
        CALL glbrefresh
      END IF

      IF k$ = "s" THEN
      END IF

      IF k$ = "u" THEN
        LOCATE bottom, 40: PRINT "updating...";
        ' update NCOs
        FOR param = 0 TO 8
          FOR nco = 0 TO 3
            IF size(param) = 1 THEN
              CALL sendtty(0, addr(param, nco), dat(param, nco))
            ELSE
              CALL sendtty(0, addr(param, nco), hi(dat(param, nco)))
              CALL sendtty(0, addr(param, nco) + 1, lo(dat(param, nco)))
            END IF
          NEXT nco
        NEXT param
       
        FOR param = 9 TO maxparam
            IF size(param) = 1 THEN
              CALL sendtty(0, addr(param, 0), dat(param, 0))
            ELSE
              CALL sendtty(0, addr(param, 0), hi(dat(param, 0)))
              CALL sendtty(0, addr(param, 0) + 1, lo(dat(param, 0)))
            END IF
        NEXT param
       
        LOCATE bottom, 40: PRINT "                ";
      END IF
     
      param = cy: nco = cx

'''' enter key
      IF k = 13 THEN
        COLOR 10
        DO
          LOCATE bottom, 40: INPUT ; "Enter value: ", v$
          LOCATE bottom, 40: PRINT "                                   ";
          IF LEN(v$) > 0 THEN
            ok = 1
            IF MID$(v$, 1, 1) = "-" THEN s = 2 ELSE s = 1
            FOR i = s TO LEN(v$)
              a = ASC(MID$(v$, i, 1))
              IF a < 48 OR a > 57 THEN ok = 0
            NEXT i
            IF ok = 1 THEN
              v# = VAL(v$)
              IF v# > 32767 THEN v$ = "32767"
              IF v# < -32768 THEN v$ = "0"
              v = VAL(v$)
              dat(param, nco) = v
              IF param = 1 THEN dat(param, nco) = dat(param, nco) - offset(param)
              IF dat(param, nco) > datmax(param) THEN dat(param, nco) = datmax(param)
              IF dat(param, nco) < 0 THEN dat(param, nco) = 0
              EXIT DO
            END IF
          ELSE
            EXIT DO
          END IF
        LOOP
      END IF

      'param 1 (fine tune) is a special case, ignore shift
      IF param = 1 THEN
        IF k = 43 THEN k = 61
        IF k = 95 THEN k = 45
      END IF

      IF k = 61 THEN
        dat(param, nco) = dat(param, nco) + 1
        IF dat(param, nco) > datmax(param) THEN dat(param, nco) = 0
      END IF

      IF k = 45 THEN
        dat(param, nco) = dat(param, nco) - 1
        IF dat(param, nco) < 0 THEN dat(param, nco) = datmax(param)
      END IF
     
      IF k = 43 THEN
        IF dat(param, nco) = datmax(param) THEN
          dat(param, nco) = 0
        ELSE
          IF dat(param, nco) >= INT(datmax(param) / 10) * 10 THEN
            dat(param, nco) = datmax(param)
          ELSE
            dat(param, nco) = INT((dat(param, nco) + 10) / 10) * 10
          END IF
        END IF
      END IF
     
      IF k = 95 THEN
        IF dat(param, nco) < 10 THEN
          dat(param, nco) = datmax(param)
        ELSE
          IF dat(param, nco) >= 10 THEN
            IF dat(param, nco) = INT(dat(param, nco) / 10) * 10 THEN
              dat(param, nco) = dat(param, nco) - 10
            ELSE
              dat(param, nco) = INT(dat(param, nco) / 10) * 10
            END IF
          ELSE
            dat(param, nco) = 0
          END IF
        END IF
      END IF
   
    END IF
    IF param < 9 THEN CALL ncorefresh
    IF param > 8 AND param < 17 THEN CALL ncfrefresh
    IF param > 16 AND param < 23 THEN CALL ncarefresh
    IF param > 22 THEN CALL glbrefresh
  END IF
LOOP
CLS
SYSTEM

SUB getglbstruct
OPEN "pe.glb" FOR INPUT AS 1
FOR param = 23 TO 24
  LINE INPUT #1, desc(param)
  INPUT #1, size(param)
  INPUT #1, addr(param, 0)
  INPUT #1, datmax(param)
  INPUT #1, dat(param, 0)
  INPUT #1, junk$
NEXT param
CLOSE #1
END SUB

SUB getncastruct
OPEN "pe.nca" FOR INPUT AS 1
FOR param = 17 TO 22
  LINE INPUT #1, desc(param)
  INPUT #1, size(param)
  INPUT #1, addr(param, 0)
  INPUT #1, datmax(param)
  INPUT #1, dat(param, 0)
  INPUT #1, junk$
NEXT param
CLOSE #1
END SUB

SUB getncfstruct
OPEN "pe.ncf" FOR INPUT AS 1
FOR param = 9 TO 16
  LINE INPUT #1, desc(param)
  INPUT #1, size(param)
  INPUT #1, addr(param, 0)
  INPUT #1, datmax(param)
  INPUT #1, dat(param, 0)
  INPUT #1, junk$
NEXT param
CLOSE #1
END SUB

SUB getncostruct
OPEN "pe.nco" FOR INPUT AS 1
FOR param = 0 TO 8
  LINE INPUT #1, desc(param)
  INPUT #1, size(param)
  INPUT #1, addr(param, 0), addr(param, 1), addr(param, 2), addr(param, 3)
  INPUT #1, datmax(param)
  INPUT #1, offset(param)
  INPUT #1, dat(param, 0), dat(param, 1), dat(param, 2), dat(param, 3)
  INPUT #1, junk$
NEXT param
CLOSE #1
END SUB

SUB glbgrid
IF cy >= 23 THEN gridCOLOR = 14 ELSE gridCOLOR = 6
COLOR gridCOLOR
LOCATE 31, 1
PRINT "-------[GLOBAL PARAMETER]-------------------------------+----------------------";

FOR y = 23 TO 24
  IF cy = y THEN COLOR 14 ELSE COLOR 6
  LOCATE y + 9, 1: PRINT desc(y);
  COLOR gridCOLOR
  LOCATE y + 9, 57: PRINT "|";
NEXT y
END SUB

SUB glbrefresh
COLOR 2
FOR param = 23 TO 24
  LOCATE param + 9, 58: PRINT "      ";
  LOCATE param + 9, 58: PRINT dat(param, 0);
NEXT param

IF cy > 22 THEN
  COLOR 10
  param = cy
  LOCATE param + 9, 58: PRINT "      ";
  LOCATE param + 9, 58: PRINT dat(param, 0);
END IF
END SUB

FUNCTION hi (word AS INTEGER)
  DIM n AS INTEGER
  n = word AND &H3FFF
  hi = ((n AND &H3F80) / 128)
END FUNCTION

FUNCTION lo (word AS INTEGER)
  DIM n AS INTEGER
  n = word AND &H3FFF
  lo = (n AND &H7F)
END FUNCTION

SUB ncagrid
IF cy >= 17 AND cy <= 22 THEN gridCOLOR = 14 ELSE gridCOLOR = 6
COLOR gridCOLOR
LOCATE 23, 1
PRINT "-------[NCA ADSR PARAMETER]-----------------------------+----------------------";

FOR y = 17 TO 22
  IF cy = y THEN COLOR 14 ELSE COLOR 6
  LOCATE y + 7, 1: PRINT desc(y);
  COLOR gridCOLOR
  LOCATE y + 7, 57: PRINT "|";
NEXT y

END SUB

SUB ncarefresh
COLOR 2
FOR param = 17 TO 22
  LOCATE param + 7, 58: PRINT "      ";
  LOCATE param + 7, 58: PRINT dat(param, 0);
NEXT param

IF cy > 16 AND cy < 23 THEN
  COLOR 10
  param = cy
  LOCATE param + 7, 58: PRINT "      ";
  LOCATE param + 7, 58: PRINT dat(param, 0);
END IF
END SUB

SUB ncfgrid
IF cy >= 9 AND cy <= 16 THEN gridCOLOR = 14 ELSE gridCOLOR = 6
COLOR gridCOLOR
LOCATE 13, 1
PRINT "-------[NCF ADSR PARAMETER]-----------------------------+----------------------";

FOR y = 9 TO 16
  IF cy = y THEN COLOR 14 ELSE COLOR 6
  LOCATE y + 5, 1: PRINT desc(y);
  COLOR gridCOLOR
  LOCATE y + 5, 57: PRINT "|";
NEXT y
END SUB

SUB ncfrefresh
COLOR 2
FOR param = 9 TO 16
  LOCATE param + 5, 58: PRINT "      ";
  LOCATE param + 5, 58: PRINT dat(param, 0);
NEXT param

IF cy > 8 AND cy < 17 THEN
  COLOR 10
  param = cy
  LOCATE param + 5, 58: PRINT "      ";
  LOCATE param + 5, 58: PRINT dat(param, 0);
END IF
END SUB

SUB ncogrid
IF cy >= 0 AND cy <= 8 THEN gridCOLOR = 14 ELSE gridCOLOR = 6
COLOR gridCOLOR
LOCATE 1, 47: PRINT "| NCO 0 | NCO 1 | NCO 2 | NCO 3 |";
LOCATE 2, 1:
PRINT "-------[NCO PARAMETER]------------------------+-------+-------+-------+-------+";

FOR y = 0 TO 8
  IF cy = y THEN COLOR 14 ELSE COLOR 6
  LOCATE y + 3, 1: PRINT desc(y);
  COLOR gridCOLOR
  LOCATE y + 3, 47: PRINT "|       |       |       |       |";
NEXT y
END SUB

SUB ncorefresh
colwidth = 8
COLOR 2
FOR param = 0 TO 8
  FOR nco = 0 TO 3
    LOCATE param + 3, 48 + nco * colwidth: PRINT "      ";
    LOCATE param + 3, 48 + nco * colwidth: PRINT dat(param, nco) + offset(param);
  NEXT nco
NEXT param
COLOR 10
IF cy < 9 THEN
  param = cy
  nco = cx
  LOCATE param + 3, 48 + nco * colwidth: PRINT "      ";
  LOCATE param + 3, 48 + nco * colwidth: PRINT dat(param, nco) + offset(param);
END IF
END SUB

SUB sendtty (addrMSB AS INTEGER, addrLSB AS INTEGER, datum AS INTEGER)
  IF datum > 127 THEN
    L$ = "0" + HEX$(addrLSB)
    M$ = "0" + HEX$(addrMSB)
    L$ = MID$(L$, LEN(L$) - 1)
    M$ = MID$(M$, LEN(M$) - 1)
    PRINT : PRINT "SYSEX DATA IS GREATER THAN 7F !!!"
    PRINT "Address: "; M$; " "; L$; " = "; HEX$(datum)
    PRINT
  END IF

'  IF addrMSB = 0 AND addrLSB = 17 AND datum > 0 THEN
'    PRINT : PRINT "!!! AMPLIFIER IS ON AT"; 2 ^ datum; "TIMES NORMAL !!!": PRINT
'  END IF

  x$ = header + CHR$(addrMSB) + CHR$(addrLSB) + CHR$(datum) + CHR$(&HF7)
  PRINT #2, x$;
END SUB

