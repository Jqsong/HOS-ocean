MODULE reconstruction
!
! This module contains different routines to reconstruct the wavefield
! It uses the modal description of volumic quantities generated by HOS-ocean
!
! Key module for possible coupling using SWENSE method or for output of volumic field
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!    Copyright (C) 2014 - LHEEA Lab., Ecole Centrale de Nantes, UMR CNRS 6598
!
!    This program is part of HOS-ocean
!
!    HOS-ocean is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    This program is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with this program.  If not, see <http://www.gnu.org/licenses/>.
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
USE type
USE variables_3d
USE fourier_r2c
USE read_files
!
CONTAINS
!
SUBROUTINE recons_HOS_init(filename,i_unit,n1,n2,dt_out_star,T_stop_star,xlen_star,ylen_star,depth_star,g_star,L,T, &
	modesspecx,modesspecy,modesspecz,modesspect,modesFS,modesFSt)
!
IMPLICIT NONE
!
CHARACTER(LEN=*), INTENT(IN) :: filename
INTEGER, INTENT(IN)          :: i_unit
!
! Local variables
INTEGER  :: n1,n2, n1o2p1
REAL(RP), INTENT(OUT) :: dt_out_star,T_stop_star,xlen_star,ylen_star,depth_star,g_star,L,T
!
COMPLEX(CP), ALLOCATABLE, DIMENSION(:,:), INTENT(OUT) :: modesspecx,modesspecy,modesspecz,modesspect,modesFS,modesFSt
!
! Initialize variables reading filename
! In the file, everything is non-dimensional with L and T length and time scales
CALL init_read_mod(filename,i_unit,n1,n2,dt_out_star,T_stop_star,xlen_star,ylen_star,depth_star,g_star,L,T)
!
n1o2p1 = n1/2+1
!
ALLOCATE(modesspecx(n1o2p1,n2),modesspecy(n1o2p1,n2),modesspecz(n1o2p1,n2),modesspect(n1o2p1,n2),modesFS(n1o2p1,n2), &
     modesFSt(n1o2p1,n2))
!
! Read time=0
CALL read_mod(filename,i_unit,0.0_rp,dt_out_star,n1o2p1,n2,modesspecx,modesspecy,modesspecz,modesspect,modesFS,modesFSt)
!
END SUBROUTINE recons_HOS_init
!
!
!
SUBROUTINE reconstruction_FFTs(modesspecx,modesspecy,modesspecz,modesspect,modesFS,&
	imin,imax,jmin,jmax,zlocal,depth_star,vitx,vity,vitz,phit,dudt,dvdt,dwdt)
!
! This subroutine reconstructs from modal description all fields necessary for possible coupling using SWENSE method
! or for output of volumic field
! This uses FFTs and consequently can not be used with boundary fitted coordinates
!
IMPLICIT NONE
!% INPUT VARIABLES
COMPLEX(CP), DIMENSION(m1o2p1,m2), INTENT(IN) :: modesspecx,modesspecy,modesspecz,modesspect,modesFS
INTEGER, INTENT(IN) 						  :: imin, imax, jmin, jmax
REAL(RP)      								  :: zlocal, depth_star
COMPLEX(CP) :: coeff, coeff2
REAL(RP)    :: k_n2
INTEGER     :: i1,i2
! Test with FFTs
COMPLEX(CP), DIMENSION(m1o2p1,m2) :: a_vitx, a_vity, a_vitz, a_phit, a_dudt, a_dvdt, a_dwdt
REAL(RP), DIMENSION(m1,m2)        :: vitx_tmp, vity_tmp, vitz_tmp, phit_tmp, eta_tmp, dudt_tmp, dvdt_tmp, dwdt_tmp
!
REAL(RP), DIMENSION(imax-imin+1,jmax-jmin+1), INTENT(OUT) :: vitx,vity,vitz,phit,dudt,dvdt,dwdt
!
! Reconstruction par FFTs... plus efficace?!
!
!
! Constant mode
i1=1
i2=1
a_vitx(i1,i2) = modesspecx(i1,i2)
a_vity(i1,i2) = modesspecy(i1,i2)
a_vitz(i1,i2) = modesspecz(i1,i2)
a_phit(i1,i2) = modesspect(i1,i2)
a_dudt(i1,i2) = ikx(i1,i2)*modesspect(i1,i2)
a_dvdt(i1,i2) = iky(i1,i2)*modesspect(i1,i2)
a_dwdt(i1,i2) = kth(i1,i2)*modesspect(i1,i2)
!
i1=1
DO i2=2,n2
	k_n2 = SQRT(kx(i1)**2+ky_n2(i2)**2)
	IF ((k_n2*(zlocal+depth_star).LT.50.).AND.(k_n2*depth_star.LT.50.)) THEN
		coeff = COSH(k_n2*(zlocal+depth_star))/COSH(k_n2*depth_star)
		coeff2= SINH(k_n2*(zlocal+depth_star))/SINH(k_n2*depth_star)
	ELSE
		coeff = EXP(k_n2*zlocal)
		coeff2= coeff
	ENDIF
	a_vitx(i1,i2) = modesspecx(i1,i2)*coeff
	a_vity(i1,i2) = modesspecy(i1,i2)*coeff
	a_vitz(i1,i2) = modesspecz(i1,i2)*coeff2
	a_phit(i1,i2) = modesspect(i1,i2)*coeff
	a_dudt(i1,i2) = ikx(i1,i2)*a_phit(i1,i2)
	a_dvdt(i1,i2) = iky(i1,i2)*a_phit(i1,i2)
	a_dwdt(i1,i2) = kth(i1,i2)*modesspect(i1,i2)*coeff2
