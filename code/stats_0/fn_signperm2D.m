function [pval,correctedmask,numcl,maxcl] = fn_signperm2D(mat1,mat2,permnum,thr,cl_alpha)

% 2D Sign permutation test
% Written by Siddharth Talwar
% Last edited on 26-11-2025
% The script performs sign permutation testing and clusterwise correction.
% Not compatible for other 2D tests. See fn_signperm_chan.
% Inputs
% 1) mat1, mat2 = data should be dim1 x dim2 x subjects. 
% 2) permnum    = number of permutations
% 3) thr        = threshold (0.05)
%
% Output
% 1) pval     = uncorrected pvalues at all timepoints
% 2) correctecmask = binary mask of significance after clusterwise correction

%%

%%%
%extra notes
% mostly for tempo generalization
% similar input. output is correctedmask
%Remember, that you had to transpose and average the two TG
%%%

if isempty(mat2) == 1

    tail = 1;
    
    meanvec  = squeeze(mean(mat1,3)); % dataset
    nulldist1 = zeros(permnum,1);% meanvec;
    nd2pmaps{1} = zeros(size(mat1,1),size(mat1,2),permnum);
    pval{1}     = zeros(size(mat1,1),size(mat1,2));
    
    for tp1 = 1:size(meanvec,1)
        
        for tp2 = 1:size(meanvec,2)
            if meanvec(tp1,tp2)~=0
                
                num = randi([1,size(mat1,3)],1,permnum);
                
                for perm = 1:permnum
                    r       = randperm(size(mat1,3),num(perm)); % choose indices
                    tmp     = mat1(tp1,tp2,:); % vector of all observed values
                    tmp(r)  = tmp(r)*-1; %flip sign the chosen indices
                    nulldist1(perm) = mean(tmp); % mean the result
                end
                
                % find number of instances the correlation was above observed mean
                pval{1}(tp1,tp2) = length(find(nulldist1 >= meanvec(tp1,tp2))) / permnum;
                
                % convert the null distribution to p-maps
                % find unique values, saves time removes redundancy
                [uniq1, ~,ic1] = unique(nulldist1);
                
                % Sort the null distribution in ascending order
                sortedNull1 = sort(nulldist1);
                
                % Calculate the cumulative sum in reverse to count values greater or equal
                cumCounts1 = flip(cumsum(flip(histcounts(sortedNull1, [-Inf; uniq1]))));
                
                % Normalize by the number of permutations to get the p-values
                tmp = cumCounts1 / permnum;
                
                nd2pmaps{1}(tp1,tp2,:) = tmp(ic1); % get all p-values
                
            else
                nd2pmaps{1}(tp1,tp2,:) = 1;
                pval{1}(tp1,tp2)       = 1;
            end
        end
        tp1
        
    end
    
