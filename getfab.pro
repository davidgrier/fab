;+
; NAME:
;    getfab
;
; PURPOSE:
;    Returns the base state structure of a running instance of FAB.
;    This provides access to all of the subsystems of FAB, including
;    objects controlling its hardware and defining its traps.
;
; CATEGORY:
;    Holographic optical trapping, video microscopy, instrument control
;
; CALLING SEQUENCE:
;    s = getfab()
;
; INPUTS:
;    None
;
; OUTPUTS:
;    s: structure of type fabstate, which is documented in fab.pro.
;       Returns -1 on failure.
;
; COMMON BLOCKS:
;    managed: Reads data from the common block used by XMANAGER to
;       manage the widget hierarchy in FAB.
;
; MODIFICATION HISTORY:
; 10/04/2011 Written by David G. Grier, New York University.
;
; Copyright (c) 2011, David G. Grier
;
;-
function getfab

common managed, ids, names, modalList

nmanaged = n_elements(ids)
if (nmanaged lt 1) then begin
   message, "fab is not running", /inf
   return, 0
endif

w = where(names eq 'fab', ninstances)
if ninstances ne 1 then begin
   message, "fab is not running", /inf
   return, 0
endif

widget_control, ids[w], get_uvalue = s

return, s
end
