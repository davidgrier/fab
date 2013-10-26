;+
; NAME:
;    DGGhotCGHGPU
;
; PURPOSE:
;    Object class that computes a computer generated hologram (CGH) from
;    a trapping pattern and transmits it to a spatial light modulator
;    (SLM) for projection.  Inherits DGGhotCGH and implements the
;    fastphase algorithm with GPU acceleration.
;
; CATEGORY:
;    Computational holography, objects
;
; PROPERTIES:
;    SLM   [IGS] Object of type DGGhotSLM for which holograms will be
;        computed.  No computation is performed unless this is defined.
;
;    TRAPS [IGS] pointer to array of DGGhotTrap objects defining traps
;        Default: undefined: no traps
;        (I/G/S)        
;
;    DATA  [ G ] byte-valued hologram, computed from data in TRAPS according
;        to SLM specifications.
;
;    RC    [ GS]  [rx, ry, rz] coordinates of the center of the projected
;         coordinate system.
;         Default: [0, 0, 0]
;
;    MAT   [ GS] Affine transformation matrix that maps requested trap
;         coordinates onto the projected coordinate system.
;         Default: 3 x 3 identity matrix.
;
;    KC    [ GS] [eta, xi] coordinates of optical axis on SLM.
;         Default: Center of SLM.
;
;    BACKGROUND [IGS] background field to be added to hologram.
;         Default: None.
;
; METHODS:
;    DGGhotCGHGPU::GetProperty
;
;    DGGhotCGHGPU::SetProperty
;
;    DGGhotCGHGPU::Compute
;        Use data describing TRAPS to compute hologram according to SLM
;        specifications, then transfer the hologram to the SLM.
;
; INHERITS:
;    DGGhotCGH
;    IDLitComponent
;    IDL_Object
;
; MODIFICATION HISTORY:
; 01/25/2011 Written by David G. Grier, New York University
; 02/05/2011 DGG Implemented DGGhotCGHGPU::Refine using adaptive-additive
;    algorithm.
; 03/23/2011 DGG use _ref_extra in Init
; 03/25/2011 DGG work with TRAPS rather than TRAPDATA
; 12/09/2011 DGG Fixed LHS errors.  Updated documentation for updates
;    to DGGhotCGH.  Implemented PRECOMPUTE method.
; 12/10/2011 DGG Added support for theta.  Cleaned up PRECOMPUTE.
; 02/04/2012 DGG Added support for optical vortexes and experimental
;    support for other structured traps.  Moved refinement code to
;    separate files for clarity.
; 06/12/2012 DGG Renamed gpuphi to phi.  Call own Cleanup before
;    DGGhotCGH::Cleanup.
; 06/20/2012 DGG gpufltarr can have NAN values unless zeroed
; explicitly.
; 09/11/2013 DGG Support for BACKGROUND.
; 09/15/2013 DGG Support for callbacks during computation.
; 10/03/2013 DGG and David B. Ruffner project background even if there
;    are no traps.
; 10/26/2013 DGG Can rely on background image begin defined.  Update
;    for GPULib 1.6.0.
;
; Copyright (c) 2011-2013 David G. Grier and David B. Ruffner
;-

;;;;;
;
; DGGhotCGHGPU::Compute
;
; Compute hologram for the SLM device using GPU-accelerated 
; fastphase algorithm
;
pro DGGhotCGHGPU::Compute

COMPILE_OPT IDL2, HIDDEN

self.refining = 0B
t = systime(1)

if ~isa(self.slm) then $
   return

;; field in the plane of the projecting device
*self.repsi = gpuputarr(real_part(*self.background), $
                        LHS = *self.repsi);, /NONBLOCKING)
*self.impsi = gpuputarr(imaginary(*self.background), $
                        LHS = *self.impsi);, /NONBLOCKING)

if ptr_valid(self.traps) then begin
   foreach trap, *self.traps do begin
      pr = self.mat # (trap.rc - self.rc)
      *self.phi = gpuadd(pr[0], *self.x, pr[1], *self.y, trap.phase,  $
                         LHS = *self.phi)
      *self.phi = gpuadd(1., *self.phi, pr[2], *self.rsq, 0., LHS = *self.phi)
      if trap.ell ne 0 then $
         *self.phi = gpuadd(1., *self.phi, trap.ell, *self.theta, 0., $
                            LHS = *self.phi)
      if isa(trap.phi) then $
         *self.phi = gpuadd(*self.phi, *trap.phi, LHS = *self.phi)
      *self.a = gpucos(*self.phi, LHS = *self.a, /NONBLOCKING)
      *self.b = gpusin(*self.phi, LHS = *self.b)
      if isa(trap.amplitude) then begin
         *self.a = gpumult(*self.a, *trap.amplitude, $
                           LHS = *self.a, /NONBLOCKING)
         *self.b = gpumult(*self.b, *trap.amplitude, LHS = *self.b)
      endif
      *self.repsi = gpuadd(1., *self.repsi, trap.alpha, *self.a, 0., $
                           LHS = *self.repsi, /NONBLOCKING)
      *self.impsi = gpuadd(1., *self.impsi, trap.alpha, *self.b, 0., $
                           LHS = *self.impsi)
      if (systime(1) - t) ge self.timer then begin
         call_procedure, self.callback, self.userdata
         t = systime(1)
      endif
   endforeach
