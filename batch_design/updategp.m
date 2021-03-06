function [x_seq, y_seq, r_seq, metric, time, ee, er, bias, Ef, Varf, l, sigma2, sigman, step, t_optim, t_gen, overhead, gamma] = updategp(fun, noisestructure, noisevar, Xint, xt, model, design, budget, xtt, r, ft, pcr, lambda, batch, t0)

% Generates the synthetic function in each run
%
% Description:
%   [x_seq, y_seq, r_seq, ...] = UPDATEGP(fun, noisestructure, noisevar, 
%   Xint, xt, model, design, budget, xtt, r, ft, pcr, lambda, batch, t0)
%   generates the designs, observations and batch size in each run of the
%   synthetic experiments for a given true function with a given noise
%   structure.

%   PARAMS:
%       budget - total budget (N)
%       fun - the true function
%       noisestructure - the distribution of noise: 'normal', 't_constdf',
%       't_heterodf', 'mixed'
%       noisevar - variance of noise: 'small' (0.1), 'large'(1), 'mixed', 
%       or 'hetero'
%       model - GP or t-GP
%       design - 'MCU', 'cSUR', 'ABSUR'
%       batch - 'FB', 'MLB', 'RB', 'ABSUR'
%       r - the candidate set for r levels
%       t0 - hyperparameter in ABSUR
%       lambda and pcr - hyperparameters in estimating the model 
%       performance for test set xtt

%   Outputs:
%       x_seq - designs 
%       y_seq - noisy observations
%       r_seq - batch size
%       ee - empirical error 
%       er - error rate 
%       bias - bias 
%       metric - optimized acquisition function value 
%       t - total time 
%       Ef - posterior mean function 
%       Varf - posterior function variance 
%       l - lengthscale 
%       sigma2 - sigma2 in covariance function 
%       sigman - sigma2 in likelihood 
%       steps - design size
%       t_optim - time to optimize acquisition function 
%       t_gen - time to generate observation
%       overhead - c_over in ABSUR/ the estimated overhead to optimize the 
%       acquisition function 
%       gamma - hyperparameter in MLB and RB 


%%%%%%% Initialization %%%%%%%
% updates hyperparameter every 80 budgets%
inter_step = int32(80);
% theta in calculation c_over
theta_for_optim = [0.1371 0.000815 1.9871E-6];
% upper bound r is set to be 10% of total budget in ABSUR
% lower bound and upper bound for r in ABSUR
r_lower = r(1);
r_upper = min(r(end), 0.1*budget);
% n0 %
I = size(Xint,1);
% m %
m = size(xt,1); 
% xt is for plotting consideration (grids) in 2D experiments, 
% xtt is the testing points used to measure performance; 
% except 2d experiments, xt is the same as xtt
num_diff_samples = budget/r(1); % max length of data 
% tau %
tau2 = 1; % can use estimated value in gp
% dimension %
d = size(Xint,2);
% fixed tau2 %
[yint, rint]= genFun(Xint, fun, noisestructure, noisevar, r(1));
sigmanint = repmat(tau2/r(1), I, 1);
% initializes design x, observation y, batch r
x_seq = zeros(num_diff_samples,d);
y_seq = zeros(num_diff_samples,1);
r_seq = zeros(num_diff_samples,1);
sigman = zeros(num_diff_samples, 1);
gamma = zeros(num_diff_samples, 1);
overhead = zeros(num_diff_samples, 1);

x_seq(1:I,:) = Xint;
y_seq(1:I) = yint;
r_seq(1:I) = rint;
sigman(1:I) = sigmanint;
% initializes gamma
gamma(1:I) = sqrt(calculate_overall_sigman2(yint, rint, sigmanint))/2; 

% initializes metric, empirical error, error rate, bias %
metric = zeros(num_diff_samples, 1);
ee = zeros(num_diff_samples, 1);
er = zeros(num_diff_samples, 1);
bias = zeros(num_diff_samples, 1);

% initializes hyperparemeters %
l = zeros(num_diff_samples, d);
sigma2 = zeros(num_diff_samples, 1);
time = zeros(num_diff_samples, 1);
t_optim = zeros(num_diff_samples, 1);
t_gen = zeros(num_diff_samples, 1);
opt=optimset('TolFun',1e-3,'TolX',1e-3);

% initializes estimated f, and var %
Ef = zeros(m, num_diff_samples);
Varf = zeros(m,num_diff_samples);

step = 1;
budget = budget - sum(rint);
while (budget > 0)
    total_t = tic;
    
    % updates the hyperparameters every 80 budgets and record the performance %
    if ( step == 1 || idivide(budget, inter_step) ~= idivide(budget + r_seq(I+step-1), inter_step))
        
        % estimate hyperparameters %
        [gprocess, l(step+I,:), sigma2(step+I)] = gp_setup(model, x_seq(1:(I+step-1),:), y_seq(1:(I+step-1)), sigman(1:(I+step-1)), opt);
    end
    
    % makes predictions %
    if ( d == 1 )
        [E, Varf(:,step+I)] = gp_pred(gprocess, x_seq(1:(I+step-1),:), y_seq(1:(I+step-1)), xt);
        Ef(:,step+I) = E(:,1);
        Eftest = E(:,1);
        Varftest = Varf(:,step+I);
    end
    if ( d == 2 )
        [E, Varf(:,step+I)] = gp_pred(gprocess, x_seq(1:(I+step-1),:), y_seq(1:(I+step-1)), xt);
        Ef(:,step+I) = E(:,1);
        [Eftest, Varftest] = gp_pred(gprocess, x_seq(1:(I+step-1),:), y_seq(1:(I+step-1)), xtt);
        Eftest = Eftest(:,1);
    end       
    if ( d == 6 )
        [Eftest, Varftest] = gp_pred(gprocess, x_seq(1:(I+step-1),:), y_seq(1:(I+step-1)), xtt);
        Eftest = Eftest(:,1);
        Ef(:,step+I) = Eftest;
        Varf(:,step+I) = Varftest;
    end

    % calculates the performance metric %
    [lee, er(I+step), ee(I+step), bias(I+step)] = gp_perf(Eftest, Varftest, xtt, ft, pcr, lambda);

    % for ABSUR, calculates the overhead %
    overhead(I + step) = 3*d*CalcOver(theta_for_optim(1), theta_for_optim(2), theta_for_optim(3), step + I);
    
    % optimizes the performance metric and chooses the next design together with batch size r %
    if (strcmp(design, 'uniform'))
        x_seq(I+step,:) = random('unif',0,1, 1, d);
    else
       [x_seq(I+step,:), r_curr, metric(I+step), t_optim(I+step), gamma(I+step)] = seq_design(gprocess, x_seq(1:(I+step-1),:), y_seq(1:(I+step-1)), r_seq(1:(I+step-1)), design, r, batch, gamma(I+step-1), r_lower, r_upper, overhead(I+step), t0);
    end
    
    % generates next observation y
    % handels corner case when budget is smaller than r
    if (budget < r_curr)
        r_curr = budget;
    end
    
    % fixed tau %
    [y_seq(I+step), r_seq(I+step), t_gen(I+step)] = genFun(x_seq(I+step,:), fun, noisestructure, noisevar, r_curr);
    sigman(I+step) = tau2/r_seq(I+step);
    
    % updates noise %
    gprocess.lik.sigma2 = sigman(1:(I+step));
    
    time(step+I) = toc(total_t);
    step = step + 1;
    budget = budget - r_curr;
end
end

        
