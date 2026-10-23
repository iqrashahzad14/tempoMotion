%% Temporal generalization: axis-of-motion decoding within each modality block - group level
%
% Loads each subject's saved train-time x test-time generalization
% matrices (already averaged over iterations within-subject, see
% tempoGen_axisOfMotion_withinModality_subject.m, for each of the 3
% blocks), and averages across the 6 subjects. Plots the group-average
% T x T heatmaps.
%
% Requires outputs/derivatives/tempoGen/tempoGen_axisOfMotion_withinModality/<sub>/<sub>_tempoGen_axisOfMotion.mat
% for every subject (see tempoGen_axisOfMotion_withinModality_subject.m).

clear;

addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir       = fullfile(projectDir, 'outputs', 'derivatives', 'tempoGen', 'tempoGen_axisOfMotion_withinModality');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006', ...
            'sub-007', 'sub-008', 'sub-009', 'sub-010', 'sub-011', 'sub-012', ...
            'sub-014'};  % N=13 (2026-10-22); sub-013, sub-015 still to be preprocessed

% each sample size gets its own folder (group_N<N>); the N=6 results stay in group/
groupOutDir = fullfile(tgDir, sprintf('group_N%d', numel(subjects)));
% optional: write to another folder (e.g. for a verification run)
if ~isempty(getenv('GROUP_OUTDIR')), groupOutDir = getenv('GROUP_OUTDIR'); end
nSub = numel(subjects);

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(tgDir, subjects{s}, [subjects{s} '_tempoGen_axisOfMotion.mat']), 'results');
    allResults{s} = loaded.results;
end

blockNames = fieldnames(allResults{1});

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

groupTempoGen = struct();
climRange = [0.35 0.65];

f = figure('Visible', 'off');

for b = 1:numel(blockNames)
    blkName = blockNames{b};
    timeVec = allResults{1}.(blkName).time;
    nTime = numel(timeVec);

    accStack = zeros(nSub, nTime, nTime);
    aucStack = zeros(nSub, nTime, nTime);
    for s = 1:nSub
        accStack(s, :, :) = squeeze(mean(allResults{s}.(blkName).acc, 1));
        aucStack(s, :, :) = squeeze(mean(allResults{s}.(blkName).auc, 1));
    end
    accGroup = squeeze(mean(accStack, 1));
    aucGroup = squeeze(mean(aucStack, 1));

    groupTempoGen.(blkName).acc  = accGroup;
    groupTempoGen.(blkName).auc  = aucGroup;
    groupTempoGen.(blkName).time = timeVec;

    subplot(numel(blockNames), 2, (b-1)*2 + 1);
    fn_plot_tempoGen_matrix(timeVec, timeVec, accGroup, climRange, ...
        sprintf('%s - accuracy (N=%d)', strrep(blkName, '_', ' '), nSub), 'Train time (s)', 'Test time (s)');

    subplot(numel(blockNames), 2, (b-1)*2 + 2);
    fn_plot_tempoGen_matrix(timeVec, timeVec, aucGroup, climRange, ...
        sprintf('%s - AUC (N=%d)', strrep(blkName, '_', ' '), nSub), 'Train time (s)', 'Test time (s)');
end

sgtitle('Group - axis-of-motion temporal generalization', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 1200]);
% (plain group figure no longer saved: the stats figure below shows the same
%  curves plus the significant time points)
% saveas(f, fullfile(groupOutDir, 'group_tempoGen_axisOfMotion.png'));
close(f);

save(fullfile(groupOutDir, 'group_tempoGen_axisOfMotion.mat'), 'groupTempoGen', '-v7.3');
fprintf('Saved group axis-of-motion temporal generalization results and plot to %s\n', groupOutDir);

%% ===================== statistics (merged from stats/stats_tempoGen_axisOfMotion_withinModality_group.m, 2026-10-22) =====================
%% Stats: axis-of-motion temporal generalization - sign-flip cluster-based permutation test
%
% Loads each subject's saved train-time x test-time generalization
% matrices (outputs/derivatives/tempoGen/tempoGen_axisOfMotion_withinModality/<sub>/<sub>_tempoGen_axisOfMotion.mat,
% variable results.(block).{acc,auc} = iteration x trainTime x testTime),
% averages over the 20 decoding iterations within each subject, and tests
% at which (train, test) pixels decoding is above chance across subjects,
% for each modality block, using an exact sign-flip cluster-mass
% permutation test in 2D (see fn_signflip_cluster_test2D.m: cluster
% detection via 4-connected contiguous pixels instead of 1D contiguous
% runs). Tests the WHOLE matrix (any train x test pixel above chance),
% not just the diagonal. Chance is 0.5 for both accuracy and AUC (binary
% decoding).
%
% This is pure statistics on already-computed per-subject matrices - no
% re-decoding - so it runs in well under a minute.
%
% Requires outputs/derivatives/tempoGen/tempoGen_axisOfMotion_withinModality/<sub>/<sub>_tempoGen_axisOfMotion.mat
% for every subject (see tempoGen_axisOfMotion_withinModality_subject.m).

addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir       = fullfile(projectDir, 'outputs', 'derivatives', 'tempoGen', 'tempoGen_axisOfMotion_withinModality');
% stats are saved next to the group results (groupOutDir defined above)
if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

%% Subjects and test parameters
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006', ...
            'sub-007', 'sub-008', 'sub-009', 'sub-010', 'sub-011', 'sub-012', ...
            'sub-014'};  % N=13 (2026-10-22); sub-013, sub-015 still to be preprocessed
nSub = numel(subjects);

chanceAcc = 0.5;
chanceAuc = 0.5;
tail                 = 'right'; % test decoding > chance
clusterFormingAlpha  = 0.05;
clusterAlpha         = 0.05;
climRangeAcc = [0.35 0.65];
climRangeAuc = [0.35 0.65];

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(tgDir, subjects{s}, [subjects{s} '_tempoGen_axisOfMotion.mat']), 'results');
    allResults{s} = loaded.results;
end

blockNames = fieldnames(allResults{1});
nBlocks = numel(blockNames);

statsResults = struct();

f = figure('Visible', 'off');

for b = 1:nBlocks
    blkName = blockNames{b};
    timeVec = allResults{1}.(blkName).time;
    nTime = numel(timeVec);

    accStack = zeros(nSub, nTime, nTime);
    aucStack = zeros(nSub, nTime, nTime);
    for s = 1:nSub
        accStack(s, :, :) = squeeze(mean(allResults{s}.(blkName).acc, 1)); % average over iterations
        aucStack(s, :, :) = squeeze(mean(allResults{s}.(blkName).auc, 1));
    end
    accGroup = squeeze(mean(accStack, 1));
    aucGroup = squeeze(mean(aucStack, 1));

    accStats = fn_signflip_cluster_test2D(accStack, chanceAcc, ...
        'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);
    aucStats = fn_signflip_cluster_test2D(aucStack, chanceAuc, ...
        'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);

    statsResults.(blkName).time      = timeVec;
    statsResults.(blkName).accGroup  = accGroup;
    statsResults.(blkName).aucGroup  = aucGroup;
    statsResults.(blkName).accStats  = accStats;
    statsResults.(blkName).aucStats  = aucStats;

    fprintf('%s: %d significant accuracy cluster(s), %d significant AUC cluster(s) (N=%d, nPerm=%d)\n', ...
        blkName, sum([accStats.clusters.sig]), sum([aucStats.clusters.sig]), nSub, accStats.nPerm);

    subplot(nBlocks, 2, (b-1)*2 + 1);
    fn_plot_tempoGen_matrix(timeVec, timeVec, accGroup, climRangeAcc, ...
        sprintf('%s - accuracy (N=%d)', strrep(blkName, '_', ' '), nSub), 'Train time (s)', 'Test time (s)');
    hold on;
    contour(timeVec, timeVec, double(accStats.sigMask), [0.5 0.5], 'k-', 'LineWidth', 1.5);
    hold off;

    subplot(nBlocks, 2, (b-1)*2 + 2);
    fn_plot_tempoGen_matrix(timeVec, timeVec, aucGroup, climRangeAuc, ...
        sprintf('%s - AUC (N=%d)', strrep(blkName, '_', ' '), nSub), 'Train time (s)', 'Test time (s)');
    hold on;
    contour(timeVec, timeVec, double(aucStats.sigMask), [0.5 0.5], 'k-', 'LineWidth', 1.5);
    hold off;
end

sgtitle('Group - axis-of-motion temporal generalization: sign-flip cluster stats (outline = significant)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 1200]);
saveas(f, fullfile(groupOutDir, 'group_stats_tempoGen_axisOfMotion.png'));
close(f);

save(fullfile(groupOutDir, 'group_stats_tempoGen_axisOfMotion.mat'), 'statsResults', 'chanceAcc', 'chanceAuc', ...
    'tail', 'clusterFormingAlpha', 'clusterAlpha', '-v7.3');
fprintf('Saved group axis-of-motion temporal generalization stats and plot to %s\n', groupOutDir);
