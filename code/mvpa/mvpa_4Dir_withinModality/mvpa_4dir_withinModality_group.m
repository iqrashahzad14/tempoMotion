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
% Requires outputs/derivatives/mvpa/mvpa_4Dir_withinModality/<sub>/<sub>_mvpa_4dir.mat for
% every subject (see mvpa_4dir_withinModality_subject.m).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaDir     = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa', 'mvpa_4Dir_withinModality');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006', ...
            'sub-007', 'sub-008', 'sub-009', 'sub-010', 'sub-011', 'sub-012', ...
            'sub-014'};  % N=13 (2026-10-22); sub-013, sub-015 still to be preprocessed

% each sample size gets its own folder (group_N<N>); the N=6 results stay in group/
groupOutDir = fullfile(mvpaDir, sprintf('group_N%d', numel(subjects)));
% optional: write to another folder (e.g. for a verification run)
if ~isempty(getenv('GROUP_OUTDIR')), groupOutDir = getenv('GROUP_OUTDIR'); end
nSub = numel(subjects);

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(mvpaDir, subjects{s}, [subjects{s} '_mvpa_4dir.mat']), 'results');
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

sgtitle('Group - 4-direction decoding (mean \pm SEM)', 'Interpreter', 'tex');
set(f, 'Position', [0 0 1000 900]);
% (plain group figure no longer saved: the stats figure below shows the same
%  curves plus the significant time points)
% saveas(f, fullfile(groupOutDir, 'group_mvpa_4dir.png'));
close(f);

save(fullfile(groupOutDir, 'group_mvpa_4dir.mat'), 'groupMvpa', '-v7.3');
fprintf('Saved group MVPA 4-direction results and plot to %s\n', groupOutDir);

%% ===================== statistics (merged from stats/stats_mvpa_4Dir_withinModality_group.m, 2026-10-22) =====================
%% Stats: 4-direction decoding - sign-flip cluster-based permutation test
%
% Loads the group-level accuracy/AUC time courses saved by
% mvpa_4dir_withinModality_group.m (outputs/derivatives/mvpa/mvpa_4Dir_withinModality/group/
% group_mvpa_4dir.mat, variable groupMvpa.(block).{accBySubject,aucBySubject}),
% and tests at which timepoints decoding is above chance across subjects,
% for each modality block, using an exact sign-flip cluster-mass
% permutation test (see fn_signflip_cluster_test.m). Chance is 0.25 for
% 4-class accuracy and 0.5 for macro one-vs-rest AUC.
%
% Requires outputs/derivatives/mvpa/mvpa_4Dir_withinModality/group/group_mvpa_4dir.mat.

addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaGroupMat = fullfile(groupOutDir, 'group_mvpa_4dir.mat');
% stats are saved next to the group results (groupOutDir defined above)
if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

%% Test parameters
chanceAcc = 0.25;
chanceAuc = 0.5;
tail                 = 'right'; % test decoding > chance
clusterFormingAlpha  = 0.05;
clusterAlpha         = 0.05;

%% Load group results
loaded = load(mvpaGroupMat, 'groupMvpa');
groupMvpa = loaded.groupMvpa;
blockNames = fieldnames(groupMvpa);
nBlocks = numel(blockNames);

statsResults = struct();

f = figure('Visible', 'off');

for b = 1:nBlocks
    blkName = blockNames{b};
    timeVec = groupMvpa.(blkName).time;

    accStats = fn_signflip_cluster_test(groupMvpa.(blkName).accBySubject, chanceAcc, ...
        'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);
    aucStats = fn_signflip_cluster_test(groupMvpa.(blkName).aucBySubject, chanceAuc, ...
        'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);

    statsResults.(blkName).time     = timeVec;
    statsResults.(blkName).accStats = accStats;
    statsResults.(blkName).aucStats = aucStats;

    fprintf('%s: %d significant accuracy cluster(s), %d significant AUC cluster(s)\n', ...
        blkName, sum([accStats.clusters.sig]), sum([aucStats.clusters.sig]));

    subplot(nBlocks, 2, (b-1)*2 + 1);
    plot_mean_sem_sig(timeVec, groupMvpa.(blkName).accMean, groupMvpa.(blkName).accSEM, ...
        chanceAcc, accStats.sigMask, [0.10 0.40]);
    xlabel('Time (s)'); ylabel('Accuracy');
    title(sprintf('%s - accuracy (N=%d)', strrep(blkName, '_', ' '), accStats.nSub));

    subplot(nBlocks, 2, (b-1)*2 + 2);
    plot_mean_sem_sig(timeVec, groupMvpa.(blkName).aucMean, groupMvpa.(blkName).aucSEM, ...
        chanceAuc, aucStats.sigMask, [0.35 0.65]);
    xlabel('Time (s)'); ylabel('AUC (macro)');
    title(sprintf('%s - AUC (N=%d)', strrep(blkName, '_', ' '), aucStats.nSub));
end

sgtitle('Group - 4-direction decoding: sign-flip cluster stats (red = significant)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 900]);
saveas(f, fullfile(groupOutDir, 'group_stats_mvpa_4dir.png'));
close(f);

save(fullfile(groupOutDir, 'group_stats_mvpa_4dir.mat'), 'statsResults', 'chanceAcc', 'chanceAuc', ...
    'tail', 'clusterFormingAlpha', 'clusterAlpha', '-v7.3');
fprintf('Saved group 4-direction decoding stats and plot to %s\n', groupOutDir);


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
