;+
; NAME:
;    DGGhotTrap
;
; PURPOSE:
;    This object abstracts a holographic optical trap as the
;    combination of a graphical representation and data describing
;    the 3D position and physical properties of the trap.  This is
;    the base class from which all practical implementations of
;    holographic optical traps can be abstracted.
;
; CATEGORY:
;    Holographic optical trapping, object graphics
;
; SUPERCLASSES:
;    IDLgrPolyline
;    IDL_Object
;
; PROPERTIES:
;    Note: Properties of IDLgrPolyline also are properties of
;    DGGhotTrap objects.
;
;    RC    [IGS] three-element vector [xc, yc, zc] specifying the trap's
;        position [pixels].
;
;    ALPHA [IGS] relative amplitude.
;        Default: 1
;
;    PHASE [IGS] relative phase [radians].
;        Default: random number in [0, 2pi].
;
;    AMPLITUDE [IGS] pointer to amplitude profile.
;
;    PHI [IGS] pointer to phase profile.
;
;    ELL [IGS] winding number for optical vortex.
;
; METHODS:
;
;    DGGhotTrap::GetProperty
;
;    DGGhotTrap::SetProperty
;
;    DGGhotTrap::MoveBy, dr, /override
;        Displace trap in two or three dimensions
;        DR: displacement vector [pixels]
;        OVERRIDE: If set, project the trap.  Default behavior
;            is to displace the graphic, but to leave projection
;            to the parent DGGhotTrapGroup.
;
; NOTES: 
;    Add palette for color table.
;    Return trapdata as a structure describing particular trap type.
;    This would allow for mixtures of optical vortexes, optical
;    tweezers, and other types of traps.
;
; MODIFICATION HISTORY:
; 12/30/2010: Written by David G. Grier, New York University
; 03/22/2011 DGG register properties for inclusion in property sheets
;    Added properties XC, YC, ZC, including get/set methods.
; 02/03/2012 DGG added AMPLITUDE and PHI properties as 
;    a mechanism to implement structured optical traps.
; 02/04/2012 DGG added ELL property for optical vortexes.
; 05/16/2012 DGG subclass IDL_Object for implicit Get/SetProperty methods.
; 05/17/2012 DGG updated parameter checks in SetProperty and streamlined
;    decisions regarding when to call Project method.  Notify parent
;    DGGgrTrapGroup if destroyed programmatically.  Added
;    _overloadForeach method to permit looping over arrays of traps,
;    including one-element arrays.
; 06/12/2012 DGG Don't clobber self.rc[2] when setting rc[0:1].
;    Revised MoveBy method for compatibility with
;    DGGhotTrapGroup::MoveBy.  Added OVERRIDE flag to MoveBy method.
;
; Copyright (c) 2010-2012, David G. Grier
;-

;;;;
;
; DGGhotTrap::DrawGraphic
;
; Update graphical representation of trap
;
pro DGGhotTrap::DrawGraphic

COMPILE_OPT IDL2, HIDDEN

graphic = *self.graphic
graphic[0, *] += self.rc[0]
graphic[1, *] += self.rc[1]

self->IDLgrPolyline::SetProperty, data = graphic

end

;;;;
;
; DGGhotTrap::Project
;
pro DGGhotTrap::Project

if isa(self.parent, 'DGGhotTrapGroup') then $
   self.parent.project
end

;;;;
;
; DGGhotTrap::MoveBy
;
; Move the trap by a specified displacement
;
pro DGGhotTrap::MoveBy, dr, $
                        override = override

COMPILE_OPT IDL2, HIDDEN

case n_elements(dr) of
   3: self.rc += dr
   2: self.rc[0:1] += dr
else:
endcase

if keyword_set(override) then $
   self.project

self.drawgraphic

end

;;;;
;
; DGGhotTrap::Select
;
; Return the parent trap group, and notify parent of change in state
;
function DGGhotTrap::Select, state = state ; 2: select, or 3: grouping

COMPILE_OPT IDL2, HIDDEN

if ~isa(self.parent, 'DGGhotTrapGroup') then $ ; XXX DGGhotTrap
   return, !NULL

self.parent->setproperty, state = state, rc = self.rc

return, ptr_new(self.parent)
end

;;;;
;
; DGGhotTrap::_overloadForeach
;
; Attempting to loop over just one trap should yield the trap, not an
; error
;
function DGGhotTrap::_overloadForeach, value, key

COMPILE_OPT IDL2

if n_elements(key) gt 0 then return, 0

value = self
key = 0

return, 1
end

;;;;
;
; DGGhotTrap::SetProperty
;
; Set properties associated with the trap or its representation
; Project the updated trap
;
pro DGGhotTrap::SetProperty, rc         = rc,        $ ; position
                             xc         = xc,        $
                             yc         = yc,        $
                             zc         = zc,        $
                             alpha      = alpha,     $ ; relative amplitude
                             phase      = phase,     $ ; relative phase
                             amplitude  = amplitude, $ ; structure
                             phi        = phi,       $
                             ell        = ell,       $
                             _ref_extra = re

COMPILE_OPT IDL2, HIDDEN
  
self->IDLgrPolyline::SetProperty, _extra = re

