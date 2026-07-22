%% RSA: does soma x handPos / external x handPos interact, and when?
%
% Reloads the already-BINNED raw-factorial RDM time course (3 pre-stim +
% 10 post-stim windows, see rsa_tactileFor_vision_rawFactorial_RDMtimeCourse.m)
% and the 3 pure model RDMs (see rsa_tactileFor_vision_rawFactorial_modelRDMs.m)
% - no recomputation - and correlates each BINNED (already time-averaged,
% hence less noisy than the raw per-timepoint curves) neural RDM against
% each model, for the tactile-only 4x4 crop.
%
% IMPORTANT REFRAME: the blend ("intermediate") models test whether the
% neural RDM looks like an ADDITIVE MIXTURE of two pure hypotheses - a
% different, weaker claim than genuine interaction. The correct test for
% "does factor A interact with factor B" in a 2x2 design is the
% dedicated interaction contrast, which in THIS paradigm already exists
% under a different name:
%   - somatotopic x handPos interaction contrast == the "external" model
%     (external is DEFINED as axis XOR posture by the trigger scheme)
%   - external x handPos interaction contrast == the "somatotopic" model
%     (XOR(external, posture) = axis, by the same algebra)
% So testing interaction here means looking at the EXISTING pure-model
% correlations, correctly relabeled:
%   external's correlation    = test of (somatotopic x handPos) interaction
%   somatotopic's correlation = test of (external x handPos) interaction
%   handPos's correlation     = the handPos main effect (for reference/context)
% There is no well-defined "all three interact" (3-way interaction) in a
% 2-factor (axis, posture) design - external already IS the one
% interaction this design supports. This script also reports the bins
% where all 3 pure models are simultaneously elevated, as a descriptive
% (not formally "interaction") check.
%
% Requires:
%   outputs/rsa_tactileFor_vision/group/group_rsa_tactileFor_vision_rawFactorial_RDMtimeCourse.mat
%   outputs/rsa_tactileFor_vision/models/model_RDMs_rawFactorial.mat

clear;

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tcMat      = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'group', 'group_rsa_tactileFor_vision_rawFactorial_RDMtimeCourse.mat');
modelsMat  = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'models', 'model_RDMs_rawFactorial.mat');
outDir     = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision', 'modelComparison');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% Load binned neural RDMs (tactile-only crop: indices 1:4 of the 6 conditions)
loaded = load(tcMat, 'preRDMs', 'postRDMs', 'preLabels', 'postLabels');
tacIdx = 1:4;
preRDMs_tac  = loaded.preRDMs(tacIdx, tacIdx, :);  % 4x4x3
postRDMs_tac = loaded.postRDMs(tacIdx, tacIdx, :); % 4x4x10
preLabels  = loaded.preLabels;
postLabels = loaded.postLabels;
allLabels  = [preLabels, postLabels];
nBinsPre  = size(preRDMs_tac, 3);
nBinsPost = size(postRDMs_tac, 3);
nBinsAll  = nBinsPre + nBinsPost;

allRDMs = cat(3, preRDMs_tac, postRDMs_tac); % 4x4x13

%% Load pure models
loadedM = load(modelsMat, 'models');
pureByName = struct();
for m = 1:numel(loadedM.models)
    pureByName.(loadedM.models(m).name) = loadedM.models(m).rdm;
end

C = 4;
triuMask = triu(true(C), 1); % 6 unique cells

modelNames = {'somatotopic', 'external', 'handPos'};
modelInterpretation = { ...
    'external x handPos interaction test', ...
    'somatotopic x handPos interaction test', ...
    'handPos main effect (reference)'};

%% Correlate each bin's neural RDM against each of the 3 pure models
rPearson  = nan(3, nBinsAll);
rSpearman = nan(3, nBinsAll);
for b = 1:nBinsAll
    neuralVec = allRDMs(:, :, b);
    neuralVec = neuralVec(triuMask);
    for mi = 1:3
        modelVec = pureByName.(modelNames{mi});
        modelVec = modelVec(triuMask);
        rPearson(mi, b)  = corr(neuralVec(:), modelVec(:), 'Type', 'Pearson');
        rSpearman(mi, b) = corr(neuralVec(:), modelVec(:), 'Type', 'Spearman');
    end
end

%% Report
fprintf('\n=== Interaction-window report (binned, tactile-only, Pearson r) ===\n');
fprintf('%-16s | %s\n', 'bin', strjoin(modelNames, ' | '));
for b = 1:nBinsAll
    fprintf('%-16s | %+.2f | %+.2f | %+.2f\n', allLabels{b}, rPearson(1,b), rPearson(2,b), rPearson(3,b));
end

fprintf('\nReframed:\n');
fprintf('  external r     = somatotopic x handPos interaction test\n');
fprintf('  somatotopic r  = external x handPos interaction test\n\n');

[maxExtR, maxExtBin] = max(rPearson(2, :));
[maxSomaR, maxSomaBin] = max(rPearson(1, :));
fprintf('Strongest (soma x handPos) interaction evidence: bin "%s", external r = %+.2f\n', allLabels{maxExtBin}, maxExtR);
fprintf('Strongest (external x handPos) interaction evidence: bin "%s", somatotopic r = %+.2f\n', allLabels{maxSomaBin}, maxSomaR);

allThreeElevated = all(rPearson > 0.3, 1);
if any(allThreeElevated)
    fprintf('\nBins where all 3 pure models simultaneously show r > 0.3 (descriptive only, not a 3-way interaction test):\n');
    fprintf('  %s\n', strjoin(allLabels(allThreeElevated), ', '));
else
    fprintf('\nNo bin has all 3 pure models simultaneously above r > 0.3.\n');
end

%% Save
save(fullfile(outDir, 'group_rsa_interactionWindows_rawFactorial.mat'), ...
    'rPearson', 'rSpearman', 'modelNames', 'modelInterpretation', 'allLabels', 'nBinsPre', 'nBinsPost', '-v7.3');

%% Plot: bar chart, one group of 3 bars per time bin
f = figure('Visible', 'off');

subplot(2, 1, 1);
bar(rPearson');
hold on;
xline(nBinsPre + 0.5, 'k-', 'LineWidth', 1.5);
yline(0, 'k--');
hold off;
set(gca, 'XTick', 1:nBinsAll, 'XTickLabel', allLabels, 'XTickLabelRotation', 90, 'FontSize', 7);
ylabel('Pearson r'); ylim([-1 1]);
legend({'somatotopic (= ext x hand interaction)', 'external (= soma x hand interaction)', 'handPos (main effect)'}, ...
    'Location', 'best', 'FontSize', 7);
title('Pearson correlation, binned neural RDM vs. pure models (tactile-only)');
grid on;

subplot(2, 1, 2);
bar(rSpearman');
hold on;
xline(nBinsPre + 0.5, 'k-', 'LineWidth', 1.5);
yline(0, 'k--');
hold off;
set(gca, 'XTick', 1:nBinsAll, 'XTickLabel', allLabels, 'XTickLabelRotation', 90, 'FontSize', 7);
ylabel('Spearman \rho'); ylim([-1 1]);
title('Spearman correlation, binned neural RDM vs. pure models (tactile-only)');
grid on;

sgtitle('Interaction windows: external r = soma x handPos test, somatotopic r = external x handPos test', 'Interpreter', 'none');
set(f, 'Position', [0 0 1400 800]);
saveas(f, fullfile(outDir, 'group_rsa_interactionWindows_rawFactorial.png'));
close(f);
fprintf('\nSaved interaction-window figure and data to %s\n', outDir);
