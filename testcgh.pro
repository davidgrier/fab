slm = dgghotslm()

p = 15.*textcoords("hi", /center)
npts = n_elements(p[0, *])
data = fltarr(5, npts)
data[0:1, *] = p
data[3, *] = 1.

cgh = dgghotcghfast(slm = slm)
t = systime(1)
cgh.setproperty, trapdata = data
print, systime(1) - t
obj_destroy, cgh

cgh = dgghotcghgpu(slm = slm)
t = systime(1)
cgh.setproperty, trapdata = data
print, systime(1) - t
obj_destroy, cgh

obj_destroy, slm
