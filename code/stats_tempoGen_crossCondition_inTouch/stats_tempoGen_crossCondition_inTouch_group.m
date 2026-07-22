%% Stats: cross-condition temporal generalization within touch - sign-flip cluster-based permutation test
%
% Loads each subject's saved train-time x test-time generalization
% matrices (outputs/tempoGen_crossCondition_inTouch/<sub>/<sub>_tempoGen_crossCondition.mat,
% variable results.(target).mean.(variant).{acc,auc}, already averaged
% over the 20 decoding iterations at subject-save time), and tests each
% of the 2 targets (somatotopic, external) x 3 variants (a: train
% tgt/test handPos, b: train handPos/test tgt, both: average) x 2 metrics
% (accuracy, AUC) = 12 combinations, using an exact sign-flip cluster-mass
% permutation test in 2D (see fn_signflip_cluster_test2D.m: cluster
% detection via 4-connected contiguous pixels). Tests the WHOLE matrix.
% Chance is 0.5 for both accuracy and AUC (binary decoding).
%
% Runs BOTH tail conventions for every combination:
%   - 'right' (one-tailed, decoding > chance) - matches every other
%     stats_mvpa_*/stats_tempoGen_* analysis in this project.
%   - 'both' (two-tailed, decoding != chance) - appropriate here because
%     tempoGen_crossCondition_inTouch_subject.m uses an ARBITRARY
%     class-pairing convention (see that script's header caveat): a real
%     shared-code effect in the opposite pairing would show up as
%     significantly BELOW chance, which the one-tailed test cannot detect.
%
% This is pure statistics on already-computed per-subject matrices - no
% re-decoding - so it runs in well under a minute.
%
% Requires outputs/tempoGen_crossCondition_inTouch/<sub>/<sub>_tempoGen_crossCondition.mat
% for every subject (see tempoGen_crossCondition_inTouch_subject.m).

clear;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir       = fullfile(projectDir, 'outputs', 'tempoGen_crossCondition_inTouch');
outDir      = fullfile(projectDir, 'outputs', 'stats_tempoGen_crossCondition_inTouch');
groupOutDir = fullfile(outDir, 'group');
if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

%% Subjects and test parameters
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

chanceLevel = 0.5;
clusterFormingAlpha  = 0.05;
clusterAlpha         = 0.05;
climRange = [0.35 0.65];

variants = {'a', 'b', 'both'};
variantTitles = {'train tgt / test handPos', 'train handPos / test tgt', 'both (avg)'};
metrics = {'acc', 'auc'};
tails = {'right', 'both'};
tailNames = {'oneTailed', 'twoTailed'};

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(tgDir, subjects{s}, [subjects{s} '_tempoGen_crossCondition.mat']), 'results');
    allResults{s} = loaded.results;
end

targetNames = fieldnames(allResults{1});

statsResults = struct();
groupMeans = struct(); % computed once, reused across both tail passes

for ti = 1:numel(targetNames)
    tgtName = targetNames{ti};
    timeVec = allResults{1}.(tgtName).time;
    nTime = numel(timeVec);

    for v = 1:numel(variants)
        variant = variants{v};
        for mi = 1:numel(metrics)
            metricName = metrics{mi};
            stack = zeros(nSub, nTime, nTime);
            for s = 1:nSub
                stack(s, :, :) = allResults{s}.(tgtName).mean.(variant).(metricName);
            end
            groupMeans.(tgtName).(variant).(metricName).stack = stack;
            groupMeans.(tgtName).(variant).(metricName).mean  = squeeze(mean(stack, 1, 'omitnan'));
        end
    end
end

for ti_tail = 1:numel(tails)
    tail = tails{ti_tail};
    tailName = tailNames{ti_tail};

    f = figure('Visible', 'off');
    nRows = numel(targetNames) * numel(variants);
    row = 0;

    for ti = 1:numel(targetNames)
        tgtName = targetNames{ti};
        timeVec = allResults{1}.(tgtName).time;

        for v = 1:numel(variants)
            variant = variants{v};
            row = row + 1;

            accStats = fn_signflip_cluster_test2D(groupMeans.(tgtName).(variant).acc.stack, chanceLevel, ...
                'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);
            aucStats = fn_signflip_cluster_test2D(groupMeans.(tgtName).(variant).auc.stack, chanceLevel, ...
                'tail', tail, 'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha);

            statsResults.(tailName).(tgtName).(variant).accStats = accStats;
            statsResults.(tailName).(tgtName).(variant).aucStats = aucStats;

            nSigAcc = sum([accStats.clusters.sig]);
            nSigAuc = sum([aucStats.clusters.sig]);
            fprintf('[%s] %s / %s: %d significant accuracy cluster(s), %d significant AUC cluster(s)\n', ...
                tailName, tgtName, variant, nSigAcc, nSigAuc);

            switch variant
                case 'a'
                    ylab = 'Train: target time (s)'; xlab = 'Test: handPos time (s)';
                case 'b'
                    ylab = 'Train: handPos time (s)'; xlab = 'Test: target time (s)';
                case 'both'
                    ylab = 'Target time (s)'; xlab = 'HandPos time (s)';
            end

            subplot(nRows, 2, (row-1)*2 + 1);
            fn_plot_tempoGen_matrix(timeVec, timeVec, groupMeans.(tgtName).(variant).acc.mean, climRange, ...
                sprintf('%s - %s - acc (N=%d)', tgtName, variantTitles{v}, nSub), ylab, xlab);
            hold on;
            contour(timeVec, timeVec, double(accStats.sigMask), [0.5 0.5], 'k-', 'LineWidth', 1.5);
            hold off;

            subplot(nRows, 2, (row-1)*2 + 2);
            fn_plot_tempoGen_matrix(timeVec, timeVec, groupMeans.(tgtName).(variant).auc.mean, climRange, ...
                sprintf('%s - %s - AUC (N=%d)', tgtName, variantTitles{v}, nSub), ylab, xlab);
            hold on;
            contour(timeVec, timeVec, double(aucStats.sigMask), [0.5 0.5], 'k-', 'LineWidth', 1.5);
            hold off;
        end
    end

    sgtitle(sprintf('Group - cross-condition temporal generalization within touch: sign-flip cluster stats (%s, outline = significant)', tailName), ...
        'Interpreter', 'none');
    set(f, 'Position', [0 0 1100 1600]);
    saveas(f, fullfile(groupOutDir, sprintf('group_stats_tempoGen_crossCondition_%s.png', tailName)));
    close(f);
end

save(fullfile(groupOutDir, 'group_stats_tempoGen_crossCondition.mat'), 'statsResults', 'chanceLevel', ...
    'clusterFormingAlpha', 'clusterAlpha', '-v7.3');
fprintf('Saved group cross-condition-in-touch temporal generalization stats (one-tailed + two-tailed) and plots to %s\n', groupOutDir);
