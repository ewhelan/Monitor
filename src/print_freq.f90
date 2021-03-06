SUBROUTINE print_freq(lunout,nparver,nr,scat, &
                      p1,p2,par_active,uh,uf)

 !
 ! Plot Frequency distribution
 !
 ! Ulf Andrae, SMHI, 2008
 !

 USE types
 USE functions
 USE timing
 USE constants, ONLY : seasonal_name1,seasonal_name2
 USE data, ONLY : nexp,station_name,err_ind,csi,varprop, &
                  expname,                               &
                  lfcver,output_mode,                    &
                  show_fc_length,                        &
                  ltiming,tag,maxfclenval,               &
                  ncla,classtype,pre_fcla,               &
                  mincla,maxcla,my_ymax,my_ymin,         &
                  mpre_cla,copied_mod,copied_obs,        &
                  period_freq,period_type,               &
                  output_type,len_lab,                   &
                  cini_hours,exp_offset,plot_prefix

 IMPLICIT NONE

 REAL,    PARAMETER :: spxl      = 23. ! SUB_PAGE_X_LENGTH

 ! Input
 INTEGER, INTENT(IN) :: lunout,nparver,nr,       &
                        p1,p2,par_active(nparver)

 TYPE(scatter_type), INTENT(IN) :: scat(nparver)

 LOGICAL,            INTENT(IN) :: uh(nparver,0:23),   &
                                   uf(nparver,0:maxfclenval)


 ! Local
 INTEGER :: i,j,k,m,n,ncl,                      &
            timing_id,lnexp,period

 REAL :: fdat_sum

 REAL, ALLOCATABLE :: work(:,:),                &
                      pcla(:),fcla(:),          &
                      fdat(:,:),zero(:),zdat(:)

 LOGICAL :: reset_class

 CHARACTER(LEN=100) :: fname = ''
 CHARACTER(LEN=90) :: wtext = '',wtext1=''
 CHARACTER(LEN=20) :: wname = ''
 CHARACTER(LEN=30) :: cform = ''


