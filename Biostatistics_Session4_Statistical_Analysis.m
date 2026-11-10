%% BIOSTATISTICS WITH MATLAB | SESSION 4
% From descriptive statistics to interpreting results
% Synthetic teaching data: NOT patient data; NOT evidence of intervention effects.
% Learning path:
%  1. Import and inspect data
%  2. Descriptive statistics (overall and by group)
%  3. Distribution and potential outliers
%  4. Group comparison: Welch two-sample t test (if Statistics Toolbox installed)
%  5. Correlation and scatter plot (if Statistics Toolbox installed)
%  6. Sensitivity analysis and student tasks
%
% IMPORTANT: Run one section at a time using the MATLAB Editor's Run Section.
% This file first tries the local Excel file. If not found, it downloads
% the public class file from GitHub. Internet is needed only for that step.

%% 1 | IMPORT AND INSPECT
clear; clc; close all;

filename = 'Biostatistics_MATLAB_Class_Dataset.xlsx';
url = 'https://raw.githubusercontent.com/BenBinAli/MATLAB/main/Biostatistics%20MATLAB%20Class%20Dataset.xlsx';

if ~isfile(filename)
    fprintf('Local dataset not found. Downloading from the class repository...\n');
    try
        websave(filename,url);
    catch ME
        error(['Cannot download dataset. Verify the GitHub Raw URL or ' ...
            'place the Excel file in the current MATLAB folder. Details: %s'],ME.message);
    end
end

data = readtable(filename,'Sheet','Class_Data');
required = {'SubjectID','Group','Age_years','Height_cm','Weight_kg', ...
            'RestingHR_bpm','SystolicBP_mmHg','GroupCode'};
if ~all(ismember(required,data.Properties.VariableNames))
    error('Unexpected dataset columns. Check that the correct class Excel file was loaded.');
end

fprintf('\n--- DATASET OVERVIEW ---\n');
fprintf('Number of students/participants in example: %d\n',height(data));
disp(data(1:5,:));

% Inspect missing values in the two relevant measures.
missingWeight = sum(ismissing(data.Weight_kg));
missingHR     = sum(ismissing(data.RestingHR_bpm));
fprintf('Missing weight values: %d\n',missingWeight);
fprintf('Missing resting-heart-rate values: %d\n',missingHR);

%% 2 | DESCRIPTIVE STATISTICS: WHAT DO THE NUMBERS SAY?
% mean = arithmetic average; median = middle ordered value
% std = standard deviation (spread); min and max = observed extremes
% Omit missing values before calculations for clarity.
hrAll = data.RestingHR_bpm;
hrClean = hrAll(~ismissing(hrAll));

nHR    = numel(hrClean);
meanHR = mean(hrClean);
medHR  = median(hrClean);
sdHR   = std(hrClean);
minHR  = min(hrClean);
maxHR  = max(hrClean);

fprintf('\n--- OVERALL RESTING HEART RATE ---\n');
fprintf('n = %d, Mean = %.2f bpm, Median = %.2f bpm\n',nHR,meanHR,medHR);
fprintf('SD = %.2f bpm, Min = %.0f bpm, Max = %.0f bpm\n',sdHR,minHR,maxHR);
fprintf('Interpretation: Compare mean and median; inspect high values.\n');

% GroupCode: 0 = Control; 1 = Exercise.
controlHR = data.RestingHR_bpm(data.GroupCode==0);
exerciseHR = data.RestingHR_bpm(data.GroupCode==1);
controlHR = controlHR(~ismissing(controlHR));
exerciseHR = exerciseHR(~ismissing(exerciseHR));

nControl = numel(controlHR);
nExercise = numel(exerciseHR);
meanControl = mean(controlHR);  meanExercise = mean(exerciseHR);
medianControl = median(controlHR); medianExercise = median(exerciseHR);
sdControl = std(controlHR);    sdExercise = std(exerciseHR);

