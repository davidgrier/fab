pro fabstability

n = 140
a = fltarr([640,480,n])
a[*,*,0] = fab_snap()
a_corr = fltarr(n)
a_mean = fltarr(n)
t_start = systime(0,/seconds)
for i = 1, n-1 do begin
   wait, 0.1
   a[*,*,i] = fab_snap()
   d = a[*,*,i] - float(a[*,*,0])
   a_corr[i] = total((a[*,*,i]-float(a[*,*,0]))^2)/(480*640.)/256
   a_mean[i] = mean(a[*,*,i])
endfor
t_end = systime(0,/seconds)
t_movie = t_end - t_start
print, 'movie time:', t_movie,' [sec]'
print, 'intensity max:', max(a[*,*,i-1])

b = median(a, dim=3) > 1.
spheretool, a[*,*,0]/b
end
