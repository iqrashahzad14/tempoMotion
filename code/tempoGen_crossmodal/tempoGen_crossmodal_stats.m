%% Cross-modal temporal generalization: cluster-based permutation stats
%
% Sign-flip cluster-based permutation test (Maris & Oostenveld, 2007
% style) on the group-level train-time x test-time generalization
% matrices from tempoGen_crossmodal_subject.m, for each of the 2 targets
% (somatotopic, external) x 3 variants (a, b, both) x 2 metrics
% (accuracy, AUC) = 12 combinations.
%
% Per-cell statistic: one-sample t-test of each subject's value against
% chance (0.5), across the 6 subjects (df = 5).
% Cluster-forming threshold: two-tailed uncorrected p<0.05 (|t| > t_crit).
% Clusters: contiguous (4-connected), same-signed suprathreshold regions.
% Cluster statistic: sum of |t| within the cluster ("cluster mass").
% Null distribution: flip the sign of each subject's (value - chance)
% deviation independently (a coin flip per subject), recompute the t-map
% and clusters, and take the max cluster mass across the grid. With N=6
% subjects there are exactly 2^6 = 64 possible sign-flip combinations
% (including the true, unflipped data), so this is run as an EXACT
% permutation test enumerating all 64, rather than a Monte Carlo
% approximation. This caps the smallest possible p-value at 1/64 ~= 0.0156.
%
% This is pure statistics on already-computed group matrices - no
% re-decoding - so it runs in well under a minute.
%
% Requires outputs/tempoGen_crossmodal/<sub>/<sub>_tempoGen_crossModal.mat
% for every subject (see tempoGen_crossmodal_subject.m).

clear;

addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir       = fullfile(projectDir, 'outputs', 'tempoGen_crossmodal');
statsOutDir = fullfile(tgDir, 'stats');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(tgDir, subjects{s}, [subjects{s} '_tempoGen_crossModal.mat']), 'results');
    allResults{s} = loaded.results;
end

targetNames = fieldnames(allResults{1});
variants = {'a', 'b', 'both'};
metrics = {'acc', 'auc'};
chanceLevel = 0.5;
alpha = 0.05;

if ~exist(statsOutDir, 'dir')
    mkdir(statsOutDir);
end

%% Cluster-forming threshold (two-tailed, df = nSub-1)
df = nSub - 1;
tCrit = tinv(1 - alpha/2, df);

%% Enumerate all 2^nSub sign-flip combinations (exact permutation test)
signCombos = zeros(2^nSub, nSub);
for c = 0:(2^nSub - 1)
    bits = bitget(c, 1:nSub);
    signCombos(c+1, :) = 1 - 2*bits; % 0 -> +1, 1 -> -1
end
nPerm = size(signCombos, 1);
fprintf('Exact sign-flip permutation test: %d subjects -> %d permutations, t_crit (df=%d) = %.3f\n', ...
    nSub, nPerm, df, tCrit);

statsResults = struct();

f = figure('Visible', 'off');
nRows = numel(targetNames) * numel(variants);
row = 0;

