%% RSA: intermediate (graded) model RDMs between somatotopic / external / handPos (raw factorial)
%
% Reloads the 3 PURE main-effect/interaction model RDMs (somatotopic,
% external, handPos - see rsa_tactileFor_vision_rawFactorial_modelRDMs.m)
% - no recomputation - and builds linear-blend "intermediate" models
% between each of the 3 pairs at mixing weights w = 0.2, 0.4, 0.6, 0.8:
%
%   model_blend(w) = w * modelA + (1-w) * modelB
%
% Unlike the pooled 8-condition version's blends (which mixed two sparse
% single-cell indicators), these 3 base models are FULL 0/1 contrasts
% across all 6 pairs, so a blend mixes two overlapping patterns rather
% than two disjoint sparse cells - the resulting values can take more
% than 2 distinct levels (0, w, 1-w, 1, and possibly others depending on
% cell-by-cell agreement/disagreement between the two base models).
%
% 3 pairs x 4 weights = 12 intermediate models.
%
% Requires outputs/rsa_tactileFor_vision/models/model_RDMs_rawFactorial.mat
% (see rsa_tactileFor_vision_rawFactorial_modelRDMs.m).

clear;

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
modelsMat  = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'models', 'model_RDMs_rawFactorial.mat');
modelsDir  = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'models');

%% Load the 3 pure models (somatotopic, external, handPos - skip the 2 interaction duplicates)
loaded = load(modelsMat, 'models', 'condLabels');
pureModels = loaded.models;
condLabels = loaded.condLabels;
C = numel(condLabels);

pureByName = struct();
for m = 1:numel(pureModels)
    pureByName.(pureModels(m).name) = pureModels(m).rdm;
end

%% Pairs to interpolate between, and the weights
pairs = {
    'somatotopic', 'external'
    'somatotopic', 'handPos'
    'external',    'handPos'
    };
weights = [0.2 0.4 0.6 0.8];
fullSpectrum = [0 weights 1]; % include pure endpoints for the figure

%% Build intermediate models
interModels = struct('name', {}, 'rdm', {}, 'pairA', {}, 'pairB', {}, 'weightA', {});

for p = 1:size(pairs, 1)
    nameA = pairs{p, 1};
    nameB = pairs{p, 2};
    rdmA = pureByName.(nameA);
    rdmB = pureByName.(nameB);

    for w = weights
        blend = w * rdmA + (1 - w) * rdmB;
        idx = numel(interModels) + 1;
        interModels(idx).name    = sprintf('%s_w%.1f_%s_w%.1f', nameA, w, nameB, 1 - w);
        interModels(idx).rdm     = blend;
        interModels(idx).pairA   = nameA;
        interModels(idx).pairB   = nameB;
        interModels(idx).weightA = w;
    end
end

%% Save
save(fullfile(modelsDir, 'model_RDMs_rawFactorial_intermediate.mat'), 'interModels', 'pairs', 'weights', 'condLabels', '-v7.3');
fprintf('Saved %d raw-factorial intermediate model RDMs to %s\n', numel(interModels), ...
    fullfile(modelsDir, 'model_RDMs_rawFactorial_intermediate.mat'));

%% Plot: 3 rows (pairs) x 6 columns (w = 0, 0.2, 0.4, 0.6, 0.8, 1 - full continuum)
f = figure('Visible', 'off');
nPairs = size(pairs, 1);
nSteps = numel(fullSpectrum);

for p = 1:nPairs
    nameA = pairs{p, 1};
    nameB = pairs{p, 2};
    rdmA = pureByName.(nameA);
    rdmB = pureByName.(nameB);

    for si = 1:nSteps
        w = fullSpectrum(si);
        blend = w * rdmA + (1 - w) * rdmB;

        subplot(nPairs, nSteps, (p-1)*nSteps + si);
        imagesc(blend, [0 1]);
        axis square;
        colormap(gca, local_binary_colormap());
        if si == 1
            set(gca, 'YTick', 1:C, 'YTickLabel', condLabels, 'TickLabelInterpreter', 'none', 'FontSize', 6);
        else
            set(gca, 'YTick', []);
        end
        set(gca, 'XTick', 1:C, 'XTickLabel', condLabels, 'TickLabelInterpreter', 'none', 'FontSize', 6, 'XTickLabelRotation', 90);
        title(sprintf('%s=%.1f / %s=%.1f', nameA, w, nameB, 1-w), 'Interpreter', 'none', 'FontSize', 6);
    end
end

cb = colorbar('Position', [0.93 0.15 0.015 0.7]);
cb.Ticks = [0 0.2 0.4 0.6 0.8 1];
cb.Label.String = 'model dissimilarity';

sgtitle('Raw-factorial intermediate (graded) model RDMs: pairwise blends of somatotopic / external / handPos', 'Interpreter', 'none');
set(f, 'Position', [0 0 1500 950]);
saveas(f, fullfile(modelsDir, 'model_RDMs_rawFactorial_intermediate.png'));
close(f);
fprintf('Saved raw-factorial intermediate model RDM figure to %s\n', fullfile(modelsDir, 'model_RDMs_rawFactorial_intermediate.png'));


%% ---- local functions ----

function cmap = local_binary_colormap()
% white (0) -> dark red (1)
n = 128;
cmap = [linspace(1, 0.7, n)', linspace(1, 0.05, n)', linspace(1, 0.05, n)'];
end
