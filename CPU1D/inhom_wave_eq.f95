! To run the program : gfortran -w -I/usr/local/include -L/usr/local/lib <filename.f95> -lfftw3 -lm; ./a.out
! It uses Runge-Kutta-4 Solver
program inhomogeneous_wave_equation
implicit none

include "fftw3.f"

integer ( kind = 4 ), parameter :: N = 64
integer ( kind = 4 ), parameter :: Nh = N/2+1
real ( kind = 8 ), parameter :: pi=3.14159265358979323846d0
	
DOUBLE PRECISION :: x,u,a,du_dt,d2u_dt2
DIMENSION x(N),u(N),a(N),du_dt(N),d2u_dt2(N)

integer ( kind = 8 ) :: planf, planb

integer ( kind = 4) i,t
REAL ( kind = 8 ) :: time, time_min, time_max, dt, dx, L, k, sum, delta, sigma, mu

COMMON/comm/L, dx, dt, delta, sigma, mu

!===================== USER INPUTS ============================================		
L = 2.0d0*pi
dx = L/dfloat(N)

time_min = 0.00d0
time_max = 100.00d0
dt = 0.010d0

k = 1.0d0

delta = 0.001d0

sigma = 1.0d0

mu = 0.0d0

do i=1,N
  x(i) = dfloat(i-1) * dx
  u(i) = DSIN(k*x(i))
  a(i) = -k * DCOS(k*x(i))
  write (100,*) 0, x(i), u(i)
enddo

!==================== MAIN PROGRAM ============================================

DO time = time_min, time_max, dt

sum = 0.0d0
   
t = nint(time/dt) - int(time_min/dt)

!Calculating the time evolution in real-space...
	
CALL derive(N, Nh, pi, time, u, a, du_dt, d2u_dt2)
CALL rk4(N, Nh, pi, time, u, a, du_dt, d2u_dt2)

IF ( t /= 0 .and. MOD(t,100) == 0 ) THEN
   DO i = 1, N
    !WRITE (t+100,*) t, x(i),u(i),a(i)
  enddo
endif

IF ( MOD(t,1) == 0 ) THEN
  DO i = 1, N
    sum = sum + u(i) * u(i) / dfloat(N)  
  ENDDO
  WRITE(10,*) time, sum
ENDIF

enddo ! time

contains
!===================================================================================

SUBROUTINE derive(N, Nh, pi, time, u, a, du_dt, d2u_dt2)

implicit none

INTEGER ( kind = 4 ) N, Nh, i
REAL ( kind = 8 ) pi, time, dt, dx, L, k, URn_1, URn_2, GRn, delta, sigma, mu
REAL ( kind = 8 ) u(N), u_dum(N), d2u_dx2(N), du_dt(N), a(N), d2u_dt2(N)
complex ( kind = 8 )  uk(Nh), k2_uk(Nh)

common/comm/L, dx, dt, delta, sigma, mu

integer,parameter :: seed = 99999999
CALL srand(seed)

do i = 1, N
  u_dum(i) = u(i)
enddo

call dfftw_plan_dft_r2c_1d_(planf, N, u_dum, uk, FFTW_ESTIMATE)
call dfftw_execute_(planf)
call dfftw_destroy_plan_(planf)

do i = 1, Nh
   k = 2.0d0 * pi * dfloat(i-1) / L
   k2_uk(i) = k * k * uk(i)   
enddo

call dfftw_plan_dft_c2r_1d_(planb, N, k2_uk, d2u_dx2, FFTW_ESTIMATE)
call dfftw_execute_(planb)
call dfftw_destroy_plan_(planb)

do i = 1, N
  d2u_dx2(i) = d2u_dx2(i) / dfloat(N)
enddo
  
DO i = 1, N
  URn_1 = rand()
  URn_2 = rand()
  GRn = DSQRT(-2.0d0*DLOG(URn_1)) * DCOS(2.0d0*pi*URn_2) * sigma + mu
  du_dt(i) = a(i) 
  d2u_dt2(i) = - (1.0d0 + delta * GRn) * d2u_dx2(i)
enddo

return
end 

!====================================================================================

SUBROUTINE rk4(N, Nh, pi, time, u, a, du_dt, d2u_dt2)
implicit none

INTEGER ( kind = 4 ) N, Nh, i
REAL ( kind = 8 ) pi, time, dt, dx, L, delta, sigma, mu
REAL ( kind = 8 ) u(N),du_dt(N),k1_u(N),k2_u(N),k3_u(N),k4_u(N),dum_u(N)
REAL ( kind = 8 ) a(N),d2u_dt2(N),k1_a(N),k2_a(N),k3_a(N),k4_a(N),dum_a(N)


common/comm/L, dx, dt, delta, sigma, mu

do i = 1, N
  k1_u(i) = du_dt(i)
  dum_u(i) = u(i) + k1_u(i) * dt / 2.0d0
enddo

do i = 1, N
  k1_a(i) = d2u_dt2(i)
  dum_a(i) = a(i) + k1_a(i) * dt / 2.0d0
enddo

CALL derive(N, Nh, pi, time+dt/2.0d0, dum_u, dum_a, du_dt, d2u_dt2)

do i = 1, N
  k2_u(i) = du_dt(i)
  dum_u(i) = u(i) + k2_u(i) * dt/2.0d0
enddo

do i = 1, N
  k2_a(i) = d2u_dt2(i)
  dum_a(i) = a(i) + k2_a(i) * dt/2.0d0
enddo

CALL derive(N, Nh, pi, time+dt/2.0d0, dum_u, dum_a, du_dt, d2u_dt2)

do i = 1, N
  k3_u(i) = du_dt(i)
  dum_u(i) = u(i) + k3_u(i) * dt
enddo

do i = 1, N
  k3_a(i) = d2u_dt2(i)
  dum_a(i) = a(i) + k3_a(i) * dt
enddo

CALL derive(N, Nh, pi, time+dt, dum_u, dum_a, du_dt, d2u_dt2)

do i = 1, N
  k4_u(i) = du_dt(i)
  u(i) = u(i) + dt/6.0d0*(k1_u(i) + 2.0d0*k2_u(i) + 2.0d0*k3_u(i) + k4_u(i))
enddo

do i = 1, N
  k4_a(i) = d2u_dt2(i)
  a(i) = a(i) + dt/6.0d0*(k1_a(i) + 2.0d0*k2_a(i) + 2.0d0*k3_a(i) + k4_a(i))
enddo

RETURN
end subroutine rk4

!==================================================================================

end program inhomogeneous_wave_equation