ENDDO
!
DO i1=2,n1o2p1
	DO i2=1,n2
		k_n2 = SQRT(kx(i1)**2+ky_n2(i2)**2)
		IF ((k_n2*(zlocal+depth_star).LT.50.).AND.(k_n2*depth_star.LT.50.)) THEN
			coeff = COSH(k_n2*(zlocal+depth_star))/COSH(k_n2*depth_star)
			coeff2= SINH(k_n2*(zlocal+depth_star))/SINH(k_n2*depth_star)
		ELSE
			coeff = EXP(k_n2*zlocal)
			coeff2= coeff
		ENDIF
		a_vitx(i1,i2) = modesspecx(i1,i2)*coeff
		a_vity(i1,i2) = modesspecy(i1,i2)*coeff
		a_vitz(i1,i2) = modesspecz(i1,i2)*coeff2
		a_phit(i1,i2) = modesspect(i1,i2)*coeff
		a_dudt(i1,i2) = ikx(i1,i2)*a_phit(i1,i2)
		a_dvdt(i1,i2) = iky(i1,i2)*a_phit(i1,i2)
		a_dwdt(i1,i2) = kth(i1,i2)*modesspect(i1,i2)*coeff2
	ENDDO
ENDDO
! Inverse FFTs
CALL fourier_2_space(a_vitx, vitx_tmp)
IF (n2.NE.1) THEN
	CALL fourier_2_space(a_vity, vity_tmp)
	CALL fourier_2_space(a_dvdt, dvdt_tmp)
ELSE
	vity_tmp=0.0_rp
	dvdt_tmp=0.0_rp
ENDIF
CALL fourier_2_space(a_vitz, vitz_tmp)
CALL fourier_2_space(a_phit, phit_tmp)
CALL fourier_2_space(a_dudt, dudt_tmp)
CALL fourier_2_space(a_dwdt, dwdt_tmp)
!
! For outputs
CALL fourier_2_space(modesFS, eta_tmp)
!
! Outputs
DO i2=jmin,jmax
	DO i1=imin,imax
		IF((zlocal).GT.eta_tmp(i1-imin+1,i2-jmin+1)) THEN
			vitx(i1-imin+1,i2-jmin+1) = 0.0_rp
			vity(i1-imin+1,i2-jmin+1) = 0.0_rp
			vitz(i1-imin+1,i2-jmin+1) = 0.0_rp
			phit(i1-imin+1,i2-jmin+1) = 0.0_rp
			dudt(i1-imin+1,i2-jmin+1) = 0.0_rp
			dvdt(i1-imin+1,i2-jmin+1) = 0.0_rp
			dwdt(i1-imin+1,i2-jmin+1) = 0.0_rp
		ELSE
			vitx(i1-imin+1,i2-jmin+1) = vitx_tmp(i1,i2)
			vity(i1-imin+1,i2-jmin+1) = vity_tmp(i1,i2)
			vitz(i1-imin+1,i2-jmin+1) = vitz_tmp(i1,i2)
			phit(i1-imin+1,i2-jmin+1) = phit_tmp(i1,i2)
			dudt(i1-imin+1,i2-jmin+1) = dudt_tmp(i1,i2)
			dvdt(i1-imin+1,i2-jmin+1) = dvdt_tmp(i1,i2)
			dwdt(i1-imin+1,i2-jmin+1) = dwdt_tmp(i1,i2)
		ENDIF
	ENDDO
