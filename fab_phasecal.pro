pro fab_phasecal, s

;(*s).o.slm.getproperty, dim = dim
;w = dim[0]
;h = dim[1]
w = 512
h = 512

phi = bytarr(w,h) + 127b

seq = [[1,0],[1,0]]
nx = floor(alog(w)/alog(2)) - 1

for i = 1, nx do begin
   mask = congrid(seq, w, h)
   tvscl, mask
   seq = [seq, seq]
   wait, 0.1
endfor

seq = [[0,0],[1,1]]
ny = floor(alog(h)/alog(2)) - 1

for i = 1, ny do begin
   mask = congrid(seq, w, h)
   tvscl, mask
   seq = [[seq], [seq]]
   wait, 0.1
endfor


end
