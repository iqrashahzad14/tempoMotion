%% MVPA: tactile frame-of-reference decoding - group figure on the full axis, with stats
%
% Replots the group accuracy/AUC time courses (mean +/- SEM) on the full
% axis (y 0-1, x -0.5-1.5 s) and marks the significant time points from the
% sign-flip cluster test, for the 3 decodes (somatotopic, external,
% handPos). Nothing is recomputed: it loads group_mvpa_tactileFoR.mat and
% group_stats_mvpa_tactileFoR.mat, both saved by
% mvpa_tactileFrameOfReference_group.m, from one group folder. Used for
% group folders made before the group script saved this figure itself.
%
% The group folder is set with the environment variable GROUP_DIR
% (default 'group' = N=6; e.g. GROUP_DIR=group_N13).
% Output: <group folder>/group_stats_mvpa_tactileFoR.png.

clear;

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaDir    = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa', 'mvpa_tactileFrameOfReference');
groupName  = 'group';
if ~isempty(getenv('GROUP_DIR')), groupName = getenv('GROUP_DIR'); end
groupDir   = fullfile(mvpaDir, groupName);

%% Load group results and stats
loaded = load(fullfile(groupDir, 'group_mvpa_tactileFoR.mat'), 'groupMvpa');
groupMvpa = loaded.groupMvpa;
loaded = load(fullfile(groupDir, 'group_stats_mvpa_tactileFoR.mat'), 'statsResults', 'chanceAcc', 'chanceAuc');
statsResults = loaded.statsResults;
chanceAcc = loaded.chanceAcc;
chanceAuc = loaded.chanceAuc;

decodeNames = fieldnames(groupMvpa);
nDecode = numel(decodeNames);

%% Plot
f = figure('Visible', 'off');

for d = 1:nDecode
    dcName = decodeNames{d};
    timeVec = groupMvpa.(dcName).time;
    accStats = statsResults.(dcName).accStats;
    aucStats = statsResults.(dcName).aucStats;

    subplot(nDecode, 2, (d-1)*2 + 1);
    plot_mean_sem_sig(timeVec, groupMvpa.(dcName).accMean, groupMvpa.(dcName).accSEM, ...
        chanceAcc, accStats.sigMask, [0 1]);
    xlabel('Time (s)'); ylabel('Accuracy');
    title(sprintf('%s - accuracy (N=%d)', dcName, accStats.nSub), 'Interpreter', 'none', 'FontSize', 8);

    subplot(nDecode, 2, (d-1)*2 + 2);
    plot_mean_sem_sig(timeVec, groupMvpa.(dcName).aucMean, groupMvpa.(dcName).aucSEM, ...
        chanceAuc, aucStats.sigMask, [0 1]);
    xlabel('Time (s)'); ylabel('AUC');
    title(sprintf('%s - AUC (N=%d)', dcName, aucStats.nSub), 'Interpreter', 'none', 'FontSize', 8);
end

sgtitle('Group - tactile frame-of-reference decoding: sign-flip cluster stats (red = significant)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 900]);
saveas(f, fullfile(groupDir, 'group_stats_mvpa_tactileFoR.png'));
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
