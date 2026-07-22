%% MVPA: cross-condition decoding within touch - group level (mean +/- SEM)
%
% Loads each subject's per-iteration accuracy/AUC time courses (saved by
% mvpa_crossCondition_inTouch_subject.m), averages across iterations
% within each subject, then computes the across-subject mean and SEM at
% every timepoint for accuracy and AUC, for each target (somatotopic,
% external) and each direction (a: train target/test handPos, b: train
% handPos/test target, both: average of a and b). Plots mean +/- SEM as a
% shaded band against chance (0.5).
%
% Requires outputs/mvpa_crossCondition_inTouch/<sub>/<sub>_mvpa_crossCondition.mat
% for every subject (see mvpa_crossCondition_inTouch_subject.m).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaDir     = fullfile(projectDir, 'outputs', 'mvpa_crossCondition_inTouch');
groupOutDir = fullfile(mvpaDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(mvpaDir, subjects{s}, [subjects{s} '_mvpa_crossCondition.mat']), 'results');
    allResults{s} = loaded.results;
end

targetNames = fieldnames(allResults{1});
variants = {'a', 'b', 'both'};
variantTitles = {'train tgt / test handPos', 'train handPos / test tgt', 'both (avg)'};

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

groupMvpa = struct();

f = figure('Visible', 'off');
nRows = numel(targetNames) * numel(variants);
row = 0;

for ti = 1:numel(targetNames)
    tgtName = targetNames{ti};
    timeVec = allResults{1}.(tgtName).time;
    nTime = numel(timeVec);
    labelStr = sprintf('%s vs %s', strrep(allResults{1}.(tgtName).classALabel, '_', '-'), strrep(allResults{1}.(tgtName).classBLabel, '_', '-'));

    for v = 1:numel(variants)
        variant = variants{v};
        row = row + 1;

        accBySubj = nan(nSub, nTime);
        aucBySubj = nan(nSub, nTime);
        for s = 1:nSub
            accBySubj(s, :) = mean(allResults{s}.(tgtName).(variant).acc, 1);
            aucBySubj(s, :) = mean(allResults{s}.(tgtName).(variant).auc, 1, 'omitnan');
        end

        accMean = mean(accBySubj, 1); accSEM = std(accBySubj, 0, 1) / sqrt(nSub);
        aucMean = mean(aucBySubj, 1, 'omitnan'); aucSEM = std(aucBySubj, 0, 1, 'omitnan') / sqrt(nSub);

        groupMvpa.(tgtName).(variant).time = timeVec;
        groupMvpa.(tgtName).(variant).accBySubject = accBySubj;
        groupMvpa.(tgtName).(variant).aucBySubject = aucBySubj;
        groupMvpa.(tgtName).(variant).accMean = accMean;
        groupMvpa.(tgtName).(variant).accSEM  = accSEM;
        groupMvpa.(tgtName).(variant).aucMean = aucMean;
        groupMvpa.(tgtName).(variant).aucSEM  = aucSEM;

        subplot(nRows, 2, (row-1)*2 + 1);
        plot_mean_sem(timeVec, accMean, accSEM, 0.5);
        ylim([0.35 0.65]); xlabel('Time (s)'); ylabel('Accuracy');
        title({sprintf('%s - %s - accuracy (N=%d)', tgtName, variantTitles{v}, nSub), labelStr}, 'Interpreter', 'none', 'FontSize', 8);

        subplot(nRows, 2, (row-1)*2 + 2);
        plot_mean_sem(timeVec, aucMean, aucSEM, 0.5);
        ylim([0.35 0.65]); xlabel('Time (s)'); ylabel('AUC');
        title({sprintf('%s - %s - AUC (N=%d)', tgtName, variantTitles{v}, nSub), labelStr}, 'Interpreter', 'none', 'FontSize', 8);
    end
end

sgtitle('Group - cross-condition decoding within touch (mean \pm SEM)', 'Interpreter', 'tex');
set(f, 'Position', [0 0 1000 1400]);
saveas(f, fullfile(groupOutDir, 'group_mvpa_crossCondition.png'));
close(f);

save(fullfile(groupOutDir, 'group_mvpa_crossCondition.mat'), 'groupMvpa', '-v7.3');
fprintf('Saved group MVPA cross-condition-in-touch results and plot to %s\n', groupOutDir);


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
