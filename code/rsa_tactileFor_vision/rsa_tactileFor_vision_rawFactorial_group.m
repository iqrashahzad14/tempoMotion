%% RSA: 6-condition raw-factorial cross-modal RDM - group level (mean +/- SEM)
%
% Loads each subject's saved 6x6 time-resolved RDM (see
% rsa_tactileFor_vision_rawFactorial_subject.m), averages the RDM and the
% overall distinctiveness time-course across the 6 subjects, and plots
% the group-mean baseline/post-stim RDMs plus the distinctiveness
% time-course with SEM.
%
% Requires outputs/rsa_tactileFor_vision/<sub>/<sub>_rsa_tactileFor_vision_rawFactorial.mat
% for every subject (see rsa_tactileFor_vision_rawFactorial_subject.m).

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
    loaded = load(fullfile(rsaDir, subjects{s}, [subjects{s} '_rsa_tactileFor_vision_rawFactorial.mat']), 'results');
    allResults{s} = loaded.results;
end

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

condLabels = allResults{1}.condLabels;
timeVec = allResults{1}.time;
nTime = numel(timeVec);
C = numel(condLabels);

%% Stack across subjects
rdmStack = zeros(nSub, C, C, nTime);
offDiagStack = nan(nSub, nTime);
rdmBaselineStack = zeros(nSub, C, C);
rdmPostStimStack = zeros(nSub, C, C);
for s = 1:nSub
    rdmStack(s, :, :, :) = allResults{s}.rdm;
    offDiagStack(s, :) = allResults{s}.meanOffDiag;
    rdmBaselineStack(s, :, :) = allResults{s}.rdmBaseline;
    rdmPostStimStack(s, :, :) = allResults{s}.rdmPostStim;
end

groupRsaRaw = struct();
groupRsaRaw.condLabels = condLabels;
groupRsaRaw.time = timeVec;
groupRsaRaw.rdmMean = squeeze(mean(rdmStack, 1));
groupRsaRaw.offDiagMean = mean(offDiagStack, 1);
groupRsaRaw.offDiagSEM  = std(offDiagStack, 0, 1) / sqrt(nSub);
groupRsaRaw.rdmBaselineMean = squeeze(mean(rdmBaselineStack, 1));
groupRsaRaw.rdmPostStimMean = squeeze(mean(rdmPostStimStack, 1));

save(fullfile(groupOutDir, 'group_rsa_tactileFor_vision_rawFactorial.mat'), 'groupRsaRaw', '-v7.3');

%% Plot
f = figure('Visible', 'off');

subplot(1, 3, 1);
hold on;
fill([timeVec, fliplr(timeVec)], [groupRsaRaw.offDiagMean + groupRsaRaw.offDiagSEM, fliplr(groupRsaRaw.offDiagMean - groupRsaRaw.offDiagSEM)], ...
    [0.9 0.4 0.4], 'FaceAlpha', 0.25, 'EdgeColor', 'none');
plot(timeVec, groupRsaRaw.offDiagMean, 'LineWidth', 1.5, 'Color', [0.8 0.1 0.1]);
yline(0, 'k--'); xline(0, 'k-');
hold off;
xlabel('Time (s)'); ylabel('Mean cv-distance');
title(sprintf('overall distinctiveness (N=%d)', nSub));
grid on;

subplot(1, 3, 2);
imagesc(groupRsaRaw.rdmBaselineMean);
axis square; colorbar;
set(gca, 'XTick', 1:C, 'XTickLabel', condLabels, 'YTick', 1:C, 'YTickLabel', condLabels, ...
    'TickLabelInterpreter', 'none', 'FontSize', 6, 'XTickLabelRotation', 90);
title(sprintf('RDM (baseline, N=%d)', nSub));

subplot(1, 3, 3);
imagesc(groupRsaRaw.rdmPostStimMean);
axis square; colorbar;
set(gca, 'XTick', 1:C, 'XTickLabel', condLabels, 'YTick', 1:C, 'YTickLabel', condLabels, ...
    'TickLabelInterpreter', 'none', 'FontSize', 6, 'XTickLabelRotation', 90);
title(sprintf('RDM (post-stim, N=%d)', nSub));

sgtitle('Group - 6-condition raw-factorial cross-modal RSA', 'Interpreter', 'none');
set(f, 'Position', [0 0 1500 550]);
saveas(f, fullfile(groupOutDir, 'group_rsa_tactileFor_vision_rawFactorial.png'));
close(f);

fprintf('Saved group 6-condition raw-factorial cross-modal RSA results and plot to %s\n', groupOutDir);
