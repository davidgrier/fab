;+
; NAME:
;    DGGhotTrapGroup
;
; PURPOSE:
;    A group of traps combines one or more individual traps into a
;    unit that may be manipulated.  The DGGhotTrapGroup is an IDL
;    container object, which also serves as an IDLgrModel for
;    displaying its traps' graphical representations.
;
; ORGANIZING PRINCIPLES:
;    A trapping pattern contains zero or more groups of traps.
;
;    Each group contains one or more traps, such as optical tweezers
;
;    Every trap belongs to a group.
;
;    Creating a "trap" involves creating a group, creating a trap, then
;    adding the trap to the group.
;
;    Removing the last trap from a group causes the group to be destroyed.
; 
;    Groups can be combined or broken up.
;    Combination works by moving all of the traps from one group to another.
;    Removing a trap from a group involves creating a new group, 
;    adding the new group to the parent trapping pattern, and
;    adding the trap to the new group.
;
;    Destroying a group destroys the traps in the group.
;
;    A group has states that are denoted by the color of its traps.
;        0: immutable: not under GUI control, except for destruction
;        1: normal
;        2: translating
;        3: rotating
;        4: grouping
;
; PROPERTIES:
;    DGGhotTrapGroup inherits the properties and methods of
;    IDLgrModel, with some additions and modifications.
;
;    TRAPS: The optical traps contained in the group, all of which
;        must inherit the DGGhotTrap class.  Traps are added with the
;        DGGhotTrapGroup::Add method and removed with the 
;        DGGhotTrapGroup::Remove method.
;        (I/G)
;
;    TRAPDATA: [5, ntraps] array of data describing the traps in the
;        group.  Abstracted from the DGGhotTrap objects contained in
;        the group, as needed.
;        TRAPDATA[0:2, *]: [x,y,z] coordinates of the traps
;        TRAPDATA[3,   *]: alpha -- relative amplitude of the traps
;        TRAPDATA[4,   *]: phi   -- relative phase of the traps
;        (G)
;
;    RS: [xs, ys, zs] coordinate of the group's current
;        selection point
;        (I/G/S)
;
;    RC: [xc, yc, zc] coordinate ot the group's geometric center.
;        This is computed with the SetCenter method.
;        (G)
;
;    COLOR: [3,5] byte array of the RGB colors that will color the
;        group's traps in each state.
;        (I/G)
;
;    STATE: the group's current state
;        (I/G/S)
;
; METHODS:
;    DGGhotTrapGroup::GetProperty
;
;    DGGhotTrapGroup::SetProperty
;
;    DGGhotTrapGroup::Add, traps
;        Add TRAPS to the group.  TRAPS may be a DGGhotTrap,
;        an array of DGGhotTrap objects, or a  DGGhotTrapGroup
;
;    DGGhotTrapGroup::Remove, traps
;        Uses the IDLgrModel method to remove TRAPS from the current
;        group.  The object destroys itself after its last IDLhotTrap
;        is removed.
;
;    DGGhotTrapGroup::IsMoveable(/override)
;        Returns TRUE if the group can be moved (state > 0) and
;        FALSE otherwise.
;        Setting OVERRIDE returns TRUE for all groups.
;
;    DGGhotTrapGroup::MoveTo, r, /override
;        Move a "normal" group's selection point, RS, to R.
;        R may be a two- or three-dimensional coordinate.
;        Set OVERRIDE to move an "immutable" group.
;
;    DGGhotTrapGroup::MoveBy, dr, /override
;        Move a "normal" group's selection point, RS, by a
;        displacement DR.  DR may be a two- or three-dimensional
;        array.
;        Set OVERRIDE to move an "immutable" group.
;
;    DGGhotTrapGroup::RotateTo, xy, /override
;        Rotate a "normal" group about its center, RC, so that its
;        selection point, RS, points along the vector connecting
;        RC to XY.
;        Set OVERRIDE to rotate an "immutable" group.
;
; MODIFICATION HISTORY:
; 01/20/2011 Written by David G. Grier, New York University
; 01/29/2011 DGG Added IsMoveable() method.  Implemented 3D rotations
;     using quaternions.
; 02/05/2011 DGG Add method incorporates DGGhotTrapGroup objects
;     as well as DGGhotTrap.
; 03/23/2011 DGG use _ref_extra in Init
; 06/11/2012 DGG don't clobber self.rs[2] when setting rs[0:1]
;
; Copyright (c) 2011, David G. Grier
;-

