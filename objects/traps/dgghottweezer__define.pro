;+
; NAME:
;    DGGhotTweezer
;
; PURPOSE:
;    This object abstracts a holographic optical tweezer as the
;    combination of a graphical representation and data describing
;    the 3D position and physical properties of the trap.  This
;    inherits the DGGhotTrap class, and specifies a circle for
;    the graphical representation, whose radius depends on axial
;    position, z.
;
; CATEGORY:
;    Holographic optical trapping, object graphics
;
; PROPERTIES:
;    DGGhotTweezer inherits the properties and methods of
;    the DGGhotTrap class
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
; METHODS:
;    All user-accessible methods for DGGhotTweezer are provided
;    by the DGGhotTrap class.
;
; MODIFICATION HISTORY:
; 12/30/2010 Written by David G. Grier, New York University
; 01/27/2011 DGG completed inheritance from DGGhotTrap
; 03/23/2011 DGG use _ref_extra in Init.  Register name,
;    identifier and description
; 02/04/2012 DGG initialize DGGhotTrap before doing tweezer-specific
;    initialization.
;
; Copyright (c) 2010-2012, David G. Grier
;-

;;;;;
;
; DGGhotTweezer::DrawGraphic
;
; Update graphical representation of an optical tweeer
; Replaces the default method for a DGGhotTrap
;
pro DGGhotTweezer::DrawGraphic

COMPILE_OPT IDL2, HIDDEN

graphic = *self.graphic
radius = (5. + self.rc[2] * 0.02) > 0.1 < 20
graphic[0:1, *] *= radius
graphic[0, *] += self.rc[0]
graphic[1, *] += self.rc[1]

self->IDLgrPolyline::SetProperty, data = graphic
end

;;;;;
;
; DGGhotTweezer::Init
;
function DGGhotTweezer::Init, _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

if (self->DGGhotTrap::Init(_extra = re) ne 1) then $
   return, 0

; override graphic
npts = 10
theta = 2.*!pi/(npts - 1.) * findgen(1, npts)
r = findgen(3, npts)
r[0, *] = sin(theta)
r[1, *] = cos(theta)
r[2, *] = 1.
self.graphic = ptr_new(r, /no_copy)

self.name = 'DGGhotTweezer'
self.identifier = 'DGGhotTweezer'
self.description = 'Holographic Optical Tweezer'
return, 1
end

;;;;;
;
; DGGhotTweezer__define
;
; An optical tweeer is an instance of an optical trap
;
pro DGGhotTweezer__define

COMPILE_OPT IDL2

struct = {DGGhotTweezer, $
          inherits DGGhotTrap $
         }
end
