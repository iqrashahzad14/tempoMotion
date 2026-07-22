%% Stats: cross-modal visual-tactile decoding - sign-flip cluster-based permutation test
%
% Loads the group-level accuracy/AUC time courses saved by
% mvpa_crossModal_visualTactile_group.m
% (outputs/mvpa_crossModal_visualTactile/group/group_mvpa_crossModal.mat,
% variable groupMvpa.(target).(variant).{accBySubject,aucBySubject}), and
% tests at which timepoints decoding is above chance across subjects, for
% each target (somatotopic, external) and cross-modal training direction
% (a: train vis/test tac, b: train tac/test vis, both: average of a and
% b), using an exact sign-flip cluster-mass permutation test (see
% fn_signflip_cluster_test.m). Chance is 0.5 for both accuracy and AUC
% (binary decoding).
%
% Requires outputs/mvpa_crossModal_visualTactile/group/group_mvpa_crossModal.mat.

clear;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaGroupMat = fullfile(projectDir, 'outputs', 'mvpa_crossModal_visualTactile', 'group', 'group_mvpa_crossModal.mat');
outDir      = fullfile(projectDir, 'outputs', 'stats_mvpa_crossModal_visualTactile');
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
targetNames = fieldnames(groupMvpa);
variants = {'a', 'b', 'both'};
variantTitles = {'train vis / test tac', 'train tac / test vis', 'both (avg)'};

statsResults = struct();

f = figure('Visible', 'off');
nRows = numel(targetNames) * numel(variants);
row = 0;

for ti = 1:numel(targetNames)
    tgtName = targetNames{ti};

    for v = 1:numel(variants)
        variant = variants{v};
        row = row + 1;

        timeVec = groupMvpa.(tgtName).(variant).time;

        accStats = fn_signflip_cluster_test(groupMvpa.(tgtName).(variant).accBySubject, chanceAcc, ...
            'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);
        aucStats = fn_signflip_cluster_test(groupMvpa.(tgtName).(variant).aucBySubject, chanceAuc, ...
            'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);

        statsResults.(tgtName).(variant).time     = timeVec;
        statsResults.(tgtName).(variant).accStats = accStats;
        statsResults.(tgtName).(variant).aucStats = aucStats;

        fprintf('%s - %s: %d significant accuracy cluster(s), %d significant AUC cluster(s)\n', ...
            tgtName, variant, sum([accStats.clusters.sig]), sum([aucStats.clusters.sig]));

        subplot(nRows, 2, (row-1)*2 + 1);
        plot_mean_sem_sig(timeVec, groupMvpa.(tgtName).(variant).accMean, groupMvpa.(tgtName).(variant).accSEM, ...
            chanceAcc, accStats.sigMask, [0.35 0.65]);
        xlabel('Time (s)'); ylabel('Accuracy');
        title(sprintf('%s - %s - accuracy (N=%d)', tgtName, variantTitles{v}, accStats.nSub), ...
            'Interpreter', 'none', 'FontSize', 8);

        subplot(nRows, 2, (row-1)*2 + 2);
        plot_mean_sem_sig(timeVec, groupMvpa.(tgtName).(variant).aucMean, groupMvpa.(tgtName).(variant).aucSEM, ...
            chanceAuc, aucStats.sigMask, [0.35 0.65]);
        xlabel('Time (s)'); ylabel('AUC');
        title(sprintf('%s - %s - AUC (N=%d)', tgtName, variantTitles{v}, aucStats.nSub), ...
            'Interpreter', 'none', 'FontSize', 8);
    end
end

sgtitle('Group - cross-modal visual-tactile decoding: sign-flip cluster stats (red = significant)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 1400]);
saveas(f, fullfile(groupOutDir, 'group_stats_mvpa_crossModal.png'));
close(f);

save(fullfile(groupOutDir, 'group_stats_mvpa_crossModal.mat'), 'statsResults', 'chanceAcc', 'chanceAuc', ...
    'tail', 'clusterFormingAlpha', 'clusterAlpha', '-v7.3');
fprintf('Saved group cross-modal visual-tactile decoding stats and plot to %s\n', groupOutDir);


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