ENDDO
!
END SUBROUTINE reconstruction_FFTs
!
!
!
SUBROUTINE reconstruction_direct(modesspecx,modesspecy,modesspecz,modesspect,modesFS,&
	imin,imax,jmin,jmax,zmin,ii3,i_zvect,depth_star,vitx,vity,vitz,phit,dudt,dvdt,dwdt,zvect)
!
! This subroutine reconstructs from modal description all fields necessary for possible coupling using SWENSE method
! or for output of volumic field
! This uses direct method and consequently must be used with boundary fitted coordinates
!
IMPLICIT NONE
!% INPUT VARIABLES
COMPLEX(CP), DIMENSION(m1o2p1,m2), INTENT(IN) :: modesspecx,modesspecy,modesspecz,modesspect,modesFS
INTEGER, INTENT(IN) 						  :: imin, imax, jmin, jmax, ii3, i_zvect
REAL(RP)      								  :: zmin, depth_star
!
REAL(RP), DIMENSION(imax-imin+1,jmax-jmin+1), INTENT(OUT)  :: vitx,vity,vitz,phit,dudt,dvdt,dwdt,zvect
!
REAL(RP) , DIMENSION(imax-imin+1) :: xvect
REAL(RP) , DIMENSION(jmax-jmin+1) :: yvect

COMPLEX(CP) :: vitx_l, vity_l, vitz_l, phit_l, dudt_l, dvdt_l, dwdt_l
COMPLEX(CP) :: coeff, coeff2
REAL(RP) :: k_n2
INTEGER :: i1,i2,ii1,ii2
!
REAL(RP), DIMENSION(m1o2p1,m2) :: anglex, angley, anglez, anglet, angleut, anglevt, anglewt
REAL(RP), DIMENSION(m1,m2)     :: eta_tmp
!
! Methode directe
!
! For outputs
CALL fourier_2_space(modesFS, eta_tmp)
!
! Regular spacing between zmin and eta
!
do ii1=1,imax-imin+1
	do ii2=1,jmax-jmin+1
		xvect(ii1) = x(ii1+imin-1)
		yvect(ii2) = y(ii2+jmin-1)
		! Linear description of zvect
		!zvect(ii1,ii2)=zmin+(-zmin+eta_tmp(ii1+imin-1,ii2+jmin-1))*REAL(ii3-1,RP)/REAL(i_zvect-1,RP)
		! Stretched grid of zvect
		zvect(ii1,ii2)=zmin+(-zmin+eta_tmp(ii1+imin-1,ii2+jmin-1))*SIN(pio2*REAL(ii3-1,RP)/REAL(i_zvect-1,RP))
	enddo
enddo
!
! Store some data
!
DO i1=1,n1o2p1
    DO i2=1,n2
        anglex(i1,i2)  = ATAN2(AIMAG(modesspecx(i1,i2)),REAL(modesspecx(i1,i2),RP))
        angley(i1,i2)  = ATAN2(AIMAG(modesspecy(i1,i2)),REAL(modesspecy(i1,i2),RP))
        anglez(i1,i2)  = ATAN2(AIMAG(modesspecz(i1,i2)),REAL(modesspecz(i1,i2),RP))
        anglet(i1,i2)  = ATAN2(AIMAG(modesspect(i1,i2)),REAL(modesspect(i1,i2),RP))
        angleut(i1,i2) = ATAN2(AIMAG(ikx(i1,i2)*modesspect(i1,i2)),REAL(ikx(i1,i2)*modesspect(i1,i2),RP))
        anglevt(i1,i2) = ATAN2(AIMAG(iky(i1,i2)*modesspect(i1,i2)),REAL(iky(i1,i2)*modesspect(i1,i2),RP))
        anglewt(i1,i2) = ATAN2(AIMAG(kth(i1,i2)*modesspect(i1,i2)),REAL(kth(i1,i2)*modesspect(i1,i2),RP))
    ENDDO
