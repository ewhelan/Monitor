SUBROUTINE print_freq(lunout,nparver,nr,nrun,scat,p1,p2,par_active,uh,uf)

 !
 ! Plot Frequency distribution
 !
 ! Ulf Andrae, SMHI, 2008
 !

 USE types
 USE functions
 USE mymagics
 USE timing
 USE data, ONLY : nexp,station_name,err_ind,csi,obstype, &
                  expname,gr_ind,pe_ind,pd_ind,          &
                  lfcver,output_mode,                    &
                  show_fc_length,                        &
                  ltiming,tag,maxfclenval,               &
                  ncla,classtype,pre_fcla,               &
                  mincla,maxcla,my_ymax,my_ymin,         &
                  mpre_cla,copied_mod,copied_obs,        &
                  period_freq,output_type,len_lab

 IMPLICIT NONE

 REAL,    PARAMETER :: spxl      = 23. ! SUB_PAGE_X_LENGTH

 ! Input
 INTEGER, INTENT(IN) :: lunout,nparver,nr,nrun,     &
                        p1,p2,                      &
                        par_active(nparver)

 TYPE(scatter_type), INTENT(IN) :: scat(nparver)

 LOGICAL,            INTENT(IN) :: uh(nparver,0:23),   &
                                   uf(nparver,0:maxfclenval)


 ! Local
 INTEGER :: i,j,k,l,m,n,ncl,       		&
            timing_id,lnexp,pp1,period

 REAL :: dcla,fdat_sum,bar_width,               &
         bfac,maxy,miny

 REAL, ALLOCATABLE :: work(:,:),                &
                      pcla(:),fcla(:),          &
                      fdat(:,:),zero(:),zdat(:)

 LOGICAL :: reset_class

 CHARACTER(LEN=100) :: fname = ''
 CHARACTER(LEN=90) :: wtext = '',wtext2 = ''
 CHARACTER(LEN=20) :: wname = ''
 CHARACTER(LEN=20) :: cdum  = ''

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
       CALL make_fname('f',period,nr,tag,          &
                       obstype(j)(1:2),            &
                       obstype(j)(3:len_lab),      &
                       output_mode,output_type,    &
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

    IF ( obstype(j)(1:2) == 'DD' ) THEN
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

          IF (j == gr_ind) THEN
             mincla(j) = 1.
             maxcla(j) = 1000.
          ENDIF

       ENDIF
  
       CALL freq_dist(lnexp,n,ncl,                    &
                      mincla(j),maxcla(j),classtype(j),   &
                      pre_fcla(j,1:ncl),work,fdat,fcla)

    ELSE

       fdat = 0.
       DO i=1,ncl
          fcla(i) = i
       ENDDO

    ENDIF

    ! Plotting
   
    dcla      = fcla(ncl) - fcla(ncl-1)
    bar_width = spxl / float(ncl*lnexp)
    bfac      = bar_width*dcla*(ncl)/spxl

    DO i=1,lnexp
       fdat_sum  = SUM(fdat(:,i))
       fdat(:,i) = fdat(:,i) / MAX(1.,fdat_sum)
    ENDDO

    DO i=1,ncl
     WRITE(lunout,*)fcla(i),fdat(i,:)
    ENDDO

    CLOSE(lunout)

    ! Clear memory
    DEALLOCATE(work,pcla,fcla,fdat,zero,zdat)
   
 ENDDO

 RETURN
END SUBROUTINE print_freq