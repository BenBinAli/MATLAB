%% BME 3026 LAB: COMPARE TWO ECG DATA COLLECTIONS DURING STROOP
% Put this script and analyzeStroopECG.m in the SAME folder.
% Edit fileA and fileB for your two MAT recordings.
%
% Both recordings are independently downsampled, filtered, segmented,
% and detected using the SAME parameters. Comparison is descriptive:
%   mean heart rate, mean RR, SDNN and RMSSD for Pre / Stroop / Post.
% Do NOT perform a t-test using individual heartbeats as if they were
% independent students: biological replication requires subjects/teams.

clear; clc; close all;

%% STEP 1 -- IDENTIFY TWO FILES TO COMPARE
scriptFolder = fileparts(mfilename('fullpath'));
if isempty(scriptFolder), scriptFolder = pwd; end
fileA = fullfile(scriptFolder, 'merveBME3026.ECG.mat');
fileB = fullfile(scriptFolder, 'Team_B.ECG.mat'); % CHANGE to real second file
labelA = 'Collection A';
labelB = 'Collection B';

if ~isfile(fileA)
    fprintf(2,'Recording A not found: %s\n',fileA);
    fprintf('Edit fileA to point to your first .mat file.\n');
    return;
end
if ~isfile(fileB)
    fprintf(2,'Recording B not found: %s\n',fileB);
    fprintf('Edit fileB to point to the actual second team/collection .mat file.\n');
    fprintf('No comparison was performed; a second dataset is required.\n');
    return;
end

%% STEP 2 -- USE IDENTICAL ECG-PROCESSING SETTINGS
settings = struct();
settings.FsTarget = 250;
settings.preRest_s = 5*60;
settings.postRest_s = 5*60;
settings.showFigures = false;  % avoid opening 12 individual charts
settings.exportFiles = false; % only write the final comparison outputs

% Enter exact event timestamps if recorded. Here, both use first and
% final 5 min as rest, with Stroop in the middle by default.
% Copy the common settings, then allow experiment-specific event markers.
settingsA = settings;
settingsB = settings;
settingsA.stroopStart_s = []; % Collection A actual start, if known
settingsA.stroopEnd_s   = []; % Collection A actual end, if known
settingsB.stroopStart_s = []; % Collection B actual start, if known
settingsB.stroopEnd_s   = []; % Collection B actual end, if known
settingsA.FsOriginalOverride = []; % only if A lacks sampling metadata
settingsB.FsOriginalOverride = []; % only if B lacks sampling metadata

%% STEP 3 -- PROCESS BOTH RECORDINGS
A = analyzeStroopECG(fileA, settingsA);
B = analyzeStroopECG(fileB, settingsB);

if A.Fs ~= B.Fs
    warning('Final sampling rates differ: A %.1f Hz, B %.1f Hz', A.Fs, B.Fs);
end
if abs(A.summary.Duration_s(2) - B.summary.Duration_s(2)) > 10
    warning('Stroop task durations differ. HRV metrics are duration-dependent.');
end
if ~strcmpi(A.units,B.units)
    warning('Amplitude units differ (%s and %s). Do not compare ECG amplitudes.', ...
        A.units,B.units);
end

%% STEP 4 -- COMPUTE PHASE-WISE DIFFERENCES (B MINUS A)
phase = A.summary.Phase;
comparison = table(phase, ...
    A.summary.Duration_s, B.summary.Duration_s, ...
    A.summary.MeanHR_bpm, B.summary.MeanHR_bpm, ...
    B.summary.MeanHR_bpm - A.summary.MeanHR_bpm, ...
    A.summary.MeanRR_s, B.summary.MeanRR_s, ...
    B.summary.MeanRR_s - A.summary.MeanRR_s, ...
    A.summary.SDNN_ms, B.summary.SDNN_ms, ...
    B.summary.SDNN_ms - A.summary.SDNN_ms, ...
    A.summary.RMSSD_ms, B.summary.RMSSD_ms, ...
    B.summary.RMSSD_ms - A.summary.RMSSD_ms, ...
    'VariableNames', {'Phase','Duration_A_s','Duration_B_s', ...
    'HR_A_bpm','HR_B_bpm','DeltaHR_B_minus_A_bpm', ...
    'RR_A_s','RR_B_s','DeltaRR_B_minus_A_s', ...
    'SDNN_A_ms','SDNN_B_ms','DeltaSDNN_B_minus_A_ms', ...
    'RMSSD_A_ms','RMSSD_B_ms','DeltaRMSSD_B_minus_A_ms'});

disp('===== COMPARISON: COLLECTION B MINUS COLLECTION A =====');
disp(comparison);

longSummary = [A.summary; B.summary];
longSummary.Collection = [repmat(string(labelA),3,1); ...
                          repmat(string(labelB),3,1)];
