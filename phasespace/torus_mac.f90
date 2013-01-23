subroutine state2kirk(n,phi,tip,tiq,rho,ndim,workfft) ! {{{
!  
! constructs the kirkwood representation of the pure state vector phi
! 
! on entry phi(j)=<j|phi> in the coordinate rep. (unchanged on exit)
! on exit rho(k,n) containd the Kirkwood rep. rho(k,n)=<k|rho|n>/<k|n>
! normalization is such that sum_{k,n}=1        
      complex*16 phi(0:n-1),rho(0:ndim-1,0:ndim-1)
      complex*16 workfft(2*n+16),del,work(0:n-1)
      real*8 tip,tiq      
      if(n.gt.15000)stop ' n too large in state2kirk '
      del=dcmplx(0.d0,8.d0*atan2(1.d0,1.d0))/n     !2*i*pi/N      	
      do i=0,n-1
          work(i)=phi(i)*exp(-del*tip*i)
      end do
!             write(6,*) "work(0)",work(0)
       call zfft1di(n,workfft)	  
       call zfft1d(-1,n,work(0),1,workfft)
!        write(6,*) "work(0)",work(0)
!       print*,"SI buenas"
      do k=0,n-1 
         do i=0,n-1
 	    rho(k,i)=work(k)*dconjg(phi(i))*exp(del*i*(k+tip))	
! 		if (i==0.and.k==0) print*,k,i,rho(k,i),work(k),phi(i),exp(del*i*(k+tip))    
	 end do
      end do                !rho(k,i)=<k|phi><phi|i>/<k|i>
      return
      end ! }}}
subroutine kirk(idir,n,a,lda,workfft) ! {{{
! goes back and forth between kirkwood and antikirkwood
! idir=1 assumes a(k,n)=<k|a|n>/<k|n> on input and produces a(n,k) on
! output
! idir=-1 assumes a(n,k) and produces a(k,n)  
! two su!essive calls should reproduce the original
! notice that the fourier transform should NOT be normalized
! but the output satisfies sum_{n,k}=1
! workfft should be initialized by a call to zfft2di(n,n,workfft)
! it uses as working space the vector a(n,*)
! it is used mainly by prop_kirk to propagate kirkwood matrices by kicked maps 
! if a is hermitian then kirk and antikirk are hermitian conjugates.  
      complex*16 a(0:lda-1,0:lda-1),workfft(2*n+16),den
      den=dcmplx(0.d0,8.d0*atan2(1.d0,1.d0)/n)   !2*i*pi
      do j=0,n-1
         a(n,j)=cdexp(-j*den)          !n'th roots of unity....
      end do
      if(idir.eq.1)then
        do i=0,n-1
          do k=0,n-1
             a(i,k)=a(i,k)*a(n,mod(i*k,n))
	   end do  
        end do
        call zfft2d(1,n,n,a,lda,workfft)
        do i=0,n-1
          do k=0,n-1
             a(i,k)=a(i,k)*a(n,mod(i*k,n))/n
	   end do  
        end do
      else if(idir.eq.-1)then
        do i=0,n-1
          do k=0,n-1
             a(i,k)=a(i,k)*dconjg(a(n,mod(i*k,n)))
	   end do  
        end do
        call zfft2d(-1,n,n,a,lda,workfft)
        do i=0,n-1
          do k=0,n-1
             a(i,k)=a(i,k)*dconjg(a(n,mod(i*k,n)))/n
	   end do  
        end do
      end if	
      return
      end !}}}
subroutine kirk2wig(idir,n,a,lda,nr,wig,ldwig,workfft) ! {{{
! transforms the kirkwood rep of a to the first irreducible
! quarter of the wigner  function
! on input a is the N*N complex array a(k,n) (unchanged)
! on output wig(ip,iq) is the 2N*2N complex array. When a is hermitian then
! all imaginary parts of wig should be zero. Otherwise, for a
!  unitary map it provides the Weyl representation.
!  nr is set equal to 2 for input to the plotting program
! 
! idir=1 implies a is the kirkwood rep
! idir=-1 implies a is the antikirk.     
      complex*16 a(0:lda-1,0:lda-1),wig(0:ldwig-1,0:ldwig-1)
      complex*16 ipi,temp,workfft(n+16)
      ipi=dcmplx(0.d0,4.d0*atan2(1.d0,1.d0))     !i*pi 
      do ik=0,n-1
         do in=0,n-1
	    wig(ik,in)=a(ik,in)*exp(-4.d0*idir*ipi*mod(ik*in,n)/n)
	 end do
      end do
      call zfft2d(idir,n,n,wig,ldwig,workfft)
      do iq=0,n-1
         do ip=0,n-1
	     temp=wig(iq,ip)*exp(-idir*ipi*mod(ip*iq,2*n)/n)/n
	     wig(iq,ip)=temp
	     wig(iq+n,ip)= temp*(-1)**ip
	     wig(iq,ip+n)= temp*(-1)**iq
	     wig(iq+n,ip+n)= temp*(-1)**(iq+ip)	    
	 end do
      end do
      nr=2
      return
      end      !}}}
