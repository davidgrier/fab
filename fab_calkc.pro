s = getfab()

; clear traps
(*s).o.traps.clear

xc = ((*s).o.cgh).xc
yc = ((*s).o.cgh).yc

p = 100. * [[1, 1, 0], [-1, 1, 0], [-1, -1, 0], [1, -1, 0]]
p[0, *] += xc
p[1, *] += yc

npts = n_elements(p[0, *])
group = DGGhotTrapGroup(state =  1)
for n = 0, npts-1 do $
   group -> add, DGGhotTweezer(rc = p[*, n])
(*s).o.traps -> add, group
(*s).o.traps -> project

a0 = fab_snap(max = 5)
a0[xc-20:xc+20, yc-20:yc+20] = min(a0)
b0 = bpass(a0, 1, 7)
p0 = feature(b0, 7, 30, min = 10, pickn = 4, /quiet)
print, p0
print

(*s).o.stage -> moveto, [0, 0, -15], /relative

v = []
for z = 10., 100., 2. do begin $
   group.moveto, [0, 0, z] & $
   (*s).o.traps -> project & $
   a1 = fab_snap(max = 5) & $
   v = [[v], [z, max(a1)]] & $
   tv, a1 & $
   endfor

v = v[*, 1:*]
m = max(v[1, *], loc)
group.moveto, [0, 0, v[0, loc]]
(*s).o.traps -> project
a1 = fab_snap(max = 5)
b1 = bpass(a1, 1, 7)
p1 = feature(b1, 7, 11, min = 10, pickn = 4, /quiet)
print, p1
print

(*s).o.stage -> moveto, [0, 0, +17], /relative

x0 = min([p0[0, *], p1[0, *]], max = x1)
y0 = min([p0[1, *], p1[1, *]], max = y1)
plot, [x0, x1], [y0, y1], /iso, /ynoz, /nodata

oplot, p0[0, *], p0[1, *], psym = circ()
oplot, p1[0, *], p1[1, *], psym = circ(/fill)
