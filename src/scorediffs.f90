SUBROUTINE scorediffs(exp1,exp2,nfclen,par,     &
                      istart,iend,              &
                      lnorm,lztrans,confide,    &
                      diff,ncases)

 USE data, ONLY: use_fclen
 USE sign_data 

 IMPLICIT NONE 

 ! Input
 INTEGER, INTENT(IN) :: exp1,exp2
 INTEGER, INTENT(IN) :: nfclen,par
 INTEGER, INTENT(IN) :: istart,iend
 LOGICAL, INTENT(IN) :: lnorm,lztrans
 REAL,    INTENT(IN) :: confide

 ! Output

 REAL,    INTENT(OUT)   :: diff(nfclen,2)
 INTEGER, INTENT(INOUT) :: ncases(nfclen)

 ! Local
 INTEGER :: i,j,l

 REAL :: x(sign_stat_max),y(sign_stat_max),d(sign_stat_max,nfclen)

 REAL ::  avs,avd,sigmean,dy,tcrit,confid
     
 EXTERNAL :: t4_confid
 REAL     :: t4_confid


!--- header comment for output
      confid = confide/100.0

  ncases(:) = 0
  diff(:,:) = 0
  DO j=1,nfclen

     l = 0
     DO i=istart,iend
       IF ( all_sign_stat(i)%n(1,j,par) == 0 ) CYCLE 
       l = l + 1
       x(l) = SQRT( all_sign_stat(i)%r(exp1,j,par) /  &
                      all_sign_stat(i)%n(1,j,par) )
       y(l) = SQRT( all_sign_stat(i)%r(exp2,j,par) /  &
                      all_sign_stat(i)%n(1,j,par) )
     ENDDO 

     ncases(j) = l

     IF ( l < 2 ) CYCLE

!--- transform correlations to something more Gaussian

     if (lztrans) then
       x(1:l) = 0.5*log( (1.-0.01*x(1:l))/(1.+0.01*x(1:l)) )
       y(1:l) = 0.5*log( (1.-0.01*y(1:l))/(1.+0.01*y(1:l)) )
     endif

!--- calculate the value of t corresponding to the confidence interval
!--- using bisection.

     tcrit= t4_confid(confid,l-1) 

!--- calculate differences

     d(:,j) = x(:)-y(:)

!--- mean scores and mean difference

     avs=0.
     avd=0.
     do i=1,l
       avs = avs + x(i) + y(i)
       avd = avd + d(i,j)
     enddo
     avs =0.5*avs/l
     avd =avd/l

!--- normalize

     if (lnorm) then
        d(1:l,j)  = d(1:l,j)/avs
        avd = avd/avs
     endif

!--- auto-correlation-corrected standard deviation of mean

     call stats (d(1:l,j),avd,l,sigmean)

!--- confidence interval is between avd-dy and avd+dy

     dy = sigmean*tcrit

     diff(j,:) = (/avd,dy/)

   ENDDO

END SUBROUTINE scorediffs

SUBROUTINE stats (d,avd,nsc,sigmean)

!--- returns an estimate of the population standard deviation of the
!--- mean of 'd', where 'd' is supposed to be a sample generated by a
!--- first-order auto-regressive process. (i.e. d(i) =r*d(i-1)+e(i)
!--- for a fixed coefficient r and independent random variables e(i).)

      implicit none

      integer nsc,i,j

      real d(nsc)

      real avd,sigmean,var,covd1,cord,rtoj,rinflt,std
       

!--- Sample variance

      var = 0.
      do i=1,nsc
       var = var + (d(i)-avd)*(d(i)-avd)
      enddo
      var = var/nsc

      if ( var < tiny(var) ) then
        sigmean = 0.
        return
      endif

!--- Sample lag-one auto-covariance

      covd1 = 0.
      do i=2,nsc
       covd1 = covd1 + (d(i)-avd)*(d(i-1)-avd)
      enddo
      covd1 = covd1/nsc

!--- lag-one auto-correlation

      cord = covd1/var

!--- variance and stdev of sample mean neglecting auto-correlation

      var = var/(nsc-1)
      std = sqrt(var)

!--- inflation factor to account for auto-correlation:
!---     rinflt = sqrt( (1/N) sum(cord**abs(i-j)) )
!--- where the sum is over i=1,...,nsc and j=1,...,nsc

      rtoj = 1.0
      rinflt = nsc

      do j=1,nsc-1
       rtoj = rtoj*cord
       rinflt = rinflt + 2*(nsc-j)*rtoj
      enddo
      rinflt = max(1.0,sqrt(rinflt/nsc))
!      write (0,*) 'lag-one auto-corr=',cord,
!     &            ' stdev of mean inflated by ',rinflt

!--- auto-correlation corrected standard deviation

      sigmean = std*rinflt

 RETURN
END SUBROUTINE stats
      real function t4_confid(conf_level,ndf)
      implicit none
      real conf_level
      integer ndf
      real probst
      external probst
      real cf_wish,xmin,xmax,x,cf_out
      integer error,niter
      if( ndf.le.0 ) then
         write(6,*)ndf,' degrees of freedom!!'
         write(6,*)' student t not defined'
         t4_confid = 0.
         return
      end if
      cf_wish = 1.0 - 0.5*(1.0-conf_level)
      cf_out  = cf_wish * 2
      xmin = 0.1
      xmax = 100.0
      niter=0
      do while (abs(cf_wish-cf_out).gt.0.000001.and.niter.lt.1000)
        niter=niter+1
        x = 0.5*(xmin+xmax)
        cf_out =  probst(x,ndf,error)
        if( cf_out.lt.cf_wish ) then
          xmin = x
        else
          xmax = x
        end if
      end do
      t4_confid=x
      write(6,*)'conf_level ndf t4_confid=',conf_level,ndf,t4_confid
      return 
      end
      REAL FUNCTION PROBST(T, IDF, IFAULT)
! ---------------------------------------------------------------------
!        ALGORITHM AS 3  APPL. STATIST. (1968) VOL.17, P.189
!
!        STUDENT T PROBABILITY (LOWER TAIL)
! ---------------------------------------------------------------------
      REAL A, B, C, F, G1, S, FK, T, ZERO, ONE, TWO, HALF, ZSQRT, ZATAN

!        G1 IS RECIPROCAL OF PI

      DATA ZERO, ONE, TWO, HALF, G1  /0.0, 1.0, 2.0,  0.5, 0.3183098862/

      ZSQRT(A) = SQRT(A)
      ZATAN(A) = ATAN(A)

      IFAULT = 1
      PROBST = ZERO
      IF (IDF .LT. 1) RETURN
      IFAULT = 0
      F = IDF
      A = T / ZSQRT(F)
      B = F / (F + T ** 2)
      IM2 = IDF - 2
      IOE = MOD(IDF, 2)
      S = ONE
      C = ONE
      F = ONE
      KS = 2 + IOE
      FK = KS
      IF (IM2 .LT. 2) GOTO 20
      DO 10 K = KS, IM2, 2
      C = C * B * (FK - ONE) / FK
      S = S + C
      IF (S .EQ. F) GOTO 20
      F = S
      FK = FK + TWO
   10 CONTINUE
   20 IF (IOE .EQ. 1) GOTO 30
      PROBST = HALF + HALF * A * ZSQRT(B) * S
      RETURN
   30 IF (IDF .EQ. 1) S = ZERO
      PROBST = HALF + (A * B * S + ZATAN(A)) * G1
      RETURN
      END
