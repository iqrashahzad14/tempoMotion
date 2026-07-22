function [pval,nulldist,sigind,cl_thr] = fn_signperm(vec1,vec2,permnum,thr,cl_alpha)

% 1D Sign permutation test for line plots
% Written by Siddharth Talwar
% Last edited on 12-05-2026
% The script performs sign permutation testing and clusterwise correction.
% It uses another computeclustersize.m to compute clustersize
% Inputs
% 1) vec1, vec2 = data should be timepoints x subjects.
% 2) sample     = which tails? 1 or 2
% 3) permnum    = number of permutations
% 4) thr        = threshold (0.05)
% 5) cl_alpha   = cluster alpha (could change based on bonferroni
%                   correction)
%
% Output
% 1) pval     = uncorrected pvalues at all timepoints
% 2) nulldist = null distribution
% 3) sigind   = significant timepoints after clusterwise correction
% 4) cl_thr   = cluster threshold

%%%%
% extra notes
% mostly for time wise decoding
%we want to test that at which timepoints is a curve > chance
%put vec 1 as matrix = timepoints x subjects (640x6). put vec2 = []. permnum = 5000, thr and %cl_alpha = 0.05.
%you will get "sigind" which are timepoint indices (1 to 640) that are significant. plot them as %dots or dashes or shaded area together with the curves.
%and yes IMPORTANT - vec1 = vec1-chance karna before calling the function
%All values should be around 0, not chance level.
%%%%

%% sign permutation
if isempty(vec2) == 1 % 1 sample
    
    meanvec  = squeeze(mean(vec1,2)); % mean
    nulldist = zeros(permnum,1);% null dist
    nd2pmaps = zeros(length(meanvec),size(nulldist,1)); %nulldist to pmaps
    pval     = zeros(length(meanvec),1);
    sz       = size(vec1,2);
    
    for tp = 1:size(meanvec,1)
        
        tmp = vec1(tp,:); % vector of all observed values
        
        num = randi([1,sz],1,permnum); % choose a number

        for perm = 1:permnum
            temp           = tmp;
            r              = randperm(size(vec1,2),num(perm)); % choose indices
            temp(r)        = tmp(r)*-1; %flip sign the chosen indices
            nulldist(perm) = mean(temp); % mean the result

        end
        
        % pval is fraction of values higher in n.d. than observed mean and
        % total number of permutations
        pval(tp) = sum(nulldist >= meanvec(tp)) / permnum;
        
        % Unique values and indices for the null distribution
        [uniq, ~, ic] = unique(nulldist);
        
        % Sort the null distribution in ascending order
        sortedNull = sort(nulldist);
        
        % Calculate the cumulative sum in reverse to count values greater or equal
        cumCounts = flip(cumsum(flip(histcounts(sortedNull, [-Inf; uniq]))));
        
        % Normalize by the number of permutations to get the p-values
        tmp = cumCounts / permnum;
        
        nd2pmaps(tp,:) = tmp(ic); % get all p-values
          
    end
    
elseif isempty(vec2) == 0 % 2 sample

    error('Use fn_labelperm instead of fn_signperm for two-sampled tests')
    
    % meanvec = squeeze(mean(vec1,2)) - squeeze(mean(vec2,2)); % data diff
    % nulldist = zeros(permnum,1);% null dist% assuming vec 1 and vec 2 of same length
    % nd2pmaps = zeros(length(meanvec),size(nulldist,1)); %nulldist to pmaps
    % pval     = zeros(length(meanvec),1);
    % 
    % 
    % for tp = 1 : length(meanvec)
    % 
    %     num1 = randi([1,size(vec1,2)],1,permnum); 
    %     num2 = randi([1,size(vec2,2)],1,permnum); 
    % 
    %     tmp1       = vec1(tp,:);
    %     tmp2       = vec2(tp,:);
    %     for perm = 1:permnum
    %         temp1       = tmp1;
    %         r1          = randperm(size(vec1,2),num1(perm));
    %         temp1(r1)   = temp1(r1)*-1;
    % 
    %         temp2       = tmp2;
    %         r2          = randperm(size(vec2,2),num1(perm)); % or num2 is samples are unequal
    %         temp2(r2)   = temp2(r2)*-1; %sign flip
    % 
    %         nulldist(perm) = mean(temp1) - mean(temp2);
    % 
    %     end
    % 
    %     % pval is fraction of values higher in n.d. than observed mean and
    %     % total number of permutations
    %     pval(tp) = sum(nulldist >= meanvec(tp)) / permnum;
    % 
    %     % Unique values and indices for the null distribution
    %     [uniq, ~, ic] = unique(nulldist);
    % 
    %     % Sort the null distribution in ascending order
    %     sortedNull = sort(nulldist);
    % 
    %     % Calculate the cumulative sum in reverse to count values greater or equal
    %     cumCounts = flip(cumsum(flip(histcounts(sortedNull, [-Inf; uniq]))));
    % 
    %     % Normalize by the number of permutations to get the p-values
    %     tmp = cumCounts / permnum;
    % 
    %     nd2pmaps(tp,:) = tmp(ic); % get all p-values
    % 
    % end
  
end

%% cluster correction
sigind=[];

% find max cluster size in n.d.
nullclmax = zeros(size(nd2pmaps,2),1);
for perm = 1:size(nd2pmaps,2)
    [nullclmax(perm)] = computeclustersize(nd2pmaps(:,perm),thr);
end
cl_thr = prctile(nullclmax,100-cl_alpha); % cluster threshold size

% find clusters in the empirical data
[maxcl,clusters,clusterind] = computeclustersize(pval,thr);
sigcl = clusters >= cl_thr; % find clusters above threshold

% concatenate all indices
sigind = [];
for ii = 1:length(clusters)
    if sigcl(ii) ==1
        sigind = [sigind clusterind{ii}];
    end
end
