C     Going to need some dependency on a fortran compiler... Maybe this:
C
C     $ conda install -c conda-forge fortran-compiler
C
      subroutine nmep(forecast, radius, thresh, probs, nmem, ny, nx)

        integer nmem
        integer ny
        integer nx
        real forecast(nmem, ny, nx)
        real radius
        real thresh
        real probs(ny, nx)

Cf2py intent(in) forecast
Cf2py intent(in) radius
Cf2py intent(in) thresh
Cf2py intent(in) nmem
Cf2py intent(in) ny
Cf2py intent(in) nx
Cf2py depend(ny, nx) probs
Cf2py intent(out) probs

        integer ibeg, iend, jbeg, jend, buffer, count, iii, jjj, npoints
        real rx, distz

        rx = 4.0
        buffer = int(radius / rx)

        do m=1, nmem
          do j=1, ny
            do i=1, nx

              if (i .le. buffer) then
                 ibeg=1
                 iend=i+buffer
              elseif (i .ge. nx-buffer) then
                 ibeg=i-buffer
                 iend=nx
              else
                 ibeg=i-buffer
                 iend=i+buffer
              endif
              if (j .le. buffer) then
                 jbeg=1
                 jend=j+buffer
              elseif (j .ge. ny-buffer) then
                 jbeg=j-buffer
                 jend=ny
              else
                 jbeg=j-buffer
                 jend=j+buffer
              endif

c$$$  Begin loop over points within the neighborhood
              count=0
              npoints=0
              do iii=ibeg,iend
                do jjj=jbeg,jend

c$$$  Count the number of points within the neighborhood that exceed the threshold
                  distz=(((i - iii) * rx) ** 2 + ((j - jjj) * rx) **2 )
     &              ** 0.5
                  if (distz .le. radius) then
                    npoints = npoints + 1
                    if (forecast(m, jjj, iii) .ge. thresh) then
                      count = count + 1
                    endif
                  endif
c$$$  End loop over points within the neighborhood
                enddo
              enddo

              if (count .gt. 0) then
                probs(j, i) = probs(j, i) + 1.0
              endif

            enddo
          enddo
        enddo

        probs(:, :) = (probs(:, :) / real(nmem)) * 100.0

      end
