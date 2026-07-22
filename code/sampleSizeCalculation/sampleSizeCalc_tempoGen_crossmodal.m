%% Sample size calculation: cross-modal temporal generalization (bootstrap power)
%
% For each of the 2 targets (somatotopic, external) x 3 variants (a:
% train vis/test tac, b: train tac/test vis, both: average of a and b) x
% 2 metrics (accuracy, AUC) = 12 combinations, estimates statistical
% power to detect a significant sign-flip cluster (fn_signflip_cluster_test2D.m,
% same one-tailed decoding>chance test as stats_tempoGen_crossmodal_group.m)
% as a function of hypothetical sample size, via case-resampling bootstrap
% (see fn_bootstrap_power.m for method and caveats).
%
% This is the most expensive of the 4 sample-size analyses: 2D cluster
% detection (56x56 pixel grid) is much slower per permutation than the 1D
% time-series tests, and crossmodal has the most combinations (12).
%
% Requires outputs/tempoGen_crossmodal/<sub>/<sub>_tempoGen_crossModal.mat
% for every subject.

clear;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir       = fullfile(projectDir, 'outputs', 'tempoGen_crossmodal');
outDir      = fullfile(projectDir, 'outputs', 'sampleSizeCalculation', 'tempoGen_crossmodal');
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
nPermMax   = 100; % permutations INSIDE each bootstrap replicate's significance test

variants = {'a', 'b', 'both'};
variantTitles = {'train vis / test tac', 'train tac / test vis', 'both (avg)'};
metrics = {'acc', 'auc'};

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(tgDir, subjects{s}, [subjects{s} '_tempoGen_crossModal.mat']), 'results');
    allResults{s} = loaded.results;
end

targetNames = fieldnames(allResults{1});

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

        for mi = 1:numel(metrics)
            metricName = metrics{mi};

            stack = zeros(nSub, size(allResults{1}.(tgtName).mean.(variant).(metricName), 1), ...
                          size(allResults{1}.(tgtName).mean.(variant).(metricName), 2));
            for s = 1:nSub
                stack(s, :, :) = allResults{s}.(tgtName).mean.(variant).(metricName);
            end

            fprintf('\n=== %s / %s / %s ===\n', tgtName, variant, metricName);
            pr = fn_bootstrap_power(stack, chanceLevel, Nrange, nBootstrap, ...
                'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha, 'nPermMax', nPermMax);

            sampleSizeResults.(tgtName).(variant).(metricName) = pr;

            subplot(nRows, 2, (row-1)*2 + mi);
            plot(pr.Nrange, pr.power, 'o-', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto');
            hold on;
            yline(0.8, 'k--');
            xline(nSub, 'r:');
            if ~isnan(pr.N80)
                xline(pr.N80, 'g:');
            end
            hold off;
            ylim([0 1]); xlabel('N subjects'); ylabel('Power');
            title(sprintf('%s - %s - %s (N80=%s)', tgtName, variantTitles{v}, metricName, ...
                local_n80_str(pr.N80)), 'Interpreter', 'none', 'FontSize', 8);
        end
    end
end
elapsedTotal = toc(tStart);
fprintf('\nTotal compute time: %.1f min\n', elapsedTotal/60);

sgtitle('Sample size (bootstrap power) - cross-modal temporal generalization', 'Interpreter', 'none');
set(f, 'Position', [0 0 1100 1600]);
saveas(f, fullfile(outDir, 'sampleSizeCalc_tempoGen_crossmodal.png'));
close(f);

save(fullfile(outDir, 'sampleSizeCalc_tempoGen_crossmodal.mat'), 'sampleSizeResults', 'Nrange', 'nBootstrap', ...
    'nPermMax', 'chanceLevel', 'tail', 'clusterFormingAlpha', 'clusterAlpha', 'elapsedTotal', '-v7.3');
fprintf('Saved sample size calculation results and plot to %s\n', outDir);


%% ---- local functions ----

function s = local_n80_str(n80)
if isnan(n80)
    s = '>40';
else
    s = sprintf('%.0f', n80);
end
end
