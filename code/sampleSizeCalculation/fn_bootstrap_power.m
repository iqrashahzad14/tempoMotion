function powerResults = fn_bootstrap_power(data, chanceLevel, Nrange, nBootstrap, varargin)
%% Bootstrap power analysis for the sign-flip cluster permutation test
%
% Estimates, for each hypothetical sample size in Nrange, the probability
% that the sign-flip cluster test (fn_signflip_cluster_test.m for 1D
% timepoints x subjects data, fn_signflip_cluster_test2D.m for 2D
% train-time x test-time x subjects data) would detect a significant
% cluster, by case-resampling subjects WITH REPLACEMENT from the observed
% data and rerunning the actual test many times per N.
%
% This is an empirical/simulation-based power estimate that matches the
% real cluster-forming + max-statistic correction procedure used
% throughout this project, unlike a textbook analytic power formula
% (which assumes a simple, single test statistic and can't account for
% cluster-level correction).
%
% CAVEAT: bootstrapping from a small original sample (N=6 in this
% project) can only recombine the between-subject variability already
% present in those 6 subjects - it cannot capture variability a
% genuinely new, independent subject would add. Treat this as an
% optimistic ballpark for the sample size needed, not a guarantee: true
% power at a given N could be lower than estimated here.
%
% Inputs
%   data        - nSubOrig x nTime (1D) or nSubOrig x nTime x nTime (2D)
%   chanceLevel - scalar chance level
%   Nrange      - vector of hypothetical sample sizes to test
%   nBootstrap  - number of bootstrap resamples per sample size
%
% Name-value options (passed through to the inner cluster test)
%   'tail', 'clusterFormingAlpha', 'clusterAlpha' - as in
%       fn_signflip_cluster_test(2D)
%   'nPermMax' - number of permutations used INSIDE each bootstrap
%       replicate's significance test. Kept small relative to the main
%       stats scripts' default (100 here vs 100000 there), since this
%       runs nBootstrap x numel(Nrange) times.
%
% Output: powerResults struct with fields
%   Nrange, power (1 x numel(Nrange), estimated power at each N)
%   nBootstrap, nSubOrig, chanceLevel, nPermMax, tail
%   N80 - linearly-interpolated sample size at which power first reaches
%         0.8 (NaN if never reached within Nrange, Nrange(1) if already
%         >=0.8 at the smallest N tested)

p = inputParser;
addParameter(p, 'tail', 'right');
addParameter(p, 'clusterFormingAlpha', 0.05);
addParameter(p, 'clusterAlpha', 0.05);
addParameter(p, 'nPermMax', 100);
parse(p, varargin{:});
tail                 = p.Results.tail;
clusterFormingAlpha  = p.Results.clusterFormingAlpha;
clusterAlpha         = p.Results.clusterAlpha;
nPermMax             = p.Results.nPermMax;

is2D = (ndims(data) == 3);
nSubOrig = size(data, 1);

power = zeros(1, numel(Nrange));
for ni = 1:numel(Nrange)
    N = Nrange(ni);
    successCount = 0;
    for b = 1:nBootstrap
        idx = randi(nSubOrig, [N, 1]);
        if is2D
            bootData = data(idx, :, :);
            s = fn_signflip_cluster_test2D(bootData, chanceLevel, 'tail', tail, ...
                'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha, 'nPermMax', nPermMax);
        else
            bootData = data(idx, :);
            s = fn_signflip_cluster_test(bootData, chanceLevel, 'tail', tail, ...
                'clusterFormingAlpha', clusterFormingAlpha, 'clusterAlpha', clusterAlpha, 'nPermMax', nPermMax);
        end
        if ~isempty(s.clusters) && any([s.clusters.sig])
            successCount = successCount + 1;
        end
    end
    power(ni) = successCount / nBootstrap;
    fprintf('    N=%d: power=%.2f\n', N, power(ni));
end

powerResults = struct();
powerResults.Nrange    = Nrange;
powerResults.power     = power;
powerResults.nBootstrap = nBootstrap;
powerResults.nSubOrig  = nSubOrig;
powerResults.chanceLevel = chanceLevel;
powerResults.nPermMax  = nPermMax;
powerResults.tail      = tail;
powerResults.N80       = local_interp_N_for_power(Nrange, power, 0.8);

end

%% ---- local functions ----

function N80 = local_interp_N_for_power(Nrange, power, target)
if all(power >= target)
    N80 = Nrange(1);
elseif all(power < target)
    N80 = NaN;
else
    idx = find(power >= target, 1, 'first');
    x1 = Nrange(idx-1); x2 = Nrange(idx);
    y1 = power(idx-1);  y2 = power(idx);
    N80 = x1 + (target - y1) * (x2 - x1) / (y2 - y1);
end
end