;;;;;
;
; DGGhotTrapGroup::Project
;
pro DGGhotTrapGroup::Project

if isa(self.parent, 'DGGhotTrappingPattern') then $
   self.parent.project
end

;;;;;
;
; DGGhotTrapGroup::IsMoveable()
;
; Returns 1 if the trap can be moved, and 0 otherwise
;
function DGGhotTrapGroup::IsMoveable, override = override

COMPILE_OPT IDL2, HIDDEN

return, (self.state gt 0) or keyword_set(override)
end

;;;;;
;
; DGGhotTrapGroup::SetCenter
;
; Set the center point of the group of traps.
; This is used for rotations.  It _could_ be
; weighted by alpha, but isn't.
;
pro DGGhotTrapGroup::SetCenter

COMPILE_OPT IDL2, HIDDEN

traps = self.get(/all, isa = 'DGGhotTrap')
self.rc *= 0.
foreach trap, traps, n do begin
   trap.getproperty, rc = rc
   self.rc += rc
endforeach
self.rc /= float(n)

end

;;;;;
;
; DGGhotTrapGroup::RotateTo
;
; Rotate the group about its center
;
pro DGGhotTrapGroup::RotateTo, xy, $
                               override = override

COMPILE_OPT IDL2, HIDDEN

if ~self->ismoveable(override = override) then $
   return

; quaternion for rotation
r1 = self.rs - self.rc
s1 = sqrt(total(r1^2))
xy2 = xy - self.rc
s2 = sqrt(total(xy2^2))
r2 = [xy2, (s1 gt s2) ? sqrt(s1^2 - s2^2) : 0.]

q = quaternion(v1 = r1, v2 = r2)
q.normalize

traps = self.get(/all, isa = 'DGGhotTrap')
foreach trap, traps do begin
   trap.getproperty, rc = rn
   trap.setproperty, rc = q.rotatevector(rn - self.rc) + self.rc
endforeach
self.rs = q.rotatevector(self.rs - self.rc) + self.rc

self.project

end

;;;;;
;
; DGGhotTrapGroup::MoveBy
;
; Move the group by a specified displacement
;
pro DGGhotTrapGroup::MoveBy, dr, $
                             override = override

COMPILE_OPT IDL2, HIDDEN

if ~self.ismoveable(override = override) then $
   return

traps = self.get(/all, isa = 'DGGhotTrap')

foreach trap, traps do $
   trap.moveby, dr

case n_elements(dr) of 
   3: self.rs += dr
   2: self.rs[0:1] += dr
   else:
endcase

self.project

end

;;;;;
;
; DGGhotTrapGroup::MoveTo
;
; Move the trap group's selection point to a specified position
;
pro DGGhotTrapGroup::MoveTo, r, $
                             override = override

COMPILE_OPT IDL2, HIDDEN

self.moveby, r - self.rs, override = override

end

;;;;;
;
; DGGhotTrapGroup::GetProperty
;
; Get the properties of a group of traps
;
pro DGGhotTrapGroup::GetProperty, traps = traps, $
                                  rs = rs, $
                                  rc = rc, $
                                  state = state, $
                                  trapdata = trapdata, $
                                  _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

self->IDLgrModel::GetProperty, _extra = re

if arg_present(traps) then $
   traps = self.get(/all, isa = 'DGGhotTrap')

rs = self.rs

if arg_present(rc) then begin
   self.setcenter
   rc = self.rc
