;+
; NAME:
;    fab_gettraps
;
; PURPOSE:
;    Obtain object references to the traps or trapping groups
;    running in a fab session.
;
; CATEGORY:
;    Optical trapping, hardware automation
;
; CALLING SEQUENCE:
;    traps = fab_gettraps()
;
; OUTPUTS:
;    traps: object references to traps in the fab session.
;        !NULL if fab is not running, or has no traps.
;        DGGhotTrap if fab has exactly one trap
;        array of DGGhotTrap objects otherwise
;
; KEYWORD_FLAGS:
;    groups: If set, return object references to trapping groups,
;        rather than to traps.
;
; PROCEDURE:
;    Calls getfab() to obtain the state structure of the running
;    fab process.
;
; EXAMPLE:
;    IDL> traps = fab_gettraps()
;    IDL> help, traps[0]
;
; MODIFICATION HISTORY:
; 05/17/2012 Written by David G. Grier, New York University
; 06/12/2012 DGG Optionally return groups
;
; Copyright (c) 2012 David G. Grier
;-

function fab_gettraps, groups = groups

COMPILE_OPT IDL2

traps = []

s = getfab()
if isa(s, /number) then return, traps

pattern = (*s).o.traps
if ~isa(pattern, 'DGGhotTrappingPattern') then begin
   message, 'FAB has no trapping pattern', /inf
   return, traps
endif

grps = pattern.get(/all)
if isa(grps, /number) then begin
   message, 'FAB has no groups of traps', /inf
   return, traps
endif

if keyword_set(groups) then $
   return, grps

foreach group, grps do $
   traps = [traps, group.get(/all)]

return, traps
end
