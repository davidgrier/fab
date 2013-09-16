;+
; NAME:
;    DGGgrCam_PVAPI
;
; PURPOSE:
;    Object for acquiring and displaying images from a camera
;    using PVAPI to handle hardware interfacing.
;
; CATEGORY:
;    Image acquisition, hardware control, object graphics
;
; SUPERCLASSES
;    DGGgrCam
;
; PROPERTIES:
;    CAMERA: index of the PVAPI camera to open
;    DIMENSIONS: [w,h] dimensions of image (pixels)
;    GRAYSCALE: if set, images should be cast to grayscale.
;
; METHODS:
;    DGGgrCam_PVAPI::GetProperty
;
;    DGGgrCam_PVAPI::SetProperty
;
;    DGGgrCam_PVAPI::Snap: Take a picture and transfer it to the 
;        underlying IDLgrImage
;
;    DGGgrCam_PVAPI::Snap(): Take a picture, transfer it to the 
;        underlying IDLgrImage, and then return the image data 
;        from the Image object.
;
; PROCEDURE:
;     Calls routines from the IDLPVAPI interface to the PVAPI
;     highgui library.
;
; NOTES:
;    ENUM types not properly handled by WIDGET_PROPERTYSHEET, and
;    so disabled.
;    Should properly handle unplug events
;
; MODIFICATION HISTORY:
; 01/26/2011 Written by David G. Grier, New York University
; 03/15/2011 DGG Adapted from DGGgrCam_OpenCV to acquire images
;    directly into the data buffer of the underlying IDLgrImage
;    object.
; 03/23/2011 DGG use _ref_extra in Get/SetProperty and Init
; 10/04/2011 DGG don't clobber self.buffer with /no_copy flag
;    when storing images.
; 11/03/2011 DGG Implemented GetProperty and SetProperty for all
;    camera properties.  Registered those properties that can be
;    modified so that they appear on propertysheet widgets.
; 05/04/2012 DGG Improved parameter checking in SetProperty.
; 05/24/2012 DGG SetProperty requires camera property; not optional.
; 09/16/2013 DGG record timestamp for acquired frames.
;
; Copyright (c) 2011-2013 David G. Grier
;-

;;;;;
;
; DGGgrCam_PVAPI::Snap()
;
; inherited from DGGgrCam::Snap()
;

;;;;;
;
; DGGgrCam_PVAPI::Snap
;
; Transfers a picture to the image
;
pro DGGgrCam_PVAPI::Snap

COMPILE_OPT IDL2, HIDDEN

err = pvcapturequeueframe(self.camera, *self.buffer, self.flags, $
                          debug = self.debug)
err = pvcommandrun(self.camera, "FrameStartTriggerSoftware", $
                   debug = self.debug)
err = pvcapturewaitforframedone(self.camera, 100, debug = self.debug)
self.timestamp = systime(1)
self.setproperty, data = *self.buffer
end

;;;;;
;
; DGGgrCam_PVAPI::SetProperty
;
; Set the properties of the camera.
;
pro DGGgrCam_PVAPI::SetProperty, debug = debug, $
                                 _ref_extra = ex

; Cannot call underlying DGGgrCam methods because _ref_extra
; is used to poll camera properties
self->DGGgrCam::SetProperty, _extra = ex

if arg_present(debug) then $
   self.debug = keyword_set(debug)

camera = self.camera
nprops = n_elements(ex)
for i = 0, nprops-1 do begin
   propname = pvattrname(camera, ex[i], debug = self.debug)
   if strlen(propname) gt 0 then begin
      value = scope_varfetch(ex[i], /ref_extra)
      err = pvattrset(camera, propname, value, debug = self.debug)
   endif
endfor
end

;;;;;
;
; DGGgrCam_PVAPI::GetProperty
;
; Get the properties of the camera or of the
; underlying IDLgrImage object.
;
pro DGGgrCam_PVAPI::GetProperty, camera = camera, $
                                 debug = debug, $
                                 _ref_extra = ex

COMPILE_OPT IDL2, HIDDEN

; Cannot call underlying DGGgrCam methods because _ref_extra
; is used to poll camera properties
self->DGGgrCam::GetProperty, _extra = ex

camera = self.camera

nprops = n_elements(ex)
for i = 0, nprops-1 do begin
   propname = pvattrname(camera, ex[i], debug = self.debug)
   if strlen(propname) gt 0 then begin
      value = pvattrget(camera, propname, debug = self.debug)
      (scope_varfetch(ex[i], /ref_extra)) = value
   endif
endfor

