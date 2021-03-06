% SYNTHETICEXPERIMENTS the main file used to generate results for synthetic
% experiments: 1d Exponential, 2d Brannin-Hoo, and 6d Hartman.

% Description:
%   SYNTHETICEXPERIMENTS calculates the synthetic results for known true
%   functions. There are four cases for the noise structure: normal
%   distributed noise with small/large variance, t distributed noise with
%   small/large variance, mixture normal distributed noise and
%   heteroskedastic t distributed noise. GP and t-GP are supported
%   likelihood for Gaussian Process simulator. The parameters are set at
%   the same value as in the paper (also support user defined parameters).
%   Here is a demo for 1d Exponential function with t distributed small
%   noise.

%%% k is the number of runs 
%%% I is the initial design
%%% budget is the total budget
%%% m0 is the test size

clear all; close all; clc;

currentFolder = pwd;
parentFolder = fileparts(currentFolder);
addpath(parentFolder);

startup;


%%%%%% dimensions %%%%%%

%%%%% 1d %%%%%

k = 20; % runs of experiments
I = 10; 
d = 1;
budget = 80;
m0 = 1000;
fun = @(x) (x+0.75).*(x-0.75); 

%%%%%%%%%%%%%%%%%%%%%%% other choices %%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%% 2d %%%%%

% % k = 20; % runs of experiments
% % I = 20;
% % d = 2;
% % budget = 150;
% % m0 = 50;
% % fun = @braninsc2; 

%%%% 6d %%%%%
% % 
% % k = 10; % runs of experiments
% % I = 60;
% % d = 6;
% % budget = 1000;
% % m0 = 0;
% % fun = @hart6; 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%% cases %%%%
%%% t_constdf_small %%%

noisestructure = 't_constdf';
noisevar = 'small';

%%%%%%%%%%%%%%%%%%%%%%% other choices %%%%%%%%%%%%%%%%%%%%%%%%%%%

% %%% t_constdf_large %%%
% 
% noisestructure = 't_constdf';
% noisevar = 'large';

% %%% mix_gauss %%%
% 
% noisestructure = 'mixed';
% noisevar = 'mixed';

% % t_hetero %%%
% 
% noisestructure = 't_heterodf';
% noisevar = 'hetero';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% % model % %

model = {'gauss'};
% model = {'t'};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% % design % %

design = {'MCU'};
% design = {'cSUR', 'MCU'};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% % batch % %

batch = {'MLB'};
r = [5 10 15 20 30 40 50 60 80]; % levels for r
% batch = {'FB', 'MLB', 'RB', 'null'};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[x_seq, y_seq, r_seq, ee, er, bias, metric, t, Ef, Varf] = updategppar(I, k, m0, d, budget, fun, char(noisestructure), char(noisevar), char(model), char(design), char(batch), r);
