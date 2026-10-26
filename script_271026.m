clear ; 
clc ; 

% Data for today's rain

a = 5;
b= 10;


sum = a  + b;
dif = a - b;

age = [21 23 27 19 45 30];
age_c = [21; 23; 13; 90; 67; 78 ];

Jesse = age(6);
Ali = age_c(5);

aim = age(2:5);
aim_c = age_c(1:4);

measurements = [1 20 46; 
    2 15 12;
    3 12 13;
    4 45 14;
    5 227 16;
    6 28 15;
    7 15 16];

event_day = measurements(5,2);
rain_amounts = measurements(:,2);
total_row2 = measurements(2,:);

%%

ID = [1;2;3;4;5;6];
Height = [170;175;168;182;150;190];
weight = [100; 86; 76; 65; 84; 78];


data = table (ID, age_c, Height, weight);

p = data.weight;
subject_1 = data(1,:);
Tempreture = [36.7; 37; 40; NaN; 38; 41];

idx = Tempreture<40 ;
Tempreture(idx)

missi = ismissing(Tempreture);
not_missing = ~ismissing(Tempreture);


High_temp = Tempreture==41;
Threshold_Temp = Tempreture<=39.5;


%%

figure
plot(data.ID,Height);

xlabel('participents ID')
ylabel('Heights (cm)')
title('Heights of Participents')
grid on

%%
figure
scatter(data.Height,data.weight)
xlabel('Heights (cm)')
ylabel('Weights (kg)')
title ('Height and Weight')
grid on

%%
x = [1 1 2 2 2 3 4 4];
histogram(x)

data = readtable('Biostatistics MATLAB Class Dataset.xlsx');

figure
histogram(data.Age_years)
xlabel('Age (years)')
ylabel('Frequency')
title('Age Distribution')

figure
histogram(data.SystolicBP_mmHg,6)
xlabel('Systolic Blood Pressure (mmHg)')
ylabel('Frequency')
title('Distribution of Systolic Blood Pressure')

histogram(data.SystolicBP_mmHg,4)

% Then try in a new figure:
figure
histogram(data.SystolicBP_mmHg,10)

%% mean, median, and standard deviation

x = [10 11 12 13 14];

mean(x)
median(x)
std(x)


bp = data.SystolicBP_mmHg;

meanBP = mean(bp);
medianBP = median(bp);
sdBP = std(bp);

figure
histogram(bp,6)
xlabel('Systolic Blood Pressure (mmHg)')
ylabel('Frequency')
title('Blood Pressure Distribution')
xline(meanBP,'--','Mean')

xline(meanBP - sdBP,':','-1 SD')
xline(meanBP + sdBP,':','+1 SD')

%% normal-shaped example with randn

z = randn(1000,1);
histogram(z,20)
xlabel('Value')
ylabel('Frequency')
title('Standard Normal Random Sample')

normalData = 70 + 10*randn(1000,1);

figure
histogram(normalData,20)
xlabel('Value')
ylabel('Frequency')
title('Normal Sample: Mean about 70, SD about 10')

within1SD = bp >= (meanBP - sdBP) & bp <= (meanBP + sdBP);

countWithin1SD = sum(within1SD);
totalCount = numel(bp);
percentWithin1SD = 100 * countWithin1SD / totalCount;

%% Boxchart

x = [10 11 12 13 14 15 30];
boxchart(x)
ylabel('Value')
title('Simple Box-and-Whisker Plot')


weight = data.Weight_kg(~ismissing(data.Weight_kg));

figure
boxchart(weight)
ylabel('Weight (kg)')
title('Distribution of Weight')


hr = data.RestingHR_bpm(~ismissing(data.RestingHR_bpm));

figure
boxchart(hr)
ylabel('Resting Heart Rate (bpm)')
title('Resting Heart Rate')


validHR = ~ismissing(data.RestingHR_bpm);

figure
boxchart(data.GroupCode(validHR), data.RestingHR_bpm(validHR))
xlabel('Group')
ylabel('Resting Heart Rate (bpm)')
title('Resting Heart Rate by Group')

xticks([0 1])
xticklabels({'Control','Exercise'})


