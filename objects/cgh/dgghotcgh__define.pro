;+
; NAME:
;    DGGhotCGH
;
; PURPOSE:
;    Object class that computes a computer generated hologram (CGH) from
;    a trapping pattern and transmits it to a spatial light modulator
;    (SLM) for projection.
;
; CATEGORY:
;    Computational holography, objects
;
; PROPERTIES:
;    SLM    [IGS] Object of type DGGhotSLM for which holograms will be
;        computed.  No computation is performed unless this is defined.
;
;    TRAPS  [IGS] pointer to array of DGGhotTrap objects defining traps
;        Default: undefined: no traps
;        (I/G/S)        
;
;    DATA   [ G ] byte-valued hologram, computed from data in TRAPS according
;        to SLM specifications.
;
;    RC     [ GS]  [rx, ry, rz] coordinates of the center of the projected
;         coordinate system.
;         Default: [0, 0, 0]
;
;    MAT    [ GS] Affine transformation matrix that maps requested trap
;         coordinates onto the projected coordinate system.
;         Default: 3 x 3 identity matrix.
;
;    KC     [ GS] [eta, xi] coordinates of optical axis on SLM.
;         Default: Center of SLM.
;
;    BACKGROUND [IGS] background field to be added to hologram.
;         Default: None.
;
; METHODS:
;    DGGhotCGH::GetProperty
;
;    DGGhotCGH::SetProperty
;
;    DGGhotCGH::Compute
;        Use traps to compute hologram according to SLM
;        specifications, then transfer the hologram to the SLM.
;
;    DGGhotCGH::Refine
;        Perform one iteration of hologram refinement, and
;        then transfer the hologram to the SLM.
;
;    DGGhotCGH::Allocate
;        Allocate computational resources based on SLM
;        specifications.  Should only be called by DGGhotCGH::Init
;
;    DGGhotCGH::Deallocate
;        Free previously allocated computational resources.
;        Should only be called by DGGhotCGH::Cleanup
;
; INHERITS:
;    IDLitComponent: registered properties appear on propertysheet
;        widgets.
;
;    IDL_Object: implicit get and set properties.
;
; MODIFICATION HISTORY:
; 01/20/2011 Written by David G. Grier, New York University
; 02/01/2011 DGG moved RC and MAT into CGH from SLM
; 02/05/2011 DGG added hook for DGGhotCGH::Refine
; 03/25/2011 DGG work with TRAPS rather than TRAPDATA
; 04/11/2011 DGG inherit IDLitComponent so that CGH can have
;    registered properties that can be set with a propertysheet
; 12/06/2011 DGG KC is a property of the CGH rather than the SLM.
;    Added PRECOMPUTE method to account for changed values of KC.
;    Added ETA and XI keywords for interactive updates of KC.
;    Inherits IDL_Object for implicit get/set properties.
; 12/10/2011 DGG Have pointers referring to x, y, rsq and theta
;    coordinates in the SLM plane that are precomputed by
;    PRECOMPUTE.  Goal is to permit traps to declare functions
;    for computing their fields that make use of these coordinates.
; 02/04/2012 DGG simplify ptr_free calls in CleanUp method.
; 05/04/2012 DGG Check that parameters are numbers in Init and
;    SetProperty.
; 06/12/2012 DGG Renamed phi to data.
; 06/20/2012 DGG Don't clobber traps during SetProperty.
; 09/11/2013 DGG Introduced BACKGROUND keyword.
;
; Copyright (c) 2011-2013 David G. Grier
;-

;;;;;
;
; DGGhotCGH::Refine
;
; Perform one iteration of hologram refinement
;
pro DGGhotCGH::Refine

COMPILE_OPT IDL2, HIDDEN

; Base class does not know how to do refinement.
; Derived classes must do the work.
end

;;;;;
;
; DGGhotCGH::Compute
;
; Compute hologram for the SLM device
; Does nothing without an algorithm!
;
pro DGGhotCGH::Compute

COMPILE_OPT IDL2, HIDDEN

self.refining = 0L

if ~isa(self.slm) then $
   return

if ptr_valid(self.background) then $
   *self.data = *self.background $
else $
   *self.data *= 0b             ; ... send a blank CGH

self.slm.setproperty, data = *self.data

end

