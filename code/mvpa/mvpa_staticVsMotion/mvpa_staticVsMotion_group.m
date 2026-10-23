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
% Requires outputs/derivatives/mvpa/mvpa_staticVsMotion/<sub>/<sub>_mvpa_staticVsMotion.mat
% for every subject (see mvpa_staticVsMotion_subject.m).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaDir     = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa', 'mvpa_staticVsMotion');
groupOutDir = fullfile(mvpaDir, 'group');
% optional: write to another folder (e.g. for a verification run)
if ~isempty(getenv('GROUP_OUTDIR')), groupOutDir = getenv('GROUP_OUTDIR'); end

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
    % (plain group figure no longer saved: the stats figure below shows the same
    %  curves plus the significant time points)
    % saveas(f, fullfile(groupOutDir, ['group_mvpa_staticVsMotion_' blkName '.png']));
    close(f);
end

save(fullfile(groupOutDir, 'group_mvpa_staticVsMotion.mat'), 'groupMvpa', '-v7.3');
fprintf('Saved group MVPA static-vs-motion results and plots to %s\n', groupOutDir);

%% ===================== statistics (merged from stats/stats_mvpa_staticVsMotion_group.m, 2026-10-22) =====================
%% Stats: static-vs-motion decoding - sign-flip cluster-based permutation test
%
% Loads the group-level accuracy/AUC time courses saved by
% mvpa_staticVsMotion_group.m
% (outputs/derivatives/mvpa/mvpa_staticVsMotion/group/group_mvpa_staticVsMotion.mat,
% variable groupMvpa.(block).(decode).{accBySubject,aucBySubject}), and
% tests at which timepoints decoding is above chance across subjects, for
% each of the 5 decodes per block (4 per-direction-vs-static + 1 pooled
% motion-vs-static), using an exact sign-flip cluster-mass permutation
% test (see fn_signflip_cluster_test.m). Chance is 0.5 for both accuracy
% and AUC (binary decoding).
%
% CAVEAT - N=2 (sub-001, sub-006 only; see mvpa_staticVsMotion_group.m).
% With only 2 subjects there are just 2^2=4 possible sign-flip
% permutations, so the smallest achievable cluster p-value is 1/4=0.25 -
% no cluster can ever cross a 0.05 threshold. This script still runs and
% reports the (always non-significant) result for completeness /
% consistency with the other analyses, but it cannot detect a real
% effect at this N. Treat this as exploratory/descriptive only.
%
% Requires outputs/derivatives/mvpa/mvpa_staticVsMotion/group/group_mvpa_staticVsMotion.mat.

addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaGroupMat = fullfile(groupOutDir, 'group_mvpa_staticVsMotion.mat');
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
blockNames = fieldnames(groupMvpa);

statsResults = struct();

for b = 1:numel(blockNames)
    blkName = blockNames{b};
    decodeNames = fieldnames(groupMvpa.(blkName));
    nDecode = numel(decodeNames);
    nSub = size(groupMvpa.(blkName).(decodeNames{1}).accBySubject, 1);

    f = figure('Visible', 'off');

    for d = 1:nDecode
        dcName = decodeNames{d};
        timeVec = groupMvpa.(blkName).(dcName).time;

        accStats = fn_signflip_cluster_test(groupMvpa.(blkName).(dcName).accBySubject, chanceAcc, ...
            'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);
        aucStats = fn_signflip_cluster_test(groupMvpa.(blkName).(dcName).aucBySubject, chanceAuc, ...
            'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);

        statsResults.(blkName).(dcName).time     = timeVec;
        statsResults.(blkName).(dcName).accStats = accStats;
        statsResults.(blkName).(dcName).aucStats = aucStats;

        fprintf('%s - %s: %d significant accuracy cluster(s), %d significant AUC cluster(s) (N=%d, nPerm=%d)\n', ...
            blkName, dcName, sum([accStats.clusters.sig]), sum([aucStats.clusters.sig]), accStats.nSub, accStats.nPerm);

        subplot(nDecode, 2, (d-1)*2 + 1);
        plot_mean_sem_sig(timeVec, groupMvpa.(blkName).(dcName).accMean, groupMvpa.(blkName).(dcName).accSEM, ...
            chanceAcc, accStats.sigMask, [0 1]);
        xlim([-0.5 1.5]); xlabel('Time (s)'); ylabel('Accuracy');
        title(sprintf('%s - accuracy (N=%d)', strrep(dcName, '_', ' '), accStats.nSub), ...
            'Interpreter', 'none', 'FontSize', 8);

        subplot(nDecode, 2, (d-1)*2 + 2);
        plot_mean_sem_sig(timeVec, groupMvpa.(blkName).(dcName).aucMean, groupMvpa.(blkName).(dcName).aucSEM, ...
            chanceAuc, aucStats.sigMask, [0 1]);
        xlim([-0.5 1.5]); xlabel('Time (s)'); ylabel('AUC');
        title(sprintf('%s - AUC (N=%d)', strrep(dcName, '_', ' '), aucStats.nSub), ...
            'Interpreter', 'none', 'FontSize', 8);
    end

    sgtitle(sprintf('Group (N=%d, exploratory) - %s - static vs motion: sign-flip cluster stats', nSub, blkName), ...
        'Interpreter', 'none');
    set(f, 'Position', [0 0 1000 1400]);
    saveas(f, fullfile(groupOutDir, ['group_stats_mvpa_staticVsMotion_' blkName '.png']));
    close(f);
end

save(fullfile(groupOutDir, 'group_stats_mvpa_staticVsMotion.mat'), 'statsResults', 'chanceAcc', 'chanceAuc', ...
    'tail', 'clusterFormingAlpha', 'clusterAlpha', '-v7.3');
fprintf('Saved group static-vs-motion decoding stats and plots to %s\n', groupOutDir);
fprintf('NOTE: N=2 for this analysis - minimum possible cluster p-value is 0.25, so no cluster can reach p<0.05. Results are descriptive only.\n');


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
