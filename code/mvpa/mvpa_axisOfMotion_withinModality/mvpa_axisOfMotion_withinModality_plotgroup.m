%% MVPA: axis-of-motion decoding - group figure on the full axis, with stats
%
% Replots the group accuracy/AUC time courses (mean +/- SEM) on the full
% axis (y 0-1, x -0.5-1.5 s) and marks the significant time points from the
% sign-flip cluster test. Nothing is recomputed: it loads
% group_mvpa_axisOfMotion.mat and group_stats_mvpa_axisOfMotion.mat, both
% saved by mvpa_axisOfMotion_withinModality_group.m, from one group folder.
% The class labels of each block (second title line) are read from
% sub-001's subject file.
%
% The group folder is set with the environment variable GROUP_DIR
% (default 'group' = N=6; e.g. GROUP_DIR=group_N13).
% Output: <group folder>/group_stats_mvpa_axisOfMotion.png.

clear;

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaDir    = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa', 'mvpa_axisOfMotion_withinModality');
groupName  = 'group';
if ~isempty(getenv('GROUP_DIR')), groupName = getenv('GROUP_DIR'); end
groupDir   = fullfile(mvpaDir, groupName);

%% Load group results and stats
loaded = load(fullfile(groupDir, 'group_mvpa_axisOfMotion.mat'), 'groupMvpa');
groupMvpa = loaded.groupMvpa;
loaded = load(fullfile(groupDir, 'group_stats_mvpa_axisOfMotion.mat'), 'statsResults', 'chanceAcc', 'chanceAuc');
statsResults = loaded.statsResults;
chanceAcc = loaded.chanceAcc;
chanceAuc = loaded.chanceAuc;
loaded = load(fullfile(mvpaDir, 'sub-001', 'sub-001_mvpa_axisOfMotion.mat'), 'results');
subResults = loaded.results;

blockNames = fieldnames(groupMvpa);
nBlocks = numel(blockNames);

%% Plot
f = figure('Visible', 'off');

for b = 1:nBlocks
    blkName = blockNames{b};
    timeVec = groupMvpa.(blkName).time;
    accStats = statsResults.(blkName).accStats;
    aucStats = statsResults.(blkName).aucStats;
    labelStr = sprintf('%s vs %s', strrep(subResults.(blkName).classALabel, '_', '-'), strrep(subResults.(blkName).classBLabel, '_', '-'));

    subplot(nBlocks, 2, (b-1)*2 + 1);
    plot_mean_sem_sig(timeVec, groupMvpa.(blkName).accMean, groupMvpa.(blkName).accSEM, ...
        chanceAcc, accStats.sigMask, [0 1]);
    xlabel('Time (s)'); ylabel('Accuracy');
    title({sprintf('%s - accuracy (N=%d)', strrep(blkName, '_', ' '), accStats.nSub), labelStr}, 'Interpreter', 'none', 'FontSize', 9);

    subplot(nBlocks, 2, (b-1)*2 + 2);
    plot_mean_sem_sig(timeVec, groupMvpa.(blkName).aucMean, groupMvpa.(blkName).aucSEM, ...
        chanceAuc, aucStats.sigMask, [0 1]);
    xlabel('Time (s)'); ylabel('AUC');
    title({sprintf('%s - AUC (N=%d)', strrep(blkName, '_', ' '), aucStats.nSub), labelStr}, 'Interpreter', 'none', 'FontSize', 9);
end

sgtitle('Group - axis-of-motion decoding: sign-flip cluster stats (red = significant)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 900]);
saveas(f, fullfile(groupDir, 'group_stats_mvpa_axisOfMotion.png'));
close(f);
fprintf('Saved full-axis stats figure to %s\n', groupDir);


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
xlim([-0.5 1.5]);
hold off;
grid on;

end
