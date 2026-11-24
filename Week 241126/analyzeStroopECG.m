function result = analyzeStroopECG(matFile, opts)
% analyzeStroopECG  Reusable ECG analysis for the BME Stroop-test lab.
%
% EXPECTED .MAT FORMAT (verified in merveBME3026.ECG.mat):
%   data         : N-by-1 ECG signal (mV in the example)
%   isi          : sampling interval (0.5 in the example)
%   isi_units    : interval unit ('ms' in the example)
%   units        : signal amplitude unit ('mV' in the example)
%   labels       : signal description
%   start_sample : optional original sample index (not a Stroop marker)
%
% BASIC USAGE:
%   result = analyzeStroopECG('merveBME3026.ECG.mat');
%
% OPTIONS (pass in a struct):
%   FsTarget             = 250;    % Hz; do not upsample slower recordings
%   FsOriginalOverride   = [];     % Hz, only for files missing rate metadata
%   preRest_s            = 300;    % duration of pre-Stroop rest
%   postRest_s           = 300;    % duration of post-Stroop rest
%   stroopStart_s        = [];     % exact task start (empty => 300 s)
%   stroopEnd_s          = [];     % exact task end (empty => end - 300 s)
%   zoomStart_s          = 30;     % seconds for close-up ECG/PQRST plots
%   zoomDuration_s       = 6;
%   showFigures          = true;
%   exportFiles          = true;
%   outputFolder         = '';     % default: ECG_Results/<recording name>
%
% OUTPUTS:
%   result.phases        : duration, boundaries, sample counts
%   result.beats         : PQRST peak timestamps, RR and HR by beat
%   result.summary       : phase-level HR, RR, SDNN, RMSSD
%   result.FsOriginal, result.Fs, result.t, result.ecgFiltered
%
% Requires: MATLAB R2019b+ and Signal Processing Toolbox.
% The P/Q/S/T point detector is an APPROXIMATION for teaching only.
% Automatic beat and HRV results require visual inspection and QC.

if nargin < 2 || isempty(opts)
    opts = struct();
end
FsTarget        = getOption(opts, 'FsTarget', 250);
FsOverride      = getOption(opts, 'FsOriginalOverride', []);
preRest_s       = getOption(opts, 'preRest_s', 300);
postRest_s      = getOption(opts, 'postRest_s', 300);
stroopStart_s   = getOption(opts, 'stroopStart_s', []);
stroopEnd_s     = getOption(opts, 'stroopEnd_s', []);
zoomStart_s     = getOption(opts, 'zoomStart_s', 30);
zoomDuration_s  = getOption(opts, 'zoomDuration_s', 6);
showFigures     = getOption(opts, 'showFigures', true);
exportFiles     = getOption(opts, 'exportFiles', true);
outputFolder    = getOption(opts, 'outputFolder', '');

if ~(ischar(matFile) || isstring(matFile)) || ~isfile(matFile)
    error('ECG:FileNotFound', 'Cannot find MAT file: %s. Check its path.', string(matFile));
end
if ~isscalar(FsTarget) || ~isfinite(FsTarget) || FsTarget <= 80
    error('ECG:TargetFs', 'FsTarget must exceed 80 Hz for a 40-Hz analysis bandwidth.');
end

%% STEP 1 -- LOAD ECG AND READ ITS REAL SAMPLING FREQUENCY
S = load(matFile);
if isfield(S, 'data') && isnumeric(S.data) && isvector(S.data)
    ecgRaw = double(S.data(:));
elseif isfield(S, 'ECG') && isnumeric(S.ECG) && isvector(S.ECG)
    ecgRaw = double(S.ECG(:));
elseif isfield(S, 'ecg') && isnumeric(S.ecg) && isvector(S.ecg)
    ecgRaw = double(S.ecg(:));
else
    error('ECG:MissingSignal', ...
        'No numeric ECG vector found. Expected variable: data, ECG, or ecg.');
end

if numel(ecgRaw) < 1000
    error('ECG:SignalTooShort', 'ECG must contain at least 1000 samples.');
