SUBROUTINE read_vobs
 !
 ! Read synop part of vobsyyyymmddhhll
 ! and organize in data array
 ! for verification and plotting
 !
 ! Ulf Andrae, SMHI, 2004-2011
 !

 USE data
 USE functions
 USE constants

 IMPLICIT NONE

 REAL, PARAMETER :: mflag = -99.

 INTEGER :: i,ii,k,m,mm,n,m2,mmp,m2p,   &
            ierr = 0,                   &
            cdate = 999999,             &
            ctime = 999999,             &
            wdate = 999999,             &
            wtime = 999999,             &
            istnr = 0,                  &
            stat_i,                     &
            ninvar,old_ninvar,          &
            num_temp,num_stat,          &
            num_temp_lev,               &
            stations(10000000),         &
            max_found_stat,             &
            version_flag,               &
            old_version_flag
 
 INTEGER, ALLOCATABLE :: inacc(:)

 REAL :: lat,lon,hgt,sub,sca,rtmp
 REAL, ALLOCATABLE :: val(:)

 CHARACTER(LEN=200) :: path,fname =' '
 CHARACTER(LEN= 10) :: ndate =' '
 CHARACTER(LEN= 10), ALLOCATABLE :: invar(:)

 LOGICAL :: use_stnlist,cbl

