%% IMU vs FORCE PLATE - BIOSTATISTICS PRACTICAL
% Synthetic teaching dataset: 45 participants, three independent training groups.
% IMU and FP measure the SAME participant (paired observations).
% Required: Statistics and Machine Learning Toolbox.
% Run one section at a time with Ctrl+Enter (Run Section).
% NOTE: The numbers are synthetic. They are not real force-plate or IMU recordings.

%% 1. Load and inspect the data
clear; clc; close all;

% Keep the dataset in the MATLAB Current Folder.
if exist('Biostatistics Week 6 TTEST_ANOVA_POSTHOC.xlsx','file') == 2
    data = readtable('Biostatistics Week 6 TTEST_ANOVA_POSTHOC.xlsx');
elseif exist('Biostatistics Week 6 TTEST_ANOVA_POSTHOC.csv','file') == 2
    data = readtable('Biostatistics Week 6 TTEST_ANOVA_POSTHOC.csv');
else
    error('Place Dataset in the Current Folder.');
end

head(data)
summary(data)
% Nominal factor: three DIFFERENT groups of participants
G = categorical(data.TrainingGroup);
alpha = 0.05;

%% 2. Choose the test from the study design and measurement scale
% FP_CMJ_cm and IMU_CMJ_cm: continuous ratio-scale measurements (cm).
% LandingControlScore_1to5: ORDINAL rating (1 low ... 5 high).
% IMU vs FP for one participant = PAIRED data -> paired t-test or signrank.
% FP_CMJ across Novice/Recreational/Trained = INDEPENDENT groups
%     -> one-way ANOVA (when assumptions are adequate) or Kruskal-Wallis.
% Ordinal rating across three independent groups -> Kruskal-Wallis.
%
% IMPORTANT: SJ, CMJ, and DJ are all measured on the SAME participants.
% Do NOT run ordinary independent-groups anova1 on SJ vs CMJ vs DJ.
% That comparison requires a repeated-measures approach (later lesson).

%% 3. Paired values: remove only incomplete IMU-FP pairs
validPair = ~isnan(data.FP_CMJ_cm) & ~isnan(data.IMU_CMJ_cm);
FP  = data.FP_CMJ_cm(validPair);
IMU = data.IMU_CMJ_cm(validPair);

% Positive difference = IMU overestimates FP; negative = underestimates.
difference = IMU - FP;

fprintf('\nPAIRED CMJ MEASUREMENTS\n');
fprintf('Complete participants: %d\n', numel(difference));
fprintf('Mean IMU minus FP difference: %.2f cm\n', mean(difference));
fprintf('SD of differences: %.2f cm\n', std(difference));

%% 4. Normality check for the PAIRED t-test
% Check the DIFFERENCES, not IMU and FP separately.
figure('Name','Paired differences: normality');
subplot(1,2,1);
histogram(difference, 9);
xlabel('IMU - FP (cm)'); ylabel('Count'); title('Differences'); grid on;
subplot(1,2,2);
qqplot(difference);
title('Normal Q-Q plot of differences');

[hNormalPair, pNormalPair] = lillietest(difference);
fprintf('\nLilliefors p-value (paired differences) = %.4f\n', pNormalPair);
if hNormalPair == 0
    fprintf('Normality was not rejected at alpha = %.2f.\n',alpha);
else
    fprintf('Normality was rejected; inspect the plots and outliers.\n');
end
% A non-significant normality test is NOT proof of normality.

%% 5. Paired t-test OR paired nonparametric alternative
% H0: population mean difference (IMU - FP) = 0.
% Run paired t-test when distributional assumptions look reasonable.
if hNormalPair == 0
    [hT, pT, ciT, statsT] = ttest(IMU, FP, 'Alpha', alpha);
    fprintf('\nPAIRED T-TEST: t(%d) = %.3f, p = %.6f\n', ...
        statsT.df,statsT.tstat,pT);
    fprintf('95%% CI for mean IMU - FP difference: [%.2f, %.2f] cm\n', ...
        ciT(1), ciT(2));
    fprintf('Reject H0? %d (1 = yes, 0 = no)\n',hT);
else
    pSignedRank = signrank(IMU,FP);
    fprintf('\nWILCOXON SIGNED-RANK (paired): p = %.6f\n',pSignedRank);
    fprintf('Interpret with attention to symmetry of paired differences.\n');
end

% Visual: identity line represents perfect IMU/FP agreement.
figure('Name','IMU vs FP: CMJ');
scatter(FP,IMU,40,'filled'); hold on;
low = min([FP;IMU]); high = max([FP;IMU]);
plot([low high],[low high],'k--','LineWidth',1.4);
xlabel('FP CMJ (cm)'); ylabel('IMU CMJ (cm)');
title('Paired CMJ measurements: dashed = perfect agreement');
grid on; axis equal; hold off;
% A significant t-test detects average bias, not full agreement.

%% 6. Independent groups: normality and equal-variance checks
% Outcome: FP CMJ height (continuous). Factor: TrainingGroup (nominal).
y = data.FP_CMJ_cm;
validGroup = ~isnan(y) & ~isundefined(G);
y = y(validGroup);
Gvalid = G(validGroup);