for ti = 1:numel(targetNames)
    tgtName = targetNames{ti};
    timeVec = allResults{1}.(tgtName).time;
    nTime = numel(timeVec);

    for v = 1:numel(variants)
        variant = variants{v};
        row = row + 1;

        groupMean = struct();

        for mi = 1:numel(metrics)
            metricName = metrics{mi};

            stack = zeros(nSub, nTime, nTime);
            for s = 1:nSub
                stack(s, :, :) = allResults{s}.(tgtName).mean.(variant).(metricName);
            end

            groupMean.(metricName) = squeeze(mean(stack, 1, 'omitnan'));

            dev = stack - chanceLevel;

            [obsTmap, obsClusterLabels, obsClusterMass] = local_cluster_test(dev, tCrit);

            nullMaxMass = zeros(nPerm, 1);
            for p = 1:nPerm
                flips = reshape(signCombos(p, :), [nSub 1 1]);
                devPerm = dev .* flips;
                [~, ~, permClusterMass] = local_cluster_test(devPerm, tCrit);
                nullMaxMass(p) = max([permClusterMass; 0]);
            end

            obsPvals = nan(size(obsClusterMass));
            for c = 1:numel(obsClusterMass)
                obsPvals(c) = (sum(nullMaxMass >= obsClusterMass(c)) + 1) / (nPerm + 1);
            end

            sigMask = false(nTime, nTime);
            for c = 1:numel(obsClusterMass)
                if obsPvals(c) < alpha
                    sigMask(obsClusterLabels == c) = true;
                end
            end

            statsResults.(tgtName).(variant).(metricName).tmap = obsTmap;
            statsResults.(tgtName).(variant).(metricName).clusterLabels = obsClusterLabels;
            statsResults.(tgtName).(variant).(metricName).clusterMass = obsClusterMass;
            statsResults.(tgtName).(variant).(metricName).clusterP = obsPvals;
            statsResults.(tgtName).(variant).(metricName).sigMask = sigMask;
            statsResults.(tgtName).(variant).(metricName).nullMaxMass = nullMaxMass;
            statsResults.(tgtName).(variant).(metricName).groupMean = groupMean.(metricName);

            if isempty(obsPvals)
                fprintf('%s / %s / %s: no suprathreshold clusters\n', tgtName, variant, metricName);
            else
                sigFlag = '';
                if any(obsPvals < alpha)
                    sigFlag = '  <-- significant';
                end
                fprintf('%s / %s / %s: %d cluster(s), p = %s%s\n', tgtName, variant, metricName, ...
                    numel(obsPvals), mat2str(round(obsPvals, 4)), sigFlag);
            end
        end

        switch variant
            case 'a'
                ylab = 'Train: visual time (s)'; xlab = 'Test: tactile time (s)';
                vLabel = 'train vis / test tac';
            case 'b'
                ylab = 'Train: tactile time (s)'; xlab = 'Test: visual time (s)';
                vLabel = 'train tac / test vis';
            case 'both'
                ylab = 'Visual time (s)'; xlab = 'Tactile time (s)';
                vLabel = 'both (avg)';
        end

        subplot(nRows, 2, (row-1)*2 + 1);
        fn_plot_tempoGen_matrix(timeVec, timeVec, groupMean.acc, [0.35 0.65], ...
            sprintf('%s - %s - acc (N=%d)', tgtName, vLabel, nSub), ylab, xlab);
        hold on;
        contour(timeVec, timeVec, double(statsResults.(tgtName).(variant).acc.sigMask), [0.5 0.5], 'k-', 'LineWidth', 1.5);
        hold off;

        subplot(nRows, 2, (row-1)*2 + 2);
        fn_plot_tempoGen_matrix(timeVec, timeVec, groupMean.auc, [0.35 0.65], ...
            sprintf('%s - %s - AUC (N=%d)', tgtName, vLabel, nSub), ylab, xlab);
        hold on;
        contour(timeVec, timeVec, double(statsResults.(tgtName).(variant).auc.sigMask), [0.5 0.5], 'k-', 'LineWidth', 1.5);
        hold off;
    end
end

sgtitle('Group - cross-modal temporal generalization (black outline = significant cluster, p<0.05)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1100 1600]);
saveas(f, fullfile(statsOutDir, 'tempoGen_crossmodal_stats.png'));
close(f);

save(fullfile(statsOutDir, 'tempoGen_crossmodal_stats.mat'), 'statsResults', 'tCrit', 'nPerm', 'alpha', '-v7.3');
fprintf('\nSaved cluster permutation stats and plot to %s\n', statsOutDir);


%% ---- local functions ----

function [tmap, clusterLabels, clusterMass] = local_cluster_test(dev, tCrit)
% dev: nSub x nTime x nTime deviations from chance.
% Returns the one-sample t-map, a cluster label matrix (0 = no cluster),
% and a vector of cluster masses (sum of |t| per cluster), for
% contiguous (4-connected) same-signed suprathreshold regions.

nSub = size(dev, 1);
m  = squeeze(mean(dev, 1));
sd = squeeze(std(dev, 0, 1));
se = sd / sqrt(nSub);
tmap = m ./ se;
tmap(se == 0) = 0;

posMask = tmap > tCrit;
negMask = tmap < -tCrit;

[posLabels, nPos] = local_bwlabel(posMask);
[negLabels, nNeg] = local_bwlabel(negMask);

clusterLabels = zeros(size(tmap));
clusterMass = [];
idx = 0;
for c = 1:nPos
    idx = idx + 1;
    mask = posLabels == c;
    clusterLabels(mask) = idx;
    clusterMass(idx) = sum(abs(tmap(mask))); %#ok<AGROW>
end
for c = 1:nNeg
    idx = idx + 1;
    mask = negLabels == c;
    clusterLabels(mask) = idx;
    clusterMass(idx) = sum(abs(tmap(mask))); %#ok<AGROW>
end
clusterMass = clusterMass(:);

end

function [labelMat, nClusters] = local_bwlabel(mask)
% Simple 4-connectivity connected-component labeling (no toolbox
% dependency), via breadth-first flood fill.

[nr, nc] = size(mask);
labelMat = zeros(nr, nc);
nClusters = 0;

for i = 1:nr
    for j = 1:nc
        if mask(i, j) && labelMat(i, j) == 0
            nClusters = nClusters + 1;
            queue = [i j];
            labelMat(i, j) = nClusters;
            qi = 1;
            while qi <= size(queue, 1)
                ci = queue(qi, 1); cj = queue(qi, 2);
                qi = qi + 1;
                neighbors = [ci-1 cj; ci+1 cj; ci cj-1; ci cj+1];
                for k = 1:4
                    ni = neighbors(k, 1); nj = neighbors(k, 2);
                    if ni >= 1 && ni <= nr && nj >= 1 && nj <= nc && mask(ni, nj) && labelMat(ni, nj) == 0
                        labelMat(ni, nj) = nClusters;
                        queue(end+1, :) = [ni nj]; %#ok<AGROW>
                    end
                end
            end
        end
    end
end

end
