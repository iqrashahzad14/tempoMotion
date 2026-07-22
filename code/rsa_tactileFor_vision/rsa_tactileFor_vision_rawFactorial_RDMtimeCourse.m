%% RSA: 6-condition raw-factorial RDM - time-course of binned RDMs
%
% Reloads the saved group-level time-resolved 6x6 RDM (see
% rsa_tactileFor_vision_rawFactorial_group.m) - no recomputation - and
% divides the pre-stimulus period into 3 equal-width windows and the
% post-stimulus period into 10 equal-width windows, averaging the RDM
% within each window. Visualized as a time course of heatmaps on a
% single shared, symmetric-around-zero color scale.
%
% Requires outputs/rsa_tactileFor_vision/group/group_rsa_tactileFor_vision_rawFactorial.mat
% (see rsa_tactileFor_vision_rawFactorial_group.m).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
groupMat    = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'group', 'group_rsa_tactileFor_vision_rawFactorial.mat');
groupOutDir = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'group');

nBinsPre  = 3;
nBinsPost = 10;

%% Load saved group RDM
loaded = load(groupMat, 'groupRsaRaw');
groupRsaRaw = loaded.groupRsaRaw;

timeVec    = groupRsaRaw.time;
rdm        = groupRsaRaw.rdmMean; % C x C x nTime
condLabels = groupRsaRaw.condLabels;
C = numel(condLabels);

%% Bin pre-stim (3 windows) and post-stim (10 windows) separately
[preRDMs, preLabels]   = local_bin_rdm(rdm, timeVec, timeVec < 0, nBinsPre);
[postRDMs, postLabels] = local_bin_rdm(rdm, timeVec, timeVec >= 0, nBinsPost);

%% shared, symmetric color scale (computed from off-diagonal cells only)
offDiagMask = ~eye(C);
allVals = [];
for b = 1:nBinsPre
    s = preRDMs(:, :, b); allVals = [allVals; s(offDiagMask)]; %#ok<AGROW>
end
for b = 1:nBinsPost
    s = postRDMs(:, :, b); allVals = [allVals; s(offDiagMask)]; %#ok<AGROW>
end
climMax = max(abs(allVals));
clim = [-climMax, climMax];

%% Plot: row 1 = pre-stim (3 panels), row 2 = post-stim (10 panels)
% Use a nBinsPost-wide grid throughout so both rows line up; pre-stim
% panels are placed in the first 3 columns of row 1.
f = figure('Visible', 'off');

for b = 1:nBinsPre
    subplot(2, nBinsPost, b);
    local_plot_rdm_panel(preRDMs(:, :, b), clim, preLabels{b}, condLabels, b == 1);
end
for b = 1:nBinsPost
    subplot(2, nBinsPost, nBinsPost + b);
    local_plot_rdm_panel(postRDMs(:, :, b), clim, postLabels{b}, condLabels, b == 1);
end

colormap(local_diverging_colormap());
cb = colorbar('Position', [0.93 0.15 0.015 0.7]);
cb.Label.String = 'cv-distance';

annotation('textbox', [0.005 0.68 0.05 0.1], 'String', 'pre-stim (3 bins)', 'EdgeColor', 'none', 'FontWeight', 'bold', 'FontSize', 9);
annotation('textbox', [0.005 0.22 0.05 0.1], 'String', 'post-stim (10 bins)', 'EdgeColor', 'none', 'FontWeight', 'bold', 'FontSize', 9);

sgtitle('Group - 6-condition raw-factorial RDM time course (3 pre-stim + 10 post-stim windows)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1900 800]);
saveas(f, fullfile(groupOutDir, 'group_rsa_tactileFor_vision_rawFactorial_RDMtimeCourse.png'));
close(f);

save(fullfile(groupOutDir, 'group_rsa_tactileFor_vision_rawFactorial_RDMtimeCourse.mat'), ...
    'preRDMs', 'postRDMs', 'preLabels', 'postLabels', 'condLabels', 'nBinsPre', 'nBinsPost', '-v7.3');
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