;;;;;
;
; DGGhotCGH::Precompute
;
; Compute static variables when kc changes
; Base class does not know how to represent coordinates.
;
pro DGGhotCGH::Precompute

COMPILE_OPT IDL2, HIDDEN

end

;;;;;
;
; DGGhotCGH::Deallocate
;
; Free allocated resources
;
pro DGGhotCGH::Deallocate

COMPILE_OPT IDL2, HIDDEN

if ptr_valid(self.data) then $
   ptr_free, self.data

if ptr_valid(self.background) then $
   ptr_free, self.background

end

;;;;;
;
; DGGhotCGH::Allocate
;
; Allocate memory and define coordinates
;
pro DGGhotCGH::Allocate

COMPILE_OPT IDL2, HIDDEN

if ~isa(self.slm, 'DGGhotSLM') then $
   return

self.dim = self.slm.dim
self.kc = float(self.dim)/2.
self->setpropertyattribute, 'eta', VALID_RANGE = [0., self.dim[0], 0.1]
self->setpropertyattribute, 'xi',  VALID_RANGE = [0., self.dim[1], 0.1]

;; hologram
data = bytarr(self.dim[0], self.dim[1])
self.data = ptr_new(data, /no_copy)

end

;;;;;
;
; DGGhotCGH::GetProperty
;
; Get properties for CGH object
;
pro DGGhotCGH::GetProperty, slm   = slm,   $
                            traps = traps, $
                            data  = data,  $
                            background = background, $
                            rc    = rc,    $
                            xc    = xc,    $
                            yc    = yc,    $
                            zc    = zc,    $
                            w     = w,     $
                            h     = h,     $
                            mat   = mat,   $
                            kc    = kc,    $
                            eta   = eta,   $
                            xi    = xi,    $
                            x     = x,     $
                            y     = y,     $
                            rsq   = rsq,   $
                            theta = theta, $
                            _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

self->IDLitComponent::GetProperty, _extra = re

if arg_present(slm) then $
   slm = self.slm

if arg_present(traps) then $
   traps = *self.traps

if arg_present(data) then $
   data = *self.data

if arg_present(background) then $
   background = ptr_valid(self.background) ? *self.background : 0

if arg_present(rc) then $
   rc = self.rc

if arg_present(xc) then $
   xc = self.rc[0]

if arg_present(yc) then $
   yc = self.rc[1]

if arg_present(zc) then $
   zc = self.rc[2]

if arg_present(mat) then $
   mat = self.mat

if arg_present(w) then $
   w = self.dim[0]

if arg_present(h) then $
   h = self.dim[1]

if arg_present(kc) then $
   kc = self.kc

if arg_present(eta) then $
   eta = self.kc[0]

if arg_present(xi) then $
   xi = self.kc[1]

if arg_present(x) then $
   x = self.x

if arg_present(y) then $
   y = self.y

if arg_present(rsq) then $
   rsq = self.rsq

if arg_present(theta) then $
   theta = self.theta

if arg_present(name) then $
   name = self.name

end

;;;;;
;
; DGGhotCGH::SetProperty
;
; Set properties for CGH object
;
pro DGGhotCGH::SetProperty, slm        = slm,      $
                            traps      = traps,    $
                            background = background, $
                            rc         = rc,       $
                            xc         = xc,       $
                            yc         = yc,       $
                            zc         = zc,       $
                            mat        = mat,      $
                            kc         = kc,       $
                            eta        = eta,      $
                            xi         = xi,       $
                            _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

self->IDLitComponent::SetProperty, _extra = re

doprecompute = 0
if isa(slm, 'DGGhotSLM') then begin
   self.slm = slm
   self.allocate
   doprecompute = 1
endif

if arg_present(traps) then begin
   ptr_free, self.traps
   if isa(traps) then begin
      if isa(traps[0], 'DGGhotTrap') then begin
         self.traps = ptr_new(traps)
      endif
   endif
endif

if arg_present(background) then begin
   if array_equal(size(background, /dimensions), self.dim) then $
      self.background = ptr_new(background)
endif

if isa(rc, /number) then begin
   case n_elements(rc) of
      2: self.rc[0:1] = rc
      3: self.rc = rc
      else:
   endcase
endif

if isa(xc, /scalar, /number) then $
   self.rc[0] = float(xc)

