function fab_getfirsttrap

s = getfab()
if ~isa(s) then return, obj_new()

pattern = (*s).o.traps
groups = pattern.get(/all)
group = groups[0]
traps = group.get(/all)
return, traps[0]
end
