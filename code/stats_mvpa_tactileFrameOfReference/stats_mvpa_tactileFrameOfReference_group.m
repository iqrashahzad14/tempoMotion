%% Stats: tactile frame-of-reference decoding - sign-flip cluster-based permutation test
%
% Loads the group-level accuracy/AUC time courses saved by
% mvpa_tactileFrameOfReference_group.m
% (outputs/mvpa_tactileFrameOfReference/group/group_mvpa_tactileFoR.mat,
% variable groupMvpa.(decode).{accBySubject,aucBySubject}), and tests at
% which timepoints decoding is above chance across subjects, for each of
% the 3 decodes (somatotopic, external, handPos), using an exact
% sign-flip cluster-mass permutation test (see fn_signflip_cluster_test.m).
% Chance is 0.5 for both accuracy and AUC (binary decoding).
%
% Requires outputs/mvpa_tactileFrameOfReference/group/group_mvpa_tactileFoR.mat.

clear;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaGroupMat = fullfile(projectDir, 'outputs', 'mvpa_tactileFrameOfReference', 'group', 'group_mvpa_tactileFoR.mat');
outDir      = fullfile(projectDir, 'outputs', 'stats_mvpa_tactileFrameOfReference');
groupOutDir = fullfile(outDir, 'group');
if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

%% Test parameters
chanceAcc = 0.5;
chanceAuc = 0.5;
tail                 = 'right'; % test decoding > chance
clusterFormingAlpha  = 0.05;
clusterAlpha         = 0.05;

%% Load group results
loaded = load(mvpaGroupMat, 'groupMvpa');
groupMvpa = loaded.groupMvpa;
decodeNames = fieldnames(groupMvpa);
nDecode = numel(decodeNames);

statsResults = struct();

f = figure('Visible', 'off');

for d = 1:nDecode
    dcName = decodeNames{d};
    timeVec = groupMvpa.(dcName).time;

    accStats = fn_signflip_cluster_test(groupMvpa.(dcName).accBySubject, chanceAcc, ...
        'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);
    aucStats = fn_signflip_cluster_test(groupMvpa.(dcName).aucBySubject, chanceAuc, ...
        'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);

    statsResults.(dcName).time     = timeVec;
    statsResults.(dcName).accStats = accStats;
    statsResults.(dcName).aucStats = aucStats;

    fprintf('%s: %d significant accuracy cluster(s), %d significant AUC cluster(s)\n', ...
        dcName, sum([accStats.clusters.sig]), sum([aucStats.clusters.sig]));

    subplot(nDecode, 2, (d-1)*2 + 1);
    plot_mean_sem_sig(timeVec, groupMvpa.(dcName).accMean, groupMvpa.(dcName).accSEM, ...
        chanceAcc, accStats.sigMask, [0 1]);
    xlim([-0.5 1.5]); xlabel('Time (s)'); ylabel('Accuracy');
    title(sprintf('%s - accuracy (N=%d)', dcName, accStats.nSub), 'Interpreter', 'none', 'FontSize', 8);

    subplot(nDecode, 2, (d-1)*2 + 2);
    plot_mean_sem_sig(timeVec, groupMvpa.(dcName).aucMean, groupMvpa.(dcName).aucSEM, ...
        chanceAuc, aucStats.sigMask, [0 1]);
    xlim([-0.5 1.5]); xlabel('Time (s)'); ylabel('AUC');
    title(sprintf('%s - AUC (N=%d)', dcName, aucStats.nSub), 'Interpreter', 'none', 'FontSize', 8);
end

sgtitle('Group - tactile frame-of-reference decoding: sign-flip cluster stats (red = significant)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 900]);
saveas(f, fullfile(groupOutDir, 'group_stats_mvpa_tactileFoR.png'));
close(f);

save(fullfile(groupOutDir, 'group_stats_mvpa_tactileFoR.mat'), 'statsResults', 'chanceAcc', 'chanceAuc', ...
    'tail', 'clusterFormingAlpha', 'clusterAlpha', '-v7.3');
fprintf('Saved group tactile frame-of-reference decoding stats and plot to %s\n', groupOutDir);


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
