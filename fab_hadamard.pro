function fab_hadamard, n

if n le 0 then $
   return, 1

a = fab_hadamard(n-1)
return, [[a, a], [a, -a]]
end
