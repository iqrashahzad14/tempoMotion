function fn_svm_decode_libsvm(param)

% Binary decoding using SVM.
% Written by Siddharth Talwar
% Last edited on 26-11-2025

% Inputs -
% 1) param.n_category   : number of categories
% 2) param.timewindow   : [begin end] time in data, [] for all timepoints
% 3) param.fs           : sampling frequency of the dataset
% 4) param.ds           : downsample time by a factor (2,4,8 etc)
% 5) param.n_iterations : number of iterations (from creating pseudotrials
%                         to decoding.
% 6) param.pseudo_k     : number of trials to be averaged to make pseudotr
% 7) param.pseudo_n     : number of pseudotrials reqd for decoding
%                         Put EITHER pseudo_k OR pseudo_n.
% 8) param.popn         : population name / folder name
% 9) param.system       : change paths for different system: monster or pc

% Outputs-
% 1) acc_comp_iter   : computes accuracy of classification between each
%                          comparison. comparison x time x iter
% 2) auc_comp_iter   : computes AUC of classification between each
%                          comparison. comparison x time x iter
% 3) comparison:     : indexed list of all binary comparisons
% 4) param           : input parameters

% NOTES
% - Uses fieldtrip toolbox to perform few functions before deocoding
% - Uses LIBSVM library for decoding
% - All outputs are saved in the derivatives folder, in the corresponding
%   analysis folder and sub-folder for each subject
% - The function uses parallel toolbox. Make sure there are enough workers.
% - Pseudotrials are created using an inbuit function.
% - leave one trial out cross validation implemented.

%% Paths (change)

outputs = fullfile(param.parent,'outputs');
deriv   = fullfile(param.parent,'outputs','derivatives','mvpa');
preproc = fullfile(param.parent,'outputs','preprocess');
dir_preproc = dir(fullfile(preproc));
names       = {dir_preproc([dir_preproc.isdir]).name};
dir_preproc(ismember(names,{'.','..'})) = [];

%% Binary decoding and weights

