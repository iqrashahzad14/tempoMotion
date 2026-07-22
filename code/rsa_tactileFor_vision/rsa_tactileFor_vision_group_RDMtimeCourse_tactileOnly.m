%% RSA: 8-condition cross-modal RDM - tactile-only RDM time course
%
% Reloads the saved binned RDM time course (see
% rsa_tactileFor_vision_group_RDMtimeCourse.m) - no recomputation - and
% crops each of the 20 (10 pre-stim + 10 post-stim) 8x8 RDMs down to just
% the 6x6 tactile-tactile sub-block (somatotopic/external/handPos
% conditions, dropping the 2 visual conditions entirely), recomputing the
% shared color scale from ONLY that sub-block's own range. The full 8x8
% version (group_rsa_tactileFor_vision_RDMtimeCourse.png) is dominated by
% the much larger visual-tactile distances, which visually flattens the
% tactile-tactile structure to near-white throughout - this figure is
% the same time course with that dominant signal removed, so whatever
% structure exists among the tactile reference-frame/posture conditions
% can actually be seen.
%
% Requires outputs/rsa_tactileFor_vision/group/group_rsa_tactileFor_vision_RDMtimeCourse.mat
% (see rsa_tactileFor_vision_group_RDMtimeCourse.m).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tcMat       = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'group', 'group_rsa_tactileFor_vision_RDMtimeCourse.mat');
groupOutDir = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'group');

%% Load saved binned RDM time course
loaded = load(tcMat, 'preRDMs', 'postRDMs', 'preLabels', 'postLabels', 'condLabels', 'nBins');
preRDMs    = loaded.preRDMs;    % 8 x 8 x nBins
postRDMs   = loaded.postRDMs;
preLabels  = loaded.preLabels;
postLabels = loaded.postLabels;
condLabels = loaded.condLabels; % 1x8: A1 A2 B1 B2 C1 C2 D1(visual) D2(visual)
nBins      = loaded.nBins;

%% Crop to the 6x6 tactile-tactile sub-block (drop the 2 visual conditions)
tacIdx = 1:6; % A1 A2 B1 B2 C1 C2
tacLabels = condLabels(tacIdx);
Ct = numel(tacIdx);

preRDMs_tac  = preRDMs(tacIdx, tacIdx, :);
postRDMs_tac = postRDMs(tacIdx, tacIdx, :);

%% shared color scale from the tactile-only sub-block's own range (off-diagonal cells)
offDiagMask = ~eye(Ct);
allVals = [];
for b = 1:nBins
    s = preRDMs_tac(:, :, b);  allVals = [allVals; s(offDiagMask)]; %#ok<AGROW>
    s = postRDMs_tac(:, :, b); allVals = [allVals; s(offDiagMask)]; %#ok<AGROW>
end
climMax = max(abs(allVals));
clim = [-climMax, climMax];

%% Plot: 2 rows (pre-stim, post-stim) x 10 columns, tactile-only shared scale
f = figure('Visible', 'off');

for b = 1:nBins
    subplot(2, nBins, b);
    local_plot_rdm_panel(preRDMs_tac(:, :, b), clim, preLabels{b}, tacLabels, b == 1);
end
for b = 1:nBins
    subplot(2, nBins, nBins + b);
    local_plot_rdm_panel(postRDMs_tac(:, :, b), clim, postLabels{b}, tacLabels, b == 1);
end

colormap(local_diverging_colormap());
cb = colorbar('Position', [0.93 0.15 0.015 0.7]);
cb.Label.String = 'cv-distance';

annotation('textbox', [0.005 0.68 0.05 0.1], 'String', 'pre-stim', 'EdgeColor', 'none', 'FontWeight', 'bold', 'FontSize', 9);
annotation('textbox', [0.005 0.22 0.05 0.1], 'String', 'post-stim', 'EdgeColor', 'none', 'FontWeight', 'bold', 'FontSize', 9);

sgtitle('Group - tactile-only (somatotopic/external/handPos) RDM time course - own color scale', 'Interpreter', 'none');
set(f, 'Position', [0 0 1900 800]);
saveas(f, fullfile(groupOutDir, 'group_rsa_tactileFor_vision_RDMtimeCourse_tactileOnly.png'));
close(f);

save(fullfile(groupOutDir, 'group_rsa_tactileFor_vision_RDMtimeCourse_tactileOnly.mat'), ...
    'preRDMs_tac', 'postRDMs_tac', 'preLabels', 'postLabels', 'tacLabels', 'nBins', '-v7.3');
fprintf('Saved tactile-only RDM time-course figure and data to %s\n', groupOutDir);


%% ---- local functions ----

function local_plot_rdm_panel(rdmSlice, clim, labelStr, condLabels, showYLabels)

imagesc(rdmSlice, clim);
axis square;
if showYLabels
    set(gca, 'YTick', 1:numel(condLabels), 'YTickLabel', condLabels, 'TickLabelInterpreter', 'none', 'FontSize', 6);
else
    set(gca, 'YTick', []);
end
set(gca, 'XTick', 1:numel(condLabels), 'XTickLabel', condLabels, 'TickLabelInterpreter', 'none', ...
    'FontSize', 6, 'XTickLabelRotation', 90);
title(labelStr, 'FontSize', 6);

end

function cmap = local_diverging_colormap()
% Blue (low/negative) -> white (0) -> red (high/positive)
n = 128;
cmap = [linspace(0, 1, n)', linspace(0, 1, n)', ones(n, 1); ...
        ones(n, 1), linspace(1, 0, n)', linspace(1, 0, n)'];
end
