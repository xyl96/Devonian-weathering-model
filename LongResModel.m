%%%% Xianyi Liu, Jan of 2022 %%%%%
% Devonian weathering model %
% Steady state box monte-carlo model incorporate Li and Sr isotopes %
% Main forcing: Temp, Denudation, Plants %
% Plnats increase weathering rate by 4 times and create thick regolith %
% based on Kalderon Aesal 2021 code in python
% and coupled West 2012, Rugustein 2019, Dellinger 2015, 2017
clear; 
clc;

% time start and end (across devonian), in myrs
time_start = 415;
time_end = 365;
% number of re-sampling
monte = 2000;

% re-arrange time
t = linspace(1,time_start - time_end + 1,10);

% fit curve load (madeup, +3 permil from carb to sw)
data = readtable('carb_Summary.xlsx'); % Table S1, brach carb d7Li
data2 = readtable('nature supply data.xlsx'); % d7Li data from 
data3 = readtable('bulk.xlsx'); % Table S2, bulk carbs
iso = [data.d7Lis+3.6; data2.d7Li+4; data3.d7Lis+6.1];
age = [data.Age; data2.age; data3.Age];
age(find(isnan(iso))) = [];
iso(find(isnan(iso))) = [];
iso(find(isnan(age))) = [];
age(isnan(age)) = [];
iso_loess = smooth(age,iso,0.2,'rloess');
[x1,ind] = sort(age);

% test smoothing factor

iso_loess2 = smooth(age,iso,0.1,'rloess');
iso_loess3 = smooth(age,iso,0.3,'rloess');
iso_loess4 = smooth(age,iso,0.2,'loess');

[x2,ind2] = sort(age);
[x3,ind3] = sort(age);
[x4,ind4] = sort(age);
figure;
plot(x1,iso_loess2(ind),'-','Linewidth',2);
hold on;
plot(x2,iso_loess(ind2),'-','Linewidth',2);
plot(x3,iso_loess3(ind3),'-','Linewidth',2);
plot(x4,iso_loess4(ind4),'-','Linewidth',2);
scatter(data.Age,data.d7Lis+3.6,'ok');
ylabel('\delta^{7}Li (‰)');
xlabel('Age (Ma)')
data2 = readtable('nature supply data.xlsx');
scatter(data2.age,data2.d7Li+4,'kd'); 
scatter(data3.Age,data3.d7Lis+6.1,'sk');
%result = cftool(age,iso);
set(gca,'linewidth',1.2,'FontSize',12);%,'yticklabel',{[]}
legend('rloess:0.1','rloess:0.2','rloess:0.3','loess:0.2');
set(gcf, 'Position',  [100, 100, 560, 280]);
set(gca, 'xdir', 'reverse');
set(gca,'linewidth',1.2,'FontSize',12,'xticklabel',{[]});
box on;
hold off;
early = iso(age > 385);
late = iso(age < 385);
[h,p] = ttest2(early, late);


% plot d7Li data

figure;
errorbar(data.Age,data.d7Li,data.err,data.err,data.age_err,data.age_err,'o','color',[175 120 0]/255);
%ylabel('\delta^{7}Li / ‰');
%xlabel('Age / Ma')
hold on;
data2 = readtable('nature supply data.xlsx');
scatter(data2.age,data2.d7Li,'kd'); 
scatter(data3.Age,data3.d7Li,'s','MarkerEdgeColor',[50 150 100]/255); % bulk carbs D = 6.1, Pogge von Strandmann 2019
set(gca,'linewidth',1.2,'FontSize',12,'xticklabel',{[]}, 'xdir', 'reverse');%,'yticklabel',{[]}
%legend('LOESS curve','Brachiopods','Previous studies','Bulk');
set(gcf, 'Position',  [100, 100, 560, 180]);
box on;
xlim([360 420]);
hold off;

% plot LOESS curve and screened d7Li data

figure;
plot(x1,iso_loess(ind),'-','color',[120 120 120]/255,'Linewidth',2);
hold on;
scatter(data.Age,data.d7Lis+3.6,'o','MarkerEdgeColor',[175 120 0]/255);
%ylabel('\delta^{7}Li / ‰');
%xlabel('Age / Ma')
data2 = readtable('nature supply data.xlsx');
scatter(data2.age,data2.d7Li+4,'kd'); 
scatter(data3.Age,data3.d7Lis+6.1,'s','MarkerEdgeColor',[50 150 100]/255); % bulk carbs D = 6.1, Pogge von Strandmann 2019
set(gca,'linewidth',1.2,'FontSize',12,'xticklabel',{[]});
%legend('LOESS curve','Brachiopods','Previous studies','Bulk');
set(gcf, 'Position',  [100, 100, 560, 180]);
xlim([360 420]);
hold off;