for sub = param.sub
    
    clc
    % input: load input data
    data = load(fullfile(preproc,['sub-',sprintf('%03d',sub)],...
        [['sub-',sprintf('%03d',sub)],'_preprocessed.mat']));
    
    %setting the variable right
    data.data_ref = data.data_clean ;

    % downsample
    if isempty(param.ds) ~= 1
        cfg=[];
        cfg.resamplefs = param.fs/param.ds;
        data.data_ref = ft_resampledata(cfg,data.data_ref);
    end

    % extract timewindow of interest
    if isempty(param.timewindow) ~= 1
        cfg              = [];
        cfg.toilim       = param.timewindow;
        data.data_ref = ft_redefinetrial(cfg,data.data_ref);
    end

    % num of pseudotrials to name a folder
    if isempty(param.pseudo_n) == 1
        [~,~,n_tr] = make_pseudo(data.data_ref,param.pseudo_k,...
            param.pseudo_n);
    else
        n_tr = param.pseudo_n;
    end

    % make output folders
    add  = fullfile(deriv,['sub',sprintf('%03d',sub)],...
        ['binarydecoding_svm']);
    mkdir(add);

    dest = fullfile(add,['iter',num2str(param.n_iterations),...
        '_pt',num2str(n_tr)]);
    mkdir(dest);

    % compute number of comparisons
    comparison = flip(combnk(1:4,2)); % 4 triggers at a time

    if comparison(1,1)~=1 % make sure the combinations start with the 1st
        comparison = flip(comparison);
    end

    % prepare datasets
    acc_comp_iter = zeros(size(comparison,1),...
        length(1:size(data.data_ref.trial{1},2)),...
        param.n_iterations,numel(param.condition));

    auc_comp_iter = acc_comp_iter;

    % clc
    % disp(['subject num ',num2str(sub)]);

    % iteration parfor loop
    for cond = 1:length(param.condition)
        trig = [];
        if strcmp(param.condition{cond},'visual') == 1
            trig = 11:14;
        elseif strcmp(param.condition{cond},'tactileup') == 1
            trig = 21:24;
        elseif strcmp(param.condition{cond},'tactiledown') == 1
            trig = 31:34;
        end
        
        dataset_re = cell(1,4);
        for iter = 1 : param.n_iterations %parfor
            tic
            disp(['iteration num ' ,num2str(iter)]);

            % Make pseudotrials
            [pseudo_tr] = make_pseudo(data.data_ref,...
                param.pseudo_n,trig);

            % dataset_re = trials x (for timepoint 1 - 128 chan values,
            % then 128 val for next timepoint...)
            
            % reshape dataset
            dataset_re={};
            for ii = 1:numel(pseudo_tr)
                dataset_re{ii} = reshape(pseudo_tr{ii},...
                    [size(pseudo_tr{ii},1)*size(pseudo_tr{ii},2),...
                    size(pseudo_tr{ii},3)] )';
            end

            % prepare datasets
            acc_comp = zeros(size(comparison,1),...
                length(1:size(pseudo_tr{1},2)));

            auc_comp = acc_comp;

            % main loop for each comparison
            for comp = 1 : size(comparison,1)

                % labels of each category
                target_label=[ones(size(dataset_re{comparison(comp)},1),1)*-1;...
                    ones(size(dataset_re{comparison(comp)},1),1)];

                % prepare dataset for C.V. as per current comparison
                ds          = cat(1,dataset_re{comparison(comp,1)},...
                    dataset_re{comparison(comp,2)});
                indx        = 1:length(target_label);
                sampleindx  = 1 : size(data.data_ref.trial{1},1) :...
                    size(dataset_re{comparison(comp)},2);
                targets = [-1; 1];

                % check if number of trials are equal across 2 categories
                if length(target_label==-1) ~= length(target_label==1)
                    error(['Unequal number of trials in category ',...
                        num2str(comparison(comp,1)),...
                        ' and ',num2str(comparison(comp,2))]);
                end

                % make datastructures for plt
                acc_time = zeros(1, 1 : length(size(pseudo_tr{1},2)));
                % acc_time = zeros(1, size(pseudo_tr{1},2)); % IQRA

                auc_time = acc_time;

                % compute for each time point
                jj=1;
                for time = 1 : size(pseudo_tr{1},2)

                    % make datastructures for plt
                    acc_fold = zeros(1,length(target_label)/2);
                    auc_fold = acc_fold;

                    % compute for each fold
                    for fold = 1: length(target_label)/2

                        % prepare training and testing data
                        testindx     = [fold length(target_label)/2+fold];
                        trainindx    = (~ismember(indx,testindx)==1);
                        target_train = target_label(trainindx==1);

                        samples_train = ds(trainindx,...
                            sampleindx(time) :...
                            sampleindx(time)+(size(data.data_ref.trial{1},1)-1));

                        % [samples_train, mu, sigma] = zscore(samples_train);
                        samples_train = (samples_train) ./ max(max(samples_train));
                        
                        samples_test  = ds(testindx,...
                            sampleindx(time):...
                            sampleindx(time)+(size(data.data_ref.trial{1},1)-1));

                        % samples_test = (samples_test - mu) ./ sigma;
                        samples_test = (samples_test) ./ max(max(samples_test));

                        % Train with MATLAB's built-in SVM
                        model = fitcsvm(samples_train, target_train);
                        % model = libsvm(samples_train, target_train);%IQRA

                        % Predict labels and scores on test data
                       [predicted_labels, scores] = predict(model, samples_test);

                        % Use the score for the positive class (label 1)
                        positiveClass = 1;
                        positiveScore = scores(:, model.ClassNames == positiveClass);

                        % Compute AUC with perfcurve
                        [~,~,~,auc_fold(fold)] = perfcurve(targets, positiveScore, positiveClass);

                        % Compute accuracy
                        acc_fold(fold) = mean(predicted_labels == targets);

                    end

                    % get accuracy and weights for each time point
                    acc_time(jj)   = mean(acc_fold); % mean(folds)
                    auc_time(jj)   = mean(auc_fold); % mean(folds)
                    jj=jj+1;
                end

                % get accuracy and weights for each comparison
                acc_comp(comp,:)   = acc_time;
                auc_comp(comp,:)   = auc_time;

            end

            % put each iteration in its place
            acc_comp_iter(:,:,iter,cond) = acc_comp;
            auc_comp_iter(:,:,iter,cond) = auc_comp;

            disp(['Iteration ',num2str(iter),' finished']);
            toc

        end
    end
    save(fullfile(dest,'acc_libsvm.mat'),'acc_comp_iter','auc_comp_iter','comparison','param');

end

end
