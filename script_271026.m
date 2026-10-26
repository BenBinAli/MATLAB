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

Measured_data = readtable('Biostatistics MATLAB Class Dataset');

histogram(Measured_data.SystolicBP_mmHg);