summaryTable = table( ...
    ["Control";"Exercise"], ...
    [nControl;nExercise], ...
    [meanControl;meanExercise], ...
    [medianControl;medianExercise], ...
    [sdControl;sdExercise], ...
    'VariableNames',{'Group','N','Mean_bpm','Median_bpm','SD_bpm'});

fprintf('\n--- HEART RATE BY GROUP ---\n');
disp(summaryTable);
writetable(summaryTable,'Session4_Group_Summary.xlsx');
fprintf('Group summary saved: Session4_Group_Summary.xlsx\n');

%% 3 | PLOTS: DISTRIBUTION, GROUP SPREAD, OUTLIERS
% Key interpretation questions: Where is the center? How wide is the spread?
% Is the distribution symmetric? Are any observations unusually high/low?

figure('Name','HR histogram');
histogram(controlHR,'BinWidth',5,'FaceAlpha',0.6); hold on;
histogram(exerciseHR,'BinWidth',5,'FaceAlpha',0.6);
xlabel('Resting heart rate (bpm)'); ylabel('Number of participants');
title('Heart-rate distributions by group');
legend('Control','Exercise','Location','best'); grid on; hold off;
saveas(gcf,'Session4_HR_Histogram.png');

% Box chart: center, variability, and potential outliers (1.5 IQR rule).
figure('Name','HR box chart');
boxchart(data.GroupCode,data.RestingHR_bpm);
xticks([0 1]); xticklabels({'Control','Exercise'});
xlabel('Group'); ylabel('Resting heart rate (bpm)');
title('Resting heart rate: group comparison'); grid on;
saveas(gcf,'Session4_HR_Boxchart.png');

% Optional normal Q-Q plot requires Statistics and Machine Learning Toolbox.
if exist('qqplot','file')==2
    figure('Name','Q-Q plots');
    subplot(1,2,1); qqplot(controlHR); title('Control: normal Q-Q');
    subplot(1,2,2); qqplot(exerciseHR); title('Exercise: normal Q-Q');
    saveas(gcf,'Session4_HR_QQplots.png');
else
    fprintf('\nQ-Q plot skipped: Statistics and Machine Learning Toolbox unavailable.\n');
end

%% 4 | INDEPENDENT-GROUP COMPARISON: WELCH TWO-SAMPLE T TEST
% Hypothesis H0: The two population MEANS are equal.
% Alternative H1: The two population MEANS differ.
% Welch's test does NOT assume equal group variances.
% Statistical significance is not the same as clinical importance.
% These are artificial, non-randomized groups: do NOT infer causation.

meanDiff = meanControl - meanExercise;  % Control minus Exercise
fprintf('\n--- GROUP COMPARISON ---\n');
fprintf('Observed mean difference (Control - Exercise): %.2f bpm\n',meanDiff);

if exist('ttest2','file')==2
    [h,p,ci,stats] = ttest2(controlHR,exerciseHR,'Vartype','unequal');
    fprintf('Welch t-test: t = %.3f, df = %.2f, p = %.5f\n', ...
        stats.tstat, stats.df, p);
    fprintf('95%% confidence interval for mean difference: [%.2f, %.2f] bpm\n',ci(1),ci(2));
    if h==1
        fprintf('At alpha = 0.05, reject the hypothesis of equal group means.\n');
    else
        fprintf('At alpha = 0.05, do not reject equal group means.\n');
    end
    fprintf('A CI describes uncertainty in the difference, not individual variability.\n');
else
    fprintf('Inferential test skipped: Statistics and Machine Learning Toolbox unavailable.\n');
end

% Standardized effect size, Hedges-correction not applied here.
% Cohen's d is a descriptive standardized mean difference, not a p-value.
pooledSD = sqrt(((nControl-1)*sdControl^2 + (nExercise-1)*sdExercise^2) ...
                / (nControl+nExercise-2));
