%% run_Chameleon.m
%  Launcher for the Chameleon application (v1.0).
%
%  USAGE:
%    >> run_Chameleon
%
%  REQUIREMENTS:
%    - MATLAB R2019b or later  (uifigure / App Designer components)
%    - Image Processing Toolbox  (imhist, rgb2lab, lab2rgb, imwrite, ssim)
%
%  SUPPORTED IMAGE FORMATS:
%    Input:  .tif, .tiff, .jpg, .jpeg, .bmp  (case-insensitive)
%    Output: .tif (LZW, recommended), .jpg (100% quality), .bmp
%
%  MODES:
%    1 - Histogram matching  →  user reference image
%    2 - Histogram matching  →  batch-average CDF
%    3 - Reinhard            →  user reference image
%    4 - Reinhard            →  batch-average synthetic reference
%
%  Use the Pre-flight Inspector (🔍 button) to preview all four methods
%  side by side on any image before committing to a full batch run.

clear; clc;

% Add app folder to path
addpath(fileparts(mfilename('fullpath')));

% Launch
Chameleon;
