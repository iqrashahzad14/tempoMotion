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
% Requires outputs/derivatives/mvpa/mvpa_crossCondition_inTouch/<sub>/<sub>_mvpa_crossCondition.mat
% for every subject (see mvpa_crossCondition_inTouch_subject.m).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaDir     = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa', 'mvpa_crossCondition_inTouch');
groupOutDir = fullfile(mvpaDir, 'group');
% optional: write to another folder (e.g. for a verification run)
if ~isempty(getenv('GROUP_OUTDIR')), groupOutDir = getenv('GROUP_OUTDIR'); end

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
% (plain group figure no longer saved: the stats figure below shows the same
%  curves plus the significant time points)
% saveas(f, fullfile(groupOutDir, 'group_mvpa_crossCondition.png'));
close(f);

save(fullfile(groupOutDir, 'group_mvpa_crossCondition.mat'), 'groupMvpa', '-v7.3');
fprintf('Saved group MVPA cross-condition-in-touch results and plot to %s\n', groupOutDir);

%% ===================== statistics (merged from stats/stats_mvpa_crossCondition_inTouch_group.m, 2026-10-22) =====================
%% Stats: cross-condition decoding within touch - sign-flip cluster-based permutation test
%
% Loads the group-level accuracy/AUC time courses saved by
% mvpa_crossCondition_inTouch_group.m
% (outputs/derivatives/mvpa/mvpa_crossCondition_inTouch/group/group_mvpa_crossCondition.mat,
% variable groupMvpa.(target).(variant).{accBySubject,aucBySubject}), and
% tests each of the 2 targets (somatotopic, external) x 3 variants (a:
% train tgt/test handPos, b: train handPos/test tgt, both: average) x 2
% metrics (accuracy, AUC) = 12 combinations, using an exact sign-flip
% cluster-mass permutation test (see fn_signflip_cluster_test.m). Chance
% is 0.5 for both accuracy and AUC (binary decoding).
%
% Runs BOTH tail conventions for every combination:
%   - 'right' (one-tailed, decoding > chance) - matches every other
%     stats_mvpa_*/stats_tempoGen_* analysis in this project.
%   - 'both' (two-tailed, decoding != chance) - appropriate here because
%     mvpa_crossCondition_inTouch_subject.m uses an ARBITRARY class-pairing
%     convention (see that script's header caveat): a real shared-code
%     effect in the opposite pairing would show up as significantly BELOW
%     chance, which the one-tailed test cannot detect.
%
% Requires outputs/derivatives/mvpa/mvpa_crossCondition_inTouch/group/group_mvpa_crossCondition.mat.

addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaGroupMat = fullfile(groupOutDir, 'group_mvpa_crossCondition.mat');
% stats are saved next to the group results (groupOutDir defined above)
if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

%% Test parameters
chanceLevel = 0.5; % binary decoding throughout
clusterFormingAlpha  = 0.05;
clusterAlpha         = 0.05;

variants = {'a', 'b', 'both'};
variantTitles = {'train tgt / test handPos', 'train handPos / test tgt', 'both (avg)'};
tails = {'right', 'both'};
tailNames = {'oneTailed', 'twoTailed'};

%% Load group results
loaded = load(mvpaGroupMat, 'groupMvpa');
groupMvpa = loaded.groupMvpa;
targetNames = fieldnames(groupMvpa);

statsResults = struct();

for ti_tail = 1:numel(tails)
    tail = tails{ti_tail};
    tailName = tailNames{ti_tail};

    f = figure('Visible', 'off');
    nRows = numel(targetNames) * numel(variants);
    row = 0;

    for ti = 1:numel(targetNames)
        tgtName = targetNames{ti};

        for v = 1:numel(variants)
            variant = variants{v};
            row = row + 1;

            timeVec = groupMvpa.(tgtName).(variant).time;

            accStats = fn_signflip_cluster_test(groupMvpa.(tgtName).(variant).accBySubject, chanceLevel, ...
                'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);
            aucStats = fn_signflip_cluster_test(groupMvpa.(tgtName).(variant).aucBySubject, chanceLevel, ...
                'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);

            statsResults.(tailName).(tgtName).(variant).time     = timeVec;
            statsResults.(tailName).(tgtName).(variant).accStats = accStats;
            statsResults.(tailName).(tgtName).(variant).aucStats = aucStats;

            fprintf('[%s] %s / %s: %d significant accuracy cluster(s), %d significant AUC cluster(s)\n', ...
                tailName, tgtName, variant, sum([accStats.clusters.sig]), sum([aucStats.clusters.sig]));

            subplot(nRows, 2, (row-1)*2 + 1);
            plot_mean_sem_sig(timeVec, groupMvpa.(tgtName).(variant).accMean, groupMvpa.(tgtName).(variant).accSEM, ...
                chanceLevel, accStats.sigMask, [0.35 0.65]);
            xlabel('Time (s)'); ylabel('Accuracy');
            title(sprintf('%s - %s - acc (N=%d)', tgtName, variantTitles{v}, accStats.nSub), 'Interpreter', 'none', 'FontSize', 8);

            subplot(nRows, 2, (row-1)*2 + 2);
            plot_mean_sem_sig(timeVec, groupMvpa.(tgtName).(variant).aucMean, groupMvpa.(tgtName).(variant).aucSEM, ...
                chanceLevel, aucStats.sigMask, [0.35 0.65]);
            xlabel('Time (s)'); ylabel('AUC');
            title(sprintf('%s - %s - AUC (N=%d)', tgtName, variantTitles{v}, aucStats.nSub), 'Interpreter', 'none', 'FontSize', 8);
        end
    end

    sgtitle(sprintf('Group - cross-condition decoding within touch: sign-flip cluster stats (%s, red = significant)', tailName), ...
        'Interpreter', 'none');
    set(f, 'Position', [0 0 1000 1400]);
    saveas(f, fullfile(groupOutDir, sprintf('group_stats_mvpa_crossCondition_%s.png', tailName)));
    close(f);
end

save(fullfile(groupOutDir, 'group_stats_mvpa_crossCondition.mat'), 'statsResults', 'chanceLevel', ...
    'clusterFormingAlpha', 'clusterAlpha', '-v7.3');
fprintf('Saved group cross-condition-in-touch decoding stats (one-tailed + two-tailed) and plots to %s\n', groupOutDir);


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
