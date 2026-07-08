%% MVPA: static-vs-motion decoding - group level (mean +/- SEM across subjects)
%
% Loads each subject's per-iteration accuracy/AUC time courses (saved by
% mvpa_staticVsMotion_subject.m), averages across iterations within each
% subject, then computes the across-subject mean and SEM at every
% timepoint for accuracy and AUC, for each of the 5 decodes per block (4
% per-direction-vs-static + 1 pooled motion-vs-static).
%
% NOTE: N=2 (sub-001, sub-006 only) - sub-004's static.bdf recording has
% no usable stimulus triggers (see mvpa_staticVsMotion_subject.m header).
% Treat this as an exploratory/supplementary result given the small N
% (SEM across only 2 subjects is not a robust error estimate).
%
% Requires outputs/mvpa_staticVsMotion/<sub>/<sub>_mvpa_staticVsMotion.mat
% for every subject (see mvpa_staticVsMotion_subject.m).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaDir     = fullfile(projectDir, 'outputs', 'mvpa_staticVsMotion');
groupOutDir = fullfile(mvpaDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-006'};
nSub = numel(subjects);

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(mvpaDir, subjects{s}, [subjects{s} '_mvpa_staticVsMotion.mat']), 'results');
    allResults{s} = loaded.results;
end

blockNames = fieldnames(allResults{1});

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

groupMvpa = struct();

for b = 1:numel(blockNames)
    blkName = blockNames{b};
    decodeNames = fieldnames(allResults{1}.(blkName));
    nDecode = numel(decodeNames);

    f = figure('Visible', 'off');

    for d = 1:nDecode
        dcName = decodeNames{d};
        timeVec = allResults{1}.(blkName).(dcName).time;
        nTime = numel(timeVec);

        accBySubj = nan(nSub, nTime);
        aucBySubj = nan(nSub, nTime);

        for s = 1:nSub
            accBySubj(s, :) = mean(allResults{s}.(blkName).(dcName).acc, 1); % average over iterations
            aucBySubj(s, :) = mean(allResults{s}.(blkName).(dcName).auc, 1);
        end

        accMean = mean(accBySubj, 1);
        accSEM  = std(accBySubj, 0, 1) / sqrt(nSub);
        aucMean = mean(aucBySubj, 1);
        aucSEM  = std(aucBySubj, 0, 1) / sqrt(nSub);

        groupMvpa.(blkName).(dcName).time         = timeVec;
        groupMvpa.(blkName).(dcName).accBySubject = accBySubj;
        groupMvpa.(blkName).(dcName).aucBySubject = aucBySubj;
        groupMvpa.(blkName).(dcName).accMean      = accMean;
        groupMvpa.(blkName).(dcName).accSEM       = accSEM;
        groupMvpa.(blkName).(dcName).aucMean      = aucMean;
        groupMvpa.(blkName).(dcName).aucSEM       = aucSEM;

        labelStr = sprintf('%s vs %s', strrep(allResults{1}.(blkName).(dcName).classALabel, '_', '-'), ...
            strrep(allResults{1}.(blkName).(dcName).classBLabel, '_', '-'));

        subplot(nDecode, 2, (d-1)*2 + 1);
        plot_mean_sem(timeVec, accMean, accSEM, 0.5);
        xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('Accuracy');
        title({sprintf('%s - accuracy (N=%d)', strrep(dcName, '_', ' '), nSub), labelStr}, 'Interpreter', 'none', 'FontSize', 8);

        subplot(nDecode, 2, (d-1)*2 + 2);
        plot_mean_sem(timeVec, aucMean, aucSEM, 0.5);
        xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('AUC');
        title({sprintf('%s - AUC (N=%d)', strrep(dcName, '_', ' '), nSub), labelStr}, 'Interpreter', 'none', 'FontSize', 8);
    end

    sgtitle(sprintf('Group (N=%d) - %s - static vs motion decoding (mean \\pm SEM)', nSub, blkName), 'Interpreter', 'tex');
    set(f, 'Position', [0 0 1000 1400]);
    saveas(f, fullfile(groupOutDir, ['group_mvpa_staticVsMotion_' blkName '.png']));
    close(f);
end

save(fullfile(groupOutDir, 'group_mvpa_staticVsMotion.mat'), 'groupMvpa', '-v7.3');
fprintf('Saved group MVPA static-vs-motion results and plots to %s\n', groupOutDir);


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
