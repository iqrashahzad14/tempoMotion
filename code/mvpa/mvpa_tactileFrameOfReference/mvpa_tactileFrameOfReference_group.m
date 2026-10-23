%% MVPA: tactile frame-of-reference decoding - group level (mean +/- SEM across subjects)
%
% Loads each subject's per-iteration accuracy/AUC time courses (saved by
% mvpa_tactileFrameOfReference_subject.m), averages across iterations
% within each subject, then computes the across-subject mean and SEM at
% every timepoint for accuracy and AUC, for each of the 3 decodes
% (somatotopic, external, handPos). Plots mean +/- SEM as a shaded band
% against chance (0.5 for both metrics, since this is binary decoding).
%
% Requires outputs/derivatives/mvpa/mvpa_tactileFrameOfReference/<sub>/<sub>_mvpa_tactileFoR.mat
% for every subject (see mvpa_tactileFrameOfReference_subject.m).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaDir     = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa', 'mvpa_tactileFrameOfReference');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006', ...
            'sub-007', 'sub-008', 'sub-009', 'sub-010', 'sub-011', 'sub-012', ...
            'sub-014'};  % N=13 (2026-10-22); sub-013, sub-015 still to be preprocessed

% each sample size gets its own folder (group_N<N>); the earlier N=6
% results stay in group/
groupOutDir = fullfile(mvpaDir, sprintf('group_N%d', numel(subjects)));
% optional: write to another folder (e.g. for a verification run)
if ~isempty(getenv('GROUP_OUTDIR')), groupOutDir = getenv('GROUP_OUTDIR'); end
nSub = numel(subjects);

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(mvpaDir, subjects{s}, [subjects{s} '_mvpa_tactileFoR.mat']), 'results');
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
    xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('Accuracy');
    title({sprintf('%s - accuracy (N=%d)', dcName, nSub), labelStr}, 'Interpreter', 'none', 'FontSize', 8);

    subplot(nDecode, 2, (d-1)*2 + 2);
    plot_mean_sem(timeVec, aucMean, aucSEM, 0.5);
    xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('AUC');
    title({sprintf('%s - AUC (N=%d)', dcName, nSub), labelStr}, 'Interpreter', 'none', 'FontSize', 8);
end

sgtitle('Group - tactile frame-of-reference decoding (mean \pm SEM)', 'Interpreter', 'tex');
set(f, 'Position', [0 0 1000 900]);
% (plain group figure no longer saved: the stats figure below shows the same
%  curves plus the significant time points)
% saveas(f, fullfile(groupOutDir, 'group_mvpa_tactileFoR.png'));
close(f);

save(fullfile(groupOutDir, 'group_mvpa_tactileFoR.mat'), 'groupMvpa', '-v7.3');
fprintf('Saved group MVPA tactile frame-of-reference results and plot to %s\n', groupOutDir);

%% ===================== statistics (merged from stats/stats_mvpa_tactileFrameOfReference_group.m, 2026-10-22) =====================
%% Stats: tactile frame-of-reference decoding - sign-flip cluster-based permutation test
%
% Loads the group-level accuracy/AUC time courses saved by
% mvpa_tactileFrameOfReference_group.m
% (outputs/derivatives/mvpa/mvpa_tactileFrameOfReference/group/group_mvpa_tactileFoR.mat,
% variable groupMvpa.(decode).{accBySubject,aucBySubject}), and tests at
% which timepoints decoding is above chance across subjects, for each of
% the 3 decodes (somatotopic, external, handPos), using an exact
% sign-flip cluster-mass permutation test (see fn_signflip_cluster_test.m).
% Chance is 0.5 for both accuracy and AUC (binary decoding).
%
% Requires outputs/derivatives/mvpa/mvpa_tactileFrameOfReference/group/group_mvpa_tactileFoR.mat.

addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaGroupMat = fullfile(groupOutDir, 'group_mvpa_tactileFoR.mat');
% stats are saved next to the group results (groupOutDir defined above)
if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

%% Test parameters
chanceAcc = 0.5;
chanceAuc = 0.5;
tail                 = 'right'; % test decoding > chance
clusterFormingAlpha  = 0.05;
clusterAlpha         = 0.05;

%% Load group results
loaded = load(mvpaGroupMat, 'groupMvpa');
groupMvpa = loaded.groupMvpa;
decodeNames = fieldnames(groupMvpa);
nDecode = numel(decodeNames);

statsResults = struct();

f = figure('Visible', 'off');

for d = 1:nDecode
    dcName = decodeNames{d};
    timeVec = groupMvpa.(dcName).time;

    accStats = fn_signflip_cluster_test(groupMvpa.(dcName).accBySubject, chanceAcc, ...
        'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);
    aucStats = fn_signflip_cluster_test(groupMvpa.(dcName).aucBySubject, chanceAuc, ...
        'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);

    statsResults.(dcName).time     = timeVec;
    statsResults.(dcName).accStats = accStats;
    statsResults.(dcName).aucStats = aucStats;

    fprintf('%s: %d significant accuracy cluster(s), %d significant AUC cluster(s)\n', ...
        dcName, sum([accStats.clusters.sig]), sum([aucStats.clusters.sig]));

    subplot(nDecode, 2, (d-1)*2 + 1);
    plot_mean_sem_sig(timeVec, groupMvpa.(dcName).accMean, groupMvpa.(dcName).accSEM, ...
        chanceAcc, accStats.sigMask, [0 1]);
    xlim([-0.5 1.5]); xlabel('Time (s)'); ylabel('Accuracy');
    title(sprintf('%s - accuracy (N=%d)', dcName, accStats.nSub), 'Interpreter', 'none', 'FontSize', 8);

    subplot(nDecode, 2, (d-1)*2 + 2);
    plot_mean_sem_sig(timeVec, groupMvpa.(dcName).aucMean, groupMvpa.(dcName).aucSEM, ...
        chanceAuc, aucStats.sigMask, [0 1]);
    xlim([-0.5 1.5]); xlabel('Time (s)'); ylabel('AUC');
    title(sprintf('%s - AUC (N=%d)', dcName, aucStats.nSub), 'Interpreter', 'none', 'FontSize', 8);
end

sgtitle('Group - tactile frame-of-reference decoding: sign-flip cluster stats (red = significant)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 900]);
saveas(f, fullfile(groupOutDir, 'group_stats_mvpa_tactileFoR.png'));
close(f);

save(fullfile(groupOutDir, 'group_stats_mvpa_tactileFoR.mat'), 'statsResults', 'chanceAcc', 'chanceAuc', ...
    'tail', 'clusterFormingAlpha', 'clusterAlpha', '-v7.3');
fprintf('Saved group tactile frame-of-reference decoding stats and plot to %s\n', groupOutDir);


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

function plot_mean_sem_sig(time, meanVal, semVal, chanceLevel, sigMask, yl)

hold on;
fill([time, fliplr(time)], [meanVal + semVal, fliplr(meanVal - semVal)], ...
    [0.3 0.5 0.9], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
plot(time, meanVal, 'LineWidth', 1.5, 'Color', [0.1 0.3 0.8]);
yline(chanceLevel, 'k--');
xline(0, 'k-');
if any(sigMask)
    sigY = yl(1) + 0.03 * range(yl);
    plot(time(sigMask), sigY * ones(1, sum(sigMask)), '.', 'Color', [0.85 0.1 0.1], 'MarkerSize', 8);
end
ylim(yl);
hold off;
grid on;

end
