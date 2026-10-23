%% Temporal generalization: cross-modal visual-tactile decoding - group level
%
% Loads each subject's saved train-time x test-time generalization
% matrices (already averaged over iterations within-subject, see
% tempoGen_crossmodal_subject.m, for a/b/both x acc/auc x 2 targets), and
% averages across the 6 subjects. Plots the group-average T x T heatmaps
% for each combination.
%
% Requires outputs/derivatives/tempoGen/tempoGen_crossmodal/<sub>/<sub>_tempoGen_crossmodal.mat
% for every subject (see tempoGen_crossmodal_subject.m).

clear;

addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir       = fullfile(projectDir, 'outputs', 'derivatives', 'tempoGen', 'tempoGen_crossmodal');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006', ...
            'sub-007', 'sub-008', 'sub-009', 'sub-010', 'sub-011', 'sub-012', ...
            'sub-014'};  % N=13 (2026-10-22); sub-013, sub-015 still to be preprocessed

% each sample size gets its own folder (group_N<N>)
groupOutDir = fullfile(tgDir, sprintf('group_N%d', numel(subjects)));
% optional: write to another folder (e.g. for a verification run)
if ~isempty(getenv('GROUP_OUTDIR')), groupOutDir = getenv('GROUP_OUTDIR'); end
nSub = numel(subjects);

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    srcDir = tgDir;
    fprintf('%s from %s\n', subjects{s}, srcDir);
    loaded = load(fullfile(srcDir, subjects{s}, [subjects{s} '_tempoGen_crossmodal.mat']), 'results');
    allResults{s} = loaded.results;
end

targetNames = fieldnames(allResults{1});
variants = {'a', 'b', 'both'};

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

groupTempoGen = struct();
climRange = [0.35 0.65];

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

        accStack = zeros(nSub, nTime, nTime);
        aucStack = zeros(nSub, nTime, nTime);
        for s = 1:nSub
            accStack(s, :, :) = allResults{s}.(tgtName).mean.(variant).acc;
            aucStack(s, :, :) = allResults{s}.(tgtName).mean.(variant).auc;
        end
        accGroup = squeeze(mean(accStack, 1));
        aucGroup = squeeze(mean(aucStack, 1, 'omitnan'));

        groupTempoGen.(tgtName).(variant).acc = accGroup;
        groupTempoGen.(tgtName).(variant).auc = aucGroup;
        groupTempoGen.(tgtName).(variant).time = timeVec;

        switch variant
            case 'a'
                ylab = 'Train: visual time (s)'; xlab = 'Test: tactile time (s)';
                vLabel = 'train vis / test tac';
            case 'b'
                ylab = 'Train: tactile time (s)'; xlab = 'Test: visual time (s)';
                vLabel = 'train tac / test vis';
            case 'both'
                ylab = 'Visual time (s)'; xlab = 'Tactile time (s)';
                vLabel = 'both (avg)';
        end

        subplot(nRows, 2, (row-1)*2 + 1);
        fn_plot_tempoGen_matrix(timeVec, timeVec, accGroup, climRange, ...
            sprintf('%s - %s - acc (N=%d)', tgtName, vLabel, nSub), ylab, xlab);

        subplot(nRows, 2, (row-1)*2 + 2);
        fn_plot_tempoGen_matrix(timeVec, timeVec, aucGroup, climRange, ...
            sprintf('%s - %s - AUC (N=%d)', tgtName, vLabel, nSub), ylab, xlab);
    end
end

sgtitle('Group - cross-modal temporal generalization', 'Interpreter', 'none');
set(f, 'Position', [0 0 1100 1600]);
% (plain group figure no longer saved: the stats figure below shows the same
%  curves plus the significant time points)
% saveas(f, fullfile(groupOutDir, 'group_tempoGen_crossmodal.png'));
close(f);

save(fullfile(groupOutDir, 'group_tempoGen_crossmodal.mat'), 'groupTempoGen', '-v7.3');
fprintf('Saved group cross-modal temporal generalization results and plot to %s\n', groupOutDir);

%% ===================== statistics (merged from stats/stats_tempoGen_crossmodal_group.m (N=12 version), 2026-10-22) =====================
%% Stats: cross-modal temporal generalization - sign-flip cluster-based permutation test
%
% Loads each subject's saved train-time x test-time generalization
% matrices (outputs/derivatives/tempoGen/tempoGen_crossmodal/<sub>/<sub>_tempoGen_crossmodal.mat,
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
% NOTE: this supersedes the earlier code/tempoGen/tempoGen_crossmodal/tempoGen_crossmodal_stats.m,
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
% Requires outputs/derivatives/tempoGen/tempoGen_crossmodal/<sub>/<sub>_tempoGen_crossmodal.mat
% for every subject (see tempoGen_crossmodal_subject.m).

addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir       = fullfile(projectDir, 'outputs', 'derivatives', 'tempoGen', 'tempoGen_crossmodal');
% stats are saved next to the group results (groupOutDir defined above)
if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

%% Subjects and test parameters
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006', ...
            'sub-007', 'sub-008', 'sub-009', 'sub-010', 'sub-011', 'sub-012', ...
            'sub-014'};  % N=13 (2026-10-22); sub-013, sub-015 still to be preprocessed
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
    srcDir = tgDir;
    loaded = load(fullfile(srcDir, subjects{s}, [subjects{s} '_tempoGen_crossmodal.mat']), 'results');
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

%% ===================== statistics (merged from stats/stats_tempoGen_crossmodal_somatotopicVsExternal.m (N=12 version), 2026-10-22) =====================
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
% Requires outputs/derivatives/tempoGen/tempoGen_crossmodal/<sub>/<sub>_tempoGen_crossmodal.mat
% for every subject (see tempoGen_crossmodal_subject.m).

addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir       = fullfile(projectDir, 'outputs', 'derivatives', 'tempoGen', 'tempoGen_crossmodal');
% stats are saved next to the group results (groupOutDir defined above)
if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

%% Subjects and test parameters
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006', ...
            'sub-007', 'sub-008', 'sub-009', 'sub-010', 'sub-011', 'sub-012', ...
            'sub-014'};  % N=13 (2026-10-22); sub-013, sub-015 still to be preprocessed
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
    srcDir = tgDir;
    loaded = load(fullfile(srcDir, subjects{s}, [subjects{s} '_tempoGen_crossmodal.mat']), 'results');
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
