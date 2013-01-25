pro fabc, add_traps = p, say = say, guts = guts

s = getfab()

if s eq -1 then return

if n_elements(say) gt 0 then begin
   p = textcoords(say, width, height, /center, /fuzz)
   p *= 0.8 * 640/width
   p[0,*] += 320
   p[1,*] += 240
endif

if n_elements(p) ge 2 then begin
   group = DGGhotTrapGroup(state = 1)
   npts = n_elements(p[0,*])
   for n = 0, npts-1 do $
      group->add, DGGhotTweezer(rc = p[*,n])
   (*s).o.traps->add, group
   (*s).o.traps->project
endif
   
end
