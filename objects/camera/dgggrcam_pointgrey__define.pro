;+
; NAME:
;    DGGgrCam_PointGrey
;
; PURPOSE:
;    Object for acquiring and displaying images from a
;    PointGrey camera using the flycapture2 API.
;
; CATEGORY:
;    Image acquisition, hardware control, object graphics
;
; PROPERTIES:
;    CAMERA: index of the V4L2 camera to open
;    DIMENSIONS: [w,h] dimensions of image (pixels)
;    GRAYSCALE: if set, images should be cast to grayscale.
;
; METHODS:
;    GetProperty
;    SetProperty
;
;    Snap: Take a picture and transfer it to the 
;        underlying IDLgrImage
;
;    Snap(): Take a picture, transfer it to the 
;        underlying IDLgrImage, and then return the image data 
;        from the Image object.
;
; MODIFICATION HISTORY:
; 09/24/2013 Written by David G. Grier, New York University
;
; Copyright (c) 2013 David G. Grier
;-

;;;;;
;
; DGGgrCam_PointGrey::Snap()
;
; inherited from DGGgrCam::Snap()
;

;;;;;
;
; DGGgrCam_PointGrey::Snap
;
; Transfers a picture to the image
;
pro DGGgrCam_PointGrey::Snap

COMPILE_OPT IDL2, HIDDEN

error = call_external(self.dlm, 'read_pgr', *self.buffer)

if ~error then begin
   self.timestamp = systime(1)
   self.setproperty, data = *self.buffer
endif
end

;;;;;
;
; DGGgrCam_PointGrey::SetProperty
;
; Set the camera properties
;
; FIXME: This should be implemented properly
;

;;;;;
;
; DGGgrCam_PointGrey::GetProperty
;
; Get the properties of the camera or of the
; underlying IDLgrImage object.
;
pro DGGgrCam_PointGrey::GetProperty, _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

self->DGGgrCam::GetProperty, _extra = re
end

;;;;;
;
; DGGgrCam_PointGrey::Cleanup
;
; Close video stream
;
pro DGGgrCam_PointGrey::Cleanup

COMPILE_OPT IDL2, HIDDEN

self->DGGgrCam::Cleanup
ptr_free, self.buffer
error = call_external(self.dlm, 'close_pgr')
end

;;;;;
;
; DGGgrCam_PointGrey::Init
;
; Initialize the DGGgrCam_PointGrey object:
; Open the video stream
; Load an image into the IDLgrImage object
;
function DGGgrCam_PointGrey::Init, _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

catch, error
if (error ne 0L) then begin
   catch, /cancel
   return, 0B
endif

self.dlm = '/usr/local/IDL/idlpgr/idlpgr.so'
if ~file_search(self.dlm) then begin
   message, 'Could not find shared object library: '+self.dlm, /inf
   return, 0B
endif

if (self->DGGgrCam::Init(_extra = re) ne 1) then $
   return, 0B

nx = 0
ny = 0
error = call_external(self.dlm, 'open_pgr', nx, ny)
if error then $
   return, 0B

a = bytarr(nx, ny)
self.buffer = ptr_new(a)
self.setproperty, data = a, /no_copy

self.name = 'DGGgrCam_PointGrey'
self.description = 'PointGrey Camera'

return, 1
end

;;;;;
;
; DGGgrCam_PointGrey__define
;
; Define the DGGgrCam_Point object
;
pro DGGgrCam_PointGrey__define

COMPILE_OPT IDL2

struct = {DGGgrCam_PointGrey, $
          inherits DGGgrCam,  $
          dlm: '',            $ 
          buffer: ptr_new()   $
         }
end
