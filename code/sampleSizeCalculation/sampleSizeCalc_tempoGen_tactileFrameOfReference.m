%% Sample size calculation: tactile frame-of-reference temporal generalization (bootstrap power)
%
% For each of the 3 decodes (somatotopic, external, handPos) x 2 metrics
% (accuracy, AUC) = 6 combinations, estimates statistical power to
% detect a significant sign-flip cluster (fn_signflip_cluster_test2D.m,
% same one-tailed decoding>chance test as
% stats_tempoGen_tactileFrameOfReference_group.m) as a function of
% hypothetical sample size, via case-resampling bootstrap (see
% fn_bootstrap_power.m for method and caveats).
%
% Requires outputs/tempoGen_tactileFrameOfReference/<sub>/<sub>_tempoGen_tactileFoR.mat
% for every subject.

clear;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir       = fullfile(projectDir, 'outputs', 'tempoGen_tactileFrameOfReference');
outDir      = fullfile(projectDir, 'outputs', 'sampleSizeCalculation', 'tempoGen_tactileFrameOfReference');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% Subjects and bootstrap power parameters
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

chanceLevel = 0.5;
tail                 = 'right';
clusterFormingAlpha  = 0.05;
clusterAlpha         = 0.05;

Nrange     = [6 10 20 25 30 35 40];
nBootstrap = 100;
nPermMax   = 100;

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(tgDir, subjects{s}, [subjects{s} '_tempoGen_tactileFoR.mat']), 'results');
    allResults{s} = loaded.results;
end

decodeNames = fieldnames(allResults{1});
nDecode = numel(decodeNames);

sampleSizeResults = struct();

f = figure('Visible', 'off');

tStart = tic;
for d = 1:nDecode
    dcName = decodeNames{d};
    nTime = size(allResults{1}.(dcName).acc, 2);

    accStack = zeros(nSub, nTime, nTime);
    aucStack = zeros(nSub, nTime, nTime);
    for s = 1:nSub
        accStack(s, :, :) = squeeze(mean(allResults{s}.(dcName).acc, 1)); % average over iterations
        aucStack(s, :, :) = squeeze(mean(allResults{s}.(dcName).auc, 1));
    end

    fprintf('\n=== %s / acc ===\n', dcName);
    prAcc = fn_bootstrap_power(accStack, chanceLevel, Nrange, nBootstrap, ...
        'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha, 'nPermMax', nPermMax);

    fprintf('\n=== %s / auc ===\n', dcName);
    prAuc = fn_bootstrap_power(aucStack, chanceLevel, Nrange, nBootstrap, ...
        'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha, 'nPermMax', nPermMax);

    sampleSizeResults.(dcName).acc = prAcc;
    sampleSizeResults.(dcName).auc = prAuc;

    subplot(nDecode, 2, (d-1)*2 + 1);
    local_plot_power(prAcc, sprintf('%s - acc', dcName));

    subplot(nDecode, 2, (d-1)*2 + 2);
    local_plot_power(prAuc, sprintf('%s - auc', dcName));
end
elapsedTotal = toc(tStart);
fprintf('\nTotal compute time: %.1f min\n', elapsedTotal/60);

sgtitle('Sample size (bootstrap power) - tactile frame-of-reference temporal generalization', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 1200]);
saveas(f, fullfile(outDir, 'sampleSizeCalc_tempoGen_tactileFoR.png'));
close(f);

save(fullfile(outDir, 'sampleSizeCalc_tempoGen_tactileFoR.mat'), 'sampleSizeResults', 'Nrange', 'nBootstrap', ...
    'nPermMax', 'chanceLevel', 'tail', 'clusterFormingAlpha', 'clusterAlpha', 'elapsedTotal', '-v7.3');
fprintf('Saved sample size calculation results and plot to %s\n', outDir);


%% ---- local functions ----

function local_plot_power(pr, titleStr)
plot(pr.Nrange, pr.power, 'o-', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto');
hold on;
yline(0.8, 'k--');
xline(pr.nSubOrig, 'r:');
if ~isnan(pr.N80)
    xline(pr.N80, 'g:');
    n80str = sprintf('%.0f', pr.N80);
else
    n80str = '>40';
end
hold off;
ylim([0 1]); xlabel('N subjects'); ylabel('Power');
title(sprintf('%s (N80=%s)', titleStr, n80str), 'Interpreter', 'none', 'FontSize', 8);
end
