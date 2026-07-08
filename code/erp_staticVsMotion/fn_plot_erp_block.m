function fn_plot_erp_block(outDir, condLabels, condTL, roiChans, chanOrder, titleStr)
% FN_PLOT_ERP_BLOCK Generate the standard set of ERP summary plots for one
% modality-block / analysis-type combination (e.g. visual / direction).
%
% Inputs
%   outDir     - directory to save the PNGs into (created if needed)
%   condLabels - cell array of condition names (e.g. {'left','right','up','down'})
%   condTL     - cell array of FieldTrip timelock structures, one per condition
%   roiChans   - struct with fields .occipital and .centroparietal, each a
%                cell array of channel labels
%   chanOrder  - cell array of all channel labels ordered anterior->posterior
%                (used as the row order for the all-channel heatmap/butterfly)
%   titleStr   - string used as the figure title / suptitle prefix
%
% Produces:
%   all_channels.png           - one subplot per condition, channel x time heatmap
%   all_channels_butterfly.png - one subplot per condition, all channels
%                                overlaid as line traces (classic butterfly plot)
%   across_channel.png - grand mean across all 128 channels, conditions overlaid
%   centroparietal.png - mean across the centro-parietal ROI, conditions overlaid
%   occipital.png      - mean across the occipital ROI, conditions overlaid
%
% All amplitude-vs-time plots mark stimulus onset (x=0) and zero amplitude
% (y=0) with dashed reference lines.

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

nCond = numel(condTL);
time = condTL{1}.time;

allVals = cellfun(@(tl) tl.avg(:), condTL, 'UniformOutput', false);
clim = [min(cellfun(@min, allVals)), max(cellfun(@max, allVals))];

%% all-channel heatmap (one subplot per condition)
f = figure('Visible', 'off');
for c = 1:nCond
    subplot(1, nCond, c);
    [~, chanIdx] = ismember(chanOrder, condTL{c}.label);
    chanIdx = chanIdx(chanIdx > 0);
    imagesc(time, 1:numel(chanIdx), condTL{c}.avg(chanIdx, :), clim);
    set(gca, 'YDir', 'normal');
    hold on;
    xline(0, 'k--', 'LineWidth', 1);
    hold off;
    xlabel('Time (s)');
    if c == 1
        ylabel('Channel (anterior -> posterior)');
    end
    title(strrep(condLabels{c}, '_', ' '));
    colormap(parula);
    if c == nCond
        cb = colorbar;
        cb.Label.String = 'Amplitude (\muV)';
    end
end
sgtitle([titleStr ' - all channels'], 'Interpreter', 'none');
set(f, 'Position', [0 0 420*nCond 520]);
saveas(f, fullfile(outDir, 'all_channels.png'));
close(f);

%% all-channel butterfly plot (one subplot per condition, all channels overlaid)
f = figure('Visible', 'off');
ylims = [min(cellfun(@min, allVals)), max(cellfun(@max, allVals))];
for c = 1:nCond
    subplot(1, nCond, c);
    [~, chanIdx] = ismember(chanOrder, condTL{c}.label);
    chanIdx = chanIdx(chanIdx > 0);
    hold on;
    plot(time, condTL{c}.avg(chanIdx, :)', 'LineWidth', 0.5);
    xline(0, 'k--', 'LineWidth', 1.2);
    yline(0, 'k--', 'LineWidth', 1.2);
    hold off;
    xlim([time(1) time(end)]);
    ylim(ylims);
    xlabel('Time (s)');
    if c == 1
        ylabel('Amplitude (\muV)');
    end
    title(strrep(condLabels{c}, '_', ' '));
    grid on;
end
sgtitle([titleStr ' - all channels (butterfly)'], 'Interpreter', 'none');
set(f, 'Position', [0 0 420*nCond 520]);
saveas(f, fullfile(outDir, 'all_channels_butterfly.png'));
close(f);

%% across-channel / ROI averages, conditions overlaid
plot_condition_avg(outDir, 'across_channel', condLabels, condTL, {}, titleStr, time);
plot_condition_avg(outDir, 'centroparietal', condLabels, condTL, roiChans.centroparietal, titleStr, time);
plot_condition_avg(outDir, 'occipital', condLabels, condTL, roiChans.occipital, titleStr, time);

end

function plot_condition_avg(outDir, fname, condLabels, condTL, roiLabels, titleStr, time)

nCond = numel(condTL);

f = figure('Visible', 'off');
hold on;
for c = 1:nCond
    if isempty(roiLabels)
        idx = 1:numel(condTL{c}.label);
    else
        idx = find(ismember(condTL{c}.label, roiLabels));
    end
    trace = mean(condTL{c}.avg(idx, :), 1);
    plot(time, trace, 'LineWidth', 1.5);
end
xl = xline(0, 'k--', 'LineWidth', 1);
xl.HandleVisibility = 'off';
yl = yline(0, 'k--', 'LineWidth', 1);
yl.HandleVisibility = 'off';
hold off;

xlabel('Time (s)');
ylabel('Amplitude (\muV)');
legend(strrep(condLabels, '_', ' '), 'Interpreter', 'none', 'Location', 'best');
title([titleStr ' - ' strrep(fname, '_', ' ')], 'Interpreter', 'none');
grid on;
set(f, 'Position', [0 0 900 500]);
saveas(f, fullfile(outDir, [fname '.png']));
close(f);

end
