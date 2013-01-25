;+
; NAME:
;    FAB_ROI
;
; PURPOSE:
;    Region-of-interest object for FAB.  Inherits methods and
;    properties of IDLgrModel.
;
; PROPERTIES:
;    R0: [x0, y0] - coordinates of one corner of ROI
;    
;    R1: [x1, y1] - coordinates of opposite corner of ROI
;
; METHODS:
;    FAB_ROI::GetProperty
;
;    FAB_ROI::SetProperty
;
;    FAB_ROI::ContainsPoints(r)
;        Returns 1 for each point in r that is contained within
;        the ROI.  r is a [2,npts] or [3,npts] array of coordinates
;        to be tested.
;
;    FAB_ROI::DrawROI
;        Draws the box describing the ROI on the screen.
;
; MODIFICATION HISTORY:
; 02/01/2011 Written by David G. Grier, New York University
; 05/04/2012 DGG ensure that parameters are numbers.
;
; Copyright (c) 2011-2012, David G. Grier
;-

;;;;;
;
; FAB_ROI::ContainsPoints(r)
;
; Returns a vector of values, one for each input point, determining
; whether points are inside the ROI
;
function fab_roi::ContainsPoints, r

COMPILE_OPT IDL2, HIDDEN

x = r[0,*]
y = r[1,*]
z = 0.*x + 0.01
return, *self.p.containspoints(x, y, z)
end

;;;;;
;
; FAB_ROI::DRAWROI
;
; Draw the box representing the ROI
;
pro fab_roi::DrawROI

COMPILE_OPT IDL2, HIDDEN

z = 0.01                        ; keeps ROI visible above image on screen
x0 = self.r0[0]
y0 = self.r0[1]
x1 = self.r1[0]
y1 = self.r1[1]

data = [[x0, y0, z], $
        [x1, y0, z], $
        [x1, y1, z], $
        [x0, y1, z], $
        [x0, y0, z]  $
       ]

*self.p->setproperty, data = data

end

;;;;;
;
; FAB_ROI::SETPROPERTY
;
; Set properties of the FAB_ROI object
;
pro fab_roi::SetProperty, r0 = r0, $
                          r1 = r1, $
                          _extra = e

COMPILE_OPT IDL2, HIDDEN

if (isa(r0, /number) and n_elements(r0) eq 2) then $
   self.r0 = r0

if (isa(r1, /number) and n_elements(r1) eq 2) then $
   self.r1 = r1

self->IDLgrModel::SetProperty, _extra = e
*self.p->setproperty, _extra = e

self->drawroi
end

;;;;;
;
; FAB_ROI::GETPROPERTY
;
; Get properties of the FAB_ROI object
;
pro fab_roi::GetProperty, r0 = r0, $
                          r1 = r1, $
                          _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

r0 = self.r0
r1 = self.r1
self->IDLgrModel::GetProperty, _extra = re
*self.p->getproperty, _extra = re

end

;;;;;
;
; FAB_ROI::CLEANUP
;
; Free resources
;
pro fab_roi::Cleanup

COMPILE_OPT IDL2, HIDDEN

if isa(self.p) then begin
   obj_destroy, *self.p
   ptr_free, self.p
endif

self->IDLgrModel::Cleanup
end

;;;;;
;
; FAB_ROI::INIT
;
; Initialize region of interest
;
function fab_roi::Init, r0 = r0, $
                        r1 = r1, $
                        _extra = e

COMPILE_OPT IDL2, HIDDEN

if (self->IDLgrModel::Init(_extra = e) ne 1) then $
   return, 0

p = IDLgrROI(color = [239, 234, 7], linestyle = 2, _extra = e)
self.p = ptr_new(p, /no_copy)

self->IDLgrModel::Add, *self.p

if (isa(r0, /number) and n_elements(r0) eq 2) then begin
   self.r0 = r0
   self.r1 = r0
endif

if (isa(r1, /number) and n_elements(r1) eq 2) then begin
   self.r1 = r1
   if n_elements(r0) eq 2 then $
      self.r0 = r1
endif

self.drawroi

return, 1
end

;;;;;
;
; FAB_ROI__DEFINE
;
; Define the FAB_ROI object class
;
pro fab_roi__define

COMPILE_OPT IDL2

struct = {fab_roi,             $
          inherits IDLgrModel, $
          p:  ptr_new(),       $ ; IDLanROI object
          r0: fltarr(2),       $ ; starting corner
          r1: fltarr(2)        $ ; ending corner
         }
end