levels = categories(Gvalid);
pNormalByGroup = zeros(numel(levels),1);
fprintf('\nFP CMJ HEIGHT BY INDEPENDENT TRAINING GROUP\n');
for k = 1:numel(levels)
    values = y(Gvalid == levels{k});
    [~,pNormalByGroup(k)] = lillietest(values);
    fprintf('%s: n=%d, mean=%.2f cm, SD=%.2f, normality p=%.3f\n', ...
        levels{k},numel(values),mean(values),std(values),pNormalByGroup(k));
end

% Levene test asks whether group variances can be treated as equal.
pLevene = vartestn(y,Gvalid,'TestType','LeveneAbsolute','Display','off');
fprintf('Levene equal-variance test: p = %.4f\n',pLevene);

figure('Name','Independent groups: FP CMJ');
boxplot(y,Gvalid);
xlabel('Training group'); ylabel('FP CMJ height (cm)');
title('Force-plate CMJ across independent groups'); grid on;

%% 7. One-way ANOVA + Tukey post-hoc (CONTINUOUS outcome)
% H0: all three population mean FP CMJ heights are equal.
% ANOVA requires independent subjects, approximately normal within-group
% residuals, and reasonably similar variances.
if all(pNormalByGroup >= alpha) && pLevene >= alpha
    [pAnova, anovaTable, statsAnova] = anova1(y,Gvalid,'off');
    fprintf('\nONE-WAY ANOVA: p = %.8f\n',pAnova);
    disp(anovaTable);

    if pAnova < alpha
        % Columns: group 1, group 2, lower CI, mean difference, upper CI, adj p.
        [tukeyPairs,~,~,groupNames] = multcompare(statsAnova, ...
            'CType','tukey-kramer','Display','off');
        fprintf('Tukey-Kramer post-hoc (adjusted p-values in column 6):\n');
        disp(groupNames);
        disp(tukeyPairs);
    else
        fprintf('No overall ANOVA evidence at alpha=%.2f.\n',alpha);
    end
else
    fprintf('\nCheck distribution and variance assumptions before ordinary ANOVA.\n');
    fprintf('For independent nonnormal continuous outcomes, see next section.\n');
end

%% 8. Alternative for nonnormal INDEPENDENT continuous outcomes
% Kruskal-Wallis analyzes ranks rather than raw means.
% This is presented as an alternative, not as another primary p-value to hunt for.
% Uncomment these lines if the group assumptions are unsuitable for ANOVA:
%
% [pKWcmj,~,statsKWcmj] = kruskalwallis(y,Gvalid,'off');
% fprintf('Kruskal-Wallis FP CMJ: p = %.5f\n',pKWcmj);
% if pKWcmj < alpha
%     ranksPostHoc = multcompare(statsKWcmj,'CType','dunn-sidak','Display','off');
%     disp(ranksPostHoc); % Adjusted mean-rank comparisons, NOT cm differences
% end

%% 9. ORDINAL outcome: Kruskal-Wallis + adjusted rank comparisons
% The scale is 1-5, so means and ordinary ANOVA are not our primary choice.
score = data.LandingControlScore_1to5;
validScore = ~isnan(score) & ~isundefined(G);
score = score(validScore);
Gscore = G(validScore);

figure('Name','Ordinal landing-control score');
boxplot(score,Gscore);
xlabel('Training group'); ylabel('Landing control score (1-5)');
title('Ordinal landing-control ratings'); grid on;

[pOrdinal,~,statsOrdinal] = kruskalwallis(score,Gscore,'off');
fprintf('\nKRUSKAL-WALLIS (ORDINAL): p = %.7f\n',pOrdinal);
if pOrdinal < alpha
    % Adjusted comparisons of MEAN RANKS (not raw score means).
    [ordinalPostHoc,~,~,ordinalGroupNames] = multcompare(statsOrdinal, ...
        'CType','dunn-sidak','Display','off');
    fprintf('Dunn-Sidak adjusted rank comparisons: column 6 = adjusted p\n');
    disp(ordinalGroupNames);
    disp(ordinalPostHoc);
end

%% 10. Short student exercises (complete independently)
% A. Test IMU vs FP for SQUAT JUMP (SJ): how many complete pairs?
%    Check the SJ differences' histogram, Q-Q plot, and normality.
%    Choose paired t-test or signrank, then state your conclusion.
% B. For FP_SJ_cm across training groups, check normality WITHIN each
%    group and variance homogeneity. Choose ANOVA + Tukey if appropriate.
% C. Explain why ordinary anova1 would be wrong for FP_SJ, FP_CMJ, FP_DJ
%    compared as three conditions within the same participants.
% D. Explain whether ordinal score 1-5 should be described primarily
%    by group means or by medians and distributions.

%% 11. Save processed results for later practice
% MATLAB can export the same table used for plotting and analysis.
processed = data;
processed.CMJ_IMU_minus_FP_cm = data.IMU_CMJ_cm - data.FP_CMJ_cm;
writetable(processed,'IMU_FP_Processed_Results.xlsx');
save('IMU_FP_Analysis_Workspace.mat');
fprintf('\nSaved: IMU_FP_Processed_Results.xlsx and workspace MAT file.\n');
