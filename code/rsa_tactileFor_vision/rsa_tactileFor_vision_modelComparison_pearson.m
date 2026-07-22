%% RSA: time-resolved Pearson correlation between neural RDM and candidate models
%
% Same structure as rsa_tactileFor_vision_modelComparison_spearman.m, but
% using Pearson (linear, magnitude-sensitive) correlation instead of
% Spearman (rank-based). This is the direct fix for the main limitation
% found in the Spearman version: Spearman is invariant to any monotonic
% rescaling, so it could not distinguish the 12 intermediate blend
% weights (0.2/0.4 always matched each other exactly, 0.6/0.8 always
% matched each other exactly) nor the 2 interaction models from their
% rank-equivalent pure models (external, somatotopic) - both were
% numerically IDENTICAL under Spearman despite being different matrices.
% Pearson correlation uses the actual magnitudes, so the blend weight and
% the sparse-vs-marginalized (0 vs 0.5 floor) distinction can now matter.
%
% Reloads the saved group-level time-resolved 8x8 RDM (see
% rsa_tactileFor_vision_group.m), crops it to the 6x6 tactile-only
% sub-block, and reloads the 17 candidate model RDMs (see
% rsa_tactileFor_vision_modelRDMs.m and
% rsa_tactileFor_vision_intermediateModels.m) - no recomputation of any
% of these - then computes, at EVERY post-stimulus timepoint, the
% Pearson correlation between the neural RDM's upper triangle (15 unique
% off-diagonal cells for a 6x6 matrix) and each model's upper triangle.
%
% Requires:
%   outputs/rsa_tactileFor_vision/group/group_rsa_tactileFor_vision.mat
%   outputs/rsa_tactileFor_vision/models/model_RDMs.mat
%   outputs/rsa_tactileFor_vision/models/model_RDMs_intermediate.mat

clear;

%% Paths
projectDir   = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
groupMat     = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'group', 'group_rsa_tactileFor_vision.mat');
modelsMat    = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'models', 'model_RDMs.mat');
interModelsMat = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'models', 'model_RDMs_intermediate.mat');
outDir       = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'modelComparison');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% Load neural RDM, crop to tactile-only (indices 1:6), restrict to post-stim
loaded = load(groupMat, 'groupRsa');
groupRsa = loaded.groupRsa;
timeVec = groupRsa.time;
rdmFull = groupRsa.rdmMean; % 8 x 8 x nTime

tacIdx = 1:6;
rdmTac = rdmFull(tacIdx, tacIdx, :); % 6 x 6 x nTime

postMask = timeVec >= 0;
postTime = timeVec(postMask);
rdmPost  = rdmTac(:, :, postMask); % 6 x 6 x nTimePost
nTimePost = numel(postTime);

C = numel(tacIdx);
triuMask = triu(true(C), 1); % 15 unique off-diagonal cells

%% Load all 17 models into one list
loadedM  = load(modelsMat, 'models');
loadedIM = load(interModelsMat, 'interModels');

allModels = struct('name', {}, 'rdm', {}, 'family', {});
for m = 1:numel(loadedM.models)
    allModels(end+1).name = loadedM.models(m).name; %#ok<AGROW>
    allModels(end).rdm    = loadedM.models(m).rdm;
    if startsWith(loadedM.models(m).name, 'interaction')
        allModels(end).family = 'interaction';
    else
        allModels(end).family = 'pure';
    end
end
for m = 1:numel(loadedIM.interModels)
    allModels(end+1).name = loadedIM.interModels(m).name; %#ok<AGROW>
    allModels(end).rdm    = loadedIM.interModels(m).rdm;
    allModels(end).family = sprintf('blend_%s_%s', loadedIM.interModels(m).pairA, loadedIM.interModels(m).pairB);
end

nModels = numel(allModels);
modelVecs = zeros(nModels, sum(triuMask(:)));
for m = 1:nModels
    v = allModels(m).rdm(triuMask);
    modelVecs(m, :) = v(:)';
end

%% Time-resolved Pearson correlation: neural RDM vs each model
rho = nan(nModels, nTimePost);
for t = 1:nTimePost
    slice = rdmPost(:, :, t);
    neuralVec = slice(triuMask);
    for m = 1:nModels
        rho(m, t) = corr(neuralVec(:), modelVecs(m, :)', 'Type', 'Pearson');
    end
end

%% Save
modelNames = {allModels.name};
modelFamilies = {allModels.family};
save(fullfile(outDir, 'group_rsa_modelComparison_pearson.mat'), ...
    'rho', 'postTime', 'modelNames', 'modelFamilies', '-v7.3');
fprintf('Saved Pearson model-comparison time courses (%d models x %d timepoints) to %s\n', ...
    nModels, nTimePost, fullfile(outDir, 'group_rsa_modelComparison_pearson.mat'));

%% Plot: 5 panels (pure, interaction, and 3 blend families)
f = figure('Visible', 'off');

subplot(2, 3, 1);
local_plot_family(postTime, rho, modelNames, modelFamilies, {'pure'}, {'somatotopic','external','handPos'});
title('Pure models'); ylabel('Pearson r');

subplot(2, 3, 2);
local_plot_family(postTime, rho, modelNames, modelFamilies, {'interaction'}, ...
    {'interaction_somatotopic_x_handPos','interaction_external_x_handPos'});
title('Interaction models');

subplot(2, 3, 4);
local_plot_family(postTime, rho, modelNames, modelFamilies, {'blend_somatotopic_external'}, {});
title('somatotopic \leftrightarrow external blends'); ylabel('Pearson r'); xlabel('Time (s)');

subplot(2, 3, 5);
local_plot_family(postTime, rho, modelNames, modelFamilies, {'blend_somatotopic_handPos'}, {});
title('somatotopic \leftrightarrow handPos blends'); xlabel('Time (s)');

subplot(2, 3, 6);
local_plot_family(postTime, rho, modelNames, modelFamilies, {'blend_external_handPos'}, {});
title('external \leftrightarrow handPos blends'); xlabel('Time (s)');

sgtitle('Time-resolved Pearson correlation: neural tactile-only RDM vs. candidate models (post-stim)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1500 900]);
saveas(f, fullfile(outDir, 'group_rsa_modelComparison_pearson.png'));
close(f);
fprintf('Saved figure to %s\n', fullfile(outDir, 'group_rsa_modelComparison_pearson.png'));


%% ---- local functions ----

function local_plot_family(time, rho, modelNames, modelFamilies, familyFilter, explicitNames)
% Plots all models whose family is in familyFilter (or, if explicitNames
% is non-empty, exactly those named models), one line each, color-coded.

if ~isempty(explicitNames)
    idx = find(ismember(modelNames, explicitNames));
else
    idx = find(ismember(modelFamilies, familyFilter));
end

cmap = lines(numel(idx));
hold on;
h = gobjects(1, numel(idx));
for k = 1:numel(idx)
    m = idx(k);
    h(k) = plot(time, rho(m, :), 'LineWidth', 1.3, 'Color', cmap(k, :));
end
yline(0, 'k--');
xline(0, 'k-', 'HandleVisibility', 'off');
ylim([-1 1]);
grid on;
legend(h, strrep(modelNames(idx), '_', ' '), 'Location', 'best', 'FontSize', 6, 'Interpreter', 'none');
hold off;

end