end
if any(~isfinite(ecgRaw))
    bad = ~isfinite(ecgRaw);
    badPct = 100 * nnz(bad)/numel(ecgRaw);
    if badPct > 1
        error('ECG:MissingValues', ...
            '%.2f%% of ECG samples are NaN/Inf (>1%%). Inspect file before analysis.', badPct);
    end
    warning('ECG:InterpolatedSamples', ...
        'Interpolating %.3f%% nonfinite ECG samples; inspect data quality.', badPct);
    ecgRaw(bad) = NaN;
    ecgRaw = fillmissing(ecgRaw, 'linear', 'EndValues', 'nearest');
end

if ~isempty(FsOverride)
    FsOriginal = double(FsOverride);
elseif isfield(S, 'isi') && isfield(S, 'isi_units')
    interval = double(S.isi);
    unit = lower(strtrim(char(S.isi_units)));
    if ~isscalar(interval) || ~isfinite(interval) || interval <= 0
        error('ECG:InvalidISI', 'MAT variable isi must be a positive scalar.');
    end
    switch unit
        case {'ms', 'millisecond', 'milliseconds'}
            FsOriginal = 1000 / interval;
        case {'s', 'sec', 'second', 'seconds'}
            FsOriginal = 1 / interval;
        case {'us', 'microsecond', 'microseconds'}
            FsOriginal = 1e6 / interval;
        otherwise
            error('ECG:UnknownUnit', ...
                'Unrecognized isi_units = %s. Specify FsOriginalOverride.', unit);
    end
elseif isfield(S, 'Fs') && isnumeric(S.Fs) && isscalar(S.Fs)
    FsOriginal = double(S.Fs);
elseif isfield(S, 'fs') && isnumeric(S.fs) && isscalar(S.fs)
    FsOriginal = double(S.fs);
else
    error('ECG:MissingFs', ...
        'No sampling-rate metadata (isi + isi_units or Fs). Set FsOriginalOverride.');
end
if ~isscalar(FsOriginal) || ~isfinite(FsOriginal) || FsOriginal <= 80
    error('ECG:InvalidFs', 'Original ECG sampling rate must exceed 80 Hz.');
end

units = 'a.u.';
if isfield(S, 'units'), units = strtrim(char(S.units)); end
signalLabel = 'ECG';
if isfield(S, 'labels'), signalLabel = strtrim(char(S.labels)); end
[~, recording, ~] = fileparts(char(matFile));
NOriginal = numel(ecgRaw);
durationOriginal_s = NOriginal / FsOriginal;
if durationOriginal_s <= preRest_s + postRest_s
    error('ECG:NoTaskSegment', ...
        'Recording only %.1f s; pre-rest + post-rest requires %.1f s.', ...
        durationOriginal_s, preRest_s + postRest_s);
end
fprintf('\n--- ECG recording: %s ---\n', recording);
fprintf('Channel: %s [%s] | samples: %d\n', signalLabel, units, NOriginal);
fprintf('Sample rate: %.3f Hz | Nyquist: %.3f Hz\n', FsOriginal, FsOriginal/2);
fprintf('Recording length: %.3f seconds (%.2f min)\n', ...
    durationOriginal_s, durationOriginal_s/60);

%% STEP 2 -- NYQUIST-AWARE DOWNSAMPLING
% Bandwidth of interest: 0.5--40 Hz, so final Fs must be > 80 Hz.
% 'resample' includes FIR ANTIALIAS filtering: do not use x(1:8:end).
FsDesired = min(FsOriginal, FsTarget);
if FsOriginal > FsDesired
    [p, q] = rat(FsDesired/FsOriginal, 1e-7);
    if max([p q]) > 10000
        error('ECG:ComplexResampling', ...
            'Resampling ratio is too complex. Choose a simpler FsTarget.');
    end
    ecgDown = resample(ecgRaw, p, q);
    Fs = FsOriginal * p / q;
else
    p = 1; q = 1;
    ecgDown = ecgRaw;
    Fs = FsOriginal;
end
ecgDown = ecgDown(:);
N = numel(ecgDown);
t = (0:N-1)' / Fs;
fprintf('Downsampled: p/q=%d/%d -> %.3f Hz | Nyquist=%.3f Hz\n', ...
    p, q, Fs, Fs/2);
if Fs < 250
    warning('ECG:LowFs', 'Final Fs < 250 Hz: PQRST localization may be less precise.');
end

