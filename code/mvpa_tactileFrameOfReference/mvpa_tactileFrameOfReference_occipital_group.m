%% MVPA: tactile frame-of-reference decoding - group level (mean +/- SEM across subjects)
%
% Loads each subject's per-iteration accuracy/AUC time courses (saved by
% mvpa_tactileFrameOfReference_subject.m), averages across iterations
% within each subject, then computes the across-subject mean and SEM at
% every timepoint for accuracy and AUC, for each of the 3 decodes
% (somatotopic, external, handPos). Plots mean +/- SEM as a shaded band
% against chance (0.5 for both metrics, since this is binary decoding).
%
% Requires outputs/mvpa_tactileFrameOfReference/<sub>/<sub>_mvpa_tactileFoR_occipital.mat
% for every subject (see mvpa_tactileFrameOfReference_subject.m).

% ROI-restricted variant: aggregates the occipital-channel decoding
% results (see the matching _occipital_subject.m script in this folder).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaDir     = fullfile(projectDir, 'outputs', 'mvpa_tactileFrameOfReference', 'occipital');
groupOutDir = fullfile(mvpaDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(mvpaDir, subjects{s}, [subjects{s} '_mvpa_tactileFoR_occipital.mat']), 'results');
    allResults{s} = loaded.results;
end

decodeNames = fieldnames(allResults{1});
nDecode = numel(decodeNames);

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

groupMvpa = struct();

f = figure('Visible', 'off');

for d = 1:nDecode
    dcName = decodeNames{d};
    timeVec = allResults{1}.(dcName).time;
    nTime = numel(timeVec);

    accBySubj = nan(nSub, nTime);
    aucBySubj = nan(nSub, nTime);

    for s = 1:nSub
        accBySubj(s, :) = mean(allResults{s}.(dcName).acc, 1); % average over iterations
        aucBySubj(s, :) = mean(allResults{s}.(dcName).auc, 1);
    end

    accMean = mean(accBySubj, 1);
    accSEM  = std(accBySubj, 0, 1) / sqrt(nSub);
    aucMean = mean(aucBySubj, 1);
    aucSEM  = std(aucBySubj, 0, 1) / sqrt(nSub);

    groupMvpa.(dcName).time         = timeVec;
    groupMvpa.(dcName).accBySubject = accBySubj;
    groupMvpa.(dcName).aucBySubject = aucBySubj;
    groupMvpa.(dcName).accMean      = accMean;
    groupMvpa.(dcName).accSEM       = accSEM;
    groupMvpa.(dcName).aucMean      = aucMean;
    groupMvpa.(dcName).aucSEM       = aucSEM;

    labelStr = sprintf('%s vs %s', strrep(allResults{1}.(dcName).classALabel, '_', '-'), strrep(allResults{1}.(dcName).classBLabel, '_', '-'));

    subplot(nDecode, 2, (d-1)*2 + 1);
    plot_mean_sem(timeVec, accMean, accSEM, 0.5);
    ylim([0.35 0.65]); xlabel('Time (s)'); ylabel('Accuracy');
    title({sprintf('%s - accuracy (N=%d)', dcName, nSub), labelStr}, 'Interpreter', 'none', 'FontSize', 8);

    subplot(nDecode, 2, (d-1)*2 + 2);
    plot_mean_sem(timeVec, aucMean, aucSEM, 0.5);
    ylim([0.35 0.65]); xlabel('Time (s)'); ylabel('AUC');
    title({sprintf('%s - AUC (N=%d)', dcName, nSub), labelStr}, 'Interpreter', 'none', 'FontSize', 8);
end

sgtitle('Group - tactile frame-of-reference decoding (mean \pm SEM) (occipital)', 'Interpreter', 'tex');
set(f, 'Position', [0 0 1000 900]);
saveas(f, fullfile(groupOutDir, 'group_mvpa_tactileFoR_occipital.png'));
close(f);

save(fullfile(groupOutDir, 'group_mvpa_tactileFoR_occipital.mat'), 'groupMvpa', '-v7.3');
fprintf('Saved group MVPA tactile frame-of-reference results and plot to %s\n', groupOutDir);


%% ---- local functions ----

function plot_mean_sem(time, meanVal, semVal, chanceLevel)

hold on;
fill([time, fliplr(time)], [meanVal + semVal, fliplr(meanVal - semVal)], ...
    [0.3 0.5 0.9], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
plot(time, meanVal, 'LineWidth', 1.5, 'Color', [0.1 0.3 0.8]);
yline(chanceLevel, 'k--');
xline(0, 'k-');
xline(-0.01, ':', 'Color', [0.6 0.6 0.6]);
xline(0.01, ':', 'Color', [0.6 0.6 0.6]);
hold off;
grid on;

end
