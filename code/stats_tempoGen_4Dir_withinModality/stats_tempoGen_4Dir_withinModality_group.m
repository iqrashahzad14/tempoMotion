%% Stats: 4-direction temporal generalization - sign-flip cluster-based permutation test
%
% Loads each subject's saved train-time x test-time generalization
% matrices (outputs/tempoGen_4Dir_withinModality/<sub>/<sub>_tempoGen_4dir.mat,
% variable results.(block).{acc,auc} = iteration x trainTime x testTime),
% averages over the 20 decoding iterations within each subject, and tests
% at which (train, test) pixels decoding is above chance across subjects,
% for each modality block, using an exact sign-flip cluster-mass
% permutation test in 2D (see fn_signflip_cluster_test2D.m: cluster
% detection via 4-connected contiguous pixels instead of 1D contiguous
% runs). Tests the WHOLE matrix (any train x test pixel above chance),
% not just the diagonal. Chance is 0.25 for 4-class accuracy and 0.5 for
% macro one-vs-rest AUC.
%
% This is pure statistics on already-computed per-subject matrices - no
% re-decoding - so it runs in well under a minute.
%
% Requires outputs/tempoGen_4Dir_withinModality/<sub>/<sub>_tempoGen_4dir.mat
% for every subject (see tempoGen_4Dir_withinModality_subject.m).

clear;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir       = fullfile(projectDir, 'outputs', 'tempoGen_4Dir_withinModality');
outDir      = fullfile(projectDir, 'outputs', 'stats_tempoGen_4Dir_withinModality');
groupOutDir = fullfile(outDir, 'group');
if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

%% Subjects and test parameters
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

chanceAcc = 0.25;
chanceAuc = 0.5;
tail                 = 'right'; % test decoding > chance
clusterFormingAlpha  = 0.05;
clusterAlpha         = 0.05;
climRangeAcc = [0.10 0.40];
climRangeAuc = [0.35 0.65];

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(tgDir, subjects{s}, [subjects{s} '_tempoGen_4dir.mat']), 'results');
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
        sprintf('%s - AUC macro (N=%d)', strrep(blkName, '_', ' '), nSub), 'Train time (s)', 'Test time (s)');
    hold on;
    contour(timeVec, timeVec, double(aucStats.sigMask), [0.5 0.5], 'k-', 'LineWidth', 1.5);
    hold off;
end

sgtitle('Group - 4-direction temporal generalization: sign-flip cluster stats (outline = significant)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 1200]);
saveas(f, fullfile(groupOutDir, 'group_stats_tempoGen_4dir.png'));
close(f);

save(fullfile(groupOutDir, 'group_stats_tempoGen_4dir.mat'), 'statsResults', 'chanceAcc', 'chanceAuc', ...
    'tail', 'clusterFormingAlpha', 'clusterAlpha', '-v7.3');
fprintf('Saved group 4-direction temporal generalization stats and plot to %s\n', groupOutDir);
