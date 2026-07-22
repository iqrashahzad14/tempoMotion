%% Stats: 4-direction decoding - sign-flip cluster-based permutation test
%
% Loads the group-level accuracy/AUC time courses saved by
% mvpa_4dir_withinModality_group.m (outputs/mvpa_4Dir_withinModality/group/
% group_mvpa_4dir.mat, variable groupMvpa.(block).{accBySubject,aucBySubject}),
% and tests at which timepoints decoding is above chance across subjects,
% for each modality block, using an exact sign-flip cluster-mass
% permutation test (see fn_signflip_cluster_test.m). Chance is 0.25 for
% 4-class accuracy and 0.5 for macro one-vs-rest AUC.
%
% Requires outputs/mvpa_4Dir_withinModality/group/group_mvpa_4dir.mat.

clear;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaGroupMat = fullfile(projectDir, 'outputs', 'mvpa_4Dir_withinModality', 'group', 'group_mvpa_4dir.mat');
outDir      = fullfile(projectDir, 'outputs', 'stats_mvpa_4Dir_withinModality');
groupOutDir = fullfile(outDir, 'group');
if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

%% Test parameters
chanceAcc = 0.25;
chanceAuc = 0.5;
tail                 = 'right'; % test decoding > chance
clusterFormingAlpha  = 0.05;
clusterAlpha         = 0.05;

%% Load group results
loaded = load(mvpaGroupMat, 'groupMvpa');
groupMvpa = loaded.groupMvpa;
blockNames = fieldnames(groupMvpa);
nBlocks = numel(blockNames);

statsResults = struct();

f = figure('Visible', 'off');

for b = 1:nBlocks
    blkName = blockNames{b};
    timeVec = groupMvpa.(blkName).time;

    accStats = fn_signflip_cluster_test(groupMvpa.(blkName).accBySubject, chanceAcc, ...
        'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);
    aucStats = fn_signflip_cluster_test(groupMvpa.(blkName).aucBySubject, chanceAuc, ...
        'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);

    statsResults.(blkName).time     = timeVec;
    statsResults.(blkName).accStats = accStats;
    statsResults.(blkName).aucStats = aucStats;

    fprintf('%s: %d significant accuracy cluster(s), %d significant AUC cluster(s)\n', ...
        blkName, sum([accStats.clusters.sig]), sum([aucStats.clusters.sig]));

    subplot(nBlocks, 2, (b-1)*2 + 1);
    plot_mean_sem_sig(timeVec, groupMvpa.(blkName).accMean, groupMvpa.(blkName).accSEM, ...
        chanceAcc, accStats.sigMask, [0.10 0.40]);
    xlabel('Time (s)'); ylabel('Accuracy');
    title(sprintf('%s - accuracy (N=%d)', strrep(blkName, '_', ' '), accStats.nSub));

    subplot(nBlocks, 2, (b-1)*2 + 2);
    plot_mean_sem_sig(timeVec, groupMvpa.(blkName).aucMean, groupMvpa.(blkName).aucSEM, ...
        chanceAuc, aucStats.sigMask, [0.35 0.65]);
    xlabel('Time (s)'); ylabel('AUC (macro)');
    title(sprintf('%s - AUC (N=%d)', strrep(blkName, '_', ' '), aucStats.nSub));
end

sgtitle('Group - 4-direction decoding: sign-flip cluster stats (red = significant)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 900]);
saveas(f, fullfile(groupOutDir, 'group_stats_mvpa_4dir.png'));
close(f);

save(fullfile(groupOutDir, 'group_stats_mvpa_4dir.mat'), 'statsResults', 'chanceAcc', 'chanceAuc', ...
    'tail', 'clusterFormingAlpha', 'clusterAlpha', '-v7.3');
fprintf('Saved group 4-direction decoding stats and plot to %s\n', groupOutDir);


%% ---- local functions ----

function plot_mean_sem_sig(time, meanVal, semVal, chanceLevel, sigMask, yl)

hold on;
fill([time, fliplr(time)], [meanVal + semVal, fliplr(meanVal - semVal)], ...
    [0.3 0.5 0.9], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
plot(time, meanVal, 'LineWidth', 1.5, 'Color', [0.1 0.3 0.8]);
yline(chanceLevel, 'k--');
xline(0, 'k-');
if any(sigMask)
    sigY = yl(1) + 0.03 * range(yl);
    plot(time(sigMask), sigY * ones(1, sum(sigMask)), '.', 'Color', [0.85 0.1 0.1], 'MarkerSize', 8);
end
ylim(yl);
hold off;
grid on;

end