%% STEP 3 -- ZERO-PHASE ECG BANDPASS (0.5--40 Hz)
% SOS implementation provides better numerical stability than direct-form
% b/a coefficients for a high-pass corner near zero.
[zBP, pBP, kBP] = butter(4, [0.5 40]/(Fs/2), 'bandpass');
[sosBP, gBP] = zp2sos(zBP, pBP, kBP);
ecgFiltered = filtfilt(sosBP, gBP, ecgDown);

%% STEP 4 -- DEFINE PRE-STROOP / STROOP / POST-STROOP PHASES
% IMPORTANT: This file has NO event markers. These defaults are assumptions.
% If exact event times were logged, enter them in the calling script.
if isempty(stroopStart_s), stroopStart_s = preRest_s; end
if isempty(stroopEnd_s), stroopEnd_s = durationOriginal_s - postRest_s; end
if ~isscalar(stroopStart_s) || ~isscalar(stroopEnd_s) || ...
        ~isfinite(stroopStart_s) || ~isfinite(stroopEnd_s)
    error('ECG:BadEventTimes', 'Stroop start/end must be finite scalar seconds.');
end
preStart_s = stroopStart_s - preRest_s;
postEnd_s = stroopEnd_s + postRest_s;
if preStart_s < -1/Fs || stroopStart_s >= stroopEnd_s || ...
        postEnd_s > durationOriginal_s + 1/Fs
    error('ECG:BadPhases', ...
        'Invalid phase boundaries. Verify rest durations and Stroop markers.');
end
preStart_s = max(0, preStart_s);
postEnd_s = min(durationOriginal_s, postEnd_s);
phaseNames = ["Pre"; "Stroop"; "Post"];
phaseStart = [preStart_s; stroopStart_s; stroopEnd_s];
phaseEnd = [stroopStart_s; stroopEnd_s; postEnd_s];
phaseDuration = phaseEnd - phaseStart;
phaseSamples = zeros(3,1);
for j = 1:3
    phaseSamples(j) = nnz(t >= phaseStart(j) & t < phaseEnd(j));
end
phases = table(phaseNames, phaseStart, phaseEnd, phaseDuration, phaseSamples, ...
    'VariableNames', {'Phase','Start_s','End_s','Duration_s','Samples'});
disp(phases);
if min(phaseSamples) < Fs * 10
    warning('ECG:ShortPhase', 'At least one phase has fewer than 10 seconds of data.');
end

%% STEP 5 -- R-PEAK DETECTION (PAN-TOMPKINS-INSPIRED)
% 5--20 Hz QRS emphasis -> derivative -> squared energy -> 120-ms moving
% average -> findpeaks -> refine to ECG extremum (allows inverted leads).
[zQ, pQ, kQ] = butter(2, [5 20]/(Fs/2), 'bandpass');
[sosQ, gQ] = zp2sos(zQ, pQ, kQ);
qrsSignal = filtfilt(sosQ, gQ, ecgFiltered);
qrsSlope = [0; diff(qrsSignal)];
qrsEnergy = movmean(qrsSlope.^2, max(3, round(0.12*Fs)));
sortedEnergy = sort(qrsEnergy);
p95 = sortedEnergy(max(1, ceil(0.95*numel(sortedEnergy))));
threshold = max(0.20*p95, 3*median(qrsEnergy));
[~, candidateIdx] = findpeaks(qrsEnergy, ...
    'MinPeakHeight', threshold, ...
    'MinPeakDistance', max(1, round(0.35*Fs)));

rCandidates = zeros(numel(candidateIdx),1);
for j = 1:numel(candidateIdx)
    a = max(1, candidateIdx(j) - round(0.18*Fs));
    b = min(N, candidateIdx(j) + round(0.08*Fs));
    window = ecgFiltered(a:b);
    [~, loc] = max(abs(window - median(window)));
    rCandidates(j) = a + loc - 1;
end
rCandidates = unique(rCandidates);

% Merge candidate R peaks closer than 0.30 seconds.
rIdx = zeros(numel(rCandidates),1);
nR = 0;
for j = 1:numel(rCandidates)
    current = rCandidates(j);
    if nR == 0 || (current - rIdx(nR)) >= round(0.30*Fs)
        nR = nR + 1;
        rIdx(nR) = current;
    elseif abs(ecgFiltered(current)) > abs(ecgFiltered(rIdx(nR)))
        rIdx(nR) = current;
    end
