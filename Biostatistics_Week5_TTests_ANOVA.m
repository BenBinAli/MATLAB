%% WEEK 5 - BIOSTATISTICS WITH MATLAB
% Topic: Independent and paired t-tests; one-way ANOVA; Tukey post-hoc test.
% Source: The SAME constructed 30-participant dataset used in Weeks 2-4.
%        https://github.com/BenBinAli/MATLAB
%
% TEACHING DESIGN:
%   Sections 1-3: Real columns of the earlier CLASS dataset (constructed).
%   Section 4: A SEPARATE, small invented before/after example for paired t-test.
%   Sections 5-7: Three age bands DERIVED from the original class dataset.
%       Age bands (21-24 / 25-27 / 28-32) are arbitrary teaching categories,
%       NOT clinical categories. No causal conclusions are justified.
%
% REQUIREMENTS: Statistics and Machine Learning Toolbox for ttest, ttest2,
%               anova1, and multcompare. boxchart needs MATLAB R2020a+.
% Run sections from top to bottom using Ctrl+Enter.

%% 1. OPEN THE DATASET: SAME FILE AS LAST WEEK
% isfile: checks whether the file is already in MATLAB's Current Folder.
% websave: downloads the public Excel file if no local copy exists.
% readtable: imports the spreadsheet as a table.
clear;
clc;
close all;

fileName = 'Biostatistics MATLAB Class Dataset.xlsx';
olderName = 'Biostatistics_MATLAB_Session2_Class_Dataset.xlsx';
url = ['https://raw.githubusercontent.com/BenBinAli/MATLAB/main/' ...
       'Biostatistics%20MATLAB%20Class%20Dataset.xlsx'];

if isfile(fileName)
    disp('Opening the local GitHub-named dataset.');
elseif isfile(olderName)
    fileName = olderName;
    disp('Opening the earlier-named local dataset.');
else
    disp('Downloading the public class dataset from GitHub...');
    websave(fileName, url);
end

data = readtable(fileName);
head(data)

% Data definitions: GroupCode=0 Control, GroupCode=1 Exercise.
% RestingHR_bpm has one missing Control measurement (29 valid values).
% Significance level alpha: 0.05 is a classroom convention, not a guarantee.
alpha = 0.05;

%% 2. INDEPENDENT-SAMPLES t-TEST: CONTROL vs EXERCISE HEART RATE
% Question: Are the two population mean resting heart rates different?
% H0: mean(Control) = mean(Exercise)
% H1: mean(Control) ~= mean(Exercise) [two-sided].
%
% Two groups have DIFFERENT people -> independent-samples t-test.
% Use Welch's version ('Vartype','unequal') because sample SDs differ.
% Keep only measured (not missing) heart-rate values.

controlHR = data.RestingHR_bpm(data.GroupCode == 0);
exerciseHR = data.RestingHR_bpm(data.GroupCode == 1);
controlHR = controlHR(~ismissing(controlHR));
exerciseHR = exerciseHR(~ismissing(exerciseHR));

nControl = numel(controlHR);
nExercise = numel(exerciseHR);
meanControl = mean(controlHR);
meanExercise = mean(exerciseHR);
sdControl = std(controlHR);
sdExercise = std(exerciseHR);

fprintf('\n===== INDEPENDENT t-TEST: HEART RATE =====\n');
fprintf('Control: n=%d, mean=%.2f, SD=%.2f bpm\n', ...
        nControl, meanControl, sdControl);
fprintf('Exercise: n=%d, mean=%.2f, SD=%.2f bpm\n', ...
        nExercise, meanExercise, sdExercise);

% ttest2 returns h, p, CI, and stats:
%   h: 1=reject H0, 0=do not reject H0 at the chosen alpha.
%   p: evidence against H0, assuming the test model.
%   ci: 95% CI for mean(Control)-mean(Exercise).
%   stats.tstat: observed t-statistic; stats.df: degrees of freedom.
[hWelch,pWelch,ciWelch,statsWelch] = ttest2( ...
    controlHR, exerciseHR, 'Vartype','unequal', 'Alpha',alpha);

fprintf('Difference (Control - Exercise) = %.2f bpm\n', ...
        meanControl - meanExercise);
fprintf('Welch t(%.2f) = %.3f, p = %.6g\n', ...
        statsWelch.df, statsWelch.tstat, pWelch);
fprintf('95%% CI for difference: [%.2f, %.2f] bpm\n', ...
        ciWelch(1), ciWelch(2));
fprintf('Reject equal-means H0 at alpha=%.2f? %d\n',alpha,hWelch);

