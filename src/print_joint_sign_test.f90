SUBROUTINE print_joint_sign_test(lunout,nexp,nparver,   &
                       stnr,yymm,yymm2,par_active,      &
                       uh,uf)

 USE types, ONLY : statistics
 USE functions
 USE constants, ONLY : seasonal_name1,seasonal_name2
 USE sign_data, ONLY : all_sign_stat,sign_stat_max
 USE data, ONLY : varprop,expname,station_name,                 &
                  csi,use_fclen,lfcver,                         &
                  maxfclenval,len_lab,output_mode,              &
                  nfclengths,nuse_fclen,tag,                    &
                  time_shift,show_fc_length,                    &
                  period_freq,period_type,                      &
                  output_type,lprint_seasonal,                  &
                  control_exp_nr,sign_time_diff,err_ind,confint,&
                  cini_hours,exp_offset,plot_prefix

 IMPLICIT NONE

 INTEGER, INTENT(IN) ::           &
 lunout,nexp,nparver,             &
 stnr,yymm,yymm2,                 &
 par_active(nparver)

 LOGICAL, INTENT(IN) :: uh(nparver,0:23),uf(nparver,0:maxfclenval)

! Local

 INTEGER :: i,j,k,period,ncases(nuse_fclen),istart,iend

 REAL, ALLOCATABLE :: sdiff(:,:)
 REAL minnum,maxnum,ticnum,maxnum_t,offset(nexp)

 CHARACTER(LEN=100) :: wtext=' ',wtext1=' '
 CHARACTER(LEN=300) :: expnames=''
 CHARACTER(LEN=200) :: fname=' '
 CHARACTER(LEN= 60) :: wname=' '
 CHARACTER(LEN= 10) :: prefix = ' '

