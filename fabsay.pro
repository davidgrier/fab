pro fabsay, str, scale = scale, fuzz = fuzz

COMPILE_OPT IDL2

s = getfab()
if ~isa(s, 'fabstate') then return

if n_elements(fuzz) ne 1 then $
   fuzz = 0.1

p = textcoords(str, width, height, /center, fuzz = fuzz)
if n_elements(scale) ne 1 then begin
   dim = ((*s).o.camera).dimensions
   scale = 0.8 * max(dim)/width
p *= scale
rc = (((*s).o.cgh).rc)[0:1]
p += rc

if n_elements(p) ge 2 then begin
   group = DGGhotTrapGroup(state = 1)
   npts = n_elements(p[0,*])
   for n = 0, npts-1 do $
      group->add, DGGhotTweezer(rc = p[*,n])
   (*s).o.traps->add, group
   (*s).o.traps->project
endif
   
end
