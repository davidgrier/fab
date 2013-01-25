pro fabsay, str, scale = scale, fuzz = fuzz

common managed, ids, names, modalList

nmanaged = n_elements(ids)
if (nmanaged lt 1) then begin
   message, "fab is not running", /inf
   return
endif

w = where(names eq 'fab', ninstances)
if ninstances ne 1 then begin
   message, "fab is not running", /inf
   return
endif

widget_control, ids[w], get_uvalue = s

if n_elements(fuzz) ne 1 then $
   fuzz = 0.1

p = textcoords(str, width, height, /center, fuzz = fuzz)
if n_elements(scale) ne 1 then $
   scale = 0.8 * 640/width
p *= scale
p[0,*] += 320
p[1,*] += 240

if n_elements(p) ge 2 then begin
   group = DGGhotTrapGroup(state = 1)
   npts = n_elements(p[0,*])
   for n = 0, npts-1 do $
      group->add, DGGhotTweezer(rc = p[*,n])
   (*s).o.traps->add, group
   (*s).o.traps->project
endif
   
end
