;+
; NAME:
;    fab_calxy
;
; PURPOSE:
;    Calibrate in-plane coordinate system for FAB
;
; MODIFICATION HISTORY:
; 02/01/2011 Written by David G. Grier, New York University
; 10/04/2011 DGG Force fab_snap to return a grayscale image.
; 11/20/2011 DGG Exclude central spot from search for projected trap.
;
; Copyright (c) 2011, David G. Grier
;-
;;;;;
;
; FAB_CALXY_FIND
;
; Find the position of the brightest point on the screen
;
function fab_calxy_find, s, rc

COMPILE_OPT IDL2, HIDDEN

a = fab_snap(s, delay=1.5, /gray) ; wait to settle and avoid flicker
q = fastfeature(a, 50)
;q = feature(bpass(a, 1, 7), 9, 30, pickn = 2, /quiet)
; exclude central spot from consideration ...
if (n_params() eq 2) and (n_elements(q[0, *]) gt 1) then begin
   drsq = (q[0, *] - rc[0])^2 + (q[1, *] - rc[1])^2
   w = where(drsq gt 4, ngood)
   if ngood gt 0 then $
      q = q[*, w]
endif
; desired spot (hopefully) is the brightest feature ...
m = max(q[2,*], ndx)

; handy dandy debugging code ...
; plotimage, bytscl(a), /iso
; plots, q[0, ndx], q[1, ndx], psym = circ()

return, q[0:1,ndx]
end

;;;;;;
;
; FAB_CALXY
;
; Calibrate the FAB coordinate system so that placement of traps
; is consistent with screen coordinates.
;
pro fab_calxy, s

COMPILE_OPT IDL2

fab_status, s, "Calibrating XY"

; find the center of the trapping pattern
(*s).o.traps.clear
rc = fab_calxy_find(s)
(*s).o.cgh.setproperty, rc = rc

; estimate reasonable displacements
(*s).o.camera.getproperty, dimension = dim

dx = 0.5 * (rc[0] < (dim[0] - rc[0]))
dy = 0.5 * (rc[1] < (dim[1] - rc[1]))

trap = DGGhotTrapGroup(DGGhotTweezer(rc = rc), rs = rc, state = 0)
(*s).o.traps.add, trap

; Move the trap to three places and see where it actually goes
; 1.
r1 = rc + [dx, 0, 0]
trap.moveto, r1, /override
s1 = fab_calxy_find(s, rc)

; 2.
r2 = rc + [-dx, dy, 0]
trap.moveto, r2, /override
s2 = fab_calxy_find(s, rc)

; 3.
r3 = rc + [-dx, -dy, 0]
trap.moveto, r3, /override
s3 = fab_calxy_find(s, rc)

; Calculate the affine transformation that maps the observed
; positions onto the requested positions
z = fltarr(3)
m = [$
    [s1, 1.,  z], $
    [ z, s1, 1.], $
    [s2, 1.,  z], $
    [ z, s2, 1.], $
    [s3, 1.,  z], $
    [ z, s3, 1.]  $
    ]
mm = invert(m) ## [r1[0:1], r2[0:1], r3[0:1]]
mat = fltarr(3, 3)
mat[0:1, 0:1] =  [[mm[0:1]], [mm[3:4]]]
mat[2, 2] = 1.

; save the transformation properties
(*s).o.cgh.getproperty, mat = omat
(*s).o.cgh.setproperty, mat = mat # omat

(*s).o.traps.clear

fab_status, s

end
