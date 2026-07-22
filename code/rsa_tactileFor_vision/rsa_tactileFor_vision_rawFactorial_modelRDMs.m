%% RSA: candidate model RDMs for the 4-condition (raw factorial, tactile-only) RDM
%
% Builds 5 candidate model RDMs over the 4 RAW tactile factorial
% conditions (up_fingerWrist, up_pinkyThumb, down_fingerWrist,
% down_pinkyThumb - the tactile-only crop of
% rsa_tactileFor_vision_rawFactorial_subject.m's 6-condition RDM):
%
%   1. somatotopic - axis (finger-wrist vs pinky-thumb) main effect:
%      same axis -> 0, different axis -> 1, regardless of posture.
%   2. handPos     - posture (up vs down) main effect: same posture -> 0,
%      different posture -> 1, regardless of axis.
%   3. external    - axis x posture interaction (XOR): same "parity"
%      (up-fingerWrist & down-pinkyThumb form one group, up-pinkyThumb &
%      down-fingerWrist form the other) -> 0, different parity -> 1.
%   4. interaction_somatotopic_x_handPos = XOR(axis, posture) - IDENTICAL
%      to model 3 (external). This is not a construction artifact: this
%      paradigm DEFINES external reference-frame identity as exactly the
%      axis x posture interaction (external_vertical = up-fingerWrist +
%      down-pinkyThumb, i.e. one parity group), so "external" and "the
%      somatotopic x posture interaction" are the same hypothesis by the
%      trigger scheme itself, not by any modeling choice made here.
%   5. interaction_external_x_handPos = XOR(external, posture) = axis =
%      IDENTICAL to model 1 (somatotopic), by the same logic (a 2x2
%      design only has 3 independent non-trivial contrasts: 2 main
%      effects + 1 interaction, and models 1-3 already ARE those 3).
%
% UNLIKE the pooled 8-condition version (rsa_tactileFor_vision_modelRDMs.m),
% these are FULL categorical contrasts across all 6 unique pairs (not
% sparse single-cell indicators) - with the raw, non-pooled conditions,
% every pair is well-defined (no marginalization ambiguity), so models 1
% and 2 (the true main effects) are properly ORTHOGONAL to each other,
% making this a non-degenerate basis for testing whether the neural data
% reflects axis, posture, or genuine axis x posture interaction structure.
%
% Condition order (matches rsa_tactileFor_vision_rawFactorial_subject.m,
% conditions 1-4 of 6; visual conditions 5-6 excluded here):
%   1: up_fingerWrist   2: up_pinkyThumb
%   3: down_fingerWrist 4: down_pinkyThumb
%
% Outputs saved to outputs/rsa_tactileFor_vision/models/.

clear;

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
groupMat   = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'group', 'group_rsa_tactileFor_vision_rawFactorial.mat');
modelsDir  = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'models');
if ~exist(modelsDir, 'dir')
    mkdir(modelsDir);
end

%% Load condition labels (for consistency with the raw-factorial RDM), tactile-only crop
loaded = load(groupMat, 'groupRsaRaw');
condLabelsFull = loaded.groupRsaRaw.condLabels; % 1x6
tacIdx = 1:4;
condLabels = condLabelsFull(tacIdx); % up_fingerWrist up_pinkyThumb down_fingerWrist down_pinkyThumb
C = numel(condLabels);

%% Group assignments (0/1) for the 2 underlying factors, order matches condLabels
axisAssignment    = [0 1 0 1]; % fingerWrist=0, pinkyThumb=1
postureAssignment = [0 0 1 1]; % up=0, down=1
externalAssignment = xor(axisAssignment, postureAssignment);

%% Build the 5 model RDMs
models = struct();

models(1).name = 'somatotopic';
models(1).rdm  = local_full_contrast(axisAssignment);

models(2).name = 'handPos';
models(2).rdm  = local_full_contrast(postureAssignment);

models(3).name = 'external';
models(3).rdm  = local_full_contrast(externalAssignment);

models(4).name = 'interaction_somatotopic_x_handPos';
models(4).rdm  = local_full_contrast(xor(axisAssignment, postureAssignment)); % == external

models(5).name = 'interaction_external_x_handPos';
models(5).rdm  = local_full_contrast(xor(externalAssignment, postureAssignment)); % == somatotopic

%% Save
save(fullfile(modelsDir, 'model_RDMs_rawFactorial.mat'), 'models', 'condLabels', '-v7.3');
fprintf('Saved 5 raw-factorial model RDMs to %s\n', fullfile(modelsDir, 'model_RDMs_rawFactorial.mat'));

%% Plot: 5 panels, shared 0-1 color scale
f = figure('Visible', 'off');
for m = 1:numel(models)
    subplot(1, numel(models), m);
    imagesc(models(m).rdm, [0 1]);
    axis square;
    colormap(gca, local_binary_colormap());
    set(gca, 'YTick', 1:C, 'YTickLabel', condLabels, 'TickLabelInterpreter', 'none', 'FontSize', 7);
    set(gca, 'XTick', 1:C, 'XTickLabel', condLabels, 'TickLabelInterpreter', 'none', 'FontSize', 7, 'XTickLabelRotation', 90);
    title(strrep(models(m).name, '_', ' '), 'Interpreter', 'none', 'FontSize', 8);
end
cb = colorbar('Position', [0.93 0.15 0.015 0.7]);
cb.Ticks = [0 1];
cb.Label.String = 'model dissimilarity';

sgtitle('Candidate model RDMs (raw factorial, tactile-only, 4 conditions)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1900 450]);
saveas(f, fullfile(modelsDir, 'model_RDMs_rawFactorial.png'));
close(f);
fprintf('Saved model RDM figure to %s\n', fullfile(modelsDir, 'model_RDMs_rawFactorial.png'));


%% ---- local functions ----

function rdm = local_full_contrast(groupAssignment)
% CxC symmetric matrix: 0 if same group, 1 if different group (0 diagonal).
C = numel(groupAssignment);
rdm = zeros(C, C);
for i = 1:C
    for j = 1:C
        if i ~= j
            rdm(i, j) = double(groupAssignment(i) ~= groupAssignment(j));
        end
    end
end
end

function cmap = local_binary_colormap()
% white (0) -> dark red (1)
n = 128;
cmap = [linspace(1, 0.7, n)', linspace(1, 0.05, n)', linspace(1, 0.05, n)'];
end
