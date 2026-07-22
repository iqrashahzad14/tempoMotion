%% Stats: tactile frame-of-reference temporal generalization - sign-flip cluster-based permutation test
%
% Loads each subject's saved train-time x test-time generalization
% matrices (outputs/tempoGen_tactileFrameOfReference/<sub>/<sub>_tempoGen_tactileFoR.mat,
% variable results.(decode).{acc,auc} = iteration x trainTime x testTime),
% averages over the 20 decoding iterations within each subject, and tests
% at which (train, test) pixels decoding is above chance across subjects,
% for each of the 3 decodes (somatotopic, external, handPos), using an
% exact sign-flip cluster-mass permutation test in 2D (see
% fn_signflip_cluster_test2D.m: cluster detection via 4-connected
% contiguous pixels instead of 1D contiguous runs). Tests the WHOLE
% matrix (any train x test pixel above chance), not just the diagonal.
% Chance is 0.5 for both accuracy and AUC (binary decoding).
%
% This is pure statistics on already-computed per-subject matrices - no
% re-decoding - so it runs in well under a minute.
%
% Requires outputs/tempoGen_tactileFrameOfReference/<sub>/<sub>_tempoGen_tactileFoR.mat
% for every subject (see tempoGen_tactileFrameOfReference_subject.m).

clear;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir       = fullfile(projectDir, 'outputs', 'tempoGen_tactileFrameOfReference');
outDir      = fullfile(projectDir, 'outputs', 'stats_tempoGen_tactileFrameOfReference');
groupOutDir = fullfile(outDir, 'group');
if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

%% Subjects and test parameters
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
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
    loaded = load(fullfile(tgDir, subjects{s}, [subjects{s} '_tempoGen_tactileFoR.mat']), 'results');
    allResults{s} = loaded.results;
end

decodeNames = fieldnames(allResults{1});
nDecode = numel(decodeNames);

statsResults = struct();

f = figure('Visible', 'off');

for d = 1:nDecode
    dcName = decodeNames{d};
    timeVec = allResults{1}.(dcName).time;
    nTime = numel(timeVec);

    accStack = zeros(nSub, nTime, nTime);
    aucStack = zeros(nSub, nTime, nTime);
    for s = 1:nSub
        accStack(s, :, :) = squeeze(mean(allResults{s}.(dcName).acc, 1)); % average over iterations
        aucStack(s, :, :) = squeeze(mean(allResults{s}.(dcName).auc, 1));
    end
    accGroup = squeeze(mean(accStack, 1));
    aucGroup = squeeze(mean(aucStack, 1));

    accStats = fn_signflip_cluster_test2D(accStack, chanceAcc, ...
        'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);
    aucStats = fn_signflip_cluster_test2D(aucStack, chanceAuc, ...
        'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);

    statsResults.(dcName).time      = timeVec;
    statsResults.(dcName).accGroup  = accGroup;
    statsResults.(dcName).aucGroup  = aucGroup;
    statsResults.(dcName).accStats  = accStats;
    statsResults.(dcName).aucStats  = aucStats;

    fprintf('%s: %d significant accuracy cluster(s), %d significant AUC cluster(s) (N=%d, nPerm=%d)\n', ...
        dcName, sum([accStats.clusters.sig]), sum([aucStats.clusters.sig]), nSub, accStats.nPerm);

    subplot(nDecode, 2, (d-1)*2 + 1);
    fn_plot_tempoGen_matrix(timeVec, timeVec, accGroup, climRangeAcc, ...
        sprintf('%s - accuracy (N=%d)', dcName, nSub), 'Train time (s)', 'Test time (s)');
    hold on;
    contour(timeVec, timeVec, double(accStats.sigMask), [0.5 0.5], 'k-', 'LineWidth', 1.5);
    hold off;

    subplot(nDecode, 2, (d-1)*2 + 2);
    fn_plot_tempoGen_matrix(timeVec, timeVec, aucGroup, climRangeAuc, ...
        sprintf('%s - AUC (N=%d)', dcName, nSub), 'Train time (s)', 'Test time (s)');
    hold on;
    contour(timeVec, timeVec, double(aucStats.sigMask), [0.5 0.5], 'k-', 'LineWidth', 1.5);
    hold off;
end

sgtitle('Group - tactile frame-of-reference temporal generalization: sign-flip cluster stats (outline = significant)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 1200]);
saveas(f, fullfile(groupOutDir, 'group_stats_tempoGen_tactileFoR.png'));
close(f);

save(fullfile(groupOutDir, 'group_stats_tempoGen_tactileFoR.mat'), 'statsResults', 'chanceAcc', 'chanceAuc', ...
    'tail', 'clusterFormingAlpha', 'clusterAlpha', '-v7.3');
fprintf('Saved group tactile frame-of-reference temporal generalization stats and plot to %s\n', groupOutDir);
