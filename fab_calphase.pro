pro fab_calphase, s

status = "Calibrating SLM phase profile "

rc = [100., 100., 15.] ; the test point
(*s).o.traps.clear
(*s).o.traps.add, DGGhotTrapGroup(DGGhotTweezer(rc = rc), state = 0)
(*s).o.cgh.getproperty, phi = phi ; get the hologram

sz = size(phi, /dimensions)
w = sz[0]
h = sz[1]
mask = bytarr(w, h)
res = []

plot, [-w/2, w/2], 255*[0, 1], /nodata, /xsty, /ysty

for x = 0, w-1, 20 do begin
   mask[0:x, *] =  128b
   (*s).o.slm.setproperty, data = phi + mask
   a = fab_snap(s, max = 10)       ;  avoid flicker
   this = [x - w/2, a[rc[0], rc[1]]]
   fab_status, s, status + "x =" + string(this[0]) + ": " + string(this[1])
   res = [[res], [this]]
endfor

oplot, res[0, *], res[1, *]

res =  []
mask *= 0b
for y = 0, h-1, 20 do begin
   mask[*, 0:y] =  128b
   (*s).o.slm.setproperty, data = phi + mask
   a = fab_snap(s, max = 10)
   this = [y - h/2, a[rc[0], rc[1]]]
   fab_status, s, status + "y =" + string(this[0]) + ": " + string(this[1])
   res = [[res], [this]]
endfor

oplot, res[0, *], res[1, *], linestyle = 2

fab_status, s

end
