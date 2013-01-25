;+
; NAME:
;    DGGhotTrappingPattern
;
; PURPOSE:
;    Container object for groups of optical traps that both
;    provides an IDLgrModel for their graphical representation
;    and also transmits their physical characteristics to a
;    DGGhotCGH object that computes the pattern's hologram.
;
; PROPERTIES:
;    DGGhotTrappingPattern inherits the properties and methods
;    of IDLgrModel.
;
;    GROUPS [IGS] DGGhotTrapGroup objects contained within the pattern.
;        Groups are added with the DGGhotTrappingPattern::Add method.
;        Groups are automatically removed when they are destroyed.
;
;    TRAPS  [IGS] DGGhotTrap objects contained within the pattern.
;        Traps are added with the DGGhotTrappingPattern::Add method
;        by which they are bundled into groups of type DGGhotTrapGroup.
;
;    CGH    [IGS] Object that computes the hologram associated with the
;        groups of traps in the pattern.  This computational pipeline
;        must inherit the class DGGhotCGH.
;
; METHODS:
;    DGGhotTrappingPattern::GetProperty
;
;    DGGhotTrappingPattern::SetProperty
;
;    DGGhotTrappingPattern::Add, groups, /noproject
;        Add objects of type DGGhotTrapGroup to the trapping
;        pattern, and project the result using the Project method.
;        Setting NOPROJECT adds the groups without projecting
;        the result.
;
;    DGGhotTrappingPattern::Project
;        Project the hologram encoding the groups of traps by
;        transferring trap data to the CGH.
;
;    DGGhotTrappingPattern::Clear
;        Destroy all groups of traps in the trapping pattern, and
;        projects the result.
;
; MODIFICATION HISTORY:
; 01/20/2011 Written by David G. Grier, New York University
; 03/23/2011 DGG Use _ref_extra in Get/SetProperty and Init
; 03/25/2011 DGG added TRAPS property to Get/Set trap objects
;     in the trapping pattern, rather than just the trap groups.
;     Compute holograms with TRAPS rather than TRAPDATA.
;     Documentation fixes.
; 02/03/2012 DGG Using SetProperty for TRAPS or GROUPS now clears the
;     trapping pattern and sets it explicitly to the specified traps
;     or groups of traps.  The Add method now works for both traps and
;     groups.  Added traps are bundled into a group.
;
; Copyright (c) 2011-2012, David G. Grier
;-

;;;;;
;
; DGGhotTrappingPattern::Project
;
; Transfer data from the traps to the CGH pipeline
;
pro DGGhotTrappingPattern::Project

COMPILE_OPT IDL2, HIDDEN

self.getproperty, traps = traps
self.cgh.setproperty, traps = traps

end

;;;;;
;
; DGGhotTrappingPattern::Clear
;
; Delete all traps in trapping pattern
;
pro DGGhotTrappingPattern::Clear

COMPILE_OPT IDL2, HIDDEN

groups = self.get(/all)
foreach group, groups do begin
   if isa(group, 'DGGhotTrapGroup') then begin
      obj_destroy, group
   endif
endforeach

self.project

end

;;;;;
;
; DGGhotTrappingPattern::GetProperty
;
; Get properties of the trapping pattern
;
pro DGGhotTrappingPattern::GetProperty, groups     = groups,   $
                                        traps      = traps,    $
                                        trapdata   = trapdata, $
                                        _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

self->IDLgrModel::GetProperty, _extra = re

groups = self.get(/all, isa = 'DGGhotTrapGroup', count = ngroups)
if ngroups le 0 then $
   groups = []

if arg_present(traps) then begin
   traps = []
   for j = 0, ngroups-1 do begin
      groups[j].getproperty, traps = this
      traps = [traps, this]
   endfor
endif

if arg_present(trapdata) then begin
   trapdata = []
   for j = 0, ngroups - 1 do begin
      groups[j].getproperty, trapdata = this
      trapdata = [[trapdata], [this]]
   endfor
endif

end

;;;;;
;
; DGGhotTrappingPattern::SetProperty
;
; Set properties of the trapping pattern
;
pro DGGhotTrappingPattern::SetProperty, cgh        = cgh,      $
                                        traps      = traps,    $
                                        groups     = groups,   $
                                        trapdata   = trapdata, $
                                        _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

self->IDLgrModel::SetProperty, _extra = re

if isa(cgh, 'DGGhotCGH') then $
   self.cgh = cgh

if isa(traps, 'objref') then begin
   self.clear
   self.add, traps
endif

if isa(groups, 'objref') then begin
   if ~isa(traps) then self.clear
   self.add, groups
endif

if n_elements(trapdata) ge 5 then begin
   self.clear
   group = DGGhotTrapGroup()
   ntraps = n_elements(trapdata[0,*])
   for n = 0, ntraps-1 do $
      group.add, DGGhotTweezer(rc = trapdata[0:2, n], $
                               alpha = trapdata[3, n], $
                               phase = trapdata[4, n])
   self.add, group
endif

end
                                        
;;;;;
;
; DGGhotTrappingPattern::Add
;
; Add the Trap to the Model and project the full trapping pattern
;
pro DGGhotTrappingPattern::Add, this, $
                                noproject = noproject

COMPILE_OPT IDL2, HIDDEN

if isa(this) then begin
   if isa(this[0], 'DGGhotTrapGroup') then $
      self->IDLgrModel::Add, this $
   else if isa(this[0], 'DGGhotTrap') then $
      self->IDLgrModel::Add, DGGhotTrapGroup(this)
endif

if ~keyword_set(noproject) then $
   self.project

end

;;;;;
;
; DGGhotTrappingPattern::Cleanup
;
; Free resources used by the trapping pattern
;
;pro DGGhotTrappingPattern::Cleanup

;obj_destroy, self.cgh
;self->IDLgrModel::Cleanup

;end

;;;;;
;
; DGGhotTrappingPattern::Init
;
; Initialize the Model and computational pipeline
; for a trapping pattern
;
function DGGhotTrappingPattern::Init, traps = traps, $
                                      groups = groups, $
                                      cgh = cgh, $
                                      _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

if (self->IDLgrModel::Init(_extra = re) ne 1) then $
   return, 0

if isa(cgh, 'DGGhotCGH') then $
   self.cgh = cgh

if isa(traps, 'objref') then $
   self.add, traps

if isa(groups, 'objref') then $
   self.add, groups

return, 1
end

;;;;;
;
; DGGhotTrappingPattern__define
;
; Define the structure of a trapping pattern, which
; includes an IDL Model for visualizing groups of traps and
; a pipeline for calculating holograms.
;
pro DGGhotTrappingPattern__define

COMPILE_OPT IDL2

struct = {DGGhotTrappingPattern, $
          inherits IDLgrModel, $ ; graphical representation of traps
          cgh:  obj_new() $      ; pipeline for calculating hologram
         }
end