end
rIdx = rIdx(1:nR);
fprintf('Automatic R-peak count: %d\n', nR);
if nR < 3
    warning('ECG:FewRPeaks', ...
        'Fewer than three R peaks; check ECG polarity/quality and threshold.');
end

%% STEP 6 -- APPROXIMATE P, Q, S AND T PEAKS (TEACHING ESTIMATES)
% Unlike peak timestamps, clinical PR and QT durations require ONSET/OFFSET
% delineation, so no PR or QT diagnosis is attempted in this exercise.
pIdx = nan(nR,1); qIdx = pIdx; sIdx = pIdx; tIdx = pIdx;
for j = 1:nR
    r = rIdx(j);
    polarity = sign(ecgFiltered(r));
    if polarity == 0, polarity = 1; end
    qIdx(j) = oppositeExtremum(ecgFiltered, r-round(0.100*Fs), ...
        r-round(0.012*Fs), polarity);
    sIdx(j) = oppositeExtremum(ecgFiltered, r+round(0.012*Fs), ...
        r+round(0.100*Fs), polarity);
    pA = r - round(0.300*Fs);
    pB = r - round(0.100*Fs);
    if j > 1
        pA = max(pA, rIdx(j-1)+round(0.16*Fs));
    end
    pIdx(j) = largestDeviation(ecgFiltered, pA, pB);
    tA = r + round(0.140*Fs);
    tB = r + round(0.480*Fs);
    if j < nR
        tB = min(tB, rIdx(j+1)-round(0.12*Fs));
    end
    tIdx(j) = largestDeviation(ecgFiltered, tA, tB);
end

%% STEP 7 -- CALCULATE RR INTERVALS / HEART RATE
R_s = (rIdx-1)/Fs;
P_s = samplesToTime(pIdx, Fs);
Q_s = samplesToTime(qIdx, Fs);
S_s = samplesToTime(sIdx, Fs);
T_s = samplesToTime(tIdx, Fs);
phaseOfBeat = repmat("Outside",nR,1);
for j = 1:3
    inPhase = R_s >= phaseStart(j) & R_s < phaseEnd(j);
    phaseOfBeat(inPhase) = phaseNames(j);
end
RR_raw_s = nan(nR,1);
if nR > 1
    RR_raw_s(2:end) = diff(R_s);
    for j = 2:nR
        if phaseOfBeat(j) ~= phaseOfBeat(j-1)
            RR_raw_s(j) = NaN; % no cross-phase RR interval
        end
    end
end
% Simple plausibility screen for a teaching lab, not full ectopic correction.
RR_Valid = RR_raw_s >= 0.33 & RR_raw_s <= 2.0;
RR_s = RR_raw_s;
RR_s(~RR_Valid) = NaN;
HR_bpm = 60 ./ RR_s;
R_Amplitude = ecgFiltered(rIdx);
beats = table((1:nR)', phaseOfBeat, P_s, Q_s, R_s, S_s, T_s, ...
    R_Amplitude, RR_raw_s, RR_s, RR_Valid, HR_bpm, ...
    'VariableNames', {'Beat','Phase','P_s','Q_s','R_s','S_s','T_s', ...
    'R_Amplitude','RR_raw_s','RR_s','RR_Valid','HR_bpm'});

%% STEP 8 -- PHASE-LEVEL HR, RR AND SIMPLE HRV METRICS
% SDNN and RMSSD are descriptive teaching outputs. Check R peaks, remove
% ectopic beats/artifacts, and use comparable recording durations before
% interpreting HRV physiologically.
RPeaks = zeros(3,1);
ValidRR = zeros(3,1);
MeanRR_s = nan(3,1);
MeanHR_bpm = nan(3,1);
SDNN_ms = nan(3,1);
RMSSD_ms = nan(3,1);
MeanRAmplitude = nan(3,1);
for j = 1:3
    selected = phaseOfBeat == phaseNames(j);
    RPeaks(j) = nnz(selected);
    rr = RR_s(selected);
    hr = HR_bpm(selected);
    valid = isfinite(rr);
    ValidRR(j) = nnz(valid);
    if any(valid)
        MeanRR_s(j) = mean(rr(valid));
        MeanHR_bpm(j) = mean(hr(isfinite(hr)));
    end
    if ValidRR(j) >= 2
        SDNN_ms(j) = 1000*std(rr(valid),0);
        % Consecutive NN differences only (do not bridge missing intervals).
        successive = diff(rr);
        successive = successive(isfinite(successive));
        if ~isempty(successive)
            RMSSD_ms(j) = 1000*sqrt(mean(successive.^2));
        end
    end
    rAmps = R_Amplitude(selected);
    if ~isempty(rAmps), MeanRAmplitude(j) = mean(rAmps); end
