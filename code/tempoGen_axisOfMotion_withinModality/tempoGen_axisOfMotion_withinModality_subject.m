%% Temporal generalization: axis-of-motion decoding within each modality block
%
% Full train-time x test-time generalization matrices for the same binary
% axis-of-motion decoding as mvpa_axisOfMotion_withinModality_subject.m
% (within each of visual / tactile-up / tactile-down blocks), instead of
% just the diagonal (train time == test time). Same trigger grouping:
%   visual:       vertical (up+down) vs horizontal (left+right)
%   tactile up:   finger-wrist vs pinky-thumb
%   tactile down: finger-wrist vs pinky-thumb
%
% Train and test come from the SAME block, so proper cross-validation is
% required (unlike code/tempoGen_crossmodal/, where train/test are
% disjoint domains): leave-one-pseudotrial-out (nFolds = pseudo_n), same
% as mvpa_axisOfMotion_withinModality_subject.m. For each fold, a model
% trained at time t1 is evaluated against the held-out test pseudotrials
% at EVERY time t2, and fold results are averaged.
%
% Cost note: see code/tempoGen_4Dir_withinModality/ for the rationale
% behind param.tgen_step (subsamples the train/test time grid to keep the
% O(nTime^2) cost tractable; does not affect the diagonal-only MVPA
% results in the sibling mvpa_axisOfMotion_withinModality/ folder).
%
% Follows the same conventions as mvpa_axisOfMotion_withinModality_subject.m:
%   - Binary (2-class) classification uses fitcsvm.
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
outDir     = fullfile(projectDir, 'outputs', 'tempoGen_axisOfMotion_withinModality');

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

%% Blocks (2 axis classes each)
blocks = struct();
blocks(1).name = 'visual';
blocks(1).classACodes = [13 14]; blocks(1).classALabel = 'vertical';
blocks(1).classBCodes = [11 12]; blocks(1).classBLabel = 'horizontal';

blocks(2).name = 'tactile_up';
blocks(2).classACodes = [21 22]; blocks(2).classALabel = 'finger_wrist';
blocks(2).classBCodes = [23 24]; blocks(2).classBLabel = 'pinky_thumb';

blocks(3).name = 'tactile_down';
blocks(3).classACodes = [31 32]; blocks(3).classALabel = 'finger_wrist';
blocks(3).classBCodes = [33 34]; blocks(3).classBLabel = 'pinky_thumb';

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== Temporal generalization axis-of-motion: %s ===\n', subDir);
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
        fprintf('  block: %s (%s vs %s)\n', blk.name, blk.classALabel, blk.classBLabel);

        idxA = find(ismember(trig, blk.classACodes));
        idxB = find(ismember(trig, blk.classBCodes));
        classTrials = {cat(3, data_clean.trial{idxA}), cat(3, data_clean.trial{idxB})}; % chan x time x trial

        acc_iter = zeros(param.n_iterations, nTime, nTime);
        auc_iter = zeros(param.n_iterations, nTime, nTime);

        for iter = 1:param.n_iterations

            %% build the per-iteration pseudotrial dataset
            condData = cell(1, 2);
            for c = 1:2
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
            allLabels = repelem([1; 2], classSizes);

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

                    mdl = fitcsvm(Xtrain, ytrain);

                    for t2 = 1:nTime
                        Xtest = dataByTime{t2}(testIdx, :) / scaleVal;
                        [predLabels, score] = predict(mdl, Xtest);

                        acc_mat(t1, t2) = acc_mat(t1, t2) + mean(predLabels == ytest);

                        positiveScore = score(:, mdl.ClassNames == 2);
                        if numel(unique(ytest)) < 2
                            continue
                        end
                        [~, ~, ~, aucVal] = perfcurve(ytest, positiveScore, 2);
                        auc_mat(t1, t2) = auc_mat(t1, t2) + aucVal;
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
        results.(blk.name).classALabel = blk.classALabel;
        results.(blk.name).classBLabel = blk.classBLabel;
    end

    save(fullfile(subOutDir, [subDir '_tempoGen_axisOfMotion.mat']), 'results', 'param', '-v7.3');

    %% diagnostic plot: T x T heatmaps (3 blocks x 2 metrics)
    blockNames = {blocks.name};
    climRange = [0.35 0.65];

    f = figure('Visible', 'off');
    for b = 1:numel(blockNames)
        accMean = squeeze(mean(results.(blockNames{b}).acc, 1));
        aucMean = squeeze(mean(results.(blockNames{b}).auc, 1));
        tv = results.(blockNames{b}).time;

        subplot(numel(blockNames), 2, (b-1)*2 + 1);
        fn_plot_tempoGen_matrix(tv, tv, accMean, climRange, ...
            [strrep(blockNames{b}, '_', ' ') ' - accuracy'], 'Train time (s)', 'Test time (s)');

        subplot(numel(blockNames), 2, (b-1)*2 + 2);
        fn_plot_tempoGen_matrix(tv, tv, aucMean, climRange, ...
            [strrep(blockNames{b}, '_', ' ') ' - AUC'], 'Train time (s)', 'Test time (s)');
    end
    sgtitle([subDir ' - axis-of-motion temporal generalization'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1000 1200]);
    saveas(f, fullfile(subOutDir, [subDir '_tempoGen_axisOfMotion.png']));
    close(f);

    subjectRuntime = toc(tSubject);
    fprintf('%s finished in %.1f s (%.2f min)\n', subDir, subjectRuntime, subjectRuntime/60);

end
