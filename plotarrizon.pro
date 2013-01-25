function fab_refine_arrizon2, psi

;; psi = a exp(i phi)
;;
;; Phi = phi + g(a) sin(phi),
;;
;; where J_0(g(a)) = a for a in [0,1]
;;
;; Approximation to inverse Bessel function computed with Mathematica
;; g[a_, n_] := Normal[InverseSeries[Series[BesselJ[0,a], {a, 0, n}]]]
;;

phi = atan(psi, /phase) ; first approximation to phase

a = abs(psi)            ; amplitude (already non-negative
a /= max(a)             ; scale to [0,1]

;g = sqrt(1. - a) * (10905. - $
;                    a * (2387. - $
;                         a *(859. - $
;                             a * 161.))) / 4608.
;g = sqrt(1. - a) * (79081571. + $
;                    a * (-19448684. + $
;                         a * (9578226. + $
;                              a * (-3421484. + $
;                                   a * 565571.)))) / 33177600.

; solution to J_0(g(a)) = a to within 0.007 over range a = [0,1]
g = sqrt(1. - a) * (635036903. + $
                    a * (-167511147. + $
                         a * (100469158. + $
                              a * (-51215222. + $
                                   a * (16446243. + $
                                        a * 2384335.))))) / 265420800.

phi += g * sin(phi)             ; arrizon correction for amplitude variations
phi -= min(phi)                 ; make non-negative
phi *= 128. / !pi               ; scale to byte values

return, byte(phi)
end
