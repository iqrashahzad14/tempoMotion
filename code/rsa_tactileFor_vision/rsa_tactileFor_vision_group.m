%% RSA: 8-condition cross-modal RDM - group level (mean +/- SEM)
%
% Loads each subject's saved 8x8 time-resolved RDM (see
% rsa_tactileFor_vision_subject.m), averages the RDM and the overall
% distinctiveness time-courses (all-cells and clean-cells-only) across
% the 6 subjects, and plots the group-mean baseline/post-stim RDMs plus
% the distinctiveness time-course with SEM.
%
% Requires outputs/rsa_tactileFor_vision/<sub>/<sub>_rsa_tactileFor_vision.mat
% for every subject (see rsa_tactileFor_vision_subject.m).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
rsaDir      = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision');
groupOutDir = fullfile(rsaDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(rsaDir, subjects{s}, [subjects{s} '_rsa_tactileFor_vision.mat']), 'results');
    allResults{s} = loaded.results;
end

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

condLabels    = allResults{1}.condLabels;
cleanPairMask = allResults{1}.cleanPairMask;
timeVec = allResults{1}.time;
nTime = numel(timeVec);
C = numel(condLabels);

%% Stack across subjects
rdmStack = zeros(nSub, C, C, nTime);
offDiagAllStack   = nan(nSub, nTime);
offDiagCleanStack = nan(nSub, nTime);
rdmBaselineStack = zeros(nSub, C, C);
rdmPostStimStack = zeros(nSub, C, C);
for s = 1:nSub
    rdmStack(s, :, :, :) = allResults{s}.rdm;
    offDiagAllStack(s, :)   = allResults{s}.meanOffDiagAll;
    offDiagCleanStack(s, :) = allResults{s}.meanOffDiagClean;
    rdmBaselineStack(s, :, :) = allResults{s}.rdmBaseline;
    rdmPostStimStack(s, :, :) = allResults{s}.rdmPostStim;
end

groupRsa = struct();
groupRsa.condLabels    = condLabels;
groupRsa.cleanPairMask = cleanPairMask;
groupRsa.time = timeVec;
groupRsa.rdmMean = squeeze(mean(rdmStack, 1));
groupRsa.offDiagAllMean   = mean(offDiagAllStack, 1);
groupRsa.offDiagAllSEM    = std(offDiagAllStack, 0, 1) / sqrt(nSub);
groupRsa.offDiagCleanMean = mean(offDiagCleanStack, 1);
groupRsa.offDiagCleanSEM  = std(offDiagCleanStack, 0, 1) / sqrt(nSub);
groupRsa.rdmBaselineMean = squeeze(mean(rdmBaselineStack, 1));
groupRsa.rdmPostStimMean = squeeze(mean(rdmPostStimStack, 1));

save(fullfile(groupOutDir, 'group_rsa_tactileFor_vision.mat'), 'groupRsa', '-v7.3');

%% Plot
f = figure('Visible', 'off');

subplot(1, 3, 1);
hold on;
fill([timeVec, fliplr(timeVec)], [groupRsa.offDiagAllMean + groupRsa.offDiagAllSEM, fliplr(groupRsa.offDiagAllMean - groupRsa.offDiagAllSEM)], ...
    [0.6 0.6 0.6], 'FaceAlpha', 0.25, 'EdgeColor', 'none');
plot(timeVec, groupRsa.offDiagAllMean, 'LineWidth', 1.5, 'Color', [0.5 0.5 0.5]);
fill([timeVec, fliplr(timeVec)], [groupRsa.offDiagCleanMean + groupRsa.offDiagCleanSEM, fliplr(groupRsa.offDiagCleanMean - groupRsa.offDiagCleanSEM)], ...
    [0.9 0.4 0.4], 'FaceAlpha', 0.25, 'EdgeColor', 'none');
plot(timeVec, groupRsa.offDiagCleanMean, 'LineWidth', 1.5, 'Color', [0.8 0.1 0.1]);
yline(0, 'k--'); xline(0, 'k-');
hold off;
xlabel('Time (s)'); ylabel('Mean cv-distance');
legend({'', 'all cells', '', 'clean cells only'}, 'Location', 'best', 'FontSize', 7);
title(sprintf('overall distinctiveness (N=%d)', nSub));
grid on;

subplot(1, 3, 2);
imagesc(groupRsa.rdmBaselineMean);
axis square; colorbar;
set(gca, 'XTick', 1:C, 'XTickLabel', condLabels, 'YTick', 1:C, 'YTickLabel', condLabels, ...
    'TickLabelInterpreter', 'none', 'FontSize', 6);
title(sprintf('RDM (baseline, N=%d)', nSub));

subplot(1, 3, 3);
imagesc(groupRsa.rdmPostStimMean);
axis square; colorbar;
set(gca, 'XTick', 1:C, 'XTickLabel', condLabels, 'YTick', 1:C, 'YTickLabel', condLabels, ...
    'TickLabelInterpreter', 'none', 'FontSize', 6);
title(sprintf('RDM (post-stim, N=%d)', nSub));

sgtitle('Group - 8-condition cross-modal RSA', 'Interpreter', 'none');
set(f, 'Position', [0 0 1500 500]);
saveas(f, fullfile(groupOutDir, 'group_rsa_tactileFor_vision.png'));
close(f);

fprintf('Saved group 8-condition cross-modal RSA results and plot to %s\n', groupOutDir);
