SUBROUTINE GREGOR(JD,IY,IM,ID)
  !
  ! CONVERTS JULIAN DAYNUMBER INTO GREGORIAN ( NORMAL ) DATE
  ! ( YEAR,MONTH,DAY ) .
  !
  INTEGER  JD, IY, IM, ID
  INTEGER  L, N
  !
  L  = JD + 68569 + 2415020
  N  = 4*L / 146097
  L  = L - ( 146097*N + 3 ) / 4
  IY = 4000 * ( L+1 ) / 1461001
  L  = L - 1461 * IY / 4 + 31
  IM = 80 * L / 2447
  ID = L - 2447 * IM / 80
  L  = IM / 11
  IM = IM + 2 - 12 * L
  IY = 100 * ( N- 49 ) + IY + L
  !
  RETURN
END SUBROUTINE GREGOR
