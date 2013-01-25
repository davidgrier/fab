pro fab_calaperture, s

(*s).o.cgh.getproperty, phi = phi

dim = 120.
a = 30
nx = 16
ny = 9

mask = 0b * phi

p = []

for j = 0, ny-1 do begin
   yc = (j - ny/2) * a + 240
   y0 = j * dim
   y1 = y0 + dim - 1
   for i = 0, nx-1 do begin
      xc = (i - nx/2) * a + 320
      p =  [[p], [xc, yc]]
      rc = [xc, yc, 0]
      (*s).o.traps.clear
      (*s).o.traps.add, DGGhotTrapGroup(DGGhotTweezer(rc = rc), state = 0)
;      b = fab_snap(s, delay = 4)
      (*s).o.cgh.getproperty, phi = phi
      x0 = i * dim
      x1 = x0 + dim - 1
      mask[x0:x1, y0:y1] = phi[x0:x1, y0:y1]
   endfor
endfor
      
write_gdf, mask, "fancymask.gdf"

(*s).o.slm.setproperty, data = mask

b = fab_snap(s, max = 10)

write_gdf, b, "fancytraps.gdf"

;dim = 300
;step = 50
;sz = size(phi, /dimensions)

;mask =  0b * phi
;mask[0:dim-1, 0:dim -1] = 1b

;res = []
;for y = 0, sz[1]- dim - 1, step do begin
;   fab_status, s, "calibrating: y = " + strtrim(y, 2)
;   this = []
;   for x = 0, sz[0] - dim - 1, step do begin
;      (*s).o.slm.setproperty, data = phi*shift(mask, x, y)
;      a = fab_snap(s, max = 10)
;      this = [this, a[100, 100]]
;   endfor
;   res = [[res], [this]]
;endfor

;plotimage, res, /iso

;write_gdf, res, "calap.gdf"


fab_status, s

end
