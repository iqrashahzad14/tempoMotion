%% RSA: time-resolved correlation between raw-factorial neural RDM and candidate models
%
% Reloads the saved group-level time-resolved 6x6 raw-factorial RDM (see
% rsa_tactileFor_vision_rawFactorial_group.m), crops it to the 4x4
% tactile-only sub-block (up_fingerWrist, up_pinkyThumb, down_fingerWrist,
% down_pinkyThumb), and reloads the 17 candidate model RDMs (5 from
% rsa_tactileFor_vision_rawFactorial_modelRDMs.m + 12 from
% rsa_tactileFor_vision_rawFactorial_intermediateModels.m) - no
% recomputation of any of these - then computes, at EVERY post-stimulus
% timepoint, BOTH the Spearman (rank) and Pearson (linear) correlation
% between the neural RDM's upper triangle (6 unique off-diagonal cells
% for a 4x4 matrix) and each model's upper triangle.
%
% Unlike the pooled 8-condition version, the 2 interaction models here
% are STILL identical to external/somatotopic respectively (see
% rsa_tactileFor_vision_rawFactorial_modelRDMs.m header - this is a
% genuine fact about how the paradigm defines "external", not a
% resolvable modeling artifact), so their correlation curves will match
% exactly under both Spearman and Pearson, same as before. What DOES
% improve here: with only 6 unique cells and full (non-sparse) main
% effect contrasts, the intermediate blend weights should show more
% graded structure than the earlier 15-cell version even under Spearman.
%
% Requires:
%   outputs/rsa_tactileFor_vision/group/group_rsa_tactileFor_vision_rawFactorial.mat
%   outputs/rsa_tactileFor_vision/models/model_RDMs_rawFactorial.mat
%   outputs/rsa_tactileFor_vision/models/model_RDMs_rawFactorial_intermediate.mat

clear;

%% Paths
projectDir   = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
groupMat     = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'group', 'group_rsa_tactileFor_vision_rawFactorial.mat');
modelsMat    = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'models', 'model_RDMs_rawFactorial.mat');
interModelsMat = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'models', 'model_RDMs_rawFactorial_intermediate.mat');
outDir       = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'modelComparison');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% Load neural RDM, crop to tactile-only (indices 1:4), restrict to post-stim
loaded = load(groupMat, 'groupRsaRaw');
groupRsaRaw = loaded.groupRsaRaw;
timeVec = groupRsaRaw.time;
rdmFull = groupRsaRaw.rdmMean; % 6 x 6 x nTime

tacIdx = 1:4;
rdmTac = rdmFull(tacIdx, tacIdx, :); % 4 x 4 x nTime

postMask = timeVec >= 0;
postTime = timeVec(postMask);
rdmPost  = rdmTac(:, :, postMask); % 4 x 4 x nTimePost
nTimePost = numel(postTime);

C = numel(tacIdx);
triuMask = triu(true(C), 1); % 6 unique off-diagonal cells

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
modelNames = {allModels.name};
modelFamilies = {allModels.family};

%% Time-resolved correlation: neural RDM vs each model, both Spearman and Pearson
corrTypes = {'Spearman', 'Pearson'};
rhoByType = struct();

for ct = 1:numel(corrTypes)
    corrType = corrTypes{ct};
    rho = nan(nModels, nTimePost);
    for t = 1:nTimePost
        slice = rdmPost(:, :, t);
        neuralVec = slice(triuMask);
        for m = 1:nModels
            rho(m, t) = corr(neuralVec(:), modelVecs(m, :)', 'Type', corrType);
        end
    end
    rhoByType.(corrType) = rho;
end

%% Save
save(fullfile(outDir, 'group_rsa_modelComparison_rawFactorial.mat'), ...
    'rhoByType', 'postTime', 'modelNames', 'modelFamilies', '-v7.3');
fprintf('Saved raw-factorial model-comparison time courses (%d models x %d timepoints, Spearman+Pearson) to %s\n', ...
    nModels, nTimePost, fullfile(outDir, 'group_rsa_modelComparison_rawFactorial.mat'));

%% Plot: one figure per correlation type, 5 panels each (pure, interaction, 3 blend families)
for ct = 1:numel(corrTypes)
    corrType = corrTypes{ct};
    rho = rhoByType.(corrType);

    f = figure('Visible', 'off');

    subplot(2, 3, 1);
    local_plot_family(postTime, rho, modelNames, modelFamilies, {'pure'}, {'somatotopic','external','handPos'});
    title('Pure models'); ylabel(sprintf('%s r', corrType));

    subplot(2, 3, 2);
    local_plot_family(postTime, rho, modelNames, modelFamilies, {'interaction'}, ...
        {'interaction_somatotopic_x_handPos','interaction_external_x_handPos'});
    title('Interaction models');

    subplot(2, 3, 4);
    local_plot_family(postTime, rho, modelNames, modelFamilies, {'blend_somatotopic_external'}, {});
    title('somatotopic \leftrightarrow external blends'); ylabel(sprintf('%s r', corrType)); xlabel('Time (s)');

    subplot(2, 3, 5);
    local_plot_family(postTime, rho, modelNames, modelFamilies, {'blend_somatotopic_handPos'}, {});
    title('somatotopic \leftrightarrow handPos blends'); xlabel('Time (s)');

    subplot(2, 3, 6);
    local_plot_family(postTime, rho, modelNames, modelFamilies, {'blend_external_handPos'}, {});
    title('external \leftrightarrow handPos blends'); xlabel('Time (s)');

    sgtitle(sprintf('Raw-factorial: time-resolved %s correlation, neural tactile RDM vs. candidate models (post-stim)', corrType), 'Interpreter', 'none');
    set(f, 'Position', [0 0 1500 900]);
    saveas(f, fullfile(outDir, sprintf('group_rsa_modelComparison_rawFactorial_%s.png', lower(corrType))));
    close(f);
    fprintf('Saved %s figure to %s\n', corrType, fullfile(outDir, sprintf('group_rsa_modelComparison_rawFactorial_%s.png', lower(corrType))));
end


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