!-----------------------------------------------------
 ! Init timing counter
 timing_id = 0
 IF (ltiming) CALL acc_timing(timing_id,'plot_freq')

 IF ( copied_mod .OR. copied_obs ) THEN
    lnexp = nexp
 ELSE
    lnexp = nexp + 1
 ENDIF

 ! Set filename
 IF ( p1 < 999999 ) THEN
    period = p1
 ELSE
    period = 0
 ENDIF

 DO j=1,nparver

    IF ( output_mode == 2 ) THEN
       wtext = TRIM(tag)//TRIM(cini_hours)
       CALL make_fname(plot_prefix(9),period,nr,wtext,         &
                       varprop(j)%id,varprop(j)%lev,&
                       output_mode,output_type,     &
                       fname)
       CALL open_output(fname)
    ENDIF
   
    ncl = ncla(j)
    ALLOCATE(pcla(ncl),                &
             fcla(ncl),                &
             fdat(ncl,nexp+1),         &
             zero(ncl-1),              &
             zdat(ncl-1))

    zero = 0.

    reset_class = ( mincla(j) > maxcla(j) )

    n = scat(j)%n

    !
    ! Copy data to work array
    !

    ALLOCATE(work(n,lnexp))

    work(:,lnexp) = scat(j)%dat(1,1:n)
    DO k=1,nexp
       work(1:n,k) =  scat(j)%dat(k+1,1:n) + &
                      scat(j)%dat(1  ,1:n) 
    ENDDO

    IF ( varprop(j)%id == 'DD' ) THEN
       DO k=1,nexp
        DO m=1,n
          IF(work(m,k) > 360. )THEN
            work(m,k) = work(m,k) - 360.         
          ELSEIF(work(m,k) <   0. )THEN
            work(m,k) = work(m,k) + 360.         
          ENDIF
        ENDDO
       ENDDO
    ENDIF
    
    IF (n > 0 ) THEN
       
       IF ( reset_class )THEN

          maxcla(j) = 0.
          mincla(j) = 1.

          IF( varprop(j)%id == 'GR' ) THEN

             mincla(j) = 1.
             maxcla(j) = 1000.
          ENDIF

       ENDIF
  
       CALL freq_dist(lnexp,n,ncl,                    &
                      mincla(j),maxcla(j),classtype(j),   &
                      pre_fcla(1:ncl,j),work,fdat,fcla)

    ELSE

       fdat = 0.
       DO i=1,ncl
          fcla(i) = i
       ENDDO

    ENDIF

    ! Create headers
 
    ! Line 1
    IF(ALLOCATED(station_name).AND. nr > 0 ) THEN
       wtext='Station: '//trim(station_name(csi))
    ELSE
       WRITE(wtext1(1:8),'(I8)')nr
       wtext='Station: '//trim(wtext1(1:8))
    ENDIF
    IF (nr == 0) THEN
       wname=''
       WRITE(wname(1:5),'(I5)')par_active(j)
       wtext=TRIM(wname)//' stations'
       IF ( TRIM(tag) /= '#' ) wtext='Selection: '//TRIM(tag)//'  '//TRIM(wtext)
    ENDIF
    WRITE(lunout,'(A,X,A)')'#HEADING_1',TRIM(wtext)

   ! Line 2
    wtext = ''
    IF (p1 == 0 ) THEN
    ELSEIF(p1 < 13) THEN

       SELECT CASE(period_freq)
       CASE(1)
        WRITE(wtext,'(A8,A8)')'Period: ',seasonal_name2(p1)
       CASE(3)
        WRITE(wtext,'(A8,A8)')'Period: ',seasonal_name1(p1)
       END SELECT

    ELSEIF(p1 < 9999 .OR. (period_type == 2 .AND. period_freq == 1)) THEN
       WRITE(wtext,'(A8,I8)')'Period: ',p1
    ELSEIF(p1 < 999999 ) THEN
       WRITE(wtext,'(A8,I6,A1,I6)')'Period: ',        &
       p1,'-',monincr(p1,period_freq-1)
    ELSE
       WRITE(wtext,'(A8,I8,A1,I8)')'Period: ',        &
       p1,'-',p2
    ENDIF
 
    wtext = TRIM(varprop(j)%text)//'  '//TRIM(wtext)
    WRITE(lunout,'(A,X,A)')'#HEADING_2',TRIM(wtext)

    ! Line 3
    IF ( show_fc_length ) THEN
       CALL fclen_header(.true.,maxfclenval,uh(j,:),uf(j,:), &
                         varprop(j)%acc,MAXVAL(exp_offset),wtext)
       WRITE(lunout,'(A,X,A)')'#HEADING_3',TRIM(wtext)
    ENDIF

    ! Experiments and parameters and norms
    WRITE(lunout,'(A,X,A)')'#PAR',TRIM(varprop(j)%id)

    WRITE(lunout,'(A,X,I2)')'#NEXP',nexp+1
    DO i=1,nexp
       WRITE(lunout,'(A,I2.2,X,A)')'#EXP_',i,TRIM(expname(i))
       WRITE(lunout,'(A,I2.2,X,A)')'#COLUMN_',i+1,TRIM(expname(i))
    ENDDO
    WRITE(lunout,'(A,I2.2,X,A)')'#EXP_',lnexp,'OBS'
    WRITE(lunout,'(A,I2.2,X,A)')'#COLUMN_',lnexp+1,'OBS'

    WRITE(lunout,'(A,X,A)')'#XLABEL',TRIM(varprop(j)%unit)
    WRITE(lunout,'(A,X,A)')'#YLABEL','Relative frequency'

    ! Plotting

    DO i=1,lnexp
       fdat_sum  = SUM(fdat(:,i))
       fdat(:,i) = fdat(:,i) / MAX(1.,fdat_sum)
    ENDDO

    cform = '(NN(en15.5e2,x))'
    WRITE(cform(2:3),'(I2.2)')nexp+2

    DO i=1,ncl
     WRITE(lunout,cform)fcla(i),fdat(i,:)
    ENDDO

    CLOSE(lunout)

    ! Clear memory
    DEALLOCATE(work,pcla,fcla,fdat,zero,zdat)
   
 ENDDO

 RETURN
END SUBROUTINE print_freq