figure('Name','Week 5 - Resting HR by Group');
boxchart(data.GroupCode, data.RestingHR_bpm);
xticks([0 1]);
xticklabels({'Control','Exercise'});
xlabel('Participant group');
ylabel('Resting heart rate (bpm)');
title('Two independent groups: resting HR');
grid on;
saveas(gcf,'Week5_Figure1_Independent_HR_Boxchart.png');

% DISCUSS: Why is nControl 14 instead of 15?
% Is the 100-bpm value a plausible measurement? Do not delete it merely
% because its removal changes the mean, SD, or p-value.
% A p-value does NOT prove that exercise caused the observed difference.

%% 3. RECAP: EQUAL-VARIANCE vs WELCH INDEPENDENT t-TEST
% Pooled t-test assumes population variances are equal.
% Welch t-test allows different population variances and is often safer.
% They test the same difference in means but use different standard errors.

[~,pPooled,~,statsPooled] = ttest2( ...
    controlHR, exerciseHR, 'Vartype','equal', 'Alpha',alpha);
fprintf('\nPooled t-test: t(%.0f)=%.3f, p=%.6g\n', ...
        statsPooled.df,statsPooled.tstat,pPooled);
fprintf('Welch t-test:  t(%.2f)=%.3f, p=%.6g\n', ...
        statsWelch.df,statsWelch.tstat,pWelch);

%% 4. PAIRED t-TEST: A SEPARATE ILLUSTRATIVE BEFORE/AFTER EXAMPLE
% THIS SECTION DOES NOT USE THE 30-PERSON CLASS DATASET.
% These are eight FICTIONAL participants measured twice.
% H0: mean(Before - After) = 0.
% For paired data, each Before value must align with the SAME participant's
% After value. 'ttest(before,after)' analyzes paired differences.

before = [74;77;78;80;75;79;76;81];
after  = [70;73;74;75;73;75;73;76];
pairedChange = before - after;

[hPaired,pPaired,ciPaired,statsPaired] = ttest( ...
    before, after, 'Alpha',alpha);

fprintf('\n===== PAIRED t-TEST: ILLUSTRATIVE DATA =====\n');
fprintf('N matched pairs = %d\n',numel(before));
fprintf('Mean(Before - After) = %.2f bpm\n',mean(pairedChange));
fprintf('t(%d) = %.3f, p = %.6g\n', ...
        statsPaired.df,statsPaired.tstat,pPaired);
fprintf('95%% CI for mean paired change = [%.2f, %.2f] bpm\n', ...
        ciPaired(1),ciPaired(2));