cohensD = meanDiff/pooledSD;
fprintf('Cohen''s d (Control - Exercise) = %.3f\n',cohensD);
fprintf('Discuss both magnitude (difference and d) AND uncertainty (CI).\n');

%% 5 | CORRELATION: DO TWO QUANTITATIVE VARIABLES MOVE TOGETHER?
% Explore Height and Weight: Pearson r measures LINEAR association.
% A high r does not mean height causes weight or vice versa.

completeHW = ~ismissing(data.Height_cm) & ~ismissing(data.Weight_kg);
h = data.Height_cm(completeHW);
w = data.Weight_kg(completeHW);

figure('Name','Height versus weight');
scatter(h,w,55,'filled'); hold on;
% polyfit finds a descriptive least-squares line (not causal inference).
p = polyfit(h,w,1);
xLine = linspace(min(h),max(h),100);
yLine = polyval(p,xLine);
plot(xLine,yLine,'LineWidth',1.5);
xlabel('Height (cm)'); ylabel('Weight (kg)');
title('Height and weight: descriptive relationship');
legend('Observed data','Fitted straight line','Location','best');
grid on; hold off;
saveas(gcf,'Session4_Height_Weight_Scatter.png');

fprintf('\n--- HEIGHT/WEIGHT ASSOCIATION ---\n');
fprintf('Complete pairs: %d\n',numel(h));
if exist('corr','file')==2
    [r,pCorr] = corr(h,w,'Type','Pearson');
    fprintf('Pearson r = %.3f, p = %.5f\n',r,pCorr);
    fprintf('r near +1: positive linear association; near 0: weak linear association.\n');
else
    r = corrcoef(h,w);  % basic MATLAB correlation matrix
    fprintf('Pearson r = %.3f (p-value omitted: toolbox unavailable)\n',r(1,2));
end
fprintf('Association does not establish causation.\n');

%% 6 | SENSITIVITY ANALYSIS: WHY AN UNUSUAL VALUE MATTERS
% The dataset contains a plausible teaching outlier (Control HR = 100).
% Do not delete data just because they look inconvenient!
% Here we demonstrate how the numerical results change IF it is excluded.
% This is an EXERCISE, not a justified real-study exclusion rule.

controlWithout100 = controlHR(controlHR~=100);
fprintf('\n--- SENSITIVITY EXERCISE ---\n');
fprintf('Control mean with all observed values: %.2f bpm (n=%d)\n', ...
    mean(controlHR),numel(controlHR));
fprintf('Control mean without 100 bpm observation: %.2f bpm (n=%d)\n', ...
    mean(controlWithout100),numel(controlWithout100));
fprintf('Control median with all values: %.2f bpm\n',median(controlHR));
fprintf('Control median without 100 bpm: %.2f bpm\n',median(controlWithout100));
fprintf('Ask students: Which statistic is more resistant to the unusual value?\n');

%% 7 | IN-CLASS TASKS (STUDENTS COMPLETE THESE)
% Task A. Calculate n, mean, median, SD of SystolicBP_mmHg for each group.
% Task B. Make two systolic BP histograms: BinWidth = 2 and BinWidth = 6.
%         How does binning change your visual interpretation?
% Task C. Plot SystolicBP_mmHg with boxchart, separated by GroupCode.
% Task D. Calculate the mean difference (Control minus Exercise) for BP.
% Task E. If ttest2 is available: perform Welch's test for BP and report:
%         means, mean difference, 95% CI, p-value, and a cautious conclusion.
% Task F. Make an Age_years vs SystolicBP_mmHg scatter plot.
%         If corr is available, report Pearson r and its p-value.
% Task G. Write a 3-sentence Results paragraph describing the HR comparison:
%         (1) group means/SD/n; (2) difference, 95% CI and p if available;
%         (3) what these results do NOT show about causality.
%
% DISCUSSION: Since this dataset was constructed for teaching, none of its
% statistical comparisons should be described as real clinical evidence.

fprintf('\nLesson complete. Charts and summary spreadsheet saved in current folder.\n');
