%% RSA: 8-condition cross-modal RDM - time-course of binned RDMs
%
% Reloads the saved group-level time-resolved 8x8 RDM (see
% rsa_tactileFor_vision_group.m, groupRsa.rdmMean) - no recomputation -
% and divides the pre-stimulus and post-stimulus periods EACH into 10
% equal-width time windows, averaging the (already subject- and
% iteration-averaged) RDM within each window. Result: 10 pre-stim + 10
% post-stim RDMs, visualized as a time course of heatmaps on a single
% shared, symmetric-around-zero color scale (so magnitude is comparable
% across bins - critical for seeing the actual time course rather than
% 20 independently-rescaled snapshots).
%
% Requires outputs/rsa_tactileFor_vision/group/group_rsa_tactileFor_vision.mat
% (see rsa_tactileFor_vision_group.m).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
groupMat    = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'group', 'group_rsa_tactileFor_vision.mat');
groupOutDir = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'group');

nBins = 10;

%% Load saved group RDM
loaded = load(groupMat, 'groupRsa');
groupRsa = loaded.groupRsa;

timeVec    = groupRsa.time;
rdm        = groupRsa.rdmMean; % C x C x nTime
condLabels = groupRsa.condLabels;
C = numel(condLabels);

%% Bin pre-stim and post-stim periods separately, 10 equal-width windows each
[preRDMs, preLabels]   = local_bin_rdm(rdm, timeVec, timeVec < 0, nBins);
[postRDMs, postLabels] = local_bin_rdm(rdm, timeVec, timeVec >= 0, nBins);

%% shared, symmetric color scale (computed from off-diagonal cells only)
offDiagMask = ~eye(C);
allVals = [];
for b = 1:nBins
    s = preRDMs(:, :, b);  allVals = [allVals; s(offDiagMask)]; %#ok<AGROW>
    s = postRDMs(:, :, b); allVals = [allVals; s(offDiagMask)]; %#ok<AGROW>
end
climMax = max(abs(allVals));
clim = [-climMax, climMax];

%% Plot: 2 rows (pre-stim, post-stim) x 10 columns, shared color scale
f = figure('Visible', 'off');

for b = 1:nBins
    subplot(2, nBins, b);
    local_plot_rdm_panel(preRDMs(:, :, b), clim, preLabels{b}, condLabels, b == 1);
end
for b = 1:nBins
    subplot(2, nBins, nBins + b);
    local_plot_rdm_panel(postRDMs(:, :, b), clim, postLabels{b}, condLabels, b == 1);
end

colormap(local_diverging_colormap());
cb = colorbar('Position', [0.93 0.15 0.015 0.7]);
cb.Label.String = 'cv-distance';

annotation('textbox', [0.005 0.68 0.05 0.1], 'String', 'pre-stim', 'EdgeColor', 'none', 'FontWeight', 'bold', 'FontSize', 9);
annotation('textbox', [0.005 0.22 0.05 0.1], 'String', 'post-stim', 'EdgeColor', 'none', 'FontWeight', 'bold', 'FontSize', 9);

sgtitle('Group - 8-condition cross-modal RSA: RDM time course (10 equal-width windows each)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1900 800]);
saveas(f, fullfile(groupOutDir, 'group_rsa_tactileFor_vision_RDMtimeCourse.png'));
close(f);

save(fullfile(groupOutDir, 'group_rsa_tactileFor_vision_RDMtimeCourse.mat'), ...
    'preRDMs', 'postRDMs', 'preLabels', 'postLabels', 'condLabels', 'nBins', '-v7.3');
fprintf('Saved RDM time-course figure and data to %s\n', groupOutDir);


%% ---- local functions ----

function [binnedRDMs, binLabels] = local_bin_rdm(rdm, timeVec, periodMask, nBins)

periodTime = timeVec(periodMask);
edges = linspace(periodTime(1), periodTime(end), nBins + 1);

C = size(rdm, 1);
binnedRDMs = zeros(C, C, nBins);
binLabels = cell(1, nBins);

for b = 1:nBins
    if b < nBins
        idx = timeVec >= edges(b) & timeVec < edges(b+1);
    else
        idx = timeVec >= edges(b) & timeVec <= edges(b+1); % include right edge in the last bin
    end
    binnedRDMs(:, :, b) = mean(rdm(:, :, idx), 3);
    binLabels{b} = sprintf('%.2f to %.2f s', edges(b), edges(b+1));
end

end

function local_plot_rdm_panel(rdmSlice, clim, labelStr, condLabels, showYLabels)

imagesc(rdmSlice, clim);
axis square;
if showYLabels
    set(gca, 'YTick', 1:numel(condLabels), 'YTickLabel', condLabels, 'TickLabelInterpreter', 'none', 'FontSize', 5);
else
    set(gca, 'YTick', []);
end
set(gca, 'XTick', 1:numel(condLabels), 'XTickLabel', condLabels, 'TickLabelInterpreter', 'none', ...
    'FontSize', 5, 'XTickLabelRotation', 90);
title(labelStr, 'FontSize', 6);

end

function cmap = local_diverging_colormap()
% Blue (low/negative) -> white (0) -> red (high/positive)
n = 128;
cmap = [linspace(0, 1, n)', linspace(0, 1, n)', ones(n, 1); ...
        ones(n, 1), linspace(1, 0, n)', linspace(1, 0, n)'];
end