end
summary = table(phaseNames, phaseDuration, RPeaks, ValidRR, ...
    MeanRR_s, MeanHR_bpm, SDNN_ms, RMSSD_ms, MeanRAmplitude, ...
    'VariableNames', {'Phase','Duration_s','RPeaks','ValidRR', ...
    'MeanRR_s','MeanHR_bpm','SDNN_ms','RMSSD_ms','MeanRAmplitude'});
disp('Phase results:'); disp(summary);

%% STEP 9 -- COLLECT OUTPUTS
result = struct();
result.fileName = char(matFile);
result.recording = recording;
result.units = units;
result.channelLabel = signalLabel;
result.FsOriginal = FsOriginal;
result.Fs = Fs;
result.originalSampleCount = NOriginal;
result.duration_s = durationOriginal_s;
result.resampling_p = p;
result.resampling_q = q;
result.t = t;
result.ecgDown = ecgDown;
result.ecgFiltered = ecgFiltered;
result.phases = phases;
result.beats = beats;
result.summary = summary;
result.rIdx = rIdx;
result.pIdx = pIdx;
result.qIdx = qIdx;
result.sIdx = sIdx;
result.tIdx = tIdx;

%% STEP 10 -- GENERATE THE TEACHING FIGURES (OPTIONAL)
if showFigures
    if isempty(outputFolder)
        outputFolder = fullfile(pwd, 'ECG_Results', recording);
    end
    if exportFiles && ~exist(outputFolder,'dir'), mkdir(outputFolder); end
    rawShow = min(NOriginal, max(1, round(8*FsOriginal)));
    downShow = min(N, max(1, round(8*Fs)));
    tRawShow = (0:rawShow-1)' / FsOriginal;

    f1 = figure('Name',[recording ' - Downsampling'],'Color','w');
    subplot(2,1,1); plot(tRawShow,ecgRaw(1:rawShow)); grid on;
    ylabel(['ECG (' units ')']);
    title(sprintf('Original, Fs = %.1f Hz', FsOriginal));
    subplot(2,1,2); plot(t(1:downShow),ecgDown(1:downShow)); grid on;
    xlabel('Time (s)'); ylabel(['ECG (' units ')']);
    title(sprintf('Downsampled, Fs = %.1f Hz', Fs));
    saveFig(f1, outputFolder, '01_downsampling.png', exportFiles);

    f2 = figure('Name',[recording ' - Filtering'],'Color','w');
    plot(t(1:downShow),ecgDown(1:downShow),'Color',[.65 .65 .65]); hold on;
    plot(t(1:downShow),ecgFiltered(1:downShow),'b'); grid on;
    legend('Before filter','0.5-40 Hz bandpass','Location','best');
    xlabel('Time (s)'); ylabel(['ECG (' units ')']);
    title('Effect of filtering');
    saveFig(f2, outputFolder, '02_filtering.png', exportFiles);

    f3 = figure('Name',[recording ' - Phases'],'Color','w');
    plot(t/60,ecgFiltered,'k'); grid on; hold on;
    xline(stroopStart_s/60,'b--','Stroop starts');
    xline(stroopEnd_s/60,'r--','Stroop ends');
    xlabel('Time (min)'); ylabel(['ECG (' units ')']);
    title('Three experimental phases (boundaries assumed unless marked)');
    saveFig(f3, outputFolder, '03_phase_overview.png', exportFiles);

    f4 = figure('Name',[recording ' - PQRST'],'Color','w');
    zoomStart_s = max(0, min(zoomStart_s, durationOriginal_s-1));
    zoomEnd_s = min(durationOriginal_s,zoomStart_s+zoomDuration_s);
    zoomSamples = t >= zoomStart_s & t <= zoomEnd_s;
    plot(t(zoomSamples),ecgFiltered(zoomSamples),'k','LineWidth',1); hold on;
    plotMarkers(t,ecgFiltered,pIdx,'mo',zoomStart_s,zoomEnd_s);
    plotMarkers(t,ecgFiltered,qIdx,'bo',zoomStart_s,zoomEnd_s);
    plotMarkers(t,ecgFiltered,rIdx,'ro',zoomStart_s,zoomEnd_s);
    plotMarkers(t,ecgFiltered,sIdx,'co',zoomStart_s,zoomEnd_s);
    plotMarkers(t,ecgFiltered,tIdx,'go',zoomStart_s,zoomEnd_s);
    xlabel('Time (s)'); ylabel(['ECG (' units ')']);
    title('Approximate PQRST peak timestamps (visually validate)');
    legend('Filtered ECG','P','Q','R','S','T','Location','best');
    xlim([zoomStart_s zoomEnd_s]); grid on;
    saveFig(f4, outputFolder, '04_PQRST_zoom.png', exportFiles);

    f5 = figure('Name',[recording ' - HR by phase'],'Color','w');
    plot(R_s/60, HR_bpm, '.', 'MarkerSize',6); grid on; hold on;
    xline(stroopStart_s/60,'b--','Stroop starts');
    xline(stroopEnd_s/60,'r--','Stroop ends');
    xlabel('Time (min)'); ylabel('Instantaneous HR (beats/min)');
    title('Heart rate estimated from accepted RR intervals');
    saveFig(f5, outputFolder, '05_HR_over_time.png', exportFiles);

    f6 = figure('Name',[recording ' - Phase HR comparison'],'Color','w');
    bar(MeanHR_bpm); grid on;
    set(gca,'XTick',1:3,'XTickLabel',{'Pre','Stroop','Post'});
    xlabel('Experimental phase'); ylabel('Mean instantaneous HR (beats/min)');
    title('Heart-rate comparison of three experimental phases');
    saveFig(f6, outputFolder, '06_HR_by_phase.png', exportFiles);
