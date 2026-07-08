%% Temporal generalization: 4-direction decoding within each modality block
%
% Full train-time x test-time generalization matrices for the same
% 4-class decoding as mvpa_4dir_withinModality_subject.m (all 4 directions
% at once, within each of visual / tactile-up / tactile-down blocks),
% instead of just the diagonal (train time == test time).
%
% Unlike code/tempoGen_crossmodal/ (train/test come from disjoint
% domains, so no CV fold is needed), train and test here come from the
% SAME block, so proper cross-validation is required to avoid circularity:
% leave-one-pseudotrial-out (nFolds = pseudo_n), same as
% mvpa_4dir_withinModality_subject.m. For each fold, a model trained at
% time t1 (on the training pseudotrials) is evaluated against the held-out
% test pseudotrials at EVERY time t2 (not just t1), and fold results are
% averaged.
%
% Cost note: this is O(nTime^2) per fold/iteration/block instead of
% O(nTime) for the diagonal-only version, which makes the naive full time
% resolution prohibitively expensive (~3 hours/subject, estimated
% empirically). To keep this tractable, the train/test time grid for the
% generalization matrix is subsampled by param.tgen_step (default 4,
% i.e. ~31 ms steps at the 128 Hz post-downsampling rate) -- this is
% standard practice for temporal generalization matrices (c.f. King &
% Dehaene 2014) and does not affect the diagonal MVPA results in the
% sibling mvpa_4Dir_withinModality/ folder, which keep full time
% resolution.
%
% Follows the same conventions as mvpa_4dir_withinModality_subject.m:
%   - 4-class classification uses fitcecoc.
%   - Pseudotrial generation is optional (param.usePseudo) with a default
%     of 10 pseudotrials per class (param.pseudo_n = 10).
%   - Downsampling is optional (param.ds) with a default of 2x (256 Hz ->
%     128 Hz).
%   - Steps are repeated for param.n_iterations (default 20) and averaged.
%
% Requires outputs/preprocess/<sub>/<sub>_preprocessed.mat (see
% code/preprocess/preprocess_bandstop45.m).

clear;

%% Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
preprocDir = fullfile(projectDir, 'outputs', 'preprocess');
outDir     = fullfile(projectDir, 'outputs', 'tempoGen_4Dir_withinModality');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};

%% Decoding parameters
param = [];
param.usePseudo    = true;  % true: average trials into pseudotrials before decoding
param.pseudo_n     = 10;    % number of pseudotrials per class
param.n_iterations = 20;    % repeat pseudotrial assignment / fold partition this many times
param.ds           = 2;     % downsample factor applied to the (already 256 Hz) preprocessed data; [] to skip
param.fs           = 256;   % sampling rate of the preprocessed data
param.timewindow   = [];    % [] = full epoch, or [begin end] in seconds
param.tgen_step    = 4;     % subsampling factor for the train/test time grid (cost control, see header note)

