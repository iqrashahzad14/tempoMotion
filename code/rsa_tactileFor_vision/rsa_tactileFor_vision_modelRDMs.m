%% RSA: candidate model RDMs for the 6-condition tactile-only RDM
%
% Builds 5 candidate model RDMs over the same 6 tactile conditions used
% in the tactile-only RDM time course (A1/A2 somatotopic, B1/B2 external,
% C1/C2 handPos - see rsa_tactileFor_vision_group_RDMtimeCourse_tactileOnly.m):
%
%   1. somatotopic - sparse indicator: marks ONLY the A1-A2 cell pair as
%      1, rest 0 (no prediction made for any other pair).
%   2. external    - sparse indicator: marks ONLY the B1-B2 cell pair as
%      1, rest 0.
%   3. handPos     - sparse indicator: marks ONLY the C1-C2 cell pair as
%      1, rest 0.
%   4. interaction_somatotopic_x_handPos - MARGINALIZED (not sparse): see below.
%   5. interaction_external_x_handPos    - MARGINALIZED (not sparse): see below.
%
% Models 1-3 use a sparse binary indicator: 1 at the one condition-pair
% that directly instantiates that factor, 0 everywhere else.
%
% Models 4-5 use a different, more rigorous construction. A1-A2, B1-B2,
% C1-C2 are the 3 possible non-trivial 2-way splits of the SAME
% underlying 2x2 (touch-axis x posture) design (4 raw cells: up-FW,
% up-PT, down-FW, down-PT). The true interaction contrast at the raw-cell
% level is well-defined (XOR of the two factors); to get its prediction
% for our 6 POOLED conditions, each of which marginalizes over 2 raw
% cells, the correct approach is to average the raw-cell-level contrast
% over all raw-cell-pair combinations between the two pooled conditions
% being compared - NOT to just mark one sparse cell. Working this out
% algebraically:
%   - the somatotopic x handPos interaction, at the raw-cell level, groups
%     {up-FW, down-PT} vs {up-PT, down-FW} - exactly the B1/B2 (external)
%     split. Marginalizing onto the 6 pooled conditions: every cell
%     averages to 0.5 (mixed/ambiguous - half the underlying raw-cell
%     pairs agree, half disagree) EXCEPT B1-B2 itself, which resolves
%     cleanly to 1.0 (no marginalization ambiguity, since B1 and B2 ARE
%     the raw split).
%   - by the same logic, external x handPos interaction reduces to the
%     A1/A2 (somatotopic) raw split: every cell = 0.5 except A1-A2 = 1.0.
% This 0.5-vs-clean-1.0 pattern is a real structural property of
% marginalizing a 2x2 interaction contrast over pooled conditions, not an
% arbitrary choice - see local_marginalized_interaction() below, which
% computes it directly from raw-cell membership rather than hardcoding
% the result.
%
% NOTE: the same marginalization logic, if applied to models 1-3 instead
% of the sparse-indicator convention, would ALSO introduce 0.5s in their
% cross-factor cells - the sparse convention for 1-3 was requested
% explicitly and kept as specified; only 4-5 use the marginalized version.
%
% Condition order (matches rsa_tactileFor_vision_group_RDMtimeCourse_tactileOnly.m):
%   1: somatotopic_pinkyThumb   2: somatotopic_fingerWrist
%   3: external_horizontal      4: external_vertical
%   5: handPos_up               6: handPos_down
%
% Outputs saved to outputs/rsa_tactileFor_vision/models/.

clear;

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tcMat      = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'group', 'group_rsa_tactileFor_vision_RDMtimeCourse_tactileOnly.mat');
modelsDir  = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'models');
if ~exist(modelsDir, 'dir')
    mkdir(modelsDir);
end

%% Load condition labels (for consistency with the tactile-only RDM)
loaded = load(tcMat, 'tacLabels');
condLabels = loaded.tacLabels; % 1x6, order: A1 A2 B1 B2 C1 C2
C = numel(condLabels);

idxA1 = 1; idxA2 = 2; % somatotopic_pinkyThumb, somatotopic_fingerWrist
idxB1 = 3; idxB2 = 4; % external_horizontal, external_vertical
idxC1 = 5; idxC2 = 6; % handPos_up, handPos_down

