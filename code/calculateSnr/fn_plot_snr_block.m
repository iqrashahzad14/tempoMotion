function fn_plot_snr_block(outDir, condLabels, snrPerChan, chanLabelsPerCond, roiChans, layoutLabel, layoutPos, titleStr, unitLabel)
% FN_PLOT_SNR_BLOCK Generate the standard set of SNR summary plots for one
% modality-block / analysis-type / metric combination.
%
% Inputs
%   outDir            - directory to save the 4 PNGs into (created if needed)
%   condLabels        - cell array of condition names
%   snrPerChan         - cell array (1 x nCond), each a per-channel SNR vector
%   chanLabelsPerCond - cell array (1 x nCond), channel labels matching snrPerChan{c}
%   roiChans          - struct with fields .occipital and .centroparietal,
%                       each a cell array of channel labels
%   layoutLabel/layoutPos - full 128-channel labels and 2D coordinates
%                       (from the biosemi128.lay layout) used for the
%                       scatter topography
%   titleStr          - figure title / suptitle prefix
%   unitLabel          - axis/colorbar label for the SNR metric (e.g. 'SNR (dB)')
%
% Produces:
%   all_channels.png   - one subplot per condition, per-channel SNR scatter topography
%   across_channel.png - bar chart, mean SNR across all channels, one bar per condition
%   centroparietal.png - bar chart, mean SNR within the centro-parietal ROI
%   occipital.png      - bar chart, mean SNR within the occipital ROI

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

nCond = numel(condLabels);

allVals = cell2mat(cellfun(@(v) v(:), snrPerChan, 'UniformOutput', false));
climRange = [min(allVals(:)), max(allVals(:))];

%% all-channel scatter topography (one subplot per condition)
f = figure('Visible', 'off');
for c = 1:nCond
    subplot(1, nCond, c);
    [~, idx] = ismember(chanLabelsPerCond{c}, layoutLabel);
    valid = idx > 0;
    x = layoutPos(idx(valid), 1);
    y = layoutPos(idx(valid), 2);
    scatter(x, y, 120, snrPerChan{c}(valid), 'filled');
    caxis(climRange);
    axis equal off;
    title(strrep(condLabels{c}, '_', ' '));
    colormap(parula);
    if c == nCond
        cb = colorbar;
        cb.Label.String = unitLabel;
    end
end
sgtitle([titleStr ' - all channels'], 'Interpreter', 'none');
set(f, 'Position', [0 0 380*nCond 430]);
saveas(f, fullfile(outDir, 'all_channels.png'));
close(f);

%% across-channel / ROI bar charts
plot_roi_bar(outDir, 'across_channel', condLabels, snrPerChan, chanLabelsPerCond, {}, titleStr, unitLabel);
plot_roi_bar(outDir, 'centroparietal', condLabels, snrPerChan, chanLabelsPerCond, roiChans.centroparietal, titleStr, unitLabel);
plot_roi_bar(outDir, 'occipital', condLabels, snrPerChan, chanLabelsPerCond, roiChans.occipital, titleStr, unitLabel);

end

function plot_roi_bar(outDir, fname, condLabels, snrPerChan, chanLabelsPerCond, roiLabels, titleStr, unitLabel)

nCond = numel(condLabels);
vals = zeros(1, nCond);
for c = 1:nCond
    if isempty(roiLabels)
        idx = true(size(snrPerChan{c}));
    else
        idx = ismember(chanLabelsPerCond{c}, roiLabels);
    end
    vals(c) = mean(snrPerChan{c}(idx));
end

f = figure('Visible', 'off');
bar(vals);
set(gca, 'XTick', 1:nCond, 'XTickLabel', strrep(condLabels, '_', ' '));
ylabel(unitLabel);
title([titleStr ' - ' strrep(fname, '_', ' ')], 'Interpreter', 'none');
grid on;
set(f, 'Position', [0 0 700 450]);
saveas(f, fullfile(outDir, [fname '.png']));
close(f);

end