ENDDO
!
DO ii1 = 1, imax-imin+1
    DO ii2 = 1, jmax-jmin+1
		! constant mode
		i1 = 1
		i2 = 1
		!
		vitx(ii1,ii2) = REAL(modesspecx(i1,i2),RP)
		vity(ii1,ii2) = REAL(modesspecy(i1,i2),RP)
		vitz(ii1,ii2) = REAL(modesspecz(i1,i2),RP)
		phit(ii1,ii2) = REAL(modesspect(i1,i2),RP)
		dudt(ii1,ii2) = REAL(ikx(i1,i2)*modesspect(i1,i2),RP)
		dvdt(ii1,ii2) = REAL(iky(i1,i2)*modesspect(i1,i2),RP)
		dwdt(ii1,ii2) = REAL(kth(i1,i2)*modesspect(i1,i2),RP)
		! i1=1 and all i2
		DO i2=2,n2o2p1
			k_n2 = SQRT(kx(i1)**2+ky_n2(i2)**2)
			IF ((k_n2*(zvect(ii1,ii2)+depth_star).LT.50.).AND.(k_n2*depth_star.LT.50.)) THEN
				coeff = COSH(k_n2*(zvect(ii1,ii2)+depth_star))/COSH(k_n2*depth_star) !* EXP(i*ky_n2(i2)*y(ii2))
				coeff2= SINH(k_n2*(zvect(ii1,ii2)+depth_star))/SINH(k_n2*depth_star) !* EXP(i*ky_n2(i2)*y(ii2))
			ELSE
				coeff = EXP(k_n2*zvect(ii1,ii2))
				coeff2= coeff
			ENDIF
			vitx(ii1,ii2) = vitx(ii1,ii2) + 2.0_rp*ABS(modesspecx(i1,i2) * coeff) *COS(ky_n2(i2)*yvect(ii2)+anglex(i1,i2))
			vity(ii1,ii2) = vity(ii1,ii2) + 2.0_rp*ABS(modesspecy(i1,i2) * coeff) *COS(ky_n2(i2)*yvect(ii2)+angley(i1,i2))
			vitz(ii1,ii2) = vitz(ii1,ii2) + 2.0_rp*ABS(modesspecz(i1,i2) * coeff2)*COS(ky_n2(i2)*yvect(ii2)+anglez(i1,i2))
			phit(ii1,ii2) = phit(ii1,ii2) + 2.0_rp*ABS(modesspect(i1,i2) * coeff) *COS(ky_n2(i2)*yvect(ii2)+anglet(i1,i2))
			dudt(ii1,ii2) = dudt(ii1,ii2) + 2.0_rp*ABS(ikx(i1,i2)*modesspect(i1,i2) * coeff) &
				*COS(ky_n2(i2)*yvect(ii2)+angleut(i1,i2))
			dvdt(ii1,ii2) = dvdt(ii1,ii2) + 2.0_rp*ABS(iky(i1,i2)*modesspect(i1,i2) * coeff) &
				*COS(ky_n2(i2)*yvect(ii2)+anglevt(i1,i2))
			dwdt(ii1,ii2) = dwdt(ii1,ii2) + 2.0_rp*ABS(kth(i1,i2)*modesspect(i1,i2) * coeff2) &
				*COS(ky_n2(i2)*yvect(ii2)+anglewt(i1,i2))
		ENDDO
		! FIXME: add the case n2 even
		IF (iseven(n2)) THEN
			i1=1
			i2=n2o2p1
			vitx(ii1,ii2) = vitx(ii1,ii2) - 1.0_rp*ABS(modesspecx(i1,i2) * coeff) *COS(ky_n2(i2)*yvect(ii2)+anglex(i1,i2))
			vity(ii1,ii2) = vity(ii1,ii2) - 1.0_rp*ABS(modesspecy(i1,i2) * coeff) *COS(ky_n2(i2)*yvect(ii2)+angley(i1,i2))
			vitz(ii1,ii2) = vitz(ii1,ii2) - 1.0_rp*ABS(modesspecz(i1,i2) * coeff2)*COS(ky_n2(i2)*yvect(ii2)+anglez(i1,i2))
			phit(ii1,ii2) = phit(ii1,ii2) - 1.0_rp*ABS(modesspect(i1,i2) * coeff) *COS(ky_n2(i2)*yvect(ii2)+anglet(i1,i2))
			dudt(ii1,ii2) = dudt(ii1,ii2) - 1.0_rp*ABS(ikx(i1,i2)*modesspect(i1,i2) * coeff) &
				*COS(ky_n2(i2)*yvect(ii2)+angleut(i1,i2))
			dvdt(ii1,ii2) = dvdt(ii1,ii2) - 1.0_rp*ABS(iky(i1,i2)*modesspect(i1,i2) * coeff) &
				*COS(ky_n2(i2)*yvect(ii2)+anglevt(i1,i2))
			dwdt(ii1,ii2) = dwdt(ii1,ii2) - 1.0_rp*ABS(kth(i1,i2)*modesspect(i1,i2) * coeff2) &
				*COS(ky_n2(i2)*yvect(ii2)+anglewt(i1,i2))
		ENDIF
		! i2 and i1 =/ 1
		DO i1=2,n1o2p1
			DO i2=1,n2
				k_n2 = SQRT(kx(i1)**2+ky_n2(i2)**2)
				IF ((k_n2*(zvect(ii1,ii2)+depth_star).LT.50.).AND.(k_n2*depth_star.LT.50.)) THEN
					coeff = COSH(k_n2*(zvect(ii1,ii2)+depth_star))/COSH(k_n2*depth_star) * EXP(i*ky_n2(i2)*yvect(ii2))
					coeff2= SINH(k_n2*(zvect(ii1,ii2)+depth_star))/SINH(k_n2*depth_star) * EXP(i*ky_n2(i2)*yvect(ii2))
				ELSE
					coeff = EXP(k_n2*zvect(ii1,ii2)) * EXP(i*ky_n2(i2)*yvect(ii2))
					coeff2= coeff
				ENDIF
				!
				vitx_l = modesspecx(i1,i2) * coeff
				vity_l = modesspecy(i1,i2) * coeff
				vitz_l = modesspecz(i1,i2) * coeff2
				phit_l = modesspect(i1,i2) * coeff
				dudt_l = ikx(i1,i2)*phit_l
				dvdt_l = iky(i1,i2)*phit_l
				dwdt_l = kth(i1,i2)*modesspect(i1,i2) * coeff2
				!
				vitx(ii1,ii2) = vitx(ii1,ii2) + 1.0_rp*ABS(vitx_l)*COS(kx(i1)*xvect(ii1)+ATAN2(AIMAG(vitx_l),REAL(vitx_l,RP)))
				vity(ii1,ii2) = vity(ii1,ii2) + 1.0_rp*ABS(vity_l)*COS(kx(i1)*xvect(ii1)+ATAN2(AIMAG(vity_l),REAL(vity_l,RP)))
				vitz(ii1,ii2) = vitz(ii1,ii2) + 1.0_rp*ABS(vitz_l)*COS(kx(i1)*xvect(ii1)+ATAN2(AIMAG(vitz_l),REAL(vitz_l,RP)))
				phit(ii1,ii2) = phit(ii1,ii2) + 1.0_rp*ABS(phit_l)*COS(kx(i1)*xvect(ii1)+ATAN2(AIMAG(phit_l),REAL(phit_l,RP)))
				dudt(ii1,ii2) = dudt(ii1,ii2) + 1.0_rp*ABS(dudt_l)*COS(kx(i1)*xvect(ii1)+ATAN2(AIMAG(dudt_l),REAL(dudt_l,RP)))
				dvdt(ii1,ii2) = dudt(ii1,ii2) + 1.0_rp*ABS(dvdt_l)*COS(kx(i1)*xvect(ii1)+ATAN2(AIMAG(dvdt_l),REAL(dvdt_l,RP)))
				dwdt(ii1,ii2) = dwdt(ii1,ii2) + 1.0_rp*ABS(dwdt_l)*COS(kx(i1)*xvect(ii1)+ATAN2(AIMAG(dwdt_l),REAL(dwdt_l,RP)))
			ENDDO
		ENDDO
    ENDDO