end

;;;;;
;
; DGGgrCam_PVAPI::Cleanup
;
; Close video stream
;
pro DGGgrCam_PVAPI::Cleanup

COMPILE_OPT IDL2, HIDDEN

err = pvcommandrun(self.camera, "AcquisitionStop", debug = self.debug)
err = pvcaptureend(self.camera, debug = self.debug)
err = pvcameraclose(self.camera, debug = self.debug)
;; XXX should check if other cameras are running?
pvuninitialize, debug = self.debug

self->DGGgrCam::Cleanup
ptr_free, self.buffer
end

;;;;;
;
; DGGgrCam_PVAPI::Init
;
; Initialize the DGGgrCam_PVAPI object:
; Open the video stream
; Load an image into the IDLgrImage object
;
function DGGgrCam_PVAPI::Init, camera = camera, $
                               _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

catch, error
if (error ne 0L) then begin
   catch, /cancel
   return, 0
endif

if (self->DGGgrCam::Init(_extra = re) ne 1) then $
   return, 0

self.camera = isa(camera, /scalar, /number) ? camera : 0

err = pvinitialize(debug = self.debug)
if (err ne 0) then $
   return, 0

t = systime(1)
repeat begin
   ncameras = pvcameracount(debug = self.debug)
   if (ncameras le 0) then wait, 0.1
endrep until (ncameras ge 1 || (systime(1) - t ge 5))
if (ncameras le 0) then $
   return, 0

info = pvcameralistex(debug = self.debug)
err = pvcameraopen(self.camera, debug = self.debug)
if (err ne 0) then begin
   pvuninitialize
   return, 0
endif

wrange = pvattrrange(self.camera, "Width", debug = self.debug)
hrange = pvattrrange(self.camera, "Height", debug = self.debug)
err = pvattrset(self.camera, "Width", wrange[1], debug = self.debug)
err = pvattrset(self.camera, "Height", hrange[1], debug = self.debug)
self.dimensions = [pvattrget(self.camera, "Width", debug = self.debug), $
                   pvattrget(self.camera, "Height", debug = self.debug)]

err = pvattrset(self.camera, "PixelFormat", "Mono8", debug = self.debug)
if err ne 0 then $
err = pvattrset(self.camera, "PixelFormat", "Rgb24", debug = self.debug)

err = pvcapturestart(self.camera, debug = self.debug)

err = PvAttr(self.camera, "AcquisitionMode", "Continuous", debug = self.debug)
err = PvAttr(self.camera, "FrameStartTriggerMode", "Software", $
             debug = self.debug)
err = pvcommandrun(self.camera, "AcquisitionStart", debug = self.debug)

err = pvcapturequeueframe(self.camera, a, flags, /allocate, debug = self.debug)
err = pvcommandrun(self.camera, "FrameStartTriggerSoftware", debug = self.debug)
err = pvcapturewaitforframedone(self.camera, 1000, debug = self.debug)

self.buffer = ptr_new(a)
self.setproperty, data = *(self.buffer)

if (self->DGGgrCam::Init(a, _extra = re) ne 1) then begin
   err = pvcameraclose(self.camera)
   pvuninitialize
   return, 0
endif

self.flags = flags

;;; register camera properties
list = pvattrlist(self.camera, debug = self.debug)
for i = 0, n_elements(list)-1 do begin
   prop = list[i]
   info = pvattrinfo(self.camera, prop, debug = self.debug)
   if (info[1] and 3) ne 3 then $
      continue
   case info[0] of
      3: self->registerproperty, prop, /string, sensitive = 0
      ;4: begin
      ;   range = pvattrrange(self.camera, prop, debug = self.debug)
      ;   enumlist = strsplit(range, ',', /extract)
      ;   self->registerproperty, prop, enumlist = enumlist
      ;end
      5: begin
         range = pvattrrange(self.camera, prop, debug = self.debug)
         self->registerproperty, prop, /integer, valid_range = range
      end
      6: begin
         range = pvattrrange(self.camera, prop, debug = self.debug)
         self->registerproperty, prop, /float, valid_range = range
      end
      else:                     ; register nothing
   endcase
endfor

return, 1
end

;;;;;
;
; DGGgrCam_PVAPI__define
;
; Define the DGGgrCam_PVAPI object
;
pro DGGgrCam_PVAPI__define

COMPILE_OPT IDL2

struct = {DGGgrCam_PVAPI,    $
          inherits DGGgrCam, $
          buffer: ptr_new(), $
          flags: bytarr(4),  $
          camera: 0          $
         }
end
