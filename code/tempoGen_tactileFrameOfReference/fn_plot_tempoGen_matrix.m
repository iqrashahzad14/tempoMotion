function fn_plot_tempoGen_matrix(yTime, xTime, matrix, climRange, titleStr, ylabelStr, xlabelStr)
% FN_PLOT_TEMPOGEN_MATRIX Plots a train-time x test-time generalization
% matrix (heatmap) into the current axes, with a diagonal reference line
% (train time == test time) and x=0/y=0 stimulus-onset reference lines.
%
% Inputs
%   yTime, xTime - time vectors for the train (y) and test (x) axes
%   matrix       - yTime x xTime matrix of accuracy or AUC values
%   climRange    - [min max] color axis limits (e.g. chance +/- 0.15)
%   titleStr     - subplot title
%   ylabelStr, xlabelStr - axis labels (train/test domain identity differs
%                  by variant: 'a', 'b', 'both')

imagesc(xTime, yTime, matrix, climRange);
set(gca, 'YDir', 'normal');
colormap(gca, local_diverging_colormap());
hold on;
plot([xTime(1) xTime(end)], [yTime(1) yTime(end)], 'k--', 'LineWidth', 1);
xline(0, 'k-');
yline(0, 'k-');
hold off;
xlabel(xlabelStr);
ylabel(ylabelStr);
title(titleStr, 'Interpreter', 'none', 'FontSize', 8);
colorbar;

end

function cmap = local_diverging_colormap()
% Blue (low) -> white (chance, center of climRange) -> red (high)
n = 128;
cmap = [linspace(0, 1, n)', linspace(0, 1, n)', ones(n, 1); ...
        ones(n, 1), linspace(1, 0, n)', linspace(1, 0, n)'];
end