longSummary = movevars(longSummary, 'Collection', 'Before', 'Phase');

%% STEP 5 -- EXPORT COMPARISON TABLES
outputFolder = fullfile(scriptFolder,'ECG_Results','Two_Collections_Comparison');
if ~exist(outputFolder,'dir'), mkdir(outputFolder); end
writetable(comparison,fullfile(outputFolder,'Between_collection_differences.csv'));
writetable(longSummary,fullfile(outputFolder,'Both_collections_phase_summary.csv'));

%% STEP 6 -- PLOT MEAN HEART RATE IN EACH PHASE
f1 = figure('Color','w','Name','A vs B - mean HR');
bar([A.summary.MeanHR_bpm, B.summary.MeanHR_bpm]);
grid on;
set(gca,'XTick',1:3,'XTickLabel',{'Pre','Stroop','Post'});
ylabel('Mean instantaneous heart rate (beats/min)');
xlabel('Experimental phase');
legend(labelA,labelB,'Location','best');
title('Mean HR during the three experimental phases');
saveas(f1,fullfile(outputFolder,'01_mean_heart_rate.png'));

%% STEP 7 -- PLOT INSTANTANEOUS HEART RATE VS TIME IN EACH PHASE
f2 = figure('Color','w','Name','A vs B - HR over phase time');
for j = 1:3
    subplot(3,1,j);
    inA = A.beats.Phase == phase(j) & isfinite(A.beats.HR_bpm);
    inB = B.beats.Phase == phase(j) & isfinite(B.beats.HR_bpm);
    tA = A.beats.R_s(inA) - A.phases.Start_s(j);
    tB = B.beats.R_s(inB) - B.phases.Start_s(j);
    plot(tA/60, A.beats.HR_bpm(inA),'.','MarkerSize',5); hold on;
    plot(tB/60, B.beats.HR_bpm(inB),'.','MarkerSize',5);
    grid on; ylabel('HR (beats/min)');
    title(['Phase: ' char(phase(j))]);
    if j == 1, legend(labelA,labelB,'Location','best'); end
    if j == 3, xlabel('Time from start of phase (min)'); end
end
saveas(f2,fullfile(outputFolder,'02_HR_time_by_phase.png'));

%% STEP 8 -- PLOT TIME-DOMAIN HRV METRICS BY PHASE
f3 = figure('Color','w','Name','A vs B - HRV');
subplot(2,1,1);
bar([A.summary.SDNN_ms, B.summary.SDNN_ms]); grid on;
set(gca,'XTick',1:3,'XTickLabel',{'Pre','Stroop','Post'});
ylabel('SDNN (ms)'); title('Standard deviation of accepted RR intervals');
legend(labelA,labelB,'Location','best');
subplot(2,1,2);
bar([A.summary.RMSSD_ms, B.summary.RMSSD_ms]); grid on;
set(gca,'XTick',1:3,'XTickLabel',{'Pre','Stroop','Post'});
xlabel('Experimental phase'); ylabel('RMSSD (ms)');
title('Root mean square of successive RR differences');
saveas(f3,fullfile(outputFolder,'03_SDNN_RMSSD.png'));

%% STEP 9 -- PLOT RR HISTOGRAMS FOR THE STROOP PHASE
f4 = figure('Color','w','Name','A vs B - Stroop RR intervals');
rrA = A.beats.RR_s(A.beats.Phase == "Stroop");
rrB = B.beats.RR_s(B.beats.Phase == "Stroop");
rrA = rrA(isfinite(rrA));
rrB = rrB(isfinite(rrB));
if ~isempty(rrA) && ~isempty(rrB)
    edges = 0.30:0.04:2.02;
    histogram(rrA,edges,'Normalization','probability','FaceAlpha',0.5);
    hold on;
    histogram(rrB,edges,'Normalization','probability','FaceAlpha',0.5);
    legend(labelA,labelB,'Location','best');
else
    text(0.1,0.5,'Not enough accepted RR intervals for histogram.');
end
grid on; xlabel('Accepted RR interval (s)'); ylabel('Fraction of intervals');
title('Stroop-phase RR-interval distributions');
saveas(f4,fullfile(outputFolder,'04_Stroop_RR_histograms.png'));

%% STEP 10 -- SAVE THE WORKSPACE
save(fullfile(outputFolder,'Comparison_workspace.mat'), ...
    'comparison','longSummary','A','B','labelA','labelB','-v7.3');
fprintf('\nTwo-collection comparison is complete.\n');
fprintf('Comparison files: %s\n',outputFolder);
fprintf('Interpret changes descriptively; two files alone do not justify\n');
fprintf('population-level significance testing or clinical conclusions.\n');