else
    error('Use fn_labelperm2D for 2 sample tests');
    % tail = 2;
    % if isequal(size(mat1),size(mat2)) ~= 1
    %     error('two groups of different dimensions');
    % end
    % 
    % meanvec1  = squeeze(mean(mat1,3)); % dataset1
    % meanvec2  = squeeze(mean(mat2,3)); % dataset2
    % diffvec1   = meanvec1 - meanvec2;
    % diffvec2   = meanvec2 - meanvec1;
    % nulldist1  = zeros(permnum,1);
    % nulldist2  = zeros(permnum,1);
    % for t = 1:tail
    %     nd2pmaps{t}  = zeros(size(mat1,1),size(mat1,2),permnum);
    %     pval{t}      = zeros(size(mat1,1),size(mat1,2));
    % end
    % for tp1 = 1:size(meanvec1,1)
    % 
    %     for tp2 = 1:size(meanvec1,2)
    %         if diffvec1(tp1,tp2)~=0
    % 
    %             num = randi([1,size(mat1,3)],1,permnum);
    % 
    % 
    %             for perm = 1:permnum
    %                 r       = randperm(size(mat1,3),num(perm)); % choose indices
    %                 tmp1     = squeeze(mat1(tp1,tp2,:)); % vector of all observed values
    %                 tmp1(r)  = tmp1(r)*-1; %flip sign the chosen indices
    % 
    %                 r       = randperm(size(mat2,3),num(perm)); % choose indices
    %                 tmp2     = squeeze(mat2(tp1,tp2,:)); % vector of all observed values
    %                 tmp2(r)  = tmp2(r)*-1; %flip sign the chosen indices
    % 
    %                 nulldist1(perm) = mean(tmp1) - mean(tmp2); % mean and diff
    %                 nulldist2(perm) = mean(tmp2) - mean(tmp1); % mean and diff
    %             end
    % 
    %             % find number of instances the correlation was above observed mean
    % 
    %             pval{1}(tp1,tp2) = length(find(nulldist1 >= diffvec1(tp1,tp2))) / permnum;
    % 
    %             % convert the null distribution to p-maps
    %             % find unique values, saves time removes redundancy
    %             [uniq1, ~,ic1] = unique(nulldist1);
    % 
    %             % Sort the null distribution in ascending order
    %             sortedNull1 = sort(nulldist1);
    % 
    % 
    %             % Calculate the cumulative sum in reverse to count values greater or equal
    %             cumCounts1 = flip(cumsum(flip(histcounts(sortedNull1, [-Inf; uniq1]))));
    % 
    % 
    %             % Normalize by the number of permutations to get the p-values
    %             tmp1 = cumCounts1 / permnum;
    % 
    % 
    %             nd2pmaps{1}(tp1,tp2,:) = tmp1(ic1); % get all p-values
    % 
    %             if tail == 2
    %                 pval{2}(tp1,tp2) = length(find(nulldist2 >= diffvec2(tp1,tp2))) / permnum;
    %                 [uniq2, ~,ic2]   = unique(nulldist2);
    %                 sortedNull2      = sort(nulldist2);
    %                 cumCounts2       = flip(cumsum(flip(histcounts(sortedNull2, [-Inf; uniq2]))));
    %                 tmp2             = cumCounts2 / permnum;
    % 
    %                 nd2pmaps{2}(tp1,tp2,:) = tmp2(ic2); % get all p-values
    %             end
    % 
    %         else
    % 
    %             nd2pmaps{1}(tp1,tp2,:)  = 1;
    %             pval{1}(tp1,tp2)       = 1;
    % 
    %             if tail == 2
    % 
    %                 nd2pmaps{2}(tp1,tp2,:)  = 1;
    %                 pval{2}(tp1,tp2)       = 1;
    %             end
    % 
    %         end
    %     end
    %     tp1
    % 
    % end
    % 
end
%%
for t = 1:tail
    
    % find max cluster in null distribution
    clusterdist=[];sz=[];
    for perm = 1:permnum
        img = nd2pmaps{t}(:,:,perm)<thr;
        cc  = bwconncomp(img,4);
        
        for ii = 1:length(cc.PixelIdxList)
            sz(ii) = size(cc.PixelIdxList{ii},1);
        end
        if isempty(sz)==0
            clusterdist(perm) = max(sz);
        else
            clusterdist(perm) = 0;
        end
    end
    maxcl{t} = prctile(clusterdist,100-cl_alpha);
%     maxcl{t} = max(clusterdist);
    
    % find clusters and size in the original image
    sz=[];
    origimg = pval{t}<thr;
    cc = bwconncomp(origimg,4);
    for ii = 1:length(cc.PixelIdxList)
        sz(ii) = size(cc.PixelIdxList{ii},1);
    end
    
    % find all clusters bigger than maxcl
    sigind = [];
    sigcluster = sz > maxcl{t};
    numcl = find(sigcluster == 1);
    bcgd  = 1:(size(mat1,1)*size(mat1,2));
    bcgd  = reshape(bcgd,[size(mat1,1),size(mat1,2)])';
    for ii = 1:length(numcl)
        sigind(:,:,ii) = ismember(bcgd,cc.PixelIdxList{numcl(ii)});
    end
    
    correctedmask{t} = sum(sigind,3);
end