figure('Name','Week 5 - Paired measurements');
plot([1 2], [before after]', '-o','LineWidth',1);
xticks([1 2]);
xticklabels({'Before','After'});
xlim([0.75 2.25]);
ylabel('Resting heart rate (bpm)');
title('Each line = one fictional participant');
grid on;
saveas(gcf,'Week5_Figure2_Paired_Before_After.png');

% DISCUSS: You must NOT use ttest2 for these matched observations.

%% 5. ONE-WAY ANOVA USING THE SAME ORIGINAL DATASET
% Research/teaching question: Do population mean systolic BP values
% differ across THREE age bands in this constructed class sample?
%
% The dataset has only Control/Exercise (two original groups).
% We derive three AGE categories for this ANOVA teaching illustration:
%     Group 1: 21-24 years
%     Group 2: 25-27 years
%     Group 3: 28-32 years
% The thresholds are pedagogical and arbitrary, not clinical cutoffs.
%
% 'ageBand' stores category IDs. Conditions from Session 2 are reused.

ageBand = ones(height(data),1);
ageBand(data.Age_years >= 25 & data.Age_years <= 27) = 2;
ageBand(data.Age_years >= 28) = 3;

% Restrict the analysis to observations with age and BP both measured.
validRows = ~ismissing(data.Age_years) & ...
            ~ismissing(data.SystolicBP_mmHg);
bp = data.SystolicBP_mmHg(validRows);
threeGroups = ageBand(validRows);

bp1 = bp(threeGroups == 1);
bp2 = bp(threeGroups == 2);
bp3 = bp(threeGroups == 3);

ageBandLabels = {'21-24';'25-27';'28-32'};
summary3 = table(ageBandLabels, ...
    [numel(bp1);numel(bp2);numel(bp3)], ...
    [mean(bp1);mean(bp2);mean(bp3)], ...
    [std(bp1);std(bp2);std(bp3)], ...
    'VariableNames',{'AgeBand','N','MeanBP','SDBP'});

disp('===== AGE BAND DESCRIPTIVES: SYSTOLIC BP =====');
disp(summary3);

figure('Name','Week 5 - Systolic BP by Age Band');
boxchart(threeGroups,bp);
xticks([1 2 3]);
xticklabels({'21-24','25-27','28-32'});
xlabel('Age band (years): classroom categories');
ylabel('Systolic blood pressure (mmHg)');
title('Three independent groups: BP distribution');
grid on;
saveas(gcf,'Week5_Figure3_ANOVA_BP_Boxchart.png');

%% 6. ONE-WAY ANOVA: GLOBAL TEST
% H0: meanBP(group 1) = meanBP(group 2) = meanBP(group 3)
% H1: AT LEAST ONE population mean differs (NOT necessarily all pairs).
%
% anova1(y,group,'off') runs classical one-way ANOVA and suppresses its
% automatic plots. It assumes independent observations, approximately
% normal within-group residuals, and approximately equal group variances.
% [pA,anovaTable,statsA] provides p-value, ANOVA table, post-hoc info.

[pA,anovaTable,statsA] = anova1(bp,threeGroups,'off');

fprintf('\n===== ONE-WAY ANOVA: BP BY AGE BAND =====\n');
disp(anovaTable); % Source, SS, df, MS, F, p-value
fprintf('Overall ANOVA p-value = %.6g\n',pA);
fprintf('F(%g,%g) = %.3f\n',anovaTable{2,3}, ...
        anovaTable{3,3},anovaTable{2,5});

if pA < alpha
    disp('Interpretation: evidence that at least one age-band mean differs.');
else
    disp('Interpretation: insufficient evidence of differing group means.');
end

% WHY F? Variation BETWEEN group means is compared with residual variation
% WITHIN groups. A large F relative to its reference distribution tends
% to yield a small p-value.

%% 7. TUKEY-KRAMER POST-HOC COMPARISONS
% A significant overall ANOVA does not reveal WHICH pairs differ.
% multcompare(statsA,'Display','off') uses Tukey-Kramer by default:
% adjusted p-values account for multiple pairwise comparisons.
%
% Each row of C contains: [Group1 Group2 LowerCI Difference UpperCI p].
% Group numbers are the ageBand values (1,2,3) in this example.

[C,~,~,groupNames] = multcompare(statsA,'Display','off');

fprintf('\n===== TUKEY-KRAMER POST-HOC =====\n');
fprintf('Column order: Group1 Group2 LowerCI Difference UpperCI AdjustedP\n');
disp(C);
fprintf('Age band mapping: 1=21-24, 2=25-27, 3=28-32 years\n');

for k = 1:size(C,1)
    fprintf('Group %s vs %s: difference %.2f mmHg; 95%% CI [%.2f,%.2f]; adjusted p=%.5g\n', ...
        groupNames{C(k,1)},groupNames{C(k,2)}, ...
        C(k,4),C(k,3),C(k,5),C(k,6));
end

% In this teaching dataset, the two younger age bands differ,
% and 21-24 vs 28-32 differ, but 25-27 vs 28-32 may not meet p<0.05.
% Check the MATLAB result rather than inferring significance visually.

%% 8. EXPORT THE SUMMARY RESULTS
% A result table is useful for reporting, not just displaying output.
writetable(summary3,'Week5_ANOVA_AgeBands_Summary.xlsx');

comparisonSummary = table(C(:,1),C(:,2),C(:,3),C(:,4),C(:,5),C(:,6), ...
    'VariableNames',{'Group1','Group2','CI_Lower','MeanDiff','CI_Upper','AdjustedP'});
writetable(comparisonSummary,'Week5_Tukey_PostHoc.xlsx');

% Figure files were saved in the earlier sections.
disp('Week 5 finished: 3 box/line figures and 2 Excel result tables saved.');

%% 9. OPTIONAL ADVANCED CONCEPT: F = t^2 FOR TWO GROUPS
% Two-group one-way ANOVA with equal-variance assumptions produces
% the same p-value as the equal-variance pooled, two-sided t-test.
% THIS IDENTITY IS NOT GENERALLY TRUE FOR WELCH'S UNEQUAL-VARIANCE t-TEST.

hrCombined = [controlHR;exerciseHR];
hrGroupIDs = [zeros(numel(controlHR),1);ones(numel(exerciseHR),1)];
[pTwoGroup,tableTwoGroup] = anova1(hrCombined,hrGroupIDs,'off');

fprintf('\n===== OPTIONAL: TWO-GROUP IDENTITY =====\n');
fprintf('Pooled t^2 = %.4f; ANOVA F = %.4f\n', ...
    statsPooled.tstat^2,tableTwoGroup{2,5});
fprintf('Pooled t-test p = %.6g; two-group ANOVA p = %.6g\n', ...
    pPooled,pTwoGroup);

% FINAL QUESTIONS FOR STUDENTS:
% 1) Why use ttest2 for Control vs Exercise, but ttest for Before vs After?
% 2) Why is the age-band analysis ANOVA rather than a collection of t-tests?
% 3) What is the difference between the overall ANOVA p and post-hoc p?
% 4) Can this constructed dataset establish the effect of aging or exercise?