!------------------------------------------

 ! Set period

 IF (yymm < 999999 ) THEN
    period = yymm
 ELSE
    period = 0
 ENDIF

 ! Select a subsection of our period
 IF ( yymm /= 0 ) THEN

    istart = 1
    iend   = sign_stat_max
    DO i=1,sign_stat_max
       IF ((all_sign_stat(i)%date/100 - yymm) == 0 ) THEN
          istart   = i 
          EXIT
       ENDIF
    ENDDO

    DO i=1,sign_stat_max
       IF ((all_sign_stat(i)%date/100 - yymm2) == 0 ) THEN
          iend   = i-1
          EXIT
       ENDIF
    ENDDO
 ELSE
    istart = 1
    iend   = sign_stat_max
 ENDIF

 ! Set number of hours

 ALLOCATE(sdiff(nuse_fclen,2))

 ! Printing
 j=0
 expnames=''
 DO i=1,nexp
   IF ( i == control_exp_nr ) CYCLE
   expnames = TRIM(expnames)//' '//TRIM(expname(i))
   j=j+1
   offset(i) = 0.125*(j-nexp+FLOOR(nexp/2.))
 ENDDO
 offset(control_exp_nr ) = 0.0
 expnames = adjustl(expnames)

 DO j=1,nparver
   DO i=nexp,1,-1

      IF ( i /= control_exp_nr ) &
      CALL  scorediffs(control_exp_nr,i,nuse_fclen,j,     &
                       istart,iend,                       &
                       .TRUE.,.FALSE.,confint,sdiff,ncases)
    
      ! Set output filename

      wname = ''
      IF ( i /= control_exp_nr ) THEN
         prefix = 'sub_'//TRIM(plot_prefix(14))
      ELSE
         prefix = TRIM(plot_prefix(14))
      ENDIF
      IF ( TRIM(tag) /= '#' ) &
      wname = TRIM(tag)//TRIM(cini_hours)

      IF ( output_mode == 2 ) THEN
         CALL make_fname(prefix,period,stnr,wname,   &
                         varprop(j)%id,              &
                         varprop(j)%lev,             &
                         output_mode,output_type,    &
                         fname)
         IF ( i /= control_exp_nr ) &
         fname  = TRIM(fname)//'_'//TRIM(expname(i))
         CALL open_output(fname)
      ENDIF

      minnum = MINVAL(ncases)
      maxnum_t = MAXVAL(ncases)
      minnum = FLOOR(LOG10(MAX(minnum,1.)))
      maxnum = FLOOR(LOG10(MAX(maxnum_t,1.)))
      minnum = 10.**(minnum)
      IF ( minnum < 10. ) minnum = 0.
      maxnum = 10.**(maxnum)
      maxnum = CEILING(maxnum_t/maxnum)*maxnum
      ticnum = tics(minnum,maxnum)

      WRITE(lunout,'(A,X,en15.5e2)')'#MINNUM',minnum
      WRITE(lunout,'(A,X,en15.5e2)')'#TICNUM',ticnum
      WRITE(lunout,'(A,X,en15.5e2)')'#MAXNUM',maxnum

    IF ( i == control_exp_nr ) &
    WRITE(lunout,'(A,X,A)')'#EXPNAMES',TRIM(expnames)

    ! Create headers
 
    ! Line 1
    WRITE(wname(1:2),'(I2)')NINT(confint)
    wtext = 'Normalized mean RMSE diff ('//wname(1:2)//'% conf)'
    wtext = TRIM(wtext)//' vs '//TRIM(expname(control_exp_nr))
    IF ( sign_time_diff /= -1 ) THEN
     WRITE(wtext1(1:1),'(I1)')sign_time_diff
     wtext = TRIM(wtext)//' with acc int of '//wtext1(1:1)//' days'
    ENDIF 
    WRITE(lunout,'(A,X,A)')'#HEADING_1',TRIM(wtext)
    IF(ALLOCATED(station_name).AND. stnr > 0 ) THEN
       wtext='Station: '//trim(station_name(csi))
    ELSE
       WRITE(wtext1(1:8),'(I8)')stnr
       wtext='Station: '//trim(wtext1(1:8))
    ENDIF
    IF (stnr == 0) THEN
       wname=''
       WRITE(wname(1:5),'(I5)')par_active(j)
       wtext=TRIM(wname)//' stations'
       IF ( TRIM(tag) /= '#' ) wtext='Selection: '//TRIM(tag)//' using '//TRIM(wtext)
    ENDIF
    WRITE(lunout,'(A,X,A)')'#HEADING_2',TRIM(wtext)

    ! Line 2
    IF (yymm == 0 ) THEN
    ELSEIF(yymm < 13) THEN

       SELECT CASE(period_freq) 
       CASE(1)
        WRITE(wtext,'(A8,A8)')'Period: ',seasonal_name2(yymm)
       CASE(3)
        WRITE(wtext,'(A8,A8)')'Period: ',seasonal_name1(yymm)
       END SELECT 

    ELSEIF(yymm < 9999 .OR. (period_type == 2 .AND. period_freq == 1)) THEN
       WRITE(wtext,'(A8,I8)')'Period: ',yymm
    ELSEIF(yymm < 999999 ) THEN
       WRITE(wtext,'(A8,I6,A1,I6)')'Period: ',        &
       yymm,'-',monincr(yymm,period_freq-1)
    ELSE
       WRITE(wtext,'(A8,I8,A1,I8)')'Period: ',        &
       yymm,'-',yymm2
    ENDIF
    WRITE(lunout,'(A,X,A)')'#HEADING_3',TRIM(wtext)

    ! Line 3
    IF ( show_fc_length ) THEN

       CALL fclen_header(( .NOT. lfcver .OR. ( nuse_fclen /= nfclengths )), &
                         maxfclenval,uh(j,:),uf(j,:),varprop(j)%acc,        &
                         MAXVAL(exp_offset),wtext1)
       wtext = TRIM(varprop(j)%text)//'   '//TRIM(wtext1)
       WRITE(lunout,'(A,X,A)')'#HEADING_4',TRIM(wtext)

    ENDIF

    ! Experiments and parameters and norms
    WRITE(lunout,'(A,X,A)')'#PAR',TRIM(varprop(j)%id)

    WRITE(lunout,'(A,X,A)')'#YLABEL',''
    IF ( lfcver ) THEN
          WRITE(lunout,'(A,X,A)')'#XLABEL','Forecast length'
    ENDIF

    ! Time to write the parameters
 
    ! End of heading
    WRITE(lunout,'(A,X,en15.5e2)')'#MISSING',err_ind
    WRITE(lunout,'(A)')'#END'

    DO k=1,nuse_fclen
      IF ( ncases(k) == 0 ) CYCLE
      WRITE(lunout,'(3(en15.5e2),I7)')offset(i)+use_fclen(k),sdiff(k,:),ncases(k)
    ENDDO

    CLOSE(lunout)

 ENDDO
 ENDDO

 ! Clear memory
 DEALLOCATE(sdiff)

 RETURN

END SUBROUTINE print_joint_sign_test
