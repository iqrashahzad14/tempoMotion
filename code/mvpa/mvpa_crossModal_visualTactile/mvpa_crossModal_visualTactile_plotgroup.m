%% MVPA: cross-modal visual-tactile decoding - group figure on the full axis, with stats
%
% Replots the group accuracy/AUC time courses (mean +/- SEM) on the full
% axis (y 0-1, x -0.5-1.5 s) and marks the significant time points from the
% sign-flip cluster test, for each target (somatotopic, external) and
% direction (a: train vis/test tac, b: train tac/test vis, both). Nothing is
% recomputed: it loads group_mvpa_crossModal.mat and
% group_stats_mvpa_crossModal.mat, both saved by
% mvpa_crossModal_visualTactile_group.m, from one group folder. Used for
% group folders made before the group script saved this figure itself.
%
% The group folder is set with the environment variable GROUP_DIR
% (default 'group' = N=6; e.g. GROUP_DIR=group_N13).
% Output: <group folder>/group_stats_mvpa_crossModal.png.

clear;

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaDir    = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa', 'mvpa_crossModal_visualTactile');
groupName  = 'group';
if ~isempty(getenv('GROUP_DIR')), groupName = getenv('GROUP_DIR'); end
groupDir   = fullfile(mvpaDir, groupName);

%% Load group results and stats
loaded = load(fullfile(groupDir, 'group_mvpa_crossModal.mat'), 'groupMvpa');
groupMvpa = loaded.groupMvpa;
loaded = load(fullfile(groupDir, 'group_stats_mvpa_crossModal.mat'), 'statsResults', 'chanceAcc', 'chanceAuc');
statsResults = loaded.statsResults;
chanceAcc = loaded.chanceAcc;
chanceAuc = loaded.chanceAuc;

targetNames = fieldnames(groupMvpa);
variants = {'a', 'b', 'both'};
variantTitles = {'train vis / test tac', 'train tac / test vis', 'both (avg)'};

%% Plot
f = figure('Visible', 'off');
nRows = numel(targetNames) * numel(variants);
row = 0;

for ti = 1:numel(targetNames)
    tgtName = targetNames{ti};

    for v = 1:numel(variants)
        variant = variants{v};
        row = row + 1;
        timeVec = groupMvpa.(tgtName).(variant).time;
        accStats = statsResults.(tgtName).(variant).accStats;
        aucStats = statsResults.(tgtName).(variant).aucStats;

        subplot(nRows, 2, (row-1)*2 + 1);
        plot_mean_sem_sig(timeVec, groupMvpa.(tgtName).(variant).accMean, groupMvpa.(tgtName).(variant).accSEM, ...
            chanceAcc, accStats.sigMask, [0 1]);
        xlabel('Time (s)'); ylabel('Accuracy');
        title(sprintf('%s - %s - accuracy (N=%d)', tgtName, variantTitles{v}, accStats.nSub), ...
            'Interpreter', 'none', 'FontSize', 8);

        subplot(nRows, 2, (row-1)*2 + 2);
        plot_mean_sem_sig(timeVec, groupMvpa.(tgtName).(variant).aucMean, groupMvpa.(tgtName).(variant).aucSEM, ...
            chanceAuc, aucStats.sigMask, [0 1]);
        xlabel('Time (s)'); ylabel('AUC');
        title(sprintf('%s - %s - AUC (N=%d)', tgtName, variantTitles{v}, aucStats.nSub), ...
            'Interpreter', 'none', 'FontSize', 8);
    end
end

sgtitle('Group - cross-modal visual-tactile decoding: sign-flip cluster stats (red = significant)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 1400]);
saveas(f, fullfile(groupDir, 'group_stats_mvpa_crossModal.png'));
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
