;+
; NAME:
;    DGGgrCam_OpenCV
;
; PURPOSE:
;    Object for acquiring and displaying images from a camera
;    using OpenCV to handle hardware interfacing.
;
; CATEGORY:
;    Image acquisition, hardware control, object graphics
;
; PROPERTIES:
;    CAMERA: index of the OpenCV camera to open
;    DIMENSIONS: [w,h] dimensions of image (pixels)
;    GRAYSCALE: if set, images should be cast to grayscale.
;    BRIGHTNESS: range [0, 1]
;    CONTRAST:   range [0, 1]
;
; METHODS:
;    DGGgrCam_OpenCV::GetProperty
;
;    DGGgrCam_OpenCV::SetProperty
;
;    DGGgrCam_OpenCV::Snap: Take a picture and transfer it to the 
;        underlying IDLgrImage
;
;    DGGgrCam_OpenCV::Snap(): Take a picture, transfer it to the 
;        underlying IDLgrImage, and then return the image data 
;        from the Image object.
;
; PROCEDURE:
;     Calls routines from the IDLVIDEO interface to the OpenCV
;     highgui library.
;
; MODIFICATION HISTORY:
; 01/26/2011 Written by David G. Grier, New York University
; 02/25/2011 DGG Adapted from DGGgrCam_OpenCV to acquire images
;    directly into the data buffer of the underlying IDLgrImage
;    object.
; 03/23/2011 DGG Use _ref_extra in Get/SetProperty and Init
;    Corrected use of NO_COPY on memory transfers.
; 04/29/2011 DGG make BRIGHTNESS and CONTRAST registered properties
;    that control camera operation
; 05/04/2012 DGG check parameters in Init and SetProperty.
; 09/16/2013 DGG record timestamp for each acquired frame.
;
; Copyright (c) 2011-2013 David G. Grier
;-

;;;;;
;
; DGGgrCam_OpenCV::Snap()
;
; inherited from DGGgrCam::Snap()
;

;;;;;
;
; DGGgrCam_OpenCV::Snap
;
; Transfers a picture to the image
;
pro DGGgrCam_OpenCV::Snap

COMPILE_OPT IDL2, HIDDEN

w = long(self.dimensions[0])
h = long(self.dimensions[1])
s = *self.stream
frameready = call_external('idlvideo.so', 'video_frameready', /cdecl, $
                           s.stream, self.debug)
if frameready then begin
   error = call_external('idlvideo.so', 'video_readvideoframe', /cdecl, $
                         s.stream, $
                         *self.buffer, w, h, $
                         self.grayscale, $
                         self.debug)
   self.timestamp = systime(1)
   self.setproperty, data = *self.buffer
endif
end

;;;;;
;
; DGGgrCam_OpenCV::SetProperty
;
; Set the camera properties
;
pro DGGgrCam_OpenCV::SetProperty, brightness = brightness, $
                                  contrast = contrast, $
                                  _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

self->DGGgrCAM::SetProperty, _extra = re

if isa(brightness, /scalar, /number) then $
   void = video_property(*self.stream, brightness, /brightness, $
                         debug = self.debug)

if isa(contrast, /scalar, /number) then $
   void = video_property(*self.stream, contrast, /contrast, $
                        debug = self.debug)

end

;;;;;
;
; DGGgrCam_OpenCV::GetProperty
;
; Get the properties of the camera or of the
; underlying IDLgrImage object.
;
pro DGGgrCam_OpenCV::GetProperty, camera = camera, $
                                  brightness = brightness, $
                                  contrast = contrast, $
                                  _ref_extra = re

COMPILE_OPT IDL2, HIDDEN

self->DGGgrCam::GetProperty, _extra = re

if arg_present(camera) then $
   camera = self.camera

if arg_present(brightness) then $
   brightness = video_property(*self.stream, /brightness, debug = self.debug)

if arg_present(contrast) then $
   contrast = video_property(*self.stream, /contrast, debug = self.debug)

end

;;;;;
;
; DGGgrCam_OpenCV::Cleanup
;
; Close video stream
;
pro DGGgrCam_OpenCV::Cleanup

COMPILE_OPT IDL2, HIDDEN

self->DGGgrCam::Cleanup
close_video, *self.stream
ptr_free, self.stream
ptr_free, self.buffer
end

;;;;;
;
; DGGgrCam_OpenCV::Init
;
; Initialize the DGGgrCam_OpenCV object:
; Open the video stream
; Load an image into the IDLgrImage object
;
function DGGgrCam_OpenCV::Init, camera = camera, $
                                brightness = brightness, $
                                contrast = contrast, $
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

if self.dimensions[0] ne 0 then begin ; overriding default geometry
   s = open_videocamera(self.camera, $
                        geometry = self.dimensions, $
                        grayscale = self.grayscale, $
                        debug = self.debug)
endif else begin
   s = open_videocamera(self.camera, $
                        grayscale = self.grayscale, $
                        debug = self.debug)
endelse

if ~is_videostream(s) then $
   return, 0

a = read_videoframe(s, debug = self.debug)
if n_elements(a) le 1 then $
   return, 0

if isa(brightness, /scalar, /number) then $
   void = video_property(s, brightness, /brightness, debug = self.debug)

if isa(contrast, /scalar, /number) then $
   void = video_property(s, contrast, /contrast, debug = self.debug)

self.buffer = ptr_new(a, /no_copy)
self.setproperty, data = *self.buffer
self.stream = ptr_new(s, /no_copy)

self.name = 'DGGgrCam_OpenCV'
self.description = 'OpenCV Camera'
self->registerproperty, 'brightness', /FLOAT, NAME = 'Brightness', $
                        DESCRIPTION = 'Camera brightness', $
                        VALID_RANGE = [0., 1., 0.01]
self->registerproperty, 'contrast', /FLOAT, NAME = 'Contrast', $
                        DESCRIPTION = 'Camera contrast', $
                        VALID_RANGE = [0., 1., 0.01]

return, 1
end

;;;;;
;
; DGGgrCam_OpenCV__define
;
; Define the DGGgrCam_OpenCV object
;
pro DGGgrCam_OpenCV__define

COMPILE_OPT IDL2

struct = {DGGgrCam_OpenCV,   $
          inherits DGGgrCam, $
          buffer: ptr_new(), $
          stream: ptr_new(), $
          camera: 0          $
         }
end
