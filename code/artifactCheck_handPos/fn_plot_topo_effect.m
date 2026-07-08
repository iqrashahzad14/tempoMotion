function fn_plot_topo_effect(outFile, bandNames, effectPerBand, chanLabelsPerBand, layoutLabel, layoutPos, titleStr)
% FN_PLOT_TOPO_EFFECT Scatter-topography of a per-channel effect size
% (tactile_up vs tactile_down Cohen's d), one subplot per frequency band,
% using the same scatter-topography convention as
% code/calculateSnr/fn_plot_snr_block.m.
%
% Inputs
%   outFile           - full PNG path to save to
%   bandNames         - cell array of band names (subplot titles)
%   effectPerBand     - cell array (1 x nBand), each a per-channel Cohen's
%                       d vector
%   chanLabelsPerBand - cell array (1 x nBand), channel labels matching
%                       effectPerBand{b} (order may differ from layout)
%   layoutLabel/layoutPos - 128-channel labels and 2D coordinates (from
%                       biosemi128.lay, COMNT/SCALE already excluded)
%   titleStr          - figure sgtitle

nBand = numel(bandNames);

allVals = cell2mat(cellfun(@(v) v(:), effectPerBand, 'UniformOutput', false));
climMax = max(abs(allVals(:)));
if climMax == 0 || isnan(climMax)
    climMax = 1;
end
climRange = [-climMax, climMax];

f = figure('Visible', 'off');
for b = 1:nBand
    subplot(1, nBand, b);
    [~, idx] = ismember(chanLabelsPerBand{b}, layoutLabel);
    valid = idx > 0;
    x = layoutPos(idx(valid), 1);
    y = layoutPos(idx(valid), 2);
    scatter(x, y, 100, effectPerBand{b}(valid), 'filled');
    caxis(climRange);
    axis equal off;
    colormap(gca, local_diverging_colormap());
    title(bandNames{b});
    if b == nBand
        cb = colorbar;
        cb.Label.String = 'Cohen''s d (tactile up - down)';
    end
end
sgtitle(titleStr, 'Interpreter', 'none');
set(f, 'Position', [0 0 380*nBand 430]);
saveas(f, outFile);
close(f);

end

function cmap = local_diverging_colormap()
% Blue (negative) -> white (zero) -> red (positive)
n = 128;
cmap = [linspace(0, 1, n)', linspace(0, 1, n)', ones(n, 1); ...
        ones(n, 1), linspace(1, 0, n)', linspace(1, 0, n)'];
end