ENDDO
!
END SUBROUTINE reconstruction_direct
!
!
!
SUBROUTINE build_mesh_global(xlen_star,ylen_star,depth_star,n1,n2,x,y,kx,ky_n2,ikx,iky,kth)
!
IMPLICIT NONE
!
REAL(RP), INTENT(IN) :: xlen_star, ylen_star,depth_star
INTEGER, INTENT(IN)  :: n1, n2
!
REAL(RP), DIMENSION(n1), INTENT(OUT)           :: x
REAL(RP), DIMENSION(n1o2p1), INTENT(OUT)       :: kx
REAL(RP), DIMENSION(n2), INTENT(OUT)           :: y, ky_n2
REAL(RP), DIMENSION(n1o2p1,n2), INTENT(OUT)    :: kth
COMPLEX(CP), DIMENSION(n1o2p1,n2), INTENT(OUT) :: ikx, iky
! Local variables
REAL(RP) :: pioxlen, pioylen, delx, dely, k2
INTEGER  :: n1o2p1,n2o2p1,Nd1o2p1,Nd2o2p1, N_der(2)
INTEGER  :: i1,i2
!
! Specify temporary number of points
n1o2p1   = n1/2+1
n2o2p1   = n2/2+1
Nd1o2p1  = n1o2p1
Nd2o2p1  = n2o2p1
N_der(1) = n1o2p1
N_der(2) = n2o2p1
!
! Specify length of domain
!
pioxlen = TWOPI / xlen_star
!
IF (n2 == 1) THEN
   pioylen = 0.0_rp