end

%% STEP 11 -- EXPORT TABLES + RESULTS WORKSPACE (OPTIONAL)
if exportFiles
    if isempty(outputFolder)
        outputFolder = fullfile(pwd, 'ECG_Results', recording);
    end
    if ~exist(outputFolder,'dir'), mkdir(outputFolder); end
    writetable(phases, fullfile(outputFolder,'Phases.csv'));
    writetable(beats, fullfile(outputFolder,'PQRST_and_RR_by_beat.csv'));
    writetable(summary, fullfile(outputFolder,'Phase_summary.csv'));
    save(fullfile(outputFolder,'Analysis_workspace.mat'),'result','-v7.3');
    fprintf('Saved tables, workspace and plots to: %s\n',outputFolder);
end
fprintf('Important: visually check R peaks and approximate P/Q/S/T labels.\n');
end

%% INTERNAL HELPER FUNCTIONS
function value = getOption(S, name, default)
if isfield(S,name) && ~isempty(S.(name))
    value = S.(name);
else
    value = default;
end
end

function times = samplesToTime(sampleIndices, Fs)
times = (sampleIndices-1)/Fs;
times(~isfinite(sampleIndices)) = NaN;
end

function idx = oppositeExtremum(x, a, b, rPolarity)
idx = NaN;
a = max(1, round(a)); b = min(numel(x), round(b));
if a > b, return; end
if rPolarity >= 0
    [~,loc] = min(x(a:b));
else
    [~,loc] = max(x(a:b));
end
idx = a+loc-1;
end

function idx = largestDeviation(x, a, b)
idx = NaN;
a = max(1, round(a)); b = min(numel(x), round(b));
if a > b, return; end
segment = x(a:b);
[~,loc] = max(abs(segment-median(segment)));
idx = a+loc-1;
end

function plotMarkers(t, x, sampleIdx, style, t0, t1)
sampleIdx = round(sampleIdx(isfinite(sampleIdx)));
sampleIdx = sampleIdx(sampleIdx>=1 & sampleIdx<=numel(t));
sampleIdx = sampleIdx(t(sampleIdx)>=t0 & t(sampleIdx)<=t1);
plot(t(sampleIdx),x(sampleIdx),style,'LineWidth',1,'MarkerSize',6);
end

function saveFig(fig, folder, name, doSave)
if doSave
    saveas(fig, fullfile(folder,name));
end
end
