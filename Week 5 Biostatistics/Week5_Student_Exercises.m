%% WEEK 5 - STUDENT EXERCISES (SAME CLASS DATASET)
% Complete each TODO using only the ideas shown in the Week 5 demonstration.
% Excel data: 30 synthetic participants, Control=0 and Exercise=1.
% Statistics and Machine Learning Toolbox is needed for all tests.

%% 0. IMPORT THE DATA
clear; clc; close all;
url = ['https://raw.githubusercontent.com/BenBinAli/MATLAB/main/' ...
       'Biostatistics%20MATLAB%20Class%20Dataset.xlsx'];
fileName = 'Biostatistics MATLAB Class Dataset.xlsx';
if ~isfile(fileName)
    if isfile('Biostatistics_MATLAB_Session2_Class_Dataset.xlsx')
        fileName = 'Biostatistics_MATLAB_Session2_Class_Dataset.xlsx';
    else
        websave(fileName,url);
    end
end
data = readtable(fileName);

%% EXERCISE 1 - INDEPENDENT t-TEST ON SYSTOLIC BP (12 minutes)
% A. Extract BP values for Control and Exercise using GroupCode.
% B. Calculate n, mean, SD for both groups.
% C. Run the two-sided WELCH t-test (unequal variances).
% D. Print t, df, p, mean difference and 95% CI.
% E. Write a 1-sentence interpretation without claiming causation.
% TODO:

%% EXERCISE 2 - CHOOSE THE CORRECT TEST (5 minutes)
% For each question, write one of: independent t-test, paired t-test,
% one-sample t-test, or one-way ANOVA.
% A. Mean systolic BP of 2 different participant groups.
% B. Before/after heart rate on the SAME 12 volunteers.
% C. Mean heart rate of one group compared against 70 bpm.
% D. Mean systolic BP among three independent age bands.
% Write answers as comments below.
% TODO:

%% EXERCISE 3 - ANOVA USING THE CLASS DATASET (15 minutes)
% Derive three independent age bands:
%   group 1 = ages 21-24
%   group 2 = ages 25-27
%   group 3 = ages 28-32
% A. Create an ageBand vector for each participant.
% B. Run one-way ANOVA on SystolicBP_mmHg across these age bands.
% C. Record overall F, degrees of freedom and p-value.
% D. Draw a group box-and-whisker chart and label all 3 age bands.
% TODO:

%% EXERCISE 4 - POST-HOC INTERPRETATION (10 minutes)
% A. Use multcompare with the stats output from your Exercise 3 ANOVA.
% B. State which pairwise comparisons have adjusted p < 0.05.
% C. Explain why a significant ANOVA does not imply all 3 pairs differ.
% TODO:

%% OPTIONAL CHALLENGE - 2 GROUPS: t-test vs ANOVA
% Repeat a TWO-GROUP ANOVA on Control/Exercise systolic BP.
% Compare its F value to the SQUARE of the pooled (equal-variance) t-stat.
% Do NOT compare against the Welch t-stat here.
% TODO:
