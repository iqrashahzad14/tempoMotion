%% Regenerate the tactile frame-of-reference stats plot with a zoomed y-axis
%
% Reloads the saved group means/SEMs (mvpa_tactileFrameOfReference_group.m)
% and the saved sign-flip cluster stats (stats_mvpa_tactileFrameOfReference_group.m)
% - no recomputation - and redraws the accuracy/AUC panels with the y-axis
% zoomed to [0.2 0.7] instead of the full [0 1] range, to make the
% above-chance modulation easier to see.

clear;

projectDir   = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
% N=12 inputs/outputs (the earlier N=6 results stay in .../group/)
groupTag = 'group_N13';
mvpaGroupMat  = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa', 'mvpa_tactileFrameOfReference', groupTag, 'group_mvpa_tactileFoR.mat');
statsGroupMat = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa', 'mvpa_tactileFrameOfReference', groupTag, 'group_stats_mvpa_tactileFoR.mat');
groupOutDir   = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa', 'mvpa_tactileFrameOfReference', groupTag);

yl = [0.2 0.8];

loadedMvpa  = load(mvpaGroupMat, 'groupMvpa');
loadedStats = load(statsGroupMat, 'statsResults', 'chanceAcc', 'chanceAuc');
groupMvpa    = loadedMvpa.groupMvpa;
statsResults = loadedStats.statsResults;
chanceAcc    = loadedStats.chanceAcc;
chanceAuc    = loadedStats.chanceAuc;

decodeNames = fieldnames(groupMvpa);
nDecode = numel(decodeNames);

f = figure('Visible', 'off');

for d = 1:nDecode
    dcName = decodeNames{d};
    timeVec = groupMvpa.(dcName).time;

    subplot(nDecode, 2, (d-1)*2 + 1);
    plot_mean_sem_sig(timeVec, groupMvpa.(dcName).accMean, groupMvpa.(dcName).accSEM, ...
        chanceAcc, statsResults.(dcName).accStats.sigMask, yl);
    xlim([-0.5 1.5]); xlabel('Time (s)'); ylabel('Accuracy');
    title(sprintf('%s - accuracy (N=%d)', dcName, statsResults.(dcName).accStats.nSub), 'Interpreter', 'none', 'FontSize', 8);

    subplot(nDecode, 2, (d-1)*2 + 2);
    plot_mean_sem_sig(timeVec, groupMvpa.(dcName).aucMean, groupMvpa.(dcName).aucSEM, ...
        chanceAuc, statsResults.(dcName).aucStats.sigMask, yl);
    xlim([-0.5 1.5]); xlabel('Time (s)'); ylabel('AUC');
    title(sprintf('%s - AUC (N=%d)', dcName, statsResults.(dcName).aucStats.nSub), 'Interpreter', 'none', 'FontSize', 8);
end

sgtitle('Group - tactile frame-of-reference decoding: sign-flip cluster stats (red = significant, axis zoomed)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 900]);
saveas(f, fullfile(groupOutDir, 'group_stats_mvpa_tactileFoR_axisZoom.png'));
close(f);
fprintf('Saved axis-zoomed tactile frame-of-reference stats plot to %s\n', groupOutDir);


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
