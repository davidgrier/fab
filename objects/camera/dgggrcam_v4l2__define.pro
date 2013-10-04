;+
; NAME:
;    DGGgrCam_V4L2
;
; PURPOSE:
;    Object for acquiring and displaying images from a camera
;    using libv4l (Video4Linux2) to handle hardware interfacing.
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
;    DGGgrCam_V4L2::GetProperty
;
;    DGGgrCam_V4L2::SetProperty
;
;    DGGgrCam_V4L2::Snap: Take a picture and transfer it to the 
;        underlying IDLgrImage
;
;    DGGgrCam_V4L2::Snap(): Take a picture, transfer it to the 
;        underlying IDLgrImage, and then return the image data 
;        from the Image object.
;
; PROCEDURE:
;     Calls routines from the IDLVIDEO interface to the V4L2
;     highgui library.
;
; MODIFICATION HISTORY:
; 01/26/2011 Written by David G. Grier, New York University
; 02/25/2011 DGG Adapted from DGGgrCam_V4L2 to acquire images
;    directly into the data buffer of the underlying IDLgrImage
;    object.
; 03/15/2011 DGG Adapted from DGGgrCam_OpenCV
; 03/22/2011 DGG Correctly implemented Snap.
; 03/23/2011 DGG use _ref_extra in Get/SetProperty and Init
; 09/16/2013 DGG record timestamp for each acquired frame.
;
; Copyright (c) 2011-2013 David G. Grier
;-

;;;;;
;
; DGGgrCam_V4L2::Snap()
;
; inherited from DGGgrCam::Snap()
;

;;;;;
;
; DGGgrCam_V4L2::Snap
;
; Transfers a picture to the image
;
pro DGGgrCam_V4L2::Snap

COMPILE_OPT IDL2, HIDDEN

ok = call_external("idlv4l2.so", "idlv4l2_readframe", $
                   /cdecl, self.debug, $
                   (*self.stream).fd, *(self.buffer))
if ok then begin
   self.timestamp = systime(1)
   self.setproperty, data = *self.buffer;, /no_copy
endif
end

;;;;;
;
; DGGgrCam_V4L2::SetProperty
;
; Set the camera properties
;
; FIXME: This should be implemented properly
;

;;;;;
;
; DGGgrCam_V4L2::GetProperty
;
; Get the properties of the camera or of the
; underlying IDLgrImage object.
;
pro DGGgrCam_V4L2::GetProperty, device_name = device_name, $
                                _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

self->DGGgrCam::GetProperty, _extra = re
device_name = self.device_name
end

;;;;;
;
; DGGgrCam_V4L2::Cleanup
;
; Close video stream
;
pro DGGgrCam_V4L2::Cleanup

COMPILE_OPT IDL2, HIDDEN

self->DGGgrCam::Cleanup
idlv4l2_close, *self.stream
ptr_free, self.stream
ptr_free, self.buffer
end

;;;;;
;
; DGGgrCam_V4L2::Init
;
; Initialize the DGGgrCam_V4L2 object:
; Open the video stream
; Load an image into the IDLgrImage object
;
function DGGgrCam_V4L2::Init, device_name = device_name, $
                              _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

catch, error
if (error ne 0L) then begin
   catch, /cancel
   return, 0
endif

if isa(device_name, 'String') then $
   self.device_name = device_name $
else $
   self.device_name = "/dev/video0"

stream = idlv4l2_open(self.device_name, debug = self.debug)

if ~isa(stream, 'IDLV4L2') then $
   return, 0

a = idlv4l2_readframe(stream, gray = self.grayscale, debug = self.debug)

if n_elements(a) le 1 then $
   return, 0

if (self->DGGgrCam::Init(a, _extra = re) ne 1) then begin
   idlv4l2_close, stream
   return, 0
endif

self.buffer = ptr_new(a, /no_copy)
self.stream = ptr_new(stream)

self.name = 'DGGgrCam_V4L2'
self.description = 'V4L2 Camera'

return, 1
end

;;;;;
;
; DGGgrCam_V4L2__define
;
; Define the DGGgrCam_V4L2 object
;
pro DGGgrCam_V4L2__define

COMPILE_OPT IDL2

struct = {DGGgrCam_V4L2,   $
          inherits DGGgrCam, $
          device_name: "",    $
          buffer: ptr_new(),  $
          stream: ptr_new()   $
         }
end
