function fn_svm_decode_libsvm_touch_decoding(param)

% Decoding:
% 1) somatotopic: (21,22,31,32) vs (23,24,33,34)
% 2) external:    (21,22,33,34) vs (23,24,31,32)
% 3) handPos:     (21,22,23,24) vs (31,32,33,34)

%% Paths
deriv   = fullfile(param.parent,'outputs','derivatives');
preproc = fullfile(param.parent,'outputs','preprocess');

%% Define decoding conditions
decode_name = {'somatotopic','external','handPos'};

classA{1} = [21 22 31 32];
classB{1} = [23 24 33 34];

classA{2} = [21 22 33 34];
classB{2} = [23 24 31 32];

classA{3} = [21 22 23 24];
classB{3} = [31 32 33 34];

nDecode = numel(decode_name);

%% Subjects
for sub = param.sub

    clc
    fprintf('Starting subject %03d\n', sub); drawnow;

    %% Load data
    datafile = fullfile(preproc, ['sub-',sprintf('%03d',sub)], ...
        ['sub-',sprintf('%03d',sub),'_preprocessed.mat']);

    fprintf('Loading: %s\n', datafile); drawnow;
    data = load(datafile);

    data.data_ref = data.data_clean;

    %% Downsample
    if ~isempty(param.ds)
        fprintf('Downsampling...\n'); drawnow;
        cfg = [];
        cfg.resamplefs = param.fs / param.ds;
        data.data_ref = ft_resampledata(cfg, data.data_ref);
    end

    %% Select time window
    if ~isempty(param.timewindow)
        fprintf('Selecting time window...\n'); drawnow;
        cfg = [];
        cfg.toilim = param.timewindow;
        data.data_ref = ft_redefinetrial(cfg, data.data_ref);
    end

    %% Basic sizes
    nTime = size(data.data_ref.trial{1}, 2);
    nChan = size(data.data_ref.trial{1}, 1);
    n_tr  = param.pseudo_n;

    %% Output folders
    add = fullfile(deriv, ['sub',sprintf('%03d',sub)], ...
        'binarydecoding_svm_touch_decoding');

    if ~exist(add,'dir')
        mkdir(add);
    end

    dest = fullfile(add, ['iter',num2str(param.n_iterations), ...
        '_pt',num2str(n_tr)]);

    if ~exist(dest,'dir')
        mkdir(dest);
    end

    %% Output arrays
    % decoding condition x time x iteration
    acc_comp_iter = zeros(nDecode, nTime, param.n_iterations);
    auc_comp_iter = zeros(nDecode, nTime, param.n_iterations);

    %% Main decoding loop
    for dc = 1:nDecode

        fprintf('\nDecoding %d/%d: %s\n', dc, nDecode, decode_name{dc});
        fprintf('Class A triggers: %s\n', mat2str(classA{dc}));
        fprintf('Class B triggers: %s\n', mat2str(classB{dc}));
        drawnow;

        for iter = 1:param.n_iterations

            tic
            fprintf('Iteration %d/%d\n', iter, param.n_iterations);
            drawnow;

            %% Make pseudotrials separately for each trigger
            pseudo_A = make_pseudo(data.data_ref, param.pseudo_n, classA{dc});
            pseudo_B = make_pseudo(data.data_ref, param.pseudo_n, classB{dc});

            %% Combine triggers within each class
            pseudo_A_grouped = cat(3, pseudo_A{:});
            pseudo_B_grouped = cat(3, pseudo_B{:});

            %% Reshape to trials x features
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

            sampleindx = 1:nChan:size(data_A,2);

            if sum(target_label == -1) ~= sum(target_label == 1)
                error('Unequal pseudotrials in %s', decode_name{dc});
            end

            acc_time = zeros(1, nTime);
            auc_time = zeros(1, nTime);

            %% Timepoint-by-timepoint decoding
            for time = 1:nTime

                if mod(time,25) == 0
                    fprintf('  Timepoint %d/%d\n', time, nTime);
                    drawnow;
                end

                nFold = length(target_label) / 2;

                acc_fold = zeros(1, nFold);
                auc_fold = zeros(1, nFold);

                for fold = 1:nFold

                    testindx = [fold, nFold + fold];
                    trainindx = ~ismember(indx, testindx);

                    target_train = target_label(trainindx);
                    target_test  = target_label(testindx);

                    samples_train = ds(trainindx, ...
                        sampleindx(time):sampleindx(time)+nChan-1);

                    samples_test = ds(testindx, ...
                        sampleindx(time):sampleindx(time)+nChan-1);

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
                    acc_fold(fold) = mean(predicted_labels == target_test);

                    %% AUC
                    positiveClass = 1;
                    positiveScore = scores(:, model.ClassNames == positiveClass);

                    [~,~,~,auc_fold(fold)] = perfcurve(target_test, positiveScore, positiveClass);

                end

                acc_time(time) = mean(acc_fold);
                auc_time(time) = mean(auc_fold);

            end

            acc_comp_iter(dc,:,iter) = acc_time;
            auc_comp_iter(dc,:,iter) = auc_time;

            fprintf('Finished %s, iteration %d\n', decode_name{dc}, iter);
            toc
            drawnow;

        end
    end

    %% Save
    save(fullfile(dest,'acc_libsvm_touch_decoding.mat'), ...
        'acc_comp_iter', ...
        'auc_comp_iter', ...
        'decode_name', ...
        'classA', ...
        'classB', ...
        'param');

    fprintf('\nSaved results for subject %03d\n', sub);
    drawnow;

end

end