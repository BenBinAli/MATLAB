%% BME 3026 LAB: ECG processing of ONE team's Stroop-test .MAT file
% Put this script and analyzeStroopECG.m in the SAME folder.
% Put the .mat recording there too (or specify an absolute file path).
% MATLAB R2019b+; Signal Processing Toolbox required.
%
% 1) Import ECG + read real Fs from isi/isi_units (0.5 ms => 2000 Hz).
% 2) Resample with antialiasing to 250 Hz; explain the Nyquist theorem.
% 3) 0.5--40 Hz zero-phase bandpass filtering.
% 4) Divide into 5-min pre / Stroop / 5-min post segments.
% 5) Detect R peaks and approximate PQRST peaks.
% 6) Calculate RR, HR, SDNN and RMSSD; produce plots + CSV tables.

clear; clc; close all;

%% STEP 0 -- SET YOUR TEAM FILE NAME
scriptFolder = fileparts(mfilename('fullpath'));
if isempty(scriptFolder), scriptFolder = pwd; end
fileName = fullfile('H:\Documents\Academic\PhD\Teaching\Biomedical signal processing Experiments\Week 241126', 'merveBME3026.ECG.mat');
% Example: fileName = 'C:\Users\student\Desktop\Team01.ECG.mat';

%% EXPERIMENT SETTINGS
settings = struct();
settings.FsTarget = 250;           % final Fs (Hz)
settings.preRest_s = 5*60;        % first resting period, seconds
settings.postRest_s = 5*60;       % final resting period, seconds

% If you KNOW the task's actual start/end from the experiment notes,
% enter them below. Empty means 'start at 300 s; end 300 s before finish'.
settings.stroopStart_s = [];
settings.stroopEnd_s = [];

% Leave empty if .mat includes isi and isi_units, as the sample does.
% For another .mat without sampling metadata, manually enter its true Fs.
settings.FsOriginalOverride = [];

settings.zoomStart_s = 30;
settings.zoomDuration_s = 6;
settings.showFigures = true;
settings.exportFiles = true;

%% RUN ALL PROCESSING AND EXPORT RESULTS
result = analyzeStroopECG(fileName, settings);

%% QUICK DISPLAY
fprintf('\n===== PHASE SUMMARY: %s =====\n',result.recording);
disp(result.summary);
fprintf('Beats with timestamped R peaks: %d\n',height(result.beats));
fprintf('Review Phase_summary.csv and PQRST_and_RR_by_beat.csv.\n');
