%% MVPA: cross-modal visual-tactile static-vs-motion decoding - group level
%
% Loads each subject's per-iteration accuracy/AUC time courses (saved by
% mvpa_crossModal_staticVsMotion_subject.m), averages across iterations
% within each subject, then computes the across-subject mean and SEM at
% every timepoint for accuracy and AUC, for each direction (a: train
% vis/test tac, b: train tac/test vis, both: average of a and b). Plots
% mean +/- SEM as a shaded band against chance (0.5).
%
% NOTE: N=2 (sub-001, sub-006 only) - sub-004's static.bdf recording has
% no usable stimulus triggers. Treat this as an exploratory/supplementary
% result given the small N.
%
% Requires outputs/derivatives/mvpa/mvpa_crossModal_staticVsMotion/<sub>/<sub>_mvpa_crossModal_staticVsMotion.mat
% for every subject (see mvpa_crossModal_staticVsMotion_subject.m).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaDir     = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa', 'mvpa_crossModal_staticVsMotion');
groupOutDir = fullfile(mvpaDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-006'};
nSub = numel(subjects);

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(mvpaDir, subjects{s}, [subjects{s} '_mvpa_crossModal_staticVsMotion.mat']), 'results');
    allResults{s} = loaded.results;
end

variants = {'a', 'b', 'both'};
variantTitles = {'train vis / test tac', 'train tac / test vis', 'both (avg)'};

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

groupMvpa = struct();
timeVec = allResults{1}.time;
nTime = numel(timeVec);

f = figure('Visible', 'off');

for v = 1:numel(variants)
    variant = variants{v};

    accBySubj = nan(nSub, nTime);
    aucBySubj = nan(nSub, nTime);
    for s = 1:nSub
        accBySubj(s, :) = mean(allResults{s}.(variant).acc, 1);
        aucBySubj(s, :) = mean(allResults{s}.(variant).auc, 1, 'omitnan');
    end

    accMean = mean(accBySubj, 1); accSEM = std(accBySubj, 0, 1) / sqrt(nSub);
    aucMean = mean(aucBySubj, 1, 'omitnan'); aucSEM = std(aucBySubj, 0, 1, 'omitnan') / sqrt(nSub);

    groupMvpa.(variant).time = timeVec;
    groupMvpa.(variant).accBySubject = accBySubj;
    groupMvpa.(variant).aucBySubject = aucBySubj;
    groupMvpa.(variant).accMean = accMean;
    groupMvpa.(variant).accSEM  = accSEM;
    groupMvpa.(variant).aucMean = aucMean;
    groupMvpa.(variant).aucSEM  = aucSEM;

    subplot(numel(variants), 2, (v-1)*2 + 1);
    plot_mean_sem(timeVec, accMean, accSEM, 0.5);
    xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('Accuracy');
    title(sprintf('%s - accuracy (N=%d)', variantTitles{v}, nSub), 'Interpreter', 'none');

    subplot(numel(variants), 2, (v-1)*2 + 2);
    plot_mean_sem(timeVec, aucMean, aucSEM, 0.5);
    xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('AUC');
    title(sprintf('%s - AUC (N=%d)', variantTitles{v}, nSub), 'Interpreter', 'none');
end

sgtitle(sprintf('Group (N=%d) - cross-modal visual-tactile static-vs-motion decoding (mean \\pm SEM)', nSub), 'Interpreter', 'tex');
set(f, 'Position', [0 0 1000 1000]);
saveas(f, fullfile(groupOutDir, 'group_mvpa_crossModal_staticVsMotion.png'));
close(f);

save(fullfile(groupOutDir, 'group_mvpa_crossModal_staticVsMotion.mat'), 'groupMvpa', '-v7.3');
fprintf('Saved group MVPA cross-modal static-vs-motion results and plot to %s\n', groupOutDir);


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
