;+
; NAME:
;      FASTCGH
;
; PURPOSE:
;      Calculates the hologram encoding a desired trapping
;      pattern by superposing fields as fast as possible.
;
; CATEGORY:
;      Computed holography
;
; CALLING SEQUENCE:
;      cgh = fastcgh(p)
;
; INPUTS:
;      p: [2,npts] or [3,npts] array of coordinates
;         relative to the center of the focal plane.
;         Coordinates are measured in calibrated pixel units
;         using calibration constants from HOLO_COMMON.
;
; KEYWORD INPUTS:
;      alpha: [npts] array of relative amplitudes
;         Default: uniform relative amplitudes.
;
;      phase: [npts] array of relative phases.
;         Default: random phases
;
;      lut: [nlevels] array of complex transfer values for
;         the CGH pixels.
;         Default: nlevels = 256, linear phase ramp, unit amplitude.
;      
; OUTPUTS:
;      cgh: hologram consisting of an array of indices into the
;          transfer lookup table (LUT).
;
; RESTRICTIONS:
;      Can be very memory intensive for large numbers of points.
;
; PROCEDURE:
;      Initial estimate is obtained by superposing the fields of the
;      specified beams.  The index at each pixel minimizes the
;      magnitude of the field error at that pixel.
;
; MODIFICATION HISTORY:
; 03/10/2010 Written by David G. Grier, New York University
;
; Copyright (c) 2010 David G. Grier
;-

function fastcgh, p, $
                  alpa = alpha_, $
                  phase = phase_, $
                  lut = lut, $

common holo_common, cal

w = cal.doe_w
h = cal.doe_h

; calibration constants
xc = cal.xc                     ; center of phase mask on SLM
yc = cal.yc
xfac = cal.xscale               ; scale factor for square pixels
rfac = cal.scale                ; projection scale factor
thetac = cal.theta              ; orientation

sp = size(p, /dimensions)
ndim = sp[0]                    ; number of dimensions
npts = sp[1]                    ; number of points

twopi = 2.D * !dpi

; field look-up table
if not keyword_present(lut) then begin
   nlevels = 256
   lut = exp( dcomplex(0., twopi * dindgen(nlevels)/nlevels) )
endif else $
   nlevels = n_elements(lut)
; NOTE: more LUT error checking needed here

; trap locations in trapping plane
; rotate points to account for relative SLM-CCD orientation
qx = p[0, *] * cos(thetac) + p[1, *] * sin(thetac)
qy = p[1, *] * cos(thetac) - p[0, *] * sin(thetac)
; wavevectors associated with trap position (times i)
ikx = dcomplex(0., (twopi/w) * reform(qx))
iky = dcomplex(0., (twopi/h) * reform(qy))

if ndim gt 2 then $
   ikz = dcomplex(0., twopi * cal.zfactor * reform(p[2,*]))

; coordinates in CGH plane (row vectors)
x = xfac * rfac * dindgen(w)
y = rfac * dindgen(h)
if ndim gt 2 then begin
   xsq = (x - w/2.D - xc)^2
   ysq = (y - h/2.D - yc)^2
endif

; relative amplitudes
if n_elements(alpha_) eq npts then $
   alpha = double(alpha_) $
else $
   alpha = replicate(1.d, npts)
alpha /= total(alpha)

; relative phases
if n_elements(phase_) eq npts then $
   iphase = dcomplex(0.d, phase_) $
else $
   iphase = dcomplex(0.D, twopi * randomu(seed, npts))

; field in CGH plane
psi = complexarr(w, h)
for n = 0, npts-1 do begin
                                ; i \vec{k}_n \cdot \vec{r}
   ikxx = ikx[n] * x + iphase[n]
   ikyy = iky[n] * y
   if ndim gt 2 then begin
      ikxx += ikz[n] * xsq
      ikyy += ikz[n] * ysq
   endif
   ex = exp(ikxx)
   ey = exp(ikyy)
                                ; \psi += exp( i \phi_n(\vec{r}) )
   psi += alpha[n] * ex # ey
endfor

if nlevels le 256 then $
   cgh = bytarr(w, h) $
else $
   cgh = intarr(w, h)

for n = 0, nlevels-1 do begin
return, cgh

end