doproject = 0
if isa(rc, /number, /array) then begin
   case n_elements(rc) of
      3: self.rc = rc
      2: self.rc[0:1] = rc
   else:
   endcase
   doproject = 1
endif

if isa(xc, /number, /scalar) then begin
   self.rc[0] = xc
   doproject = 1
endif

if isa(yc, /number, /scalar) then begin
   self.rc[1] = yc
   doproject = 1
endif

if isa(zc, /number, /scalar) then begin
   self.rc[2] = zc
   doproject = 1
endif

if isa(alpha, /number, /scalar) then begin
   self.alpha = alpha
   doproject = 1
endif

if isa(phase, /number, /scalar) then begin
   self.phase = phase
   doproject = 1
endif

if isa(amplitude, 'pointer') then $
   self.amplitude = amplitude

if isa(phi, 'pointer') then $
   self.phi = phi

if isa(ell, /number, /scalar) then begin
   self.ell = ell
   doproject = 1
endif

if doproject then self.project
self.drawgraphic

end

;;;;
;
; DGGhotTrap::GetProperty
;
; Retrive the value of properties associated with the trap
;
pro DGGhotTrap::GetProperty, rc         = rc,        $
                             xc         = xc,        $
                             yc         = yc,        $
                             zc         = zc,        $
                             alpha      = alpha,     $
                             phase      = phase,     $
                             amplitude  = amplitude, $
                             phi        = phi,       $
                             ell        = ell,       $
                             trapdata   = trapdata,  $
                             _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

self->IDLgrPolyline::GetProperty, _extra = re

rc = self.rc
xc = rc[0]
yc = rc[1]
zc = rc[2]

if arg_present(alpha) then $
   alpha = self.alpha

if arg_present(phase) then $
   phase = self.phase

if arg_present(amplitude) then $
   amplitude = self.amplitude

if arg_present(phi) then $
   phi = self.phi

if arg_present(ell) then $
   ell = self.ell

if arg_present(trapdata) then $
   trapdata = [self.rc, self.alpha, self.phase, self.ell]

end

;;;;;
;
; DGGhotTrap::Init
;
; Initialize the trap object
;
function DGGhotTrap::Init, rc         = rc,        $
                           alpha      = alpha,     $
                           phase      = phase,     $
                           amplitude  = amplitude, $
                           phi        = phi,       $
                           ell        = ell,       $
                           _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

if (self->IDLgrPolyline::Init(_extra = re) ne 1) then $
   return, 0

if ~isa(self.graphic) then $
   self.graphic = ptr_new(fltarr(3))

case n_elements(rc) of
   3: self.rc = rc
   2: self.rc = [rc, 0.]
else:
endcase

self.alpha = 1.
if (n_elements(alpha) eq 1) then $
   self.alpha = alpha

self.phase = 2. * !pi * randomu(long(systime(1)), 1)
if (n_elements(phase) eq 1) then $
   self.phase = phase

if isa(amplitude, 'pointer') then $
   self.amplitude = amplitude

if isa(phi, 'pointer') then $
   self.phi = phi

if isa(ell, /NUMBER) then $
   self.ell = ell

self.drawgraphic

self.name = 'DGGhotTrap'
self.description = 'Holographic Optical Trap'
self->registerproperty, 'name', /STRING, NAME = 'NAME', /HIDE
self->registerproperty, 'xc', /FLOAT, NAME = 'XC', $
                        DESCRIPTION = 'Trap position: x'
self->registerproperty, 'yc', /FLOAT, NAME = 'YC', $
                        DESCRIPTION = 'Trap position: y'
self->registerproperty, 'zc', /FLOAT, NAME = 'ZC', $
                        DESCRIPTION = 'Trap position: z'
self->registerproperty, 'alpha', /FLOAT, NAME = 'alpha', $
                        DESCRIPTION = 'Relative amplitude', $
                        VALID_RANGE = [0., 100., 0.01]
self->registerproperty, 'phase', /FLOAT, NAME = 'phase', $
                        DESCRIPTION = 'Relative phase', $
                        VALID_RANGE = [0., 2.*!pi, 0.01]


return, 1
end

;;;;
;
; DGGhotTrap::Cleanup
;
; Free resources claimed by trap
;
pro DGGhotTrap::Cleanup

COMPILE_OPT IDL2, HIDDEN

if isa(self.parent, 'DGGhotTrapGroup') then begin
   self.parent->Remove, self
;   self.parent->Project
endif

self->IDLgrPolyline::Cleanup

ptr_free, self.amplitude
ptr_free, self.phi
end

;;;;
;
; DGGhotTrap__define
;
; Define the object structure for a DGGhotTrap
;
pro DGGhotTrap__define

COMPILE_OPT IDL2

struct = {DGGhotTrap, $
          inherits IDL_Object,    $
          inherits IDLgrPolyline, $
          graphic:   ptr_new(),   $ ; coordinates of graphical representation
          rc:        fltarr(3),   $ ; 3D position [pixels]
          alpha:     0.,          $ ; relative amplitude
          phase:     0.,          $ ; relative phase
          amplitude: ptr_new(),   $ ; amplitude profile
          phi:       ptr_new(),   $ ; phase profile
          ell:       0.           $ ; winding number
         }
end