%% Raw 2x2 design (4 raw cells) each of the 6 pooled conditions marginalizes over
% raw cell order: r1 = up-fingerWrist, r2 = up-pinkyThumb, r3 = down-fingerWrist, r4 = down-pinkyThumb
condRawMembership = { ...
    [2 4], ... % A1 pinky_thumb   (PT axis, both postures)
    [1 3], ... % A2 finger_wrist  (FW axis, both postures)
    [2 3], ... % B1 ext_horizontal (up-PT, down-FW)
    [1 4], ... % B2 ext_vertical   (up-FW, down-PT)
    [1 2], ... % C1 handPos_up
    [3 4]  ... % C2 handPos_down
    };

% raw-cell-level interaction contrasts (0 = same side of the interaction, 1 = different)
axisXposture_raw = [0 1 1 0; 1 0 0 1; 1 0 0 1; 0 1 1 0];    % somatotopic x posture -> external split
extXposture_raw  = [0 1 0 1; 1 0 1 0; 0 1 0 1; 1 0 1 0];    % external x posture -> somatotopic split

%% Build the 5 model RDMs
models = struct();

models(1).name = 'somatotopic';
models(1).rdm  = local_sparse_indicator(C, idxA1, idxA2);

models(2).name = 'external';
models(2).rdm  = local_sparse_indicator(C, idxB1, idxB2);

models(3).name = 'handPos';
models(3).rdm  = local_sparse_indicator(C, idxC1, idxC2);

models(4).name = 'interaction_somatotopic_x_handPos';
models(4).rdm  = local_marginalized_interaction(condRawMembership, axisXposture_raw);

models(5).name = 'interaction_external_x_handPos';
models(5).rdm  = local_marginalized_interaction(condRawMembership, extXposture_raw);

%% Save
save(fullfile(modelsDir, 'model_RDMs.mat'), 'models', 'condLabels', '-v7.3');
fprintf('Saved 5 model RDMs to %s\n', fullfile(modelsDir, 'model_RDMs.mat'));

%% Plot: 5 panels, shared 0-1 color scale
f = figure('Visible', 'off');
for m = 1:numel(models)
    subplot(1, numel(models), m);
    imagesc(models(m).rdm, [0 1]);
    axis square;
    colormap(gca, local_binary_colormap());
    set(gca, 'YTick', 1:C, 'YTickLabel', condLabels, 'TickLabelInterpreter', 'none', 'FontSize', 6);
    set(gca, 'XTick', 1:C, 'XTickLabel', condLabels, 'TickLabelInterpreter', 'none', 'FontSize', 6, 'XTickLabelRotation', 90);
    title(strrep(models(m).name, '_', ' '), 'Interpreter', 'none', 'FontSize', 8);
end
cb = colorbar('Position', [0.93 0.15 0.015 0.7]);
cb.Ticks = [0 0.5 1];
cb.Label.String = 'model dissimilarity';

sgtitle('Candidate model RDMs (tactile-only, 6 conditions)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1900 500]);
saveas(f, fullfile(modelsDir, 'model_RDMs.png'));
close(f);
fprintf('Saved model RDM figure to %s\n', fullfile(modelsDir, 'model_RDMs.png'));


%% ---- local functions ----

function rdm = local_sparse_indicator(C, i, j)
% CxC symmetric matrix, 1 at (i,j) and (j,i), 0 elsewhere (incl. diagonal).
rdm = zeros(C, C);
rdm(i, j) = 1;
rdm(j, i) = 1;
end

function rdm = local_marginalized_interaction(condRawMembership, rawContrast)
% Marginalizes a raw-cell-level (RxR) binary contrast onto the pooled
% conditions in condRawMembership (1xC cell array of raw-cell index
% vectors), by averaging the raw contrast over every raw-cell-pair
% combination between the two pooled conditions being compared.
C = numel(condRawMembership);
rdm = zeros(C, C);
for i = 1:C
    for j = 1:C
        if i == j
            continue % diagonal stays 0
        end
        vals = [];
        for ri = condRawMembership{i}
            for rj = condRawMembership{j}
                vals(end+1) = rawContrast(ri, rj); %#ok<AGROW>
            end
        end
        rdm(i, j) = mean(vals);
    end
end
end

function cmap = local_binary_colormap()
% white (0) -> dark red (1), passing through a light pink at 0.5
n = 128;
cmap = [linspace(1, 0.7, n)', linspace(1, 0.05, n)', linspace(1, 0.05, n)'];
end
