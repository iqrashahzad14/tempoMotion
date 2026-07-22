%% Stats: cross-condition decoding within touch - sign-flip cluster-based permutation test
%
% Loads the group-level accuracy/AUC time courses saved by
% mvpa_crossCondition_inTouch_group.m
% (outputs/mvpa_crossCondition_inTouch/group/group_mvpa_crossCondition.mat,
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
% Requires outputs/mvpa_crossCondition_inTouch/group/group_mvpa_crossCondition.mat.

clear;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaGroupMat = fullfile(projectDir, 'outputs', 'mvpa_crossCondition_inTouch', 'group', 'group_mvpa_crossCondition.mat');
outDir      = fullfile(projectDir, 'outputs', 'stats_mvpa_crossCondition_inTouch');
groupOutDir = fullfile(outDir, 'group');
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