%% Blocks (4 directions each)
blocks = struct();
blocks(1).name = 'visual';       blocks(1).trig = [11 12 13 14];
blocks(2).name = 'tactile_up';   blocks(2).trig = [21 22 23 24];
blocks(3).name = 'tactile_down'; blocks(3).trig = [31 32 33 34];

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== Temporal generalization 4-direction: %s ===\n', subDir);
    tSubject = tic;

    subOutDir = fullfile(outDir, subDir);
    if ~exist(subOutDir, 'dir')
        mkdir(subOutDir);
    end

    loaded = load(fullfile(preprocDir, subDir, [subDir '_preprocessed.mat']), 'data_clean');
    data_clean = loaded.data_clean;

    %% downsample
    if ~isempty(param.ds)
        cfg = [];
        cfg.resamplefs = param.fs / param.ds;
        data_clean = ft_resampledata(cfg, data_clean);
    end

    %% time window
    if ~isempty(param.timewindow)
        cfg = [];
        cfg.toilim = param.timewindow;
        data_clean = ft_redefinetrial(cfg, data_clean);
    end

    trig     = data_clean.trialinfo(:, 1);
    nTimeAll = size(data_clean.trial{1}, 2);
    nChan    = size(data_clean.trial{1}, 1);
    timeVecAll = data_clean.time{1};

    gridIdx = 1:param.tgen_step:nTimeAll;
    nTime   = numel(gridIdx);
    timeVec = timeVecAll(gridIdx);

    results = struct();

    for b = 1:numel(blocks)
        blk = blocks(b);
        fprintf('  block: %s\n', blk.name);

        % raw single trials per class, extracted once per block
        classTrials = cell(1, 4);
        for c = 1:4
            idx = find(trig == blk.trig(c));
            classTrials{c} = cat(3, data_clean.trial{idx}); % chan x time x trial
        end

        acc_iter = zeros(param.n_iterations, nTime, nTime);
        auc_iter = zeros(param.n_iterations, nTime, nTime);

        for iter = 1:param.n_iterations

            %% build the per-iteration pseudotrial dataset
            condData = cell(1, 4);
            for c = 1:4
                nTr = size(classTrials{c}, 3);
                nPerGroup = floor(nTr / param.pseudo_n);
                perm = randperm(nTr, nPerGroup * param.pseudo_n);
                perm = reshape(perm, [nPerGroup, param.pseudo_n]);

                avgGroups = nan(nChan, nTimeAll, param.pseudo_n);
                for g = 1:param.pseudo_n
                    avgGroups(:, :, g) = mean(classTrials{c}(:, :, perm(:, g)), 3);
                end
                condData{c} = avgGroups;
            end
            nFolds = param.pseudo_n;

            classSizes = cellfun(@(x) size(x, 3), condData);
            allData = cat(3, condData{:}); % chan x time x totalTrials
            allLabels = repelem((1:4)', classSizes);

            % leave-one-pseudotrial-out: fold f = the f-th pseudotrial of every class
            startIdx = [0, cumsum(classSizes(1:end-1))];
            foldTestIdx = arrayfun(@(f) startIdx + f, 1:nFolds, 'UniformOutput', false);

            % pre-extract each grid timepoint's feature matrix once
            dataByTime = cell(1, nTime);
            for gi = 1:nTime
                dataByTime{gi} = squeeze(allData(:, gridIdx(gi), :))'; % trials x channels
            end

            acc_mat = zeros(nTime, nTime);
            auc_mat = zeros(nTime, nTime);

            for f = 1:nFolds
                testIdx  = foldTestIdx{f};
                trainIdx = setdiff(1:size(allData, 3), testIdx);
                ytrain = allLabels(trainIdx);
                ytest  = allLabels(testIdx); % always exactly 1 sample per class

                for t1 = 1:nTime

                    Xtrain = dataByTime{t1}(trainIdx, :);
                    scaleVal = max(abs(Xtrain(:)));
                    if scaleVal == 0 || isnan(scaleVal)
                        scaleVal = 1;
                    end
                    Xtrain = Xtrain / scaleVal;

                    mdl = fitcecoc(Xtrain, ytrain);

                    for t2 = 1:nTime
                        Xtest = dataByTime{t2}(testIdx, :) / scaleVal;
                        [predLabels, negLoss] = predict(mdl, Xtest);

                        acc_mat(t1, t2) = acc_mat(t1, t2) + mean(predLabels == ytest);

                        % macro one-vs-rest AUC across the 4 classes
                        aucPerClass = nan(1, 4);
                        for c = 1:4
                            binaryTest = double(ytest == c);
                            if numel(unique(binaryTest)) < 2
                                continue
                            end
                            [~, ~, ~, aucPerClass(c)] = perfcurve(binaryTest, negLoss(:, c), 1);
                        end
                        auc_mat(t1, t2) = auc_mat(t1, t2) + mean(aucPerClass, 'omitnan');
                    end
                end
            end

            acc_iter(iter, :, :) = acc_mat / nFolds;
            auc_iter(iter, :, :) = auc_mat / nFolds;

            fprintf('    iteration %d/%d done\n', iter, param.n_iterations);
        end

        results.(blk.name).acc  = acc_iter; % iteration x t1 x t2
        results.(blk.name).auc  = auc_iter;
        results.(blk.name).time = timeVec;
    end

    save(fullfile(subOutDir, [subDir '_tempoGen_4dir.mat']), 'results', 'param', '-v7.3');

    %% diagnostic plot: T x T heatmaps (3 blocks x 2 metrics)
    blockNames = {blocks.name};
    climRangeAcc = [0.10 0.40];
    climRangeAuc = [0.35 0.65];

    f = figure('Visible', 'off');
    for b = 1:numel(blockNames)
        accMean = squeeze(mean(results.(blockNames{b}).acc, 1));
        aucMean = squeeze(mean(results.(blockNames{b}).auc, 1));
        tv = results.(blockNames{b}).time;

        subplot(numel(blockNames), 2, (b-1)*2 + 1);
        fn_plot_tempoGen_matrix(tv, tv, accMean, climRangeAcc, ...
            [strrep(blockNames{b}, '_', ' ') ' - accuracy'], 'Train time (s)', 'Test time (s)');

        subplot(numel(blockNames), 2, (b-1)*2 + 2);
        fn_plot_tempoGen_matrix(tv, tv, aucMean, climRangeAuc, ...
            [strrep(blockNames{b}, '_', ' ') ' - AUC (macro)'], 'Train time (s)', 'Test time (s)');
    end
    sgtitle([subDir ' - 4-direction temporal generalization'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1000 1200]);
    saveas(f, fullfile(subOutDir, [subDir '_tempoGen_4dir.png']));
    close(f);

    subjectRuntime = toc(tSubject);
    fprintf('%s finished in %.1f s (%.2f min)\n', subDir, subjectRuntime, subjectRuntime/60);

end