ELSE
   pioylen = TWOPI / ylen_star
END IF
!
!   mesh generation
!
delx = xlen_star / n1
DO i1 = 1,n1
	x(i1) = (i1 - 1) * delx
END DO
!
IF (n2 == 1) THEN
   dely = 0.0_rp
ELSE
   dely = ylen_star / n2
END IF
DO i2 = 1,n2
	y(i2) = (i2 - 1) * dely
END DO
!
!	wave numbers
DO i1 = 1, Nd1o2p1
	kx(i1)  = REAL(i1 - 1,RP) * pioxlen
END DO
!  y-wave numbers (on n2 modes)
DO i2 = 1, n2o2p1
   ky_n2(i2) = REAL(i2 - 1,RP) * pioylen
ENDDO
DO i2 = 2,n2o2p1
   ky_n2(n2-i2+2) = - REAL(i2 - 1,RP) * pioylen
END DO
!
IF (iseven(n2)) ky_n2(n2o2p1) = REAL(n2o2p1 - 1,RP) * pioylen
! Storage for derivatives
ikx = 0.0_cp
!  x-derivative on n1 points (i.e. n1o2p1 modes)
DO i2 = 1, n2o2p1
   ikx(1:MIN(N_der(1),n1o2p1),i2) = i * kx(1:MIN(N_der(1),n1o2p1))
END DO
! Last mode contains cos information only and must not be part of the differentiation.
IF (iseven(n1)) ikx(n1o2p1,:) = 0.0_cp
! negative ky
DO i2 = 2, n2o2p1
   ikx(1:MIN(N_der(1),n1o2p1),n2-i2+2) = i * kx(1:MIN(N_der(1),n1o2p1))
END DO
!
iky = 0.0_cp
! y-derivative on n1 points (i.e. n1o2p1 modes)
DO i1 = 1, n1o2p1
   iky(i1,1:MIN(N_der(2),n2o2p1)) = i * ky_n2(1:MIN(N_der(2),n2o2p1))
   ! negative ky
   DO i2 = 2, MIN(N_der(2), n2o2p1)
      iky(i1,n2-i2+2) = - i * ky_n2(i2)
   END DO
   IF (iseven(n2) .AND. N_der(2)>=n2o2p1) iky(i1,n2o2p1) = 0.0_cp
END DO
!
! HOS modal coefficients of the vertical derivatives
DO i2 = 1, n2
   DO i1 = 1, n1o2p1
	  k2         = kx(i1) * kx(i1) + ky_n2(i2) * ky_n2(i2)
	  kth(i1,i2) = SQRT(k2)*TANH(SQRT(k2) * depth_star)
   END DO
END DO
!
END SUBROUTINE build_mesh_global
!
!
!
SUBROUTINE build_mesh_local(x_min,x_max,y_min,y_max,z_min,z_max,xlen_star,ylen_star,L,n1,n2,nz,&
	xvect,yvect,zvect,imin,imax,jmin,jmax)