y1 = iso_loess(ind);
[x2,ind2] = unique(x1);
y2 = y1(ind2);
fit_age = linspace(365,415,length(t));
fit_Li = interp1(x2,y2,fit_age);

%interpolate curve(don't need here)

% upper and lower limit (give uncertainty)
fit_Li_upp = fit_Li + 4;
fit_Li_low = fit_Li - 4;

% pre-allocate memory for simulation
Li_sw = NaN(length(t),monte);
Fr = NaN(length(t),monte);
Rr = NaN(length(t),monte);
Fh = NaN(length(t),monte);
Rh = NaN(length(t),monte);
Dsink = NaN(length(t),monte);
D = NaN(length(t),monte); % Weathering intensity
z = NaN(length(t),monte); % present-day W/D
Inten = NaN(length(t),monte);
Rc = NaN(length(t),monte);
total_flux = NaN(length(t),monte);
D =  NaN(length(t),monte);
Rc =  NaN(length(t),monte);
Sr_sil = NaN(length(t),monte);
Sr_carb = NaN(length(t),monte);
Fr_Sr = NaN(length(t),monte);
Fh_Sr = NaN(length(t),monte);
Li_sw_result = NaN(length(t),monte);
Fr_result = NaN(length(t),monte);
Rr_result = NaN(length(t),monte);
f = NaN(length(t),monte);

% Denudation and stuff, mainly from West 2012
D_modern = 0.06 * 2500; % mm/yr, [0.04,0.08], Rugustein 2019, assume density = 2.5
K = 5e-6 * 120 * 12e7 ; % from Ferrier and Kirchner 2008, in y
Kcl = 5e-8 * 2000 * 8e7; % from Ferrier and Kirchner 2008, in y
kp = 1; % plants enhancing weathering rate
Ea = 45.3 * 1000; % j/mol, silicate diss Ea
Ea_c = 65 * 1000; % calcite dissolution Ea
sig = -0.18; %  range -0.33 to 0.13
sig2 = -0.06; %  range -0.33 to 0.13
P = 1; % precipitation 1000mm = 1m world average
w = 2.6; % modern-day Budyko Parameter
Ep = 1; % evaporation + transipiration
q = P - P .* (1 + Ep./P - (1 + (Ep./P).^w).^(1./w)); % run-off based on modern data by following Ibarra 2019.
r_off_rate = q/P;
kw = 7.6e-5; % West 2012
R = 8.314; % Gas const
T0 = 288; % ambient temp, 15C
T = 287; % modern world avg temp
kh = 1e5; % Gabbet and Mudd 2009
phi = 2300; % Gabbet and Mudd 2009
R_rock = 2;
Fr0 = 1e10; % modern Li output
Fr_modern = Fr0;
k_Denudation = interp1([365; 380; 404; 415], [0.82; 0.67; 0.61; 1.07], fit_age); % from Berner 2001, Denudation rate to present, Table S3

% load degassing rate from Ben Mills 2017, from ridge/ subduction length
Degas = readtable ('Degassing.xlsx'); % Table S3
k_degas = Degas.k;

% calibrate Li riverine flux based on modern field study
D_modern = 0.06 * 2500; % Denudation from Caves Rugestein 2019
z_modern = 2500 .* log(D_modern ./ kh) ./ (-1*phi);
z_r_modern = z_modern .* exp(-z_modern / 2.5/2.75);
Rc_modern = 1 - exp(-K * (1 - exp(-kw * q)) * exp(...
    Ea ./ (R * T0) - Ea ./ (R * T)) * ((z_r_modern ./ (D_modern))^(sig + 1) ./ (sig + 1))); % modern scenario, calculate W from D
Rccl_modern = 1 - exp(-Kcl * (1 - exp(-kw * q)) * exp(...
    Ea ./ (R * T0) - Ea ./ (R * T)) * ((z_r_modern ./ D_modern).^(sig2 + 1) ./ (sig2 + 1))); % modern scenario, calculate W from D (clay mineral diss)

W_modern = Rc_modern .* D_modern ;
Inten_modern = W_modern ./ D_modern; % WI
Wcl_modern = Rccl_modern .* D_modern;
f0 = 0.05 * (Inten_modern .^-0.47); % from Dellinger 2015
k_Li = Fr_modern ./ (W_modern .* f0 + Wcl_modern); % scaling factor to link Li weathering flux and E, mainly incorporates Li concs in crust & land area


% import T data from Scotese et al., 2021 ESR
T_table = readtable('temp.xlsx'); % Table S3
T = T_table.temp_K;
%alpha = 1.8 * 1e6./(T.^2); % fractioantion dependence of temp,  Li and West 2014

% temperature and runoff
%P = 1 * (1 + 0.038 *(T - 287)); % from Probst and Tardy, 1989

% model initilization 
for i = 1:length(t)
    
    for j = 1: monte
 
        % Forcing of plants enhacning weathering
        %kp(i,j) = 4; % Berner & Berner 2003, Lenton et al., 2012
        
        %Forcing (Denudation & Regolith thickness)
        D(i,j) = k_Denudation(i) .* 2500 * unifrnd(0.04,0.08); % present-day value
        x(i,j) = unifrnd(-2,1.5); % makes sure unifrnd can sample the lowerend
        z(i,j) = 10.^x(i,j); % weathering profile thickness

        %Temperature uncertainty
        T(i,j) = unifrnd(T(i)-2,T(i)+2);
        P(i,j) = 1 * (1 + 0.038 *(T(i,j) - 287));  %precipitation
        q(i,j) = P(i,j) .* r_off_rate; % run-off
        Rc(i,j) = 1 - exp(-K .* exp(-z(i,j) ./ 2.5/2.75) * (1 - exp(-kw * q(i,j))) * exp(...
        Ea ./ (R * T0) - Ea ./ (R * T(i,j))) * ((z(i,j) ./ D(i,j))^(sig + 1) ./ (sig + 1))); % Silicate weathering, West 2012
        Rccl(i,j) = 1 - exp(-Kcl .* exp(-z(i,j) ./ 2.5/2.75) * (1 - exp(-kw * q(i,j))) * exp(...
        Ea ./ (R * T0) - Ea ./ (R * T(i,j))) * ((z(i,j) ./ D(i,j)).^(sig2 + 1) ./ (sig2 + 1))); % secondary silicate mienral dissolution
        
        %Li input
        Inten(i,j) = Rc(i,j); %weathering intensity assignment
        f(i,j) = 0.05 .* (Inten(i,j).^-0.47); % from Dellinger 2015

        if f(i,j) > 1 
           f(i,j) = 1;
        else
           f(i,j) = f(i,j);
        end

        alpha(i,j) = 1.8 * 1e6./(T(i,j).^2);
        W(i,j) = D(i,j) .* Rc(i,j); % primary rocks weathering rate
        Wcl(i,j) = D(i,j) .* Rccl(i,j); % dissolution from secondary minerals;
        Fr_dis(i,j) = W(i,j) .* k_Li; %scale withc onstant k_Li
        Fr_p(i,j) = Fr_dis(i,j) .* f(i,j); % fit the Li flux with Dellinger 2015, weathering rate of Li after removal
        Fr_cl(i,j) = Wcl(i,j) .* k_Li; % do not consider minerals precipitation from secondary mineral dissolution
        Fr(i,j) = Fr_p(i,j) + Fr_cl(i,j); % riverine Li flux
        %alpha(i,j) = unifrnd(alpha(i)-5,alpha(i)-5);
        Rr_r(i,j) = R_rock - alpha(i) .* log(f(i,j)); % fluid d7Li evolved following Rayleigh;
        Rr_b(i,j) = R_rock + alpha(i) .* (1-f(i,j)); % fluid d7Li evolve following Batch;
        Rcl(i,j) = R_rock - 2 - 10 * Inten(i,j); % seconday mineral d7Li, from Dellinger 2017
        Rr_p(i,j) = Rr_r(i,j) .* (1 - Inten(i,j)) + Rr_b(i,j) .* Inten(i,j); % high intensity follow batch, low intensity follow rayleigh
        Rr(i,j) = Rcl(i,j) .* Fr_cl(i,j) ./(Fr_p(i,j) + Fr_cl(i,j)) + Rr_p(i,j) .* Fr_p(i,j) ./(Fr_p(i,j) + Fr_cl(i,j)); % mixing between pri and sec minerals
        Rr(i,j) = unifrnd(Rr(i,j) - 2, Rr(i,j) + 2); % assign uncertainties
        Fh(i,j) = k_degas(i) .* unifrnd(5.2e9,6e9); % hydrothermal input Flux
        Rh(i,j) = unifrnd(6.3,8.3); % hydrothermal input Ratio
        Dsink(i,j) = unifrnd(1,10); % Delta of sink, do not distinguish maac and aoc
        Fs(i,j) = k_degas(i) .* unifrnd(5e9,7e9); % Misra 2012 subduction reflux
        Rs(i,j) = fit_Li(i) - Dsink(i,j); % subduction R = seawater - D
        
        % Li mass balance, assume steady state, Li residence time = 1Ma
        total_flux (i,j) = Fr(i,j) + Fh(i,j) + Fs(i,j); % mass balance
        Li_sw(i,j) = (Fr(i,j) .* Rr(i,j) + Fh(i,j) * Rh(i,j) + Rs(i,j) .* Fs(i,j)) ./ total_flux (i,j) + ...
              Dsink (i,j);   % isotopic balance

        % exclude data that are not in the range
        
        if (Li_sw (i,j) <= fit_Li_upp(i)) && (Li_sw (i,j) >= fit_Li_low(i)) %...
                %&& (Rsw_Sr(i,j) <= fit_Sr_upp(i)) && (Rsw_Sr (i,j) >= fit_Sr_low(i))
            % Li data output
            Li_sw_result(i,j) = Li_sw(i,j);
            Fr_result(i,j) = Fr(i,j);
            Rr_result(i,j) = Rr(i,j);
            Dsink_result(i,j) = Dsink(i,j);
            Inten_result(i,j) = Inten(i,j);
            z_result (i,j) = z(i,j);
            D_result(i,j) = D(i,j);
            f_result(i,j) = f(i,j);
            D_result(i,j) = D(i,j);

        else
            Li_sw_result(i,j) = nan;
            Fr_result(i,j) = nan;
            Rr_result(i,j) = nan;
            f_result(i,j) = nan;
            Dsink_result(i,j) = nan;
            Dmaac_result(i,j) = nan;
            Inten_result(i,j) = nan;
            z_result (i,j) = nan;
             
        end

    end
end
    
% data plot   
subplot(4,2,2);
plot (fit_age, Li_sw_result,'.r','MarkerSize',30);
hold on;
plot(fit_age,fit_Li_upp,'k','linewidth',1.2);
plot(fit_age,fit_Li_low,'k','linewidth',1.2);
plot(fit_age,fit_Li,'k--','linewidth',1.2);
%xlabel('Age / Ma');
ylabel('\delta^{7}Li (‰)');
set(gca,'linewidth',1.2,'FontSize',12,'xticklabel',{[]});
%set(gcf, 'Position',  [100, 100, 560, 200]);
set (gca, 'xdir', 'reverse');
hold off;

numberfit = sum(~isnan(Li_sw_result),2);
subplot(4,2,1);
area(fit_age,numberfit);
set(gca,'linewidth',1.2,'FontSize',12,'xticklabel',{[]});
set(gcf, 'Position',  [100, 100, 560, 80]);
set (gca, 'xdir', 'reverse');
xlim([360 420]);
ylabel('n');
hold off;

% figure;
% plot(fit_age_Sr,Rsw_Sr_result,'.r','MarkerSize',12);
% hold on;
% plot(fit_age,fit_Sr_upp,'r');
% plot(fit_age,fit_Sr_low,'r');
% plot(fit_age,fit_Sr,'r--');
% %xlabel('Age / Ma');
% ylabel('^{87}Sr / ^{86}Sr');
% set(gca,'linewidth',1.2,'FontSize',12,'xticklabel',{[]}, 'xdir', 'reverse');
% set(gcf, 'Position',  [100, 100, 560, 200]);
% hold off;

subplot(4,2,3);
scatter (fit_age, Fr_result./(1e9),'MarkerFaceAlpha', 0.01, 'MarkerEdgeColor', 'r', 'MarkerEdgeAlpha',  0.025);%,'MarkerSize',12
hold on;
plot(fit_age,median(Fr_result,2,'omitnan')/(1e9),'k','linewidth',1.5);
%xlabel('Age / Ma');
ylabel('Riverine Li flux (Gmol/y)');
set(gca,'linewidth',1.2,'FontSize',8,'xticklabel',{[]}, 'xdir', 'reverse');
%set(gcf, 'Position',  2.*[100, 100, 560, 200]);
box on;
hold off;

subplot(4,2,4);
scatter (fit_age, Rr_result, 25,'MarkerFaceAlpha', 0.01, 'MarkerEdgeColor', 'r', 'MarkerEdgeAlpha',  0.025);
hold on;
plot(fit_age,median(Rr_result,2,'omitnan'),'k','linewidth',1.5);
%xlabel('Age / Ma');
ylabel('Riverine \delta^{7}Li (‰)');
set(gca,'linewidth',1.2,'FontSize',8,'xticklabel',{[]}, 'xdir', 'reverse');
%set(gcf, 'Position',  2.*[100, 100, 560, 200]);
box on;
hold off;

subplot(4,2,5);
scatter(fit_age, Dsink_result,25,'MarkerFaceAlpha', 0.01, 'MarkerEdgeColor', 'r', 'MarkerEdgeAlpha',  0.025);
hold on;
plot(fit_age,median(Dsink_result,2,'omitnan'),'k','linewidth',1.5);
%xlabel('Age / Ma');
ylabel('\Delta^{7}Li_{(seawater-sink)} (‰)');
set(gca,'linewidth',1.2,'FontSize',8, 'xticklabel',{[]},'xdir', 'reverse');
%set(gcf, 'Position',  2.*[100, 100, 560, 200]);
box on;
hold off;
%figure(6);
%plot (fit_age, Dmaac_result,'r.');

subplot(4,2,6);
scatter(fit_age,Inten_result,25,'MarkerFaceAlpha', 0.01, 'MarkerEdgeColor', 'r', 'MarkerEdgeAlpha',  0.025);
hold on;
plot(fit_age,median(Inten_result,2,'omitnan'),'k','linewidth',1.5);
%xlabel('Age / Ma');
ylabel('WI');
set(gca, 'YScale', 'log','linewidth',1.2,'FontSize',8, 'xticklabel',{[]},'xdir', 'reverse');
%set(gcf, 'Position',  2.*[0, 0, 500, 500]);
box on;
hold off;



subplot(4,2,8);
scatter(fit_age, z_result,25,'MarkerFaceAlpha', 0.01, 'MarkerEdgeColor', 'r', 'MarkerEdgeAlpha',  0.025);
hold on;
semilogy(fit_age,median(z_result,2,'omitnan'),'k','linewidth',1.5);
%xlabel('Age / Ma');
ylabel('Regolith thickness (t/m^{2})');
set(gca,'YScale','log','linewidth',1.2,'FontSize',8, 'xdir', 'reverse');
box on;
%set(gcf, 'Position',  [100, 100, 560, 200]);
hold off;

subplot(4,2,7);
scatter(fit_age, f_result,25,'MarkerFaceAlpha', 0.01, 'MarkerEdgeColor', 'r', 'MarkerEdgeAlpha',  0.025);
hold on;
plot(fit_age,median(f_result,2,'omitnan'),'k','linewidth',1.5);
%xlabel('Age / Ma');
ylabel('W. Congruency');
set(gca,'linewidth',1.2,'FontSize',8, 'xdir', 'reverse');
set(gcf, 'Position',  [0, 0, 600, 800]);
box on;
hold off;

figure;
plot(Fr_result,Rr_result,'r.','MarkerSize',12);
hold on;
%xlabel('Li / mol/y');
ylabel('\delta^{7}Li (‰)');
set(gca,'linewidth',1.2,'FontSize',12,'xticklabel',{[]}, 'xdir', 'reverse');
%set(gcf, 'Position',  [100, 100, 560, 200]);
hold off;

figure;
plot(fit_age, D_result/2500,'r.','MarkerSize',12);
hold on;
%xlabel('Age / Ma');
ylabel('Denudeation (mm/y)');
set(gca,'linewidth',1.2,'FontSize',12,'xticklabel',{[]}, 'xdir', 'reverse');
set(gcf, 'Position',  [100, 100, 560, 200]);
hold off;