endif

;; phase of the field in the plane of the projecting device
; scale from 0 to 255
*self.a = gpuatan2(*self.impsi, *self.repsi, LHS = *self.a)
*self.phi = gpuadd(127.5/!pi, *self.a, 0., *self.b, 127.5/!pi, $
                   LHS = *self.phi)

*self.data = byte(gpugetarr(*self.phi))
self.slm.setproperty, data = *self.data
end

;;;;;
;
; DGGhotCGHGPU::Precompute
;
; Precompute SLM geometry when kc changes
; Overrides Precompute method in DGGhotCGH
;
pro DGGhotCGHGPU::Precompute

COMPILE_OPT IDL2, HIDDEN

w = self.dim[0]
h = self.dim[1]
x = 2. * (findgen(w) - self.kc[0]) / min([w,h])
x = rebin(x, w, h)
y = 2. * (findgen(1, h) - self.kc[1]) / min([w,h])
y = rebin(y, w, h)
rsq = x^2 + y^2
theta = atan(y, x) + !pi
*self.x = gpuputarr(x, LHS = *self.x)
*self.y = gpuputarr(y, LHS = *self.y)
*self.rsq = gpuputarr(rsq, LHS = *self.rsq)
*self.theta = gpuputarr(theta, LHS = *self.theta)

end

;;;;;
;
; DGGhotCGHGPU::Deallocate
;
; Free allocated resources
;
pro DGGhotCGHGPU::Deallocate

COMPILE_OPT IDL2, HIDDEN

gpufree, [*self.x,     $ ; geometry
          *self.y,     $
          *self.rsq,   $
          *self.theta, $
          *self.repsi, $ ; field
          *self.impsi, $
          *self.phi,   $
          *self.a,     $ ; temporary variables
          *self.b      $
         ]

ptr_free, self.repsi, $ ; field
          self.impsi, $
          self.phi,   $
          self.a,     $ ; temporary variables
          self.b

self->DGGhotCGH::Deallocate

end

;;;;;
;
; DGGhotCGHGPU::Allocate
;
; Allocate memory and define coordinates
;
pro DGGhotCGHGPU::Allocate

COMPILE_OPT IDL2, HIDDEN

;; interrogate SLM and allocate hologram
self->DGGhotCGH::Allocate

;; allocate resources for CGH algorithm
w = self.dim[0]                 ; hologram dimensions
h = self.dim[1]

; field in SLM plane
repsi = gpufltarr(w, h, /nozero) ; real part of field
impsi = gpufltarr(w, h, /nozero) ; imaginary part of field
phi   = gpufltarr(w, h, /nozero) ; phase
self.repsi = ptr_new(repsi, /no_copy)
self.impsi = ptr_new(impsi, /no_copy)
self.phi   = ptr_new(phi,   /no_copy)

; geometry
x = gpufltarr(w, h, /nozero)
y = gpufltarr(w, h, /nozero)
rsq = gpufltarr(w, h, /nozero)
theta = gpufltarr(w, h, /nozero)
self.x = ptr_new(x, /no_copy)
self.y = ptr_new(y, /no_copy)
self.rsq = ptr_new(rsq, /no_copy)
self.theta = ptr_new(theta, /no_copy)

; temporary variables
a = gpufltarr(w, h, /nozero)
b = gpufltarr(w, h, /nozero)
self.a = ptr_new(a, /no_copy)
self.b = ptr_new(b, /no_copy)
end

;;;;;
;
; DGGhotCGHGPU::GetProperty
;
; Get properties for CGH object
;
; inherited from DGGhotCGH

;;;;;
;
; DGGhotCGHGPU::SetProperty
;
; Set properties for CGH object
;
; inherited from DGGhotCGH

;;;;;
;
; DGGhotCGHGPU::Init
;
; Initialize GPULib
;
function DGGhotCGHGPU::Init, slm = slm, $
                             _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

catch, error
if (error ne 0L) then begin
   catch, /cancel
   return, 0
endif

gpuinit, /hardware, /quiet

ok = self->DGGhotCGH::Init(_extra = re)
if not ok then $
   return, 0

if isa(slm, 'DGGhotSLM') then begin
   self.slm = slm
   self.allocate
   self.precompute
endif

self.name = 'DGGhotCGHGPU'
self.description = 'GPU-accelerated CGH Pipeline'

return, 1
end

;;;;;
;
; DGGhotCGHGPU::Cleanup
;
; inherited from DGGhotCGH

;;;;;
;
; DGGhotCGHGPU__define
;
; Define an object that computes holograms from specifications
;
pro DGGhotCGHGPU__define

COMPILE_OPT IDL2

struct = {DGGhotCGHGPU, $
          inherits DGGhotCGH,     $
          repsi:  ptr_new(), $ ; computed field in SLM plane
          impsi:  ptr_new(), $
          phi:    ptr_new(), $ ; computed phase hologram
          a:      ptr_new(), $ ; temporary variables
          b:      ptr_new()  $
         }
end