!----------------------------------------------------------

 ! Init 
 stations       = 0
 max_found_stat = 0
 old_version_flag = -1
 version_flag   = 0
 old_ninvar     = -1
 ninvar         = 0
 INQUIRE(FILE='black.list',EXIST=cbl)

 use_stnlist =(  MAXVAL(stnlist) > 0 )

 CALL allocate_obs

 ! Copy time

 cdate = sdate
 ctime = stime*10000
 wdate = cdate
 wtime = ctime
 
 !
 ! Loop over all times
 !

 i = 0

 TIME_LOOP : DO

 IF (print_read > 1) WRITE(6,*)'TIME:',cdate,ctime/10000
 WRITE(ndate(1:10),'(I8.8,I2.2)')cdate,ctime/10000
 path = obspath
 CALL check_path(cdate,path)
 fname = TRIM(path)//'vobs'//ndate

 i = i + 1

 !
 ! Read obs data
 !

       OPEN(lunin,file=fname,status='old',iostat=ierr)

       IF (ierr /= 0) THEN
  
          IF( print_read > 0 )WRITE(6,'(2A)')'MISS ',TRIM(fname)

          wdate = cdate
          wtime = ctime
          CALL adddtg(wdate,wtime,3600*obint,cdate,ctime)
          IF(cdate.gt.edate_obs) EXIT TIME_LOOP

          i = i - 1
          CYCLE TIME_LOOP

       ENDIF

       IF (print_read > 0 ) WRITE(6,'(2A)')'READ ',TRIM(fname)

       version_flag = 0

       READ(lunin,'(1x,3I6)',IOSTAT=ierr)num_stat,num_temp,version_flag
       IF ( ierr /= 0 ) THEN
          WRITE(6,*)'Error reading first line of vobs file',ierr
          CALL abort
       ENDIF

       IF ( print_read > 1 ) WRITE(6,*)'FILE version',version_flag,old_version_flag

       IF ( version_flag /= old_version_flag ) THEN
         SELECT CASE(version_flag)
          CASE(0)
            IF ( ALLOCATED(invar) ) DEALLOCATE(invar,val,inacc)
            ninvar=8
            ALLOCATE(invar(ninvar),val(ninvar),inacc(ninvar))
            invar = (/'NN','DD','FF','TT','RH','PS','PE','QQ'/)
          CASE(1)
            IF ( ALLOCATED(invar) ) DEALLOCATE(invar,val,inacc)
            ninvar=10
            ALLOCATE(invar(ninvar),val(ninvar),inacc(ninvar))
            invar = (/'NN','DD','FF','TT','RH','PS','PE','QQ','VI','TD'/)
          CASE(2,3)
            IF ( ALLOCATED(invar) ) DEALLOCATE(invar,val,inacc)
            ninvar=15
            ALLOCATE(invar(ninvar),val(ninvar),inacc(ninvar))
            invar = (/'NN','DD','FF','TT','RH', &
                      'PS','PE','QQ','VI','TD', &
                      'TX','TN','GG','GX','FX'/)
          CASE(4)

          CASE DEFAULT
             WRITE(6,*)'Cannot handle this vobs-file version',version_flag
             CALL abort
         END SELECT
       ENDIF

       old_version_flag = version_flag

       SELECT CASE(version_flag)
       CASE(0:3)
       READ(lunin,*)num_temp_lev
       CASE(4)
          READ(lunin,*)ninvar
          IF ( ninvar /= old_ninvar ) THEN
            IF ( ALLOCATED(invar) ) DEALLOCATE(invar,val,inacc)
            ALLOCATE(invar(ninvar),val(ninvar),inacc(ninvar))
          ENDIF
          DO i=1,ninvar
            READ(lunin,*)invar(i),inacc(i)
            IF ( invar(i)(1:2) == 'TM' ) &
            invar(i)(1:2) = 'TN'
          ENDDO
       END SELECT
       old_ninvar = ninvar

       !
       ! Read, identify and store station data
       !

       READ_STATION_OBS : DO k=1,num_stat

          val = mflag
          SELECT CASE(version_flag)
           CASE(0)
             READ(lunin,*,iostat=ierr)istnr,lat,lon,hgt,val(1:8)
           CASE(1)
             READ(lunin,*,iostat=ierr)istnr,lat,lon,hgt,val(1:10)
           CASE(2,4)
             READ(lunin,*,iostat=ierr)istnr,lat,lon,hgt,val
           CASE DEFAULT
             WRITE(6,*)'Cannot handle this vobs-file version',version_flag
             CALL abort
          END SELECT

          IF (ierr  /= 0 .OR. istnr == 0 ) CYCLE READ_STATION_OBS

          !
          ! Find station index
          !

          SELECT CASE(stations(istnr))
          CASE(-1)
             CYCLE READ_STATION_OBS
          CASE( 0)
           
             stat_i = 0
             IF ( use_stnlist ) THEN
                DO ii=1,maxstn
                      IF (istnr == stnlist(ii) ) THEN
                          stat_i = ii
                          EXIT
                      ENDIF
                ENDDO
                IF ( stat_i == 0 ) THEN
                   stations(istnr) = -1
                   CYCLE READ_STATION_OBS
                ENDIF
             ENDIF

             IF (stat_i == 0 ) THEN 
                max_found_stat  = max_found_stat + 1
                stnlist(max_found_stat)= istnr
             ELSE
                max_found_stat  = stat_i
             ENDIF

             stations(istnr) = max_found_stat 
             obs(max_found_stat)%active = .TRUE.
             obs(max_found_stat)%stnr   = istnr
             obs(max_found_stat)%lat    = lat
             obs(max_found_stat)%lon    = lon
             obs(max_found_stat)%hgt    = hgt

             IF (max_found_stat > maxstn) THEN
                WRITE(6,*)'Increase maxstn',max_found_stat
                CALL abort
             ENDIF

          END SELECT


          stat_i = stations(istnr)

          !
          ! Add data
          !

          i = obs(stat_i)%ntim + 1

          IF ( i > maxtim ) CALL abort

          IF ( print_read > 1 ) WRITE(6,*)'STATION ',stat_i,obs(stat_i)%stnr

          ALLOCATE(obs(stat_i)%o(i)%date)
          ALLOCATE(obs(stat_i)%o(i)%time)
          ALLOCATE(obs(stat_i)%o(i)%val(nparver))

          obs(stat_i)%ntim      = i
          obs(stat_i)%o(i)%date = cdate
          obs(stat_i)%o(i)%time = ctime/10000
          obs(stat_i)%o(i)%val  = err_ind

          IF ( use_pos ) obs(stat_i)%pos(cdate * 100 + ctime/10000 ) = i

          PARVER_LOOP : DO m=1,nparver
            INVAR_LOOP : DO n=1,ninvar
              IF ( varprop(m)%id == invar(n) ) THEN

                ! Check for missing data flag
                IF ( .NOT. qca(val(n),mflag) ) CYCLE PARVER_LOOP

                ! Special treatment of some variabels
                sca = 1.0
                sub = 0.0
                SELECT CASE(invar(n))

                CASE('TT','TN','TX','TD')
                   sub = tzero
                CASE('QQ')
                   sca = 1.e3
                END SELECT

                IF ( do_you_like_me(cbl,obs(stat_i)%stnr,invar(n)) ) THEN
                 ! Check for missing data / gross error
                  IF ( qclr(val(n),varprop(m)%llim) .AND. &
                       qcur(val(n),varprop(m)%ulim) )     &
                  obs(stat_i)%o(i)%val(m) = ( val(n) - sub ) * sca
                ENDIF

              ENDIF
            ENDDO INVAR_LOOP

            ! Static pseudo variables
            SELECT CASE(varprop(m)%id)
              CASE('FFP1','FFP2','DDP1','DDP2','RHP1','RHP2')
               mm = find_var(ninvar,invar,varprop(m)%id(1:2))
               IF ( mm > 0 ) THEN
                IF ( qca(val(mm),mflag)) &
                obs(stat_i)%o(i)%val(m) = val(mm)
               ENDIF
              CASE('QQP1','QQP2')
               mm = find_var(ninvar,invar,varprop(m)%id(1:2))
               IF ( mm > 0 ) THEN
                IF ( qca(val(mm),mflag)) &
                obs(stat_i)%o(i)%val(m) = val(mm) * 1.e3
               ENDIF
              CASE('LA')
               obs(stat_i)%o(i)%val(m) = obs(stat_i)%lat
              CASE('HG')
               obs(stat_i)%o(i)%val(m) = obs(stat_i)%hgt
              CASE('PE12')
               ! Use PE if PE12 not found
               mm = find_var(ninvar,invar,varprop(m)%id(1:2))
               IF ( mm > 0 ) THEN
                IF ( qca(val(mm),mflag)            .AND. &
                     qclr(val(mm),varprop(m)%llim) .AND. &
                     qcur(val(mm),varprop(m)%ulim) )     &
                obs(stat_i)%o(i)%val(m) = val(mm)
               ENDIF
              CASE('TTHA','TNHA','TXHA','TTP1','TTP2', &
                   'TDP1','TDP2','TNP1','TNP2','TXP1','TXP2')
               ! Convert to celcius
               mm = find_var(ninvar,invar,varprop(m)%id(1:2))
               IF ( mm > 0 ) THEN
                IF ( qca(val(mm),mflag)            .AND. &
                     qclr(val(mm),varprop(m)%llim) .AND. &
                     qcur(val(mm),varprop(m)%ulim) )     &
                obs(stat_i)%o(i)%val(m) = val(mm) - tzero
               ENDIF
              CASE('TDD')
               mm=find_var(ninvar,invar,varprop(m)%id(1:2))
               m2=find_var(ninvar,invar,'TT')
               mmp=find_varprop(varprop(m)%id(1:2))
               m2p=find_varprop('TT')
               IF ( mm > 0 .AND. mmp > 0 .AND. &
                    m2 > 0 .AND. m2p > 0 ) THEN
                ! Calc dew point deficit
                IF ( qca(val(mm),mflag)             .AND. &
                     qca(val(m2),mflag)             .AND. &
                     qclr(val(mm),varprop(mmp)%llim) .AND. &
                     qcur(val(mm),varprop(mmp)%ulim) .AND. &
                     qclr(val(m2),varprop(m2p)%llim) .AND. &
                     qcur(val(m2),varprop(m2p)%ulim) ) THEN
                  rtmp = val(m2) - val(mm)
                  IF ( qclr(rtmp,varprop(m)%llim) .AND. &
                       qcur(rtmp,varprop(m)%ulim) )     &
                       obs(stat_i)%o(i)%val(m) = rtmp
                ENDIF
               ENDIF
              CASE('NN')
                IF ( qca(obs(stat_i)%o(i)%val(m),err_ind) ) THEN
                 ! Translate clould cover to discrete eights
                 obs(stat_i)%o(i)%val(m) =              &
                 FLOAT(NINT(obs(stat_i)%o(i)%val(m)))
                ENDIF
              CASE('SPS')
               mm=find_var(ninvar,invar,'PSS')
               IF ( qca(val(mm),mflag) ) &
               obs(stat_i)%o(i)%val(m) = val(mm)
             CASE('ISS')
               mm=find_var(ninvar,invar,'RH')
               m2=find_var(ninvar,invar,'TT')
               mmp=find_varprop('RH')
               m2p=find_varprop('TT')
               IF ( mm  > 0 .AND. m2  > 0 .AND. &
                    mmp > 0 .AND. m2p > 0 ) THEN
                IF ( qca(val(mm),mflag)             .AND. &
                    qca(val(m2),mflag)             .AND. &
                     qclr(val(mm),varprop(mmp)%llim) .AND. &
                     qcur(val(mm),varprop(mmp)%ulim) .AND. &
                     qclr(val(m2),varprop(m2p)%llim) .AND. &
                     qcur(val(m2),varprop(m2p)%ulim) ) THEN
                  obs(stat_i)%o(i)%val(m) = &
                  get_iss(val(mm),val(m2))
                ENDIF
               ENDIF
            END SELECT

          ENDDO PARVER_LOOP

          IF (print_read > 1 ) WRITE(6,*)varprop(1:nparver)%id,obs(stat_i)%o(i)%val

       ENDDO READ_STATION_OBS

       CLOSE(lunin)

    wdate = cdate
    wtime = ctime
    CALL adddtg(wdate,wtime,3600*obint,cdate,ctime)
    IF(cdate > edate_obs) EXIT TIME_LOOP

 ENDDO TIME_LOOP

 DO i=1,maxstn
    obs(i)%active = ( obs(i)%ntim > 0 )
 ENDDO

 WRITE(6,*) 'FOUND TIMES OBS',MAXVAL(obs(:)%ntim)

 ! Clear memory

 IF ( ALLOCATED(invar) ) DEALLOCATE(invar,val)
 IF ( ALLOCATED(inacc) ) DEALLOCATE(inacc)

 RETURN
END SUBROUTINE read_vobs