if isa(yc, /scalar, /number) then $
   self.rc[1] = float(yc)

if isa(zc, /scalar, /number) then $
   self.rc[2] = float(zc)

if (isa(mat, /number) and n_elements(mat) eq 9) then $
   self.mat = float(mat)

if (isa(kc, /number) and n_elements(kc) eq 2) then $
   self.kc = float(kc)

if isa(eta, /scalar, /number) then begin
   self.kc[0] = float(eta)
   doprecompute = 1
endif

if isa(xi, /scalar, /number) then begin
   self.kc[1] = float(xi)
   doprecompute = 1
endif

if doprecompute then self.precompute
self.compute
   
end

;;;;;
;
; DGGhotCGH::Init
;
function DGGhotCGH::Init, slm        = slm,   $
                          traps      = traps, $
                          background = background, $
                          rc         = rc,    $
                          mat        = mat,   $
                          kc         = kc,    $
                          _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

if (self->IDLitComponent::Init(_extra = re) ne 1) then $
   return, 0

if isa(slm, 'DGGhotSLM') then begin
   self.slm = slm
   self.allocate
   self.precompute
endif

if isa(background, /number, /array) then begin
   if array_equal(size(background, /dimensions), self.dim) then $
      self.background = ptr_new(background)
endif

if isa(rc, /number) then begin
   case n_elements(rc) of
      2: self.rc[0:1] = float(rc)
      3: self.rc = float(rc)
      else:
   endcase
endif

if (isa(mat, /number) and n_elements(mat) eq 9) then $
   self.mat = float(mat) $
else $
   self.mat = [[1., 0., 0.], [0., 1., 0.], [0., 0., 1.]]

if isa(kc, /number) and n_elements(kc) eq 2 then begin
   self.kc = float(kc)
   self.precompute
endif

if isa(traps) then begin
   if isa(traps[0], 'DGGhotTrap') then begin
      self.traps = ptr_new(traps)
      self.compute
   endif
endif

self.name = 'DGGhotCGH'
self.description = 'CGH Calculation Pipeline'
self->setpropertyattribute, 'name', /HIDE
self->registerproperty, 'xc', /FLOAT, NAME = 'XC'
self->registerproperty, 'yc', /FLOAT, NAME = 'YC'
self->registerproperty, 'zc', /FLOAT, NAME = 'ZC'
self->registerproperty, 'w', /INTEGER, NAME = 'Width', SENSITIVE = 0
self->registerproperty, 'h', /INTEGER, NAME = 'Height', SENSITIVE = 0
self->registerproperty, 'eta', /FLOAT, NAME = 'ETA'
self->registerproperty, 'xi', /FLOAT, NAME = 'XI'

return, 1
end

;;;;;
;
; DGGhotCGH::Cleanup
;
pro DGGhotCGH::Cleanup

COMPILE_OPT IDL2, HIDDEN

; Cleaning up SLM should be parent's task
; if isa(self.slm) then obj_destroy, self.slm

self.deallocate

ptr_free, self.traps, $
          self.x,     $
          self.y,     $
          self.theta, $
          self.rsq,   $
          self.data

end

;;;;;
;
; DGGhotCGH__define
;
; Define an object that computes holograms from specifications
;
pro DGGhotCGH__define

COMPILE_OPT IDL2

struct = {DGGhotCGH, $
          inherits IDLitComponent, $ ; for registered properties
          inherits IDL_Object,     $ ; implicit get/set methods
          slm:      obj_new(),     $ ; target SLM
          traps:    ptr_new(),     $ ; array of trap objects
          rc:       fltarr(3),     $ ; center of trap coordinate system
          mat:      fltarr(3, 3),  $ ; transformation matrix
          kc:       fltarr(2),     $ ; center of hologram
          dim:      lonarr(2),     $ ; dimensions of hologram
          x:        ptr_new(),     $ ; coordinates in SLM plane
          y:        ptr_new(),     $ ;
          rsq:      ptr_new(),     $ ; polar coordinates in SLM plane
          theta:    ptr_new(),     $ ;
          data:     ptr_new(),     $ ; computed hologram
          background: ptr_new(),   $ ; background hologram
          refining: 0L             $ ; set if refining the hologram
         }
end
