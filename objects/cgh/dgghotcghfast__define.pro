;+
; NAME:
;    DGGhotCGHfast
;
; PURPOSE:
;    Object class that computes a computer generated hologram (CGH) from
;    a trapping pattern and transmits it to a spatial light modulator
;    (SLM) for projection.  Inherits DGGhotCGH and implements the
;    fastphase algorithm
;
; CATEGORY:
;    Computational holography, objects
;
; PROPERTIES:
;    SLM: Object of type DGGhotSLM for which holograms will be
;        computed.  No computation is performed unless this is defined.
;        (I/G/S)
;
;    TRAPS: array of DGGhotTrap objects describing the traps
;        Default: undefined: no traps
;        (I/G/S)        
;
;    PHI: byte-value hologram, computed from TRAPS according
;        to SLM specifications.
;        (G)
;
;    RC:  [rx, ry, rz] coordinates of the center of the projected
;         coordinate system.
;         Default: [0, 0, 0]
;        (S,G)
;
;    MAT: Affine transformation matrix that maps requested trap
;         coordinates onto the projected coordinate system.
;         Default: 3 x 3 identity matrix.
;        (S,G)
;
; METHODS:
;    DGGhotCGHfast::GetProperty
;
;    DGGhotCGHfast::SetProperty
;
;    DGGhotCGHfast::Compute
;        Use traps to compute hologram according to SLM
;        specifications, then transfer the hologram to the SLM.
;
; MODIFICATION HISTORY:
; 01/20/2011 Written by David G. Grier, New York University
; 03/25/2011 DGG Work with TRAPS rather than TRAPDATA.
; 09/02/2012 DGG Fixed bug in trap superposition pointed out by
;    David Ruffner and Ellery Russel.
;
; Copyright (c) 2011-2012, David G. Grier
;-

;;;;;
;
; DGGhotCGHfast::Compute
;
; Compute hologram for the SLM device using fastphase algorithm
;
pro DGGhotCGHfast::Compute

COMPILE_OPT IDL2, HIDDEN

if ~isa(self.slm) then $
   return

if ~isa(self.traps) then begin ; no traps
   *self.phi *= 0b
   self.slm.setproperty, data = *self.phi
   return
endif

;; field in the plane of the projecting device
*self.psi *= complex(0.)
foreach trap, *self.traps do begin
   pr = self.mat # (trap.rc - self.rc)
   ex = exp(*self.ikx * pr[0] + *self.ikxsq * pr[2])
   ey = exp(*self.iky * pr[1] + *self.ikysq * pr[2])
   *self.psi += (trap.alpha * exp(complex(0., trap.phase))) * (ex # ey)
endforeach

;; phase of the field in the plane of the projecting device
*self.phi = bytscl(atan(*self.psi, /phase))

computedone:
self.slm.setproperty, data = *self.phi
end

;;;;;
;
; DGGhotCGHfast::Deallocate
;
; Free allocated resources
;
pro DGGhotCGHfast::Deallocate

COMPILE_OPT IDL2, HIDDEN

self->DGGhotCGH::Deallocate

if isa(self.psi) then $
   ptr_free, self.psi

if isa(self.ikx) then $
   ptr_free, self.ikx

if isa(self.iky) then $
   ptr_free, self.iky

if isa(self.ikxsq) then $
   ptr_free, self.ikxsq

if isa(self.ikysq) then $
   ptr_free, self.ikysq
end

;;;;;
;
; DGGhotCGHfast::Allocate
;
; Allocate memory and define coordinates
;
pro DGGhotCGHfast::Allocate

COMPILE_OPT IDL2, HIDDEN

;; interrogate SLM and allocate hologram
self->DGGhotCGH::Allocate

;; allocate resources for CGH algorithm
; field in SLM plane
psi = complexarr(self.dim[0], self.dim[1])
self.psi = ptr_new(psi, /no_copy)
; coordinates in SLM plane scaled as wavevectors
ci = complex(0., 1.)
ikx = 2. * (findgen(self.dim[0]) - self.kc[0]) / min(self.dim)
iky = 2. * (findgen(self.dim[1]) - self.kc[1]) / min(self.dim)
ikxsq = ikx^2
ikysq = iky^2
ikx *= ci
iky *= ci
ikxsq *= ci
ikysq *= ci
self.ikx = ptr_new(ikx, /no_copy)
self.iky = ptr_new(iky, /no_copy)
self.ikxsq = ptr_new(ikxsq, /no_copy)
self.ikysq = ptr_new(ikysq, /no_copy)
end

;;;;;
;
; DGGhotCGHfast::GetProperty
;
; Get properties for CGH object
;
; inherited from DGGhotCGH

;;;;;
;
; DGGhotCGHfast::SetProperty
;
; Set properties for CGH object
;
; inherited from DGGhotCGH

;;;;;
;
; DGGhotCGHfast::Init
;
; inherited from DGGhotCGH

;;;;;
;
; DGGhotCGHfast::Cleanup
;
; inherited from DGGhotCGH

;;;;;
;
; DGGhotCGHfast__define
;
; Define an object that computes holograms from specifications
;
pro DGGhotCGHfast__define

COMPILE_OPT IDL2

struct = {DGGhotCGHfast, $
          inherits DGGhotCGH,     $
          psi:      ptr_new(),    $ ; computed field
          ikx:      ptr_new(),    $
          iky:      ptr_new(),    $
          ikxsq:    ptr_new(),    $
          ikysq:    ptr_new()     $
         }
end
