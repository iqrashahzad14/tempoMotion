%% Sample size calculation: cross-modal visual-tactile MVPA (bootstrap power)
%
% For each of the 2 targets (somatotopic, external) x 3 variants (a:
% train vis/test tac, b: train tac/test vis, both: average of a and b) x
% 2 metrics (accuracy, AUC) = 12 combinations, estimates statistical
% power to detect a significant sign-flip cluster (fn_signflip_cluster_test.m,
% same one-tailed decoding>chance test as stats_mvpa_crossModal_visualTactile_group.m)
% as a function of hypothetical sample size, via case-resampling bootstrap
% (see fn_bootstrap_power.m for method and caveats).
%
% 1D time-series version - much cheaper per permutation than the 2D
% temporal generalization version (vectorized cluster detection over
% ~450 timepoints instead of flood-fill over a 56x56 pixel grid).
%
% Requires outputs/mvpa_crossModal_visualTactile/group/group_mvpa_crossModal.mat
% (variable groupMvpa.(target).(variant).{accBySubject,aucBySubject}).

clear;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir   = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaGroupMat = fullfile(projectDir, 'outputs', 'mvpa_crossModal_visualTactile', 'group', 'group_mvpa_crossModal.mat');
outDir       = fullfile(projectDir, 'outputs', 'sampleSizeCalculation', 'mvpa_crossModal_visualTactile');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% Bootstrap power parameters
chanceLevel = 0.5;
tail                 = 'right';
clusterFormingAlpha  = 0.05;
clusterAlpha         = 0.05;

Nrange     = [6 10 20 25 30 35 40];
nBootstrap = 100;
nPermMax   = 100;

variants = {'a', 'b', 'both'};
variantTitles = {'train vis / test tac', 'train tac / test vis', 'both (avg)'};

%% Load group results
loaded = load(mvpaGroupMat, 'groupMvpa');
groupMvpa = loaded.groupMvpa;
targetNames = fieldnames(groupMvpa);

sampleSizeResults = struct();

f = figure('Visible', 'off');
nRows = numel(targetNames) * numel(variants);
row = 0;

tStart = tic;
for ti = 1:numel(targetNames)
    tgtName = targetNames{ti};

    for v = 1:numel(variants)
        variant = variants{v};
        row = row + 1;

        fprintf('\n=== %s / %s / acc ===\n', tgtName, variant);
        prAcc = fn_bootstrap_power(groupMvpa.(tgtName).(variant).accBySubject, chanceLevel, Nrange, nBootstrap, ...
            'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha, 'nPermMax', nPermMax);

        fprintf('\n=== %s / %s / auc ===\n', tgtName, variant);
        prAuc = fn_bootstrap_power(groupMvpa.(tgtName).(variant).aucBySubject, chanceLevel, Nrange, nBootstrap, ...
            'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha, 'nPermMax', nPermMax);

        sampleSizeResults.(tgtName).(variant).acc = prAcc;
        sampleSizeResults.(tgtName).(variant).auc = prAuc;

        subplot(nRows, 2, (row-1)*2 + 1);
        local_plot_power(prAcc, sprintf('%s - %s - acc', tgtName, variantTitles{v}));

        subplot(nRows, 2, (row-1)*2 + 2);
        local_plot_power(prAuc, sprintf('%s - %s - auc', tgtName, variantTitles{v}));
    end
end
elapsedTotal = toc(tStart);
fprintf('\nTotal compute time: %.1f min\n', elapsedTotal/60);

sgtitle('Sample size (bootstrap power) - cross-modal visual-tactile MVPA', 'Interpreter', 'none');
set(f, 'Position', [0 0 1100 1600]);
saveas(f, fullfile(outDir, 'sampleSizeCalc_mvpa_crossModal_visualTactile.png'));
close(f);

save(fullfile(outDir, 'sampleSizeCalc_mvpa_crossModal_visualTactile.mat'), 'sampleSizeResults', 'Nrange', 'nBootstrap', ...
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
