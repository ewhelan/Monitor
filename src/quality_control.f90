SUBROUTINE quality_control

!
! Loop through all observations and check
! the quality against qc_fclen. 
! qc_fclen could preferably be an analysis ( = 0 ).
!
! Ulf Andrae, SMHI, 2007
! 

 USE data
 USE functions

 IMPLICIT NONE

 !
 ! Local
 !

 INTEGER :: i,j,k,l,n,o,ii,nn,                          &
            jj,jjstart,jjcheck(nfclengths),             &
            wdate,wtime,                                &
            ind_pe(nparver,nfclengths),                 &
            nver(nparver)

 INTEGER, ALLOCATABLE :: gross_error(:,:,:),            &
                         total_amount(:,:)

 REAL              :: diff(nexp),diff_prep,             &
                      bias(nparver),rmse(nparver),      &
                      stdv

 LOGICAL :: found_qc_file      = .FALSE.
 LOGICAL :: found_right_time   = .FALSE.
 LOGICAL :: lprint_gross_first = .TRUE.
 LOGICAL :: qc_control(nexp)
 LOGICAL :: par_is_checked(nparver)

 !----------------------------------------------------------

 INQUIRE(UNIT=lunqc,EXIST=found_qc_file)

 IF ( print_qc > 0 ) THEN

    IF ( found_qc_file ) THEN
       OPEN(lunqc,POSITION='APPEND')
    ELSE
       OPEN(lunqc)
    ENDIF

    WRITE(lunqc,*)
    IF ( estimate_qc_limit ) THEN
       WRITE(lunqc,*)'--ESTIMATE QC LIMITS--'
    ELSE
       WRITE(lunqc,*)'--QUALTITY CONTROL--'
    ENDIF
    WRITE(lunqc,*)

 ENDIF

 bias = 0.
 rmse = 0.
 nver = 0

 !
 ! Check qc_flen
 !

 IF ( ALL(qc_fclen == -1) ) THEN

    !
    ! Set qc_fclen as all fc_len <= fcint
    !

    ii = 0
    DO i=1,nfclengths
       IF ( fclen(i) <= 2*fcint ) THEN
          ii = ii + 1
          qc_fclen(ii) = fclen(i)
       ENDIF
    ENDDO

 ENDIF

 IF ( print_qc > 0 ) THEN
    DO i=1,nfclengths
       IF(qc_fclen(i) == -1 ) EXIT
       WRITE(lunqc,*)'Quality check forecast length ',qc_fclen(i)
    ENDDO
    WRITE(lunqc,*)
 ENDIF

 !
 ! Find accumulation index locations
 !

 ind_pe = 0
 IF ( ANY(varprop(:)%acc /= 0) ) THEN
  IF (print_qc>1) WRITE(lunqc,*)'Accumulation index'
  DO j=1,nparver
    IF ( varprop(j)%acc == 0 ) CYCLE
    IF (print_qc>1) WRITE(lunqc,*)varprop(j)%text,varprop(j)%acc
   DO i=1,nfclengths

    IF ( fclen(i) < varprop(j)%acc ) CYCLE 

    ind_pe(j,i)=TRANSFER(MINLOC(ABS(fclen(1:nfclengths)-(fclen(i)-varprop(j)%acc))),ii)

    IF (fclen(i)-fclen(ind_pe(j,i)) < varprop(j)%acc ) ind_pe(j,i) = 0

    IF (print_qc>1) WRITE(lunqc,*)i,fclen(i),fclen(ind_pe(j,i)),ind_pe(j,i)

   ENDDO
  ENDDO
  IF (print_qc>1) WRITE(lunqc,*)
 ENDIF

 IF ( .NOT. estimate_qc_limit ) THEN

   !
   ! Set up quality control levels
   !

   DO j=1,nparver
     IF ( ABS(qc_lim(j) - err_ind ) > 1.e-6 ) CYCLE
     qc_lim(j) = varprop(j)%lim
   ENDDO

   !
   ! Gross error tracking
   !

    ALLOCATE(gross_error(2,maxstn,nparver))
    gross_error  = 0

 ENDIF

 ALLOCATE(total_amount(maxstn,nparver))
 total_amount = 0

 !
 ! Loop over all stations
 !

 STATION_CYCLE : DO i=1,maxstn

    !
    ! Check if data are available, active and correct
    !

    IF ( .NOT. hir(i)%obs_is_allocated ) THEN
       WRITE(6,*)'Your model data is not allocated '
       WRITE(6,*)'Set RELEASE_MEMORY = F'
       CYCLE STATION_CYCLE
    ENDIF

    IF (.NOT.(hir(i)%active.AND.obs(i)%active)) THEN
       IF (release_memory) DEALLOCATE(obs(i)%o,hir(i)%o)
       CYCLE STATION_CYCLE
    ENDIF

    IF (hir(i)%stnr /= obs(i)%stnr) THEN
       WRITE(6,*)'Your stations does not agree',hir(i)%stnr,obs(i)%stnr,i
       CALL abort
    ENDIF

    !
    ! Loop over all observation times and forecasts for this observation
    !

    jjstart = 1
    jjcheck = hir(i)%ntim

    J_CYCLE : DO j=1,obs(i)%ntim

      found_right_time = .FALSE.
     par_is_checked(:) = .FALSE.

       IF ( print_qc > 2 ) WRITE(lunqc,*)'DATE IS',&
       obs(i)%o(j)%date,obs(i)%o(j)%time,obs(i)%o(j)%val

       IF(ALL(ABS(obs(i)%o(j)%val-err_ind) < eps)) CYCLE J_CYCLE

     FC_CYCLE : DO n=1,nfclengths

       IF ( print_qc > 2 ) WRITE(lunqc,*)'Check fclen',fclen(n)

       IF ( ALL(par_is_checked) ) EXIT FC_CYCLE

       !
       ! Step time to verification time 
       ! If we have no observations inside the range then cycle
       !

       CALL adddtg(obs(i)%o(j)%date,obs(i)%o(j)%time*10000,&
                   -fclen(n)*3600,wdate,wtime)
       wtime = wtime / 10000

        
       !
       ! Loop over all observations and all times
       !

       JJ_CYCLE : DO jj=jjstart,hir(i)%ntim

       !
       ! Cycle FC_CYCLE if we have passed the model date
       !

       IF (hir(i)%o(jj)%date > wdate) CYCLE FC_CYCLE

       MOD_TEST : IF(hir(i)%o(jj)%date == wdate .AND.&
                     hir(i)%o(jj)%time == wtime ) THEN

          IF ( print_qc > 2 ) WRITE(lunqc,*)&
          'Found right time',wdate,wtime,'+',fclen(n)

          found_right_time  = .TRUE.
                 jjcheck(n) = jj

          NPARVER_LOOP : DO k=1,nparver

             IF ( print_qc > 2 ) WRITE(lunqc,*)'PAR IS CHECKED', &
             par_is_checked(k),varprop(k)%id

             IF ( par_is_checked(k) ) CYCLE NPARVER_LOOP

             !
             ! Cycle if fclen should not be used but ONLY if this is NOT an accumulated value
             !

             IF ( (.NOT.ANY(qc_fclen == fclen(n))) .AND. (varprop(k)%acc == 0 ) ) CYCLE NPARVER_LOOP

             IF ( print_qc > 2 ) WRITE(lunqc,*)'PASSED qc_fclen test', &
             obs(i)%o(j)%val(k)

             !
             ! Loop over all variables
             !

             IF(ABS(obs(i)%o(j)%val(k)-err_ind) < 1.e-6) CYCLE NPARVER_LOOP
             IF ( print_qc > 2 ) WRITE(lunqc,*)'PASSED err_ind test '

             qc_control = .FALSE.
             diff       = err_ind

             EXP_LOOP : DO o=1,nexp
 
                IF ( print_qc > 2 ) WRITE(lunqc,*)'EXP',o, &
                hir(i)%o(jj)%nal(o,n,k)

                IF (ABS(hir(i)%o(jj)%nal(o,n,k)-err_ind)<1.e-6) CYCLE EXP_LOOP

                IF(varprop(k)%acc /= 0) THEN

                  !
                  ! Special for accumulated values
                  !

                  SELECT CASE(varprop(k)%acctype) 
                  CASE(0)

                   !
                   ! Take difference between fclen(n) and fclen(ind_pe(k,n))
                   !

                   IF(fclen(n) == varprop(k)%acc) THEN
                      diff_prep = hir(i)%o(jj)%nal(o,n,k)
                   ELSEIF(fclen(n) > varprop(k)%acc .AND. ind_pe(k,n) > 0 ) THEN
                      IF ( print_qc > 2 ) WRITE(lunqc,*)'EXP fclen -acc_int',o,ind_pe(k,n), &
                      hir(i)%o(jj)%nal(o,ind_pe(k,n),k)
                      IF (ABS(hir(i)%o(jj)%nal(o,ind_pe(k,n),k)-err_ind)<1.e-6) CYCLE EXP_LOOP

                      diff_prep = hir(i)%o(jj)%nal(o,n          ,k) - &
                                  hir(i)%o(jj)%nal(o,ind_pe(k,n),k)

                      IF ( print_qc > 2 ) WRITE(lunqc,*) &
                      'ACCU_PAR CHECKED',ind_pe(k,n),diff_prep

                      IF (diff_prep < 0.) THEN
                         WRITE(lunqc,*)'Accumulated model value difference is negative',diff_prep
                         WRITE(lunqc,*)TRIM(varprop(k)%id),diff_prep
                         WRITE(lunqc,'(2A,I10)')TRIM(expname(o)),' station:',hir(i)%stnr
                         WRITE(lunqc,*)hir(i)%stnr,hir(i)%o(jj)%date,      &
                                   hir(i)%o(jj)%time,fclen(n),         &
                                   hir(i)%o(jj)%nal(o,n,k)
                         WRITE(lunqc,*)hir(i)%stnr,hir(i)%o(jj)%date,      &
                                   hir(i)%o(jj)%time,fclen(ind_pe(k,n)), &
                                   hir(i)%o(jj)%nal(o,ind_pe(k,n),k)

                         diff_prep = 0.0

                      ENDIF

                   ELSE
                      CYCLE EXP_LOOP
                   ENDIF

                  CASE(2)

                   !
                   ! Take MIN over fclen(ind_pe(k,n)) - fclen(n)
                   !

                   nn=MAX(1,ind_pe(k,n)+1)
                   diff_prep = hir(i)%o(jj)%nal(o,n,k)
                   DO l=nn,n-1
                     IF (ABS(hir(i)%o(jj)%nal(o,l,k)-err_ind)>1.e-6) THEN
                       diff_prep = MIN(hir(i)%o(jj)%nal(o,l,k),diff_prep)
                     ENDIF
                   ENDDO
                  CASE(3)

                   !
                   ! Take MAX over fclen(ind_pe(k,n)) - fclen(n)
                   !

                   nn=MAX(1,ind_pe(k,n)+1)
                   diff_prep = hir(i)%o(jj)%nal(o,n,k)
                   DO l=nn,n-1
                     IF (ABS(hir(i)%o(jj)%nal(o,l,k)-err_ind)>1.e-6) THEN
                       diff_prep = MAX(hir(i)%o(jj)%nal(o,l,k),diff_prep)
                     ENDIF
                   ENDDO

                  CASE DEFAULT
                   CALL ABORT
                 END SELECT

                ELSE
                   diff_prep=hir(i)%o(jj)%nal(o,n,k)
                ENDIF

                diff(o) =  diff_prep - obs(i)%o(j)%val(k)
            
                !
                ! Wind direction
                !

                 IF(varprop(k)%id == 'DD'.AND.ABS(diff(o)) > 180.) &
                 diff(o) = diff(o) + SIGN(360.,180.-diff(o))

                IF ( print_qc > 2 )WRITE(lunqc,*)'Diff_prep',o,diff_prep,obs(i)%o(j)%val(k),diff(o)

                !
                ! Gross error check
                !

                    qc_control(o) = ( ABS(diff(o)) < qc_lim(k) )
                par_is_checked(k) = .TRUE.

                IF ( estimate_qc_limit ) THEN

                   !
                   ! Accumulate bias and rmse
                   !
                   
                   nver(k) = nver(k) + 1
                   bias(k) = bias(k) + diff(o)
                   rmse(k) = rmse(k) + diff(o)**2

                ENDIF

             ENDDO EXP_LOOP

             IF ( par_is_checked(k).AND.     &
                  .NOT. ANY(qc_control).AND. &
                  .NOT. estimate_qc_limit      ) THEN

               !
               ! Reject erroneous observations
               !

               IF (varprop(k)%acc == 0 ) THEN
                IF (print_qc > 1 ) THEN
                  WRITE(lunqc,'(A,2I10,2I3)')'GROSS ERROR station:', &
                  hir(i)%stnr,hir(i)%o(jj)%date,hir(i)%o(jj)%time,fclen(n)
                  WRITE(lunqc,*)varprop(k)%text(1:15),qc_lim(k),     &
                  obs(i)%o(j)%val(k),hir(i)%o(jj)%nal(:,n,k)
                ENDIF

                gross_error(1,i,k)   = gross_error(1,i,k) + 1
                obs(i)%o(j)%val(k) = err_ind

               ELSE
                SELECT CASE(varprop(k)%acctype)

                 CASE(0)

                  IF ( (fclen(n) == varprop(k)%acc).OR. &
                       (fclen(n) >  varprop(k)%acc .AND.  ind_pe(k,n) > 0 )) THEN
                   IF (print_qc > 1 ) THEN
                     IF (lprint_gross_first ) THEN
                       WRITE(lunqc,'(A)')'GROSS ERROR station: stnr, date, time, fclen'
                       WRITE(lunqc,'(A)')'Obstype, qc limit, obs, model'
                       lprint_gross_first = .FALSE.
                     ENDIF
                     WRITE(lunqc,'(A,2I10,2I3)')'GROSS ERROR station:', &
                     hir(i)%stnr,hir(i)%o(jj)%date,hir(i)%o(jj)%time,fclen(n)
                     WRITE(lunqc,*)varprop(k)%text(1:15),qc_lim(k),     &
                     obs(i)%o(j)%val(k),obs(i)%o(j)%val(k)+diff(1)
                   ENDIF

                   gross_error(1,i,k)   = gross_error(1,i,k) + 1
                   obs(i)%o(j)%val(k) = err_ind

                  ENDIF

                 CASE(2:3)

                   IF (print_qc > 1 ) THEN
                     WRITE(lunqc,'(A,2I10,2I3)')'GROSS ERROR station:', &
                     hir(i)%stnr,hir(i)%o(jj)%date,hir(i)%o(jj)%time,fclen(n)
                     WRITE(lunqc,*)varprop(k)%text(1:15),qc_lim(k),     &
                     obs(i)%o(j)%val(k),hir(i)%o(jj)%nal(:,n,k)
                   ENDIF

                   gross_error(1,i,k)   = gross_error(1,i,k) + 1
                   obs(i)%o(j)%val(k) = err_ind

                  CASE DEFAULT
                   WRITE(6,*)'Unknown acctype',varprop(k)%acctype
                   CALL abort
                 END SELECT
                ENDIF


             ENDIF

             IF ( par_is_checked(k) ) total_amount(i,k) = total_amount(i,k) + 1


          ENDDO NPARVER_LOOP

          IF ( ALL(par_is_checked) ) EXIT FC_CYCLE

          CYCLE FC_CYCLE

       ENDIF MOD_TEST

       ENDDO JJ_CYCLE

     ENDDO FC_CYCLE

     ! Updated index position
     IF(found_right_time) THEN

        jjstart = MINVAL(jjcheck) 
        jjstart = MAX(jjstart,1) 

     ENDIF

     
     !
     ! Reject non quality controlled observations
     !

     IF (.NOT. estimate_qc_limit ) THEN

        IF ( .NOT. ALL(par_is_checked) .AND. print_qc > 1 ) THEN
           WRITE(lunqc,'(A,2I10,I3)')'   No check station:', &
           obs(i)%stnr,obs(i)%o(j)%date,obs(i)%o(j)%time
        ENDIF

        DO k=1,nparver
 
           IF ( par_is_checked(k) ) CYCLE

           IF ( ABS(obs(i)%o(j)%val(k)-err_ind) > 1.e-6 ) THEN

              IF (print_qc > 1 ) WRITE(lunqc,*)varprop(k)%text(1:20),obs(i)%o(j)%val(k)
              obs(i)%o(j)%val(k) = err_ind
   
              gross_error(2,i,k) = gross_error(2,i,k) + 1
               total_amount(i,k) =  total_amount(i,k) + 1

           ENDIF

        ENDDO

     ENDIF

    ENDDO J_CYCLE

 ENDDO STATION_CYCLE


 IF ( estimate_qc_limit ) THEN

    WRITE(lunqc,*)
    WRITE(lunqc,*)' Qualtiy control limits (QC_LIM_SCALE,STDV,QC_LIM) '
    WRITE(lunqc,*)

    DO k=1,nparver

       IF (ABS(qc_lim (k) - err_ind ) < 1.e-6 ) THEN
          stdv = sqrt(ABS(rmse(k)/MAX(1.,FLOAT(nver(k)))        &
                        -(bias(k)/MAX(1.,FLOAT(nver(k))))**2))
          qc_lim(k) = qc_lim_scale(k) * stdv
       ENDIF

       WRITE(lunqc,*)varprop(k)%text(1:20),qc_lim_scale(k),stdv,qc_lim(k)
    ENDDO
    WRITE(lunqc,*)

    estimate_qc_limit = .FALSE.

 ELSE

    IF ( print_qc > 0 ) CALL sumup_gross(gross_error,total_amount)
    DEALLOCATE(gross_error)

 ENDIF

 DEALLOCATE(total_amount)

 CLOSE(lunqc)

 RETURN

END SUBROUTINE quality_control