endif

state = self.state

if arg_present(trapdata) then begin
   traps = self.get(/all)
   trapdata = []
   foreach trap, traps do $
      if isa(trap, 'DGGhotTrap') then begin
         trap.getproperty, trapdata = thisdata
         trapdata = [[trapdata],[thisdata]]
      endif
endif

end

;;;;;
;
; DGGhotTrapGroup::SetProperty
;
; Set the properties of a group of traps, or of the
; individual traps within the group
;
pro DGGhotTrapGroup::SetProperty, rs = rs, $
                                  state = state

COMPILE_OPT IDL2, HIDDEN

case n_elements(rs) of
   3: self.rs = rs
   2: self.rs[0:1] = rs
else:
endcase

if n_elements(state) eq 1 then begin
   self.state = state
   traps = self->get(/all)
   foreach trap, traps do $
      trap.setproperty, color = self.color[*,self. state]
endif

end

;;;;;
;
; DGGhotTrapGroup::Remove
;
; Remove one or more traps from a Trap.
; If the Trap is empty, destroy it, but do not notify the
; parent because the traps may simply have been moved to another
; group.
;
pro DGGhotTrapGroup::Remove, traps

COMPILE_OPT IDL2, HIDDEN

self->IDLgrModel::Remove, traps

if self.count() eq 0 then $
   obj_destroy, self

end

;;;;;
;
; DGGhotTrapGroup::Add
;
; Add traps to the group.  Can add a single object
; of type DGGhotTrap, or an array.
;
pro DGGhotTrapGroup::Add, this

COMPILE_OPT IDL2, HIDDEN

if isa(this, 'DGGhotTrapGroup') then begin
   foreach group, this do begin
      if group eq self then continue
      traps = group.get(/all)
      group.remove, traps
      foreach trap, traps do begin
         trap.setproperty, color = self.color[*, self.state]
         self->IDLgrModel::Add, trap
      endforeach
   endforeach
endif else if isa(this, 'DGGhotTrap') then begin
   foreach trap, this do begin 
      trap.setproperty, color = self.color[*, self.state]
      self->IDLgrModel::Add, trap
   endforeach
endif
end

;;;;;
;
; DGGhotTrapGroup::Cleanup
;
; Destroy group of traps by destroying all constituent traps
;
pro DGGhotTrapGroup::Cleanup

COMPILE_OPT IDL2, HIDDEN

traps = self.get(/all)
foreach trap, traps do $
   if isa(trap, 'DGGhotTrap') then $
      obj_destroy, trap

self->IDLgrModel::Cleanup
end

;;;;;
;
; DGGhotTrapGroup::Init
;
; Create a trap group, optionally containing traps
;
function DGGhotTrapGroup::Init, traps, $
                                rs = rs, $
                                state = state, $
                                _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

if (self->IDLgrModel::Init(_extra = re) ne 1) then $
   return, 0

self.state = (n_elements(state) eq 1) ? state : 1

self.color = [ $
             [191,  62, 255], $ ; immutable   (purple)
             [  0, 255,   0], $ ; normal      (green)
             [200,   0,   0], $ ; translating (red)
             [255, 127,   0], $ ; rotating    (orange)
             [239, 234,   7]  $ ; grouping    (yellow)
             ]

if isa(traps, 'DGGhotTrap') then $
   self.add, traps

case n_elements(rs) of
   3: self.rs = rs
   2: self.rs = [rs, 0.]
else:
endcase

return, 1

end

;;;;;
;
; DGGhotTrapGroup__define
;
; Define the structure of a group of optical traps
;
pro DGGhotTrapGroup__define

COMPILE_OPT IDL2

struct = {DGGhotTrapGroup, $
          inherits IDLgrModel, $
          rs: fltarr(3), $       ; position of the group's selection point
          rc: fltarr(3), $       ; position of the group's center
          color: bytarr(3, 5), $ ; colors for states
          state: 0 $             ; state of the group
         }

end
