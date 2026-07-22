%% Stats: crossmodal temporal generalization - somatotopic vs external, paired test
%
% Direct paired comparison of the two cross-modal targets from
% tempoGen_crossmodal_subject.m: does training on visual motion and
% testing on tactile (variant 'a'), or training on tactile and testing on
% visual (variant 'b'), generalize differently depending on whether the
% tactile code being decoded is somatotopic (skin-based) or external
% (allocentric)?
%
% For each subject, takes the difference (somatotopic - external) of the
% train-time x test-time generalization matrix, then runs the same
% sign-flip cluster-mass permutation test as fn_signflip_cluster_test2D.m
% (see stats_tempoGen_crossmodal_group.m), but against a chance level of
% 0 instead of 0.5 - a paired difference test is mathematically identical
% to a one-sample test once you work on the per-subject differences
% directly, so the same function is reused unchanged.
%
% Two-tailed (unlike the one-tailed decoding-vs-chance tests elsewhere in
% this project): there is no a priori direction here - the question is
% simply whether somatotopic and external cross-modal generalization
% differ, not which one is bigger.
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

tail                 = 'both'; % two-tailed: no a priori direction for this comparison
clusterFormingAlpha  = 0.05;
clusterAlpha         = 0.05;
climRangeCond = [0.35 0.65];
climRangeDiff = [-0.15 0.15];

variants = {'a', 'b'};
variantTitles = {'train vis / test tac', 'train tac / test vis'};
metrics = {'acc', 'auc'};

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(tgDir, subjects{s}, [subjects{s} '_tempoGen_crossModal.mat']), 'results');
    allResults{s} = loaded.results;
end

timeVec = allResults{1}.somatotopic.time;
nTime = numel(timeVec);

statsResults = struct();

f = figure('Visible', 'off');
nRows = numel(variants) * numel(metrics);
row = 0;

for v = 1:numel(variants)
    variant = variants{v};

    for mi = 1:numel(metrics)
        metricName = metrics{mi};
        row = row + 1;

        somStack = zeros(nSub, nTime, nTime);
        extStack = zeros(nSub, nTime, nTime);
        for s = 1:nSub
            somStack(s, :, :) = allResults{s}.somatotopic.mean.(variant).(metricName);
            extStack(s, :, :) = allResults{s}.external.mean.(variant).(metricName);
        end
        somMean = squeeze(mean(somStack, 1, 'omitnan'));
        extMean = squeeze(mean(extStack, 1, 'omitnan'));

        diffStack = somStack - extStack; % paired within subject
        diffMean = squeeze(mean(diffStack, 1, 'omitnan'));

        diffStats = fn_signflip_cluster_test2D(diffStack, 0, ...
            'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);

        statsResults.(variant).(metricName).somMean   = somMean;
        statsResults.(variant).(metricName).extMean   = extMean;
        statsResults.(variant).(metricName).diffMean  = diffMean;
        statsResults.(variant).(metricName).diffStats = diffStats;

        nSig = sum([diffStats.clusters.sig]);
        if isempty(diffStats.clusters)
            fprintf('%s / %s: no suprathreshold clusters\n', variant, metricName);
        else
            [~, bestIdx] = min([diffStats.clusters.pval]);
            fprintf('%s / %s: %d significant cluster(s) of %d total; best pval=%.4f (mass=%.2f, %d px)\n', ...
                variant, metricName, nSig, numel(diffStats.clusters), diffStats.clusters(bestIdx).pval, ...
                diffStats.clusters(bestIdx).mass, sum(diffStats.clusters(bestIdx).mask(:)));
        end

        switch variant
            case 'a'
                ylab = 'Train: visual time (s)'; xlab = 'Test: tactile time (s)';
            case 'b'
                ylab = 'Train: tactile time (s)'; xlab = 'Test: visual time (s)';
        end
        vLabel = variantTitles{v};

        subplot(nRows, 3, (row-1)*3 + 1);
        fn_plot_tempoGen_matrix(timeVec, timeVec, somMean, climRangeCond, ...
            sprintf('somatotopic - %s - %s (N=%d)', vLabel, metricName, nSub), ylab, xlab);

        subplot(nRows, 3, (row-1)*3 + 2);
        fn_plot_tempoGen_matrix(timeVec, timeVec, extMean, climRangeCond, ...
            sprintf('external - %s - %s (N=%d)', vLabel, metricName, nSub), ylab, xlab);

        subplot(nRows, 3, (row-1)*3 + 3);
        fn_plot_tempoGen_matrix(timeVec, timeVec, diffMean, climRangeDiff, ...
            sprintf('somatotopic - external - %s - %s (N=%d)', vLabel, metricName, nSub), ylab, xlab);
        hold on;
        contour(timeVec, timeVec, double(diffStats.sigMask), [0.5 0.5], 'k-', 'LineWidth', 1.5);
        hold off;
    end
end

sgtitle('Group - crossmodal temporal generalization: somatotopic vs external (paired sign-flip test, two-tailed)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1500 1200]);
saveas(f, fullfile(groupOutDir, 'group_stats_tempoGen_crossmodal_somatotopicVsExternal.png'));
close(f);

save(fullfile(groupOutDir, 'group_stats_tempoGen_crossmodal_somatotopicVsExternal.mat'), 'statsResults', ...
    'tail', 'clusterFormingAlpha', 'clusterAlpha', '-v7.3');
fprintf('Saved somatotopic-vs-external paired stats and plot to %s\n', groupOutDir);
