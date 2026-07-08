function fn_svm_decode_libsvm_grouped(param)

% Binary decoding using SVM.
% Classification: triggers 1&2 vs 3&4 within each condition
% visual:       (11,12) vs (13,14)
% tactileup:    (21,22) vs (23,24)
% tactiledown:  (31,32) vs (33,34)

%% Paths
deriv   = fullfile(param.parent,'outputs','derivatives');
preproc = fullfile(param.parent,'outputs','preprocess');

%% Binary decoding
for sub = param.sub

    clc
    fprintf('Starting subject %d\n', sub); drawnow;

    %% Load data
    fprintf('Loading data...\n'); drawnow;

    data = load(fullfile(preproc, ['sub-',sprintf('%03d',sub)], ...
        ['sub-',sprintf('%03d',sub),'_preprocessed.mat']));

    fprintf('Loaded data.\n'); drawnow;

    data.data_ref = data.data_clean;

    %% Downsample
    if ~isempty(param.ds)
        fprintf('Downsampling...\n'); drawnow;
        cfg = [];
        cfg.resamplefs = param.fs / param.ds;
        data.data_ref = ft_resampledata(cfg, data.data_ref);
        fprintf('Downsampling done.\n'); drawnow;
    end

    %% Time window
    if ~isempty(param.timewindow)
        fprintf('Selecting time window...\n'); drawnow;
        cfg = [];
        cfg.toilim = param.timewindow;
        data.data_ref = ft_redefinetrial(cfg, data.data_ref);
        fprintf('Time window done.\n'); drawnow;
    end

    %% Number of pseudotrials
    n_tr = param.pseudo_n;

    %% Output folders
    add = fullfile(deriv, ['sub',sprintf('%03d',sub)], ...
        'binarydecoding_svm_grouped');
    if ~exist(add,'dir')
        mkdir(add);
    end

    dest = fullfile(add, ['iter',num2str(param.n_iterations), ...
        '_pt',num2str(n_tr)]);
    if ~exist(dest,'dir')
        mkdir(dest);
    end

    %% Output arrays
    nTime = size(data.data_ref.trial{1}, 2);

    acc_comp_iter = zeros(1, nTime, param.n_iterations, numel(param.condition));
    auc_comp_iter = zeros(1, nTime, param.n_iterations, numel(param.condition));

    fprintf('Subject %d ready.\n', sub); drawnow;

    %% Loop over conditions
    for cond = 1:length(param.condition)

        fprintf('\nCondition %d/%d: %s\n', ...
            cond, length(param.condition), param.condition{cond});
        drawnow;

        if strcmp(param.condition{cond}, 'visual')
            trig = 11:14;
        elseif strcmp(param.condition{cond}, 'tactileup')
            trig = 21:24;
        elseif strcmp(param.condition{cond}, 'tactiledown')
            trig = 31:34;
        else
            error('Unknown condition: %s', param.condition{cond});
        end

        % Class split
        trig_classA = trig(1:2);  % e.g. 11,12
        trig_classB = trig(3:4);  % e.g. 13,14

        %% Iterations
        for iter = 1:param.n_iterations

            tic
            fprintf('Iteration %d/%d\n', iter, param.n_iterations);
            drawnow;

            %% Make pseudotrials separately for each trigger in each class
            pseudo_A = make_pseudo(data.data_ref, param.pseudo_n, trig_classA);
            pseudo_B = make_pseudo(data.data_ref, param.pseudo_n, trig_classB);

            %% Combine triggers within class
            % pseudo_A{1} = trigger 11, pseudo_A{2} = trigger 12
            % pseudo_B{1} = trigger 13, pseudo_B{2} = trigger 14
            pseudo_A_grouped = cat(3, pseudo_A{:});
            pseudo_B_grouped = cat(3, pseudo_B{:});

            %% Reshape: trials x features
            data_A = reshape(pseudo_A_grouped, ...
                [size(pseudo_A_grouped,1) * size(pseudo_A_grouped,2), ...
                 size(pseudo_A_grouped,3)])';

            data_B = reshape(pseudo_B_grouped, ...
                [size(pseudo_B_grouped,1) * size(pseudo_B_grouped,2), ...
                 size(pseudo_B_grouped,3)])';

            %% Labels
            target_label = [ones(size(data_A,1),1) * -1; ...
                            ones(size(data_B,1),1)];

            ds = cat(1, data_A, data_B);
            indx = 1:length(target_label);

            sampleindx = 1:size(data.data_ref.trial{1},1):size(data_A,2);

            if sum(target_label == -1) ~= sum(target_label == 1)
                error('Unequal number of pseudotrials between class A and class B');
            end

            acc_time = zeros(1, nTime);
            auc_time = zeros(1, nTime);

            %% Decode each time point
            for time = 1:nTime

                if mod(time,25) == 0
                    fprintf('  Timepoint %d/%d\n', time, nTime);
                    drawnow;
                end

                acc_fold = zeros(1, length(target_label)/2);
                auc_fold = zeros(1, length(target_label)/2);

                for fold = 1:length(target_label)/2

                    testindx = [fold, length(target_label)/2 + fold];
                    trainindx = ~ismember(indx, testindx);

                    target_train = target_label(trainindx);

                    samples_train = ds(trainindx, ...
                        sampleindx(time):sampleindx(time)+size(data.data_ref.trial{1},1)-1);

                    samples_test = ds(testindx, ...
                        sampleindx(time):sampleindx(time)+size(data.data_ref.trial{1},1)-1);

                    %% Scale using training data only
                    scaleVal = max(abs(samples_train(:)));
                    if scaleVal == 0
                        scaleVal = 1;
                    end

                    samples_train = samples_train ./ scaleVal;
                    samples_test  = samples_test ./ scaleVal;

                    %% Train SVM
                    model = fitcsvm(samples_train, target_train);

                    %% Predict
                    [predicted_labels, scores] = predict(model, samples_test);

                    %% Accuracy
                    target_test = target_label(testindx);
                    acc_fold(fold) = mean(predicted_labels == target_test);

                    %% AUC
                    positiveClass = 1;
                    positiveScore = scores(:, model.ClassNames == positiveClass);

                    [~,~,~,auc_fold(fold)] = perfcurve(target_test, positiveScore, positiveClass);

                end

                acc_time(time) = mean(acc_fold);
                auc_time(time) = mean(auc_fold);

            end

            acc_comp_iter(1,:,iter,cond) = acc_time;
            auc_comp_iter(1,:,iter,cond) = auc_time;

            fprintf('Iteration %d finished.\n', iter);
            toc
            drawnow;

        end
    end

    %% Save
    save(fullfile(dest,'acc_libsvm_grouped.mat'), ...
        'acc_comp_iter', 'auc_comp_iter', 'param');

    fprintf('Saved results for subject %d\n', sub); drawnow;

end

end