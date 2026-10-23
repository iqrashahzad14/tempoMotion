function stats = fn_signflip_cluster_test2D(data, chanceLevel, varargin)
%% Sign-flip cluster-based permutation test against a fixed chance level (2D)
%
% 2D (train-time x test-time) generalization of fn_signflip_cluster_test.m:
% tests, at each (train, test) pixel, whether a group-level temporal
% generalization metric (accuracy or AUC) sits above chance across
% subjects, then corrects for the many pixels tested by comparing cluster
% mass (summed t-statistic over contiguous above-threshold pixels,
% 4-connectivity) against a null distribution built by flipping the sign
% of each subject's whole deviation matrix (Maris & Oostenveld, 2007).
% Subject counts in this project are small (N<=6), so the sign-flip null
% is enumerated exactly (all 2^N sign combinations) rather than Monte
% Carlo sampled, unless N is large enough that 2^N exceeds nPermMax.
%
% Connected-component labeling is implemented locally via flood fill (no
% Image Processing Toolbox dependency).
%
% Inputs
%   data        - nSubjects x nTime x nTime matrix (one page per subject,
%                 already averaged over decoding iterations)
%   chanceLevel - scalar chance level to test against (e.g. 0.5, 0.25)
%
% Name-value options
%   'tail'                - 'right' (default; tests metric > chance),
%                           'left', or 'both'
%   'clusterFormingAlpha' - per-pixel threshold for forming clusters
%                           (default 0.05)
%   'clusterAlpha'        - cluster-level significance threshold (default 0.05)
%   'nPermMax'             - if 2^nSubjects exceeds this, fall back to
%                           random sign-flip sampling instead of exact
%                           enumeration (default 100000)
%
% Output: stats struct with fields
%   nSub, nTime, chanceLevel, tail, clusterFormingAlpha, clusterAlpha
%   tobs         - nTime x nTime observed t-statistic (deviation from chance)
%   nPerm, exact - number of permutations used, and whether exact
%   nullMaxMass  - nPerm x 1 null distribution of max cluster mass
%   clusters     - struct array, one per observed cluster: mask, mass, pval, sig
%   sigMask      - nTime x nTime logical, true at pixels in a significant cluster

p = inputParser;
addParameter(p, 'tail', 'right');
addParameter(p, 'clusterFormingAlpha', 0.05);
addParameter(p, 'clusterAlpha', 0.05);
addParameter(p, 'nPermMax', 100000);
parse(p, varargin{:});
tail                = p.Results.tail;
clusterFormingAlpha = p.Results.clusterFormingAlpha;
clusterAlpha        = p.Results.clusterAlpha;
nPermMax            = p.Results.nPermMax;

[nSub, nTime1, nTime2] = size(data);
dev = data - chanceLevel;

df = nSub - 1;
switch tail
    case 'right'
        tcrit = tinv(1 - clusterFormingAlpha, df);
    case 'left'
        tcrit = tinv(clusterFormingAlpha, df);
    case 'both'
        tcrit = tinv(1 - clusterFormingAlpha/2, df);
    otherwise
        error('tail must be ''right'', ''left'', or ''both''');
end

%% sign-flip permutations: exact enumeration, or random fallback for large N
if 2^nSub <= nPermMax
    exact = true;
    nPerm = 2^nSub;
    signMat = ones(nPerm, nSub);
    for i = 1:nSub
        block = 2^(i-1);
        pattern = repmat([-ones(block, 1); ones(block, 1)], 2^(nSub-i), 1);
        signMat(:, i) = pattern;
    end
else
    exact = false;
    nPerm = nPermMax;
    signMat = sign(rand(nPerm, nSub) - 0.5);
    signMat(signMat == 0) = 1;
end

%% observed statistic and clusters
tobs = local_tstat(dev);
obsClusters = local_find_clusters2D(tobs, tcrit, tail);

%% null distribution of the max cluster mass
nullMaxMass = zeros(nPerm, 1);
for perm = 1:nPerm
    flips = reshape(signMat(perm, :), [nSub 1 1]);
    devPerm = dev .* flips;
    tperm = local_tstat(devPerm);
    permClusters = local_find_clusters2D(tperm, tcrit, tail);
    if isempty(permClusters)
        nullMaxMass(perm) = 0;
    else
        nullMaxMass(perm) = max([permClusters.mass]);
    end
end

%% cluster p-values (family-wise, via max-statistic null)
for c = 1:numel(obsClusters)
    obsClusters(c).pval = (sum(nullMaxMass >= obsClusters(c).mass) + 1) / (nPerm + 1);
    obsClusters(c).sig  = obsClusters(c).pval < clusterAlpha;
end

sigMask = false(nTime1, nTime2);
for c = 1:numel(obsClusters)
    if obsClusters(c).sig
        sigMask(obsClusters(c).mask) = true;
    end
end

stats = struct();
stats.nSub                = nSub;
stats.nTime                = [nTime1 nTime2];
stats.chanceLevel          = chanceLevel;
stats.tail                 = tail;
stats.clusterFormingAlpha  = clusterFormingAlpha;
stats.clusterAlpha         = clusterAlpha;
stats.tobs                 = tobs;
stats.nPerm                = nPerm;
stats.exact                = exact;
stats.nullMaxMass          = nullMaxMass;
stats.clusters             = obsClusters;
stats.sigMask              = sigMask;

end

%% ---- local functions ----

function tstat = local_tstat(dev)
% dev: nSubjects x nTime x nTime deviation from chance
n = size(dev, 1);
m = squeeze(mean(dev, 1));
s = squeeze(std(dev, 0, 1));
s(s == 0) = eps; % avoid divide-by-zero if a subject-set is perfectly flat
tstat = m ./ (s / sqrt(n));
end

function clusters = local_find_clusters2D(tstat, tcrit, tail)
switch tail
    case 'right'
        supra = tstat > tcrit;
    case 'left'
        supra = tstat < tcrit;
    case 'both'
        supra = abs(tstat) > tcrit;
end

clusters = struct('mask', {}, 'mass', {});
if ~any(supra(:))
    return
end

[labelMat, nClusters] = local_bwlabel4(supra);
for c = 1:nClusters
    mask = labelMat == c;
    clusters(end+1).mask = mask; %#ok<AGROW>
    clusters(end).mass   = sum(abs(tstat(mask)));
end

end

function [labelMat, nClusters] = local_bwlabel4(mask)
% 4-connectivity connected-component labeling via breadth-first flood
% fill (no Image Processing Toolbox dependency).

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
