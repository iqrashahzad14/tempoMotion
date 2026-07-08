function fn_svm_decode_libsvm_updated(param)

% Binary decoding using SVM.

%% Paths

outputs = fullfile(param.parent,'outputs');
deriv   = fullfile(param.parent,'outputs','derivatives','mvpa');
preproc = fullfile(param.parent,'outputs','preprocess');

dir_preproc = dir(fullfile(preproc));
names       = {dir_preproc([dir_preproc.isdir]).name};
dir_preproc(ismember(names,{'.','..'})) = [];

%% Binary decoding

for sub = param.sub

    clc

    % load input data
    data = load(fullfile(preproc, ['sub-',sprintf('%03d',sub)], ...
        ['sub-',sprintf('%03d',sub),'_preprocessed.mat']));

    data.data_ref = data.data_clean;

    % downsample
    if ~isempty(param.ds)
        cfg = [];
        cfg.resamplefs = param.fs / param.ds;
        data.data_ref = ft_resampledata(cfg, data.data_ref);
    end

    % extract time window
    if ~isempty(param.timewindow)
        cfg = [];
        cfg.toilim = param.timewindow;
        data.data_ref = ft_redefinetrial(cfg, data.data_ref);
    end

    % number of pseudotrials
    n_tr = param.pseudo_n;

    % make output folders
    add = fullfile(deriv, ['sub',sprintf('%03d',sub)], 'binarydecoding_svm');
    if ~exist(add, 'dir')
        mkdir(add);
    end

    dest = fullfile(add, ['iter',num2str(param.n_iterations), ...
        '_pt',num2str(n_tr)]);
    if ~exist(dest, 'dir')
        mkdir(dest);
    end

    % all pairwise comparisons among 4 classes
    comparison = nchoosek(1:4, 2);

    % prepare output arrays
    nTime = size(data.data_ref.trial{1}, 2);

    acc_comp_iter = zeros(size(comparison,1), nTime, ...
        param.n_iterations, numel(param.condition));

    auc_comp_iter = acc_comp_iter;

    %% condition loop

    for cond = 1:length(param.condition)

        trig = [];

        if strcmp(param.condition{cond}, 'visual')
            trig = 11:14;
        elseif strcmp(param.condition{cond}, 'tactileup')
            trig = 21:24;
        elseif strcmp(param.condition{cond}, 'tactiledown')
            trig = 31:34;
        else
            error('Unknown condition: %s', param.condition{cond});
        end

        %% iteration loop

        for iter = 1:param.n_iterations

            tic
            disp(['Subject ', num2str(sub), ...
                ', condition ', param.condition{cond}, ...
                ', iteration ', num2str(iter)]);

            % make pseudotrials
            pseudo_tr = make_pseudo(data.data_ref, param.pseudo_n, trig);

            % reshape:
            % each class becomes pseudotrials x features
            % features are channel-time concatenated
            dataset_re = cell(1, numel(pseudo_tr));

            for ii = 1:numel(pseudo_tr)
                dataset_re{ii} = reshape(pseudo_tr{ii}, ...
                    [size(pseudo_tr{ii},1) * size(pseudo_tr{ii},2), ...
                    size(pseudo_tr{ii},3)])';
            end

            % prepare result matrices for this iteration
            acc_comp = zeros(size(comparison,1), nTime);
            auc_comp = zeros(size(comparison,1), nTime);

            %% comparison loop

            for comp = 1:size(comparison,1)

                class1 = comparison(comp,1);
                class2 = comparison(comp,2);

                % labels
                target_label = [ones(size(dataset_re{class1},1),1) * -1; ...
                                ones(size(dataset_re{class2},1),1)];

                % dataset for current comparison
                ds = cat(1, dataset_re{class1}, dataset_re{class2});

                indx = 1:length(target_label);

                % feature index for each time point
                nChan = size(data.data_ref.trial{1},1);
                sampleindx = 1:nChan:size(dataset_re{class1},2);

                % check equal number of pseudotrials
                if sum(target_label == -1) ~= sum(target_label == 1)
                    error(['Unequal number of trials in category ', ...
                        num2str(class1), ' and ', num2str(class2)]);
                end

                acc_time = zeros(1, nTime);
                auc_time = zeros(1, nTime);

                %% time-point-wise decoding

                for time = 1:nTime

                    nFolds = length(target_label) / 2;

                    acc_fold = zeros(1, nFolds);
                    auc_fold = zeros(1, nFolds);

                    %% leave-one-pseudotrial-per-class-out CV

                    for fold = 1:nFolds

                        testindx = [fold, nFolds + fold];
                        trainindx = ~ismember(indx, testindx);

                        target_train = target_label(trainindx);
                        target_test  = target_label(testindx);

                        samples_train = ds(trainindx, ...
                            sampleindx(time):sampleindx(time)+nChan-1);

                        samples_test = ds(testindx, ...
                            sampleindx(time):sampleindx(time)+nChan-1);

                        % normalize using training data only
                        scale = max(abs(samples_train(:)));

                        if scale == 0 || isnan(scale)
                            scale = 1;
                        end

                        samples_train = samples_train ./ scale;
                        samples_test  = samples_test ./ scale;

                        % train SVM
                        model = fitcsvm(samples_train, target_train);

                        % predict
                        [predicted_labels, scores] = predict(model, samples_test);

                        % positive-class score
                        positiveClass = 1;
                        positiveScore = scores(:, model.ClassNames == positiveClass);

                        % AUC
                        [~,~,~,auc_fold(fold)] = perfcurve( ...
                            target_test, positiveScore, positiveClass);

                        % accuracy
                        acc_fold(fold) = mean(predicted_labels == target_test);

                    end

                    acc_time(time) = mean(acc_fold);
                    auc_time(time) = mean(auc_fold);

                end

                acc_comp(comp,:) = acc_time;
                auc_comp(comp,:) = auc_time;

            end

            acc_comp_iter(:,:,iter,cond) = acc_comp;
            auc_comp_iter(:,:,iter,cond) = auc_comp;

            disp(['Iteration ', num2str(iter), ' finished']);
            toc

        end

    end

    save(fullfile(dest, 'acc_libsvm.mat'), ...
        'acc_comp_iter', 'auc_comp_iter', 'comparison', 'param');

end

end