subroutine zfft1di(n,workfft) ! {{{
!  converts the calls of sgi complib to fftw on MAC OSX     
complex*16 workfft(2*n+16)
return
end subroutine zfft1di !}}}
subroutine zfft1d(dir,n,a,stride,workfft) ! {{{
! converts the sgi calls to dxml calls' implements non normalized FFT'      
integer dir
integer*8 plan
character*1 ty
complex(8) workfft(0:n-1)
complex*16 a(0:n-1) !,b(1:n)
INTEGER,PARAMETER:: FFTW_ESTIMATE=64
INTEGER,PARAMETER:: FFTW_MEASURE=0
integer*4 nn(1),HOWMANY,IDIST,ODIST,SIGN
integer*4 ISTRIDE,OSTRIDE
integer*4 inembed(1),onembed(1)		
nn(1)=n
inembed(1)=n
onembed(1)=n
HOWMANY=1;IDIST=1;ODIST=1
ISTRIDE=1;OSTRIDE=1
CALL DFFTW_PLAN_MANY_DFT(plan,1,nn, HOWMANY,a, 		&
 			inembed, ISTRIDE, IDIST,a,onembed, 		&
 			OSTRIDE, ODIST, dir, FFTW_ESTIMATE)
call dfftw_execute(plan)
call dfftw_destroy_plan(plan)       
return 
end subroutine zfft1d !}}}
subroutine zfft2di(n,m,workfft) !{{{
complex*16 workfft(n)
return
end subroutine zfft2di ! }}}
subroutine zfft2d(dir,n1,n2,a,lda,workfft) ! {{{
! converts the sgi calls to fftw calls on Mac OSX
!      include'dxmldef.for'   
      INTEGER,PARAMETER:: FFTW_ESTIMATE=64
      INTEGER,PARAMETER:: FFTW_MEASURE=0

      integer*4 dir,status,dim,SIGN
      integer*4 nn(2),HOWMANY,IDIST,ODIST
      integer*4 ISTRIDE,OSTRIDE
      integer*4 inembed(2),onembed(2)
       integer*8 plan
      character*1 tyc
      complex*16,intent(inout):: a(0:lda-1,0:lda-1)
      complex*16 workfft(n1)
      complex(8), allocatable::work(:,:)
nn(1)=n1
nn(2)=n2
SIGN=dir
HOWMANY=1;IDIST=1;ODIST=1
ISTRIDE=1;OSTRIDE=1

inembed(1)=lda;onembed(1)=lda
inembed(2)=lda;onembed(2)=lda
if(n1.gt.lda.or.n2.gt.lda)then
	write(16,*) "dim of work vector too small, sorry"
	stop       "************* BYE *****************"
end if

allocate(work(lda,lda))
work(1:lda,1:lda)=a(0:lda-1,0:lda-1)
  !DFFTW_PLAN_MANY_DFT(PLAN, RANK, N, HOWMANY, IN, INEMBED, ISTRIDE, IDIST, 
  !						OUT, ONEMBED, OSTRIDE, ODIST, SIGN, FLAGS)
  !CALL DFFTW_PLAN_MANY_DFT(plan,2,nn, HOWMANY,work,inembed, ISTRIDE, IDIST,		& 
  !					work,onembed, OSTRIDE, ODIST, SIGN, FFTW_ESSTIMATE)
  CALL DFFTW_PLAN_MANY_DFT(plan,2,nn, HOWMANY,a, 		&
        			inembed, ISTRIDE, IDIST,a,onembed, &
        			OSTRIDE, ODIST, SIGN, FFTW_ESTIMATE)
 !!! call dfftw_plan_dft_2d(plan,n1,n2,a(0:n1-1,0:n2-1),a(0:n1-1,0:n2-1),(-1)*dir,FFTW_ESTIMATE)
       call dfftw_execute(plan)
       call dfftw_destroy_plan(plan) 	
!a(0:lda-1,0:lda-1)=work(1:lda,1:lda)/sqrt(1.d0*n1*n2)   
!!a=a/sqrt(1.d0*n1*n2)
      return
      end subroutine zfft2d ! }}}
