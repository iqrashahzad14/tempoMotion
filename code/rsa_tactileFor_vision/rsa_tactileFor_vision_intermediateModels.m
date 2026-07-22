%% RSA: intermediate (graded) model RDMs between somatotopic / external / handPos
%
% Reloads the 3 PURE sparse-indicator model RDMs (somatotopic, external,
% handPos - see rsa_tactileFor_vision_modelRDMs.m) - no recomputation -
% and builds linear-blend "intermediate" models between each of the 3
% pairs (somatotopic<->external, somatotopic<->handPos, external<->handPos)
% at mixing weights w = 0.2, 0.4, 0.6, 0.8:
%
%   model_blend(w) = w * modelA + (1-w) * modelB
%
% Since modelA and modelB are sparse indicators with disjoint non-zero
% cells (each lights up only its own defining pair), a blend at weight w
% simply places w at modelA's cell and (1-w) at modelB's cell, with
% everything else remaining 0 - a graded continuum connecting the two
% pure (w=1 and w=0) endpoints, useful for testing whether the observed
% neural RDM is better explained by a mixture than by either pure
% categorical hypothesis alone.
%
% 3 pairs x 4 weights = 12 intermediate models. Saved alongside the full
% 0->1 continuum (w = 0, 0.2, 0.4, 0.6, 0.8, 1) per pair for visualization,
% reusing the existing pure models as the w=0/w=1 endpoints.
%
% Requires outputs/rsa_tactileFor_vision/models/model_RDMs.mat (see
% rsa_tactileFor_vision_modelRDMs.m).

clear;

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
modelsMat  = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'models', 'model_RDMs.mat');
modelsDir  = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'models');

%% Load the 3 pure models
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
save(fullfile(modelsDir, 'model_RDMs_intermediate.mat'), 'interModels', 'pairs', 'weights', 'condLabels', '-v7.3');
fprintf('Saved %d intermediate model RDMs to %s\n', numel(interModels), ...
    fullfile(modelsDir, 'model_RDMs_intermediate.mat'));

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
            set(gca, 'YTick', 1:C, 'YTickLabel', condLabels, 'TickLabelInterpreter', 'none', 'FontSize', 5);
        else
            set(gca, 'YTick', []);
        end
        set(gca, 'XTick', 1:C, 'XTickLabel', condLabels, 'TickLabelInterpreter', 'none', 'FontSize', 5, 'XTickLabelRotation', 90);
        title(sprintf('%s=%.1f / %s=%.1f', nameA, w, nameB, 1-w), 'Interpreter', 'none', 'FontSize', 6);
    end
end

cb = colorbar('Position', [0.93 0.15 0.015 0.7]);
cb.Ticks = [0 0.2 0.4 0.6 0.8 1];
cb.Label.String = 'model dissimilarity';

sgtitle('Intermediate (graded) model RDMs: pairwise blends of somatotopic / external / handPos', 'Interpreter', 'none');
set(f, 'Position', [0 0 1900 950]);
saveas(f, fullfile(modelsDir, 'model_RDMs_intermediate.png'));
close(f);
fprintf('Saved intermediate model RDM figure to %s\n', fullfile(modelsDir, 'model_RDMs_intermediate.png'));


%% ---- local functions ----

function cmap = local_binary_colormap()
% white (0) -> dark red (1)
n = 128;
cmap = [linspace(1, 0.7, n)', linspace(1, 0.05, n)', linspace(1, 0.05, n)'];
end
