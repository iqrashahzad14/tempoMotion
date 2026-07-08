function [pseudo_tr] = make_pseudo(preproc,ps_n,trig)

% this function creates pseudotrials. preproc should be a preprocessed file
% with fieldtrip data structure. Insert EITHER ps_k OR ps_n. ps_k refers to
% the number of trials to be averaged. Example - With 40 trials and
% ps_k = 5, there will be 8 pseudotrials. ps_n refers to the number of
% pseudotrials required invariant to the number of trials. Example - With
% 40 trials and ps_n = 3 will average 13 trials and leave one trial
% randomly out.
%%
% if (isempty(ps_k)==1 && isempty(ps_n)==1) || (isempty(ps_k)==0 && isempty(ps_n)==0)
%     error('enter number of trials to avg OR number of pseudotrials reqd.');
% end

epochs = cell(1, numel(trig));

for k = 1:numel(trig)
    epochs{k} = preproc.trial(preproc.trialinfo == trig(k));
    mintr(k)         = size(epochs{k},3);
end

nLabels = numel(trig);
grouped_avg = cell(1, nLabels);

for li = 1:nLabels
    trials = epochs{li};
    nTrials = numel(trials);
    if nTrials < ps_n
        error('Not enough trials in label %d for %d groups', li, ps_n);
    end

    nPerGroup = floor(nTrials / ps_n);
    totalTrials = nPerGroup * ps_n;
    perm = randperm(nTrials, totalTrials);
    perm = reshape(perm, [nPerGroup, ps_n]);

    trialSize = size(trials{1});          % channels x time
    avgGroups = nan([trialSize, ps_n]);  % channels x time x ps_n

    for g = 1:ps_n
        selected = trials(perm(:, g));
        stacked = cat(3, selected{:});
        avgGroups(:, :, g) = mean(stacked, 3);
    end

    pseudo_tr{li} = avgGroups;
end

%% epoch by condition

% for trig = 1:length(trigger)
%     epochs{trig} = zeros(size(preproc.trial{1},1),size(preproc.trial{1},2),1); % create data structure
% end
% 
% for tr = 1:length(preproc.trial)
%     epochs{trinfo(tr)}(:,:,size(epochs{trinfo(tr)},3)+1) = preproc.trial{tr}; % ep_ds_bl_tr{trigno}(ch x tp x trials)
% end
% 
% for trig = 1:length(uniquetrig)
%     epochs{trig}(:,:,1) = []; % remove the 1st empty dummy trial (because of initializing and +1 in the above step)
%     mintr(trig)         = size(epochs{trig},3);
% end
% 

% %% condition if no avg is required
% if ps_k==1
%     group     = [];
%     pseudo_tr = epochs;
%     n_tr      = [];
%     return
% end
% 
% % condition if num of trials to avg are given
% if isempty(ps_k) == 0
% 
%     mintr = min(mintr);
%     temp  = mod(mintr,ps_k);
% 
%     if temp == 0
%         n_tr = mintr/ps_k;
%     else
%         n_tr = (mintr-temp)/ps_k;
%     end
% end
% 
% % condition if num of pseudotrials reqd are given
% if isempty(ps_n) == 0
% 
%     mintr = min(mintr);
%     temp  = mod(mintr,ps_n);
%     ps_k  = (mintr-temp)/ps_n;
%     temp  = mod(mintr,ps_k);
%     n_tr  = ps_n;
% end
% 
% % choose trials to avg further
% for trig = 1:length(uniquetrig)
%     r = randperm(size(epochs{trig},3),(mintr-temp));
%     if isempty(temp) == 0
%         epochs{trig} = epochs{trig}(:,:,r);
%     end
% end
% 
% % pseudotrials
% pseudo_tr=[];
% for trig = 1:length(uniquetrig)
%     r     = randperm(size(epochs{1},3),size(epochs{1},3)); % create a unique order
%     total_gr = (size(epochs{1},3)/ps_k);
%     group{trig} = zeros(total_gr,ps_k); % create groups of n
% 
%     temp = mod(size(epochs{1},3),ps_k);
% 
%     if mod(temp,ps_k)~=0
%         error('Enter n to divide all trials equally');
%     else
% 
%         ps_tr=1; %reset group counter
%         for num_group = 1:total_gr
% 
%             temp  = randperm(length(r),ps_k); %choose random n indices
%             group{trig}(num_group,:) = r(temp); %make a group of values of those indices
%             r(temp) = []; %remove the used values
% 
%             pseudo_tr{trig}(:,:,ps_tr) = mean(epochs{trig}(:,:,group{trig}(num_group,:)),3); %mean of the grouped trials
%             ps_tr = ps_tr+1; %next group
%         end
%     end
% end
% 
end
