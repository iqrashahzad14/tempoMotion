%% Compare latency of the 3 tactile frame-of-reference decodes in one figure
%
% Reloads the saved group means/SEMs (mvpa_tactileFrameOfReference_group.m)
% and the saved sign-flip cluster stats (stats_mvpa_tactileFrameOfReference_group.m)
% - no recomputation - and overlays the somatotopic / external / handPos
% decoding time courses on shared axes (one panel for accuracy, one for
% AUC), so their onset latency and significance timing can be compared
% directly. Each decode's significant cluster(s) are drawn as a separate
% colour-matched marker row stacked beneath the curves, labelled in place
% with its onset latency (first significant timepoint relative to
% stimulus onset).
%
% Saved to outputs/reports/ (a synthesis figure spanning the 3 decodes,
% as opposed to the per-analysis figures under outputs/stats_mvpa_*/).

clear;

projectDir    = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaGroupMat  = fullfile(projectDir, 'outputs', 'mvpa_tactileFrameOfReference', 'group', 'group_mvpa_tactileFoR.mat');
statsGroupMat = fullfile(projectDir, 'outputs', 'stats_mvpa_tactileFrameOfReference', 'group', 'group_stats_mvpa_tactileFoR.mat');
reportsDir    = fullfile(projectDir, 'outputs', 'reports');
if ~exist(reportsDir, 'dir')
    mkdir(reportsDir);
end

loadedMvpa  = load(mvpaGroupMat, 'groupMvpa');
loadedStats = load(statsGroupMat, 'statsResults', 'chanceAcc', 'chanceAuc');
groupMvpa    = loadedMvpa.groupMvpa;
statsResults = loadedStats.statsResults;
chanceAcc    = loadedStats.chanceAcc;
chanceAuc    = loadedStats.chanceAuc;

decodeNames = {'somatotopic', 'external', 'handPos'};
% categorical palette, fixed order (blue / aqua / yellow), CVD-validated
colors = [0.16 0.47 0.84;   % somatotopic - blue
          0.11 0.69 0.48;   % external    - aqua
          0.93 0.63 0.00];  % handPos     - yellow

inkPrimary   = [0.04 0.04 0.04];
inkMuted     = [0.54 0.53 0.51];
gridColor    = [0.88 0.88 0.85];
baselineColor = [0.76 0.76 0.72];

xl = [-0.2 1.4];
yl = [0.20 0.80];
sigBandTop = 0.235; % sig rows live in a dedicated gutter below the data

%% compute onset latency (first significant timepoint) per decode/metric
latency = struct();
for i = 1:numel(decodeNames)
    dcName = decodeNames{i};
    timeVec = groupMvpa.(dcName).time;

    accSig = statsResults.(dcName).accStats.sigMask;
    aucSig = statsResults.(dcName).aucStats.sigMask;

    latency.(dcName).acc = local_first_sig_time(timeVec, accSig);
    latency.(dcName).auc = local_first_sig_time(timeVec, aucSig);

    fprintf('%s: first significant accuracy timepoint = %s, first significant AUC timepoint = %s\n', ...
        dcName, local_time_str(latency.(dcName).acc), local_time_str(latency.(dcName).auc));
end

%% figure: accuracy (left) and AUC (right), all 3 decodes overlaid
f = figure('Visible', 'off', 'Color', 'w');
set(f, 'Position', [0 0 1500 620]);
tl = tiledlayout(f, 1, 2, 'Padding', 'compact', 'TileSpacing', 'loose');

ax1 = nexttile(tl);
local_plot_overlay(ax1, groupMvpa, statsResults, decodeNames, colors, 'acc', chanceAcc, ...
    xl, yl, sigBandTop, latency, 'acc', inkMuted, gridColor, baselineColor);
ylabel(ax1, 'Accuracy', 'Color', inkPrimary, 'FontSize', 11);

ax2 = nexttile(tl);
h = local_plot_overlay(ax2, groupMvpa, statsResults, decodeNames, colors, 'auc', chanceAuc, ...
    xl, yl, sigBandTop, latency, 'auc', inkMuted, gridColor, baselineColor);
ylabel(ax2, 'AUC', 'Color', inkPrimary, 'FontSize', 11);

xlabel(tl, 'Time from stimulus onset (s)', 'Color', inkPrimary, 'FontSize', 11);

lgd = legend(ax2, h, decodeNames, 'Box', 'off', 'FontSize', 10);
lgd.Layout.Tile = 'east';

title(tl, 'Tactile frame-of-reference decoding: latency comparison', ...
    'Color', inkPrimary, 'FontWeight', 'normal', 'FontSize', 14);

outFile = fullfile(reportsDir, 'group_stats_mvpa_tactileFoR_latencyComparison.png');
exportgraphics(f, outFile, 'Resolution', 200);
close(f);
fprintf('Saved latency comparison figure to %s\n', outFile);


%% ---- local functions ----

function h = local_plot_overlay(ax, groupMvpa, statsResults, decodeNames, colors, metric, chanceLevel, ...
    xl, yl, sigBandTop, latency, latField, inkMuted, gridColor, baselineColor)

axes(ax); %#ok<LAXES>
hold(ax, 'on');

sigRowY = linspace(yl(1) + 0.01, sigBandTop, numel(decodeNames));

h = gobjects(1, numel(decodeNames));
for i = 1:numel(decodeNames)
    dcName = decodeNames{i};
    col = colors(i, :);
    timeVec = groupMvpa.(dcName).time;

    if strcmp(metric, 'acc')
        meanVal = groupMvpa.(dcName).accMean;
        semVal  = groupMvpa.(dcName).accSEM;
        sigMask = statsResults.(dcName).accStats.sigMask;
    else
        meanVal = groupMvpa.(dcName).aucMean;
        semVal  = groupMvpa.(dcName).aucSEM;
        sigMask = statsResults.(dcName).aucStats.sigMask;
    end

    fill(ax, [timeVec, fliplr(timeVec)], [meanVal + semVal, fliplr(meanVal - semVal)], ...
        col, 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    h(i) = plot(ax, timeVec, meanVal, 'LineWidth', 2, 'Color', col, 'DisplayName', dcName);

    if any(sigMask)
        plot(ax, timeVec(sigMask), sigRowY(i) * ones(1, sum(sigMask)), '-', ...
            'Color', col, 'LineWidth', 4, 'HandleVisibility', 'off');
        t0 = latency.(dcName).(latField);
        text(ax, t0, sigRowY(i) + 0.012, sprintf('%.2f s', t0), ...
            'Color', col, 'FontSize', 8, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
    end
end

yline(ax, chanceLevel, '--', 'Color', inkMuted, 'LineWidth', 1, 'HandleVisibility', 'off');
xline(ax, 0, '-', 'Color', baselineColor, 'LineWidth', 1, 'HandleVisibility', 'off');

xlim(ax, xl); ylim(ax, yl);
ax.XTick = -0.5:0.5:1.5;
ax.YTick = 0.3:0.1:0.8;
ax.Box = 'off';
ax.TickDir = 'out';
ax.GridColor = gridColor;
ax.GridAlpha = 1;
ax.YGrid = 'on';
ax.XGrid = 'off';
ax.XColor = inkMuted;
ax.YColor = inkMuted;
ax.FontSize = 10;
ax.LineWidth = 0.75;

hold(ax, 'off');

end

function t = local_first_sig_time(timeVec, sigMask)
idx = find(sigMask, 1, 'first');
if isempty(idx)
    t = [];
else
    t = timeVec(idx);
end
end

function s = local_time_str(t)
if isempty(t)
    s = 'n.s.';
else
    s = sprintf('%.3f s', t);
end
end
