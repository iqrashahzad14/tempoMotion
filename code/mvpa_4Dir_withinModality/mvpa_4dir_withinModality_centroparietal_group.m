%% MVPA: 4-direction decoding - group level (mean +/- SEM across subjects)
%
% Loads each subject's per-iteration accuracy/AUC time courses (saved by
% mvpa_4dir_withinModality_subject.m), averages across iterations within
% each subject (collapsing the pseudotrial-assignment randomness), then
% computes the across-subject mean and SEM at every timepoint for
% accuracy and macro-averaged one-vs-rest AUC, for each modality block.
% Plots mean +/- SEM as a shaded band against the chance-level reference
% (0.25 for 4-class accuracy, 0.5 for AUC).
%
% Requires outputs/mvpa_4Dir_withinModality/<sub>/<sub>_mvpa_4dir_centroparietal.mat for
% every subject (see mvpa_4dir_withinModality_subject.m).

% ROI-restricted variant: aggregates the centroparietal-channel decoding
% results (see the matching _centroparietal_subject.m script in this folder).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaDir     = fullfile(projectDir, 'outputs', 'mvpa_4Dir_withinModality', 'centroparietal');
groupOutDir = fullfile(mvpaDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(mvpaDir, subjects{s}, [subjects{s} '_mvpa_4dir_centroparietal.mat']), 'results');
    allResults{s} = loaded.results;
end

blockNames = fieldnames(allResults{1});
nBlocks = numel(blockNames);

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

groupMvpa = struct();

f = figure('Visible', 'off');

for b = 1:nBlocks
    blkName = blockNames{b};
    timeVec = allResults{1}.(blkName).time;
    nTime = numel(timeVec);

    accBySubj = nan(nSub, nTime);
    aucBySubj = nan(nSub, nTime);

    for s = 1:nSub
        accBySubj(s, :) = mean(allResults{s}.(blkName).acc, 1); % average over iterations
        aucBySubj(s, :) = mean(allResults{s}.(blkName).auc, 1);
    end

    accMean = mean(accBySubj, 1);
    accSEM  = std(accBySubj, 0, 1) / sqrt(nSub);
    aucMean = mean(aucBySubj, 1);
    aucSEM  = std(aucBySubj, 0, 1) / sqrt(nSub);

    groupMvpa.(blkName).time         = timeVec;
    groupMvpa.(blkName).accBySubject = accBySubj;
    groupMvpa.(blkName).aucBySubject = aucBySubj;
    groupMvpa.(blkName).accMean      = accMean;
    groupMvpa.(blkName).accSEM       = accSEM;
    groupMvpa.(blkName).aucMean      = aucMean;
    groupMvpa.(blkName).aucSEM       = aucSEM;

    subplot(nBlocks, 2, (b-1)*2 + 1);
    plot_mean_sem(timeVec, accMean, accSEM, 0.25);
    ylim([0.10 0.40]); xlabel('Time (s)'); ylabel('Accuracy');
    title(sprintf('%s - accuracy (N=%d)', strrep(blkName, '_', ' '), nSub));

    subplot(nBlocks, 2, (b-1)*2 + 2);
    plot_mean_sem(timeVec, aucMean, aucSEM, 0.5);
    ylim([0.35 0.65]); xlabel('Time (s)'); ylabel('AUC (macro)');
    title(sprintf('%s - AUC (N=%d)', strrep(blkName, '_', ' '), nSub));
end

sgtitle('Group - 4-direction decoding (mean \pm SEM) (centroparietal)', 'Interpreter', 'tex');
set(f, 'Position', [0 0 1000 900]);
saveas(f, fullfile(groupOutDir, 'group_mvpa_4dir_centroparietal.png'));
close(f);

save(fullfile(groupOutDir, 'group_mvpa_4dir_centroparietal.mat'), 'groupMvpa', '-v7.3');
fprintf('Saved group MVPA 4-direction results and plot to %s\n', groupOutDir);


%% ---- local functions ----

function plot_mean_sem(time, meanVal, semVal, chanceLevel)

hold on;
fill([time, fliplr(time)], [meanVal + semVal, fliplr(meanVal - semVal)], ...
    [0.3 0.5 0.9], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
plot(time, meanVal, 'LineWidth', 1.5, 'Color', [0.1 0.3 0.8]);
yline(chanceLevel, 'k--');
xline(0, 'k-');
hold off;
grid on;

end
