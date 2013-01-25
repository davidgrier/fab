; add traps until traps are desaturated

pro fab_desaturate, s

phi = (sqrt(5.) + 1.)/2.        ; golden mean
theta0 = 2. * !pi / phi^2       ; golden angle
r0 = 40.

n = 0
repeat begin
   theta = n * theta0
   r = r0 * sqrt(n + 0.5)
   x = r * cos(theta)
   y = r * sin(theta)
   (*s).o.traps.add, DGGhotTrapGroup(DGGhotTweezer(rc = [x,y]), state = 0)
   a = (*s).o.camera.snap(max = 10)
   n++
until (a[x,y] lt 200) end


repeat
