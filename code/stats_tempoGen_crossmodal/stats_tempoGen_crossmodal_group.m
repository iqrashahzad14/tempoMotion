%% Stats: cross-modal temporal generalization - sign-flip cluster-based permutation test
%
% Loads each subject's saved train-time x test-time generalization
% matrices (outputs/tempoGen_crossmodal/<sub>/<sub>_tempoGen_crossModal.mat,
% variable results.(target).mean.(variant).{acc,auc}, already averaged
% over the 20 decoding iterations at subject-save time), and tests at
% which (train, test) pixels decoding is above chance across subjects,
% for each of the 2 targets (somatotopic, external) x 3 variants (a:
% train vis/test tac, b: train tac/test vis, both: average of a and b),
% using an exact sign-flip cluster-mass permutation test in 2D (see
% fn_signflip_cluster_test2D.m: cluster detection via 4-connected
% contiguous pixels instead of 1D contiguous runs). Tests the WHOLE
% matrix (any train x test pixel above chance), not just the diagonal.
% Chance is 0.5 for both accuracy and AUC (binary decoding).
%
% NOTE: this supersedes the earlier code/tempoGen_crossmodal/tempoGen_crossmodal_stats.m,
% which used a two-tailed test (decoding != chance, either direction).
% This version uses a one-tailed test (decoding > chance only), for
% consistency with the other 3 tempoGen stats analyses
% (stats_tempoGen_4Dir_withinModality, stats_tempoGen_axisOfMotion_withinModality,
% stats_tempoGen_tactileFrameOfReference) and with the 1D stats_mvpa_*
% analyses, which all test decoding > chance one-tailed. See
% fn_signflip_cluster_test2D.m for the one-tailed vs two-tailed tradeoff.
%
% This is pure statistics on already-computed per-subject matrices - no
% re-decoding - so it runs in well under a minute.
%
% Requires outputs/tempoGen_crossmodal/<sub>/<sub>_tempoGen_crossModal.mat
% for every subject (see tempoGen_crossmodal_subject.m).

clear;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir       = fullfile(projectDir, 'outputs', 'tempoGen_crossmodal');
outDir      = fullfile(projectDir, 'outputs', 'stats_tempoGen_crossmodal');
groupOutDir = fullfile(outDir, 'group');
if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

%% Subjects and test parameters
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

chanceLevel = 0.5; % both accuracy and AUC (binary decoding)
tail                 = 'right'; % test decoding > chance
clusterFormingAlpha  = 0.05;
clusterAlpha         = 0.05;
climRange = [0.35 0.65];

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

statsResults = struct();

f = figure('Visible', 'off');
nRows = numel(targetNames) * numel(variants);
row = 0;

for ti = 1:numel(targetNames)
    tgtName = targetNames{ti};
    timeVec = allResults{1}.(tgtName).time;
    nTime = numel(timeVec);

    for v = 1:numel(variants)
        variant = variants{v};
        row = row + 1;

        groupMean = struct();
        for mi = 1:numel(metrics)
            metricName = metrics{mi};

            stack = zeros(nSub, nTime, nTime);
            for s = 1:nSub
                stack(s, :, :) = allResults{s}.(tgtName).mean.(variant).(metricName);
            end
            groupMean.(metricName) = squeeze(mean(stack, 1, 'omitnan'));

            mStats = fn_signflip_cluster_test2D(stack, chanceLevel, ...
                'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);

            statsResults.(tgtName).(variant).(metricName).stats = mStats;
            statsResults.(tgtName).(variant).(metricName).groupMean = groupMean.(metricName);

            nSig = sum([mStats.clusters.sig]);
            fprintf('%s / %s / %s: %d significant cluster(s) (N=%d, nPerm=%d)\n', ...
                tgtName, variant, metricName, nSig, nSub, mStats.nPerm);
        end

        vLabel = variantTitles{v};
        switch variant
            case 'a'
                ylab = 'Train: visual time (s)'; xlab = 'Test: tactile time (s)';
            case 'b'
                ylab = 'Train: tactile time (s)'; xlab = 'Test: visual time (s)';
            case 'both'
                ylab = 'Visual time (s)'; xlab = 'Tactile time (s)';
        end

        subplot(nRows, 2, (row-1)*2 + 1);
        fn_plot_tempoGen_matrix(timeVec, timeVec, groupMean.acc, climRange, ...
            sprintf('%s - %s - acc (N=%d)', tgtName, vLabel, nSub), ylab, xlab);
        hold on;
        contour(timeVec, timeVec, double(statsResults.(tgtName).(variant).acc.stats.sigMask), [0.5 0.5], 'k-', 'LineWidth', 1.5);
        hold off;

        subplot(nRows, 2, (row-1)*2 + 2);
        fn_plot_tempoGen_matrix(timeVec, timeVec, groupMean.auc, climRange, ...
            sprintf('%s - %s - AUC (N=%d)', tgtName, vLabel, nSub), ylab, xlab);
        hold on;
        contour(timeVec, timeVec, double(statsResults.(tgtName).(variant).auc.stats.sigMask), [0.5 0.5], 'k-', 'LineWidth', 1.5);
        hold off;
    end
end

sgtitle('Group - cross-modal temporal generalization: sign-flip cluster stats (outline = significant, one-tailed)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1100 1600]);
saveas(f, fullfile(groupOutDir, 'group_stats_tempoGen_crossmodal.png'));
close(f);

save(fullfile(groupOutDir, 'group_stats_tempoGen_crossmodal.mat'), 'statsResults', 'chanceLevel', ...
    'tail', 'clusterFormingAlpha', 'clusterAlpha', '-v7.3');
fprintf('Saved group cross-modal temporal generalization stats and plot to %s\n', groupOutDir);
