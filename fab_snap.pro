;+
; NAME:
;    fab_snap
;
; PURPOSE:
;    Acquire video image for analysis from the FAB camera subsystem
;    while optionally displaying intermediate images
;
; USAGE:
;    a = fab_snap([s])
;
; OPTIONAL INPUTS:
;    s: pointer to the fabstate structure of a running fab instance.
;       If not provided, this will be obtained by calling GETFAB.
;
; OUTPUTS:
;    a: Current image from the video camera controlled by FAB.
;       If fab is not running, or is otherwise inaccessible, 
;       fab_snap returns 0.
;
; KEYWORDS:
;    DELAY: delay time, in seconds, before an image should be
;        returned.  System continues to acquire and display images
;        during this interval, although no GUI interaction is
;        possible.  Returns last acquired image.
;
;    MAX: return an image composed of the brightest pixels in a
;        specified number of frames.  May be combined with DELAY.
;
;    MEAN: return an image composed of the average of the specified
;        number of frames.  May be combined with DELAY
;
;    GRAYSCALE: return a grayscale image, even if the camera is taking
;        color pictures.
;
; MODIFICATION HISTORY
; 02/05/2011 Written by David G. Grier, New York University
; 02/16/2011 DGG reset camera for better synchronization.
; 10/04/2011 DGG use GETFAB to obtain fabstate if not provided.
;    Added GRAYSCALE keyword.
;    Documentation updates.
;
; Copyright (c) 2011, David G. Grier
;-
function fab_snap, s, $
                   delay = delay, $
                   max = max, $
                   mean = mean,  $
                   grayscale = grayscale

COMPILE_OPT IDL2

if n_params() eq 0 then begin
   s = getfab()
   if ~isa(*s, 'fabstate') then $
      return, 0
endif

;(*s).o.camera.reset
a = (*s).o.camera.snap()
(*s).o.screen.draw

if keyword_set(delay) then begin
   nframes = delay / (*s).timer
   for i = 1, nframes - 1 do begin
      wait, (*s).timer
      a = (*s).o.camera.snap()
      (*s).o.screen.draw
   endfor
endif

if keyword_set(max) then begin
   for i = 1, max-1 do begin
      wait, (*s).timer
      a = a > (*s).o.camera.snap()
      (*s).o.screen.draw
   endfor
endif

if keyword_set(mean) then begin
   for i = 1, mean-1 do begin
      wait, (*s).timer
      a += float((*s).o.camera.snap())
      (*s).o.screen.draw
   endfor
   a = byte(a/mean)
endif

if keyword_set(grayscale) then begin
   if size(a, /n_dimensions) eq 3 then begin
      dim = size(a, /dimensions)
      ndx = where(dim eq 3) + 1
      a = byte(mean(a, dimension = ndx)) ; FIXME proper RGB weighting
   endif
endif

return, a
end