!
IMPLICIT NONE
!
REAL(RP), INTENT(IN)                  :: x_min,x_max,y_min,y_max,z_min,z_max,xlen_star,ylen_star,L
INTEGER, INTENT(IN)                   :: n1,n2,nz
!
REAL(RP), ALLOCATABLE, DIMENSION(:), INTENT(OUT)   :: xvect, yvect, zvect
INTEGER, INTENT(OUT)                               :: imin,imax,jmin,jmax
!
! Local variables
REAL(RP) :: delx, dely
INTEGER  :: i_xvect,i_yvect,i_zvect,i1,i2
!
delx = xlen_star / n1
!
IF (n2 == 1) THEN
   dely = 0.0_rp
ELSE
   dely = ylen_star / n2
END IF
!
imin = FLOOR(x_min/L/delx) + 1
imax = CEILING(x_max/L/delx) + 1
if(n2.NE.1) then
	jmin = FLOOR(y_min/L/dely) + 1
	jmax = CEILING(y_max/L/dely) + 1
else
	jmin = 1
	jmax = 1
endif
i_xvect = imax-imin+1
i_yvect = jmax-jmin+1
i_zvect = nz !FIXME: what do I have to choose.
!
ALLOCATE(xvect(i_xvect), yvect(i_yvect), zvect(i_zvect))
!
DO i1 = 1, i_xvect
	xvect(i1) = x(i1+imin-1)
ENDDO
DO i2 = 1, i_yvect
	yvect(i2) = y(i2+jmin-1)
ENDDO
!
! Define zvect
DO i1 = 1, i_zvect/2
	zvect(i1) = z_min/L+(i1-1)*(-z_min-z_max)/(L*(i_zvect/2-1)) !FIXME: in which zone does it need refinement?
ENDDO
DO i1 = i_zvect/2+1, i_zvect
	zvect(i1) = zvect(i_zvect/2)+(i1-(i_zvect/2+1)+1)*2.0_rp*z_max/(L*(i_zvect-(i_zvect/2+1)+1))
ENDDO
!
END SUBROUTINE build_mesh_local
!
!
!
SUBROUTINE check_sizes(n2,x_min,x_max,y_min,y_max,z_min,t_min,t_max,xlen_star,ylen_star,depth_star,T_stop_star,L,T)
!
! Test the domain size and time window
!
IMPLICIT NONE
!
INTEGER, INTENT(IN)  :: n2
REAL(RP), INTENT(IN) :: x_min,x_max,y_min,y_max,z_min,t_min,t_max,xlen_star,ylen_star,depth_star,T_stop_star,L,T
REAL(RP)             :: tiny_sp
!
! tiny_sp is single precision: useful for inequalities check with values read from files
tiny_sp = epsilon(1.0)
!
IF(x_max.GT.(xlen_star+tiny_sp)*L) THEN
	WRITE(*,*) 'Warning, length of HOS-ocean domain exceeded'
	WRITE(*,*) 'xmax =',x_max,'xlen =',xlen_star*L
	STOP
ENDIF
IF(x_min.LT.(-tiny_sp)) then
	WRITE(*,*) 'Warning, negative x location'
	WRITE(*,*) 'xmin =',x_min
	STOP
ENDIF
IF(n2 /= 1) then
   IF(y_max.GT.(ylen_star+tiny_sp)*L) then
      WRITE(*,*) 'Warning, length of HOS-ocean domain exceeded'
      WRITE(*,*) 'ymax =',y_max,'ylen =',ylen_star*L
      STOP
   ENDIF
   IF(y_min.LT.(-tiny_sp)) then
      WRITE(*,*) 'Warning, negative y location'
      WRITE(*,*) 'ymin =',y_min
      STOP
   ENDIF
ENDIF
IF(t_max.GT.(T_stop_star+tiny_sp)*T) THEN
	WRITE(*,*) 'Warning, duration of HOS-ocean simulation exceeded'
	WRITE(*,*) 'tmax =',t_max,'T_stop =',T_stop_star*T
	STOP
ENDIF
IF(t_min.LT.(-tiny_sp)) then
	WRITE(*,*) 'Warning, negative starting time'
	WRITE(*,*) 'tmin =',t_min
	STOP
ENDIF
IF(z_min.LT.(-depth_star-tiny_sp)*L) then
	WRITE(*,*) 'Warning, |z_min| is greater than water depth'
	WRITE(*,*) 'zmin =',z_min
	STOP
ENDIF
!
END SUBROUTINE check_sizes
!
END MODULE reconstruction