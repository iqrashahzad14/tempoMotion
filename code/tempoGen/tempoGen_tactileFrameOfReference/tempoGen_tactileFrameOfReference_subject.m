%% Temporal generalization: tactile frame-of-reference decoding
%
% Full train-time x test-time generalization matrices for the same binary
% tactile frame-of-reference decoding as
% mvpa_tactileFrameOfReference_subject.m, pooling trials across BOTH the
% tactile-up and tactile-down blocks:
%
%   somatotopic : finger-wrist (up+down) vs pinky-thumb (up+down)
%   external    : (up-finger-wrist + down-pinky-thumb) vs
%                 (up-pinky-thumb + down-finger-wrist)
%   handPos     : tactile-up (all 4 directions) vs tactile-down (all 4 directions)
%
% Train and test come from the SAME decode, so proper cross-validation is
% required (unlike code/tempoGen/tempoGen_crossmodal/, where train/test are
% disjoint domains): leave-one-pseudotrial-out (nFolds = pseudo_n), same
% as mvpa_tactileFrameOfReference_subject.m. For each fold, a model
% trained at time t1 is evaluated against the held-out test pseudotrials
% at EVERY time t2, and fold results are averaged.
%
% Cost note: see code/tempoGen/tempoGen_4Dir_withinModality/ for the rationale
% behind param.tgen_step (subsamples the train/test time grid to keep the
% O(nTime^2) cost tractable; does not affect the diagonal-only MVPA
% results in the sibling mvpa_tactileFrameOfReference/ folder).
%
% Follows the same conventions as mvpa_tactileFrameOfReference_subject.m:
%   - Binary (2-class) classification uses fitcsvm.
%   - Pseudotrial generation is optional (param.usePseudo) with a default
%     of 10 pseudotrials per class (param.pseudo_n = 10).
%   - Downsampling is optional (param.ds) with a default of 2x (256 Hz ->
%     128 Hz).
%   - Steps are repeated for param.n_iterations (default 20) and averaged.
%
% Requires outputs/derivatives/preprocess/<sub>/<sub>_preprocessed.mat (see
% code/preprocess/preprocess_bandstop45.m).

clear;

%% Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
preprocDir = fullfile(projectDir, 'outputs', 'derivatives', 'preprocess');
outDir     = fullfile(projectDir, 'outputs', 'derivatives', 'tempoGen', 'tempoGen_tactileFrameOfReference');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006', ...
            'sub-007', 'sub-008', 'sub-009', 'sub-010', 'sub-011', 'sub-012', ...
            'sub-014'};  % N=13 (2026-10-22); sub-013, sub-015 still to be preprocessed
% subjects can be set from the shell (TG_SUBJECTS=sub-007,sub-008) so that
% subjects run in parallel MATLAB processes
if ~isempty(getenv('TG_SUBJECTS'))
    subjects = strsplit(getenv('TG_SUBJECTS'), ',');
end


%% Decoding parameters
param = [];
param.usePseudo    = true;  % true: average trials into pseudotrials before decoding
param.pseudo_n     = 10;    % number of pseudotrials per class
param.n_iterations = 20;    % repeat pseudotrial assignment / fold partition this many times
param.ds           = 2;     % downsample factor applied to the (already 256 Hz) preprocessed data; [] to skip
param.fs           = 256;   % sampling rate of the preprocessed data
param.timewindow   = [];    % [] = full epoch, or [begin end] in seconds
param.tgen_step    = 4;     % subsampling factor for the train/test time grid (cost control, see header note)

%% Decoding conditions (2 classes each, pooling across tactile_up + tactile_down)
decodes = struct();
decodes(1).name = 'somatotopic';
decodes(1).classACodes = [21 22 31 32]; decodes(1).classALabel = 'finger_wrist';
decodes(1).classBCodes = [23 24 33 34]; decodes(1).classBLabel = 'pinky_thumb';

decodes(2).name = 'external';
decodes(2).classACodes = [21 22 33 34]; decodes(2).classALabel = 'up_fingerwrist_down_pinkythumb';
decodes(2).classBCodes = [23 24 31 32]; decodes(2).classBLabel = 'up_pinkythumb_down_fingerwrist';

decodes(3).name = 'handPos';
decodes(3).classACodes = [21 22 23 24]; decodes(3).classALabel = 'tactile_up';
decodes(3).classBCodes = [31 32 33 34]; decodes(3).classBLabel = 'tactile_down';

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== Temporal generalization tactile frame-of-reference: %s ===\n', subDir);
    tSubject = tic;

    subOutDir = fullfile(outDir, subDir);
    resultFile = fullfile(subOutDir, [subDir '_tempoGen_tactileFoR.mat']);

    % never redo or overwrite a subject that is already decoded
    if exist(resultFile, 'file')
        fprintf('%s already decoded (%s) - skipping.\n', subDir, resultFile);
        continue
    end
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

    for d = 1:numel(decodes)
        dc = decodes(d);
        fprintf('  decode: %s (%s vs %s)\n', dc.name, dc.classALabel, dc.classBLabel);

        idxA = find(ismember(trig, dc.classACodes));
        idxB = find(ismember(trig, dc.classBCodes));
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

        results.(dc.name).acc  = acc_iter; % iteration x t1 x t2
        results.(dc.name).auc  = auc_iter;
        results.(dc.name).time = timeVec;
        results.(dc.name).classALabel = dc.classALabel;
        results.(dc.name).classBLabel = dc.classBLabel;
    end

    save(resultFile, 'results', 'param', '-v7.3');

    %% diagnostic plot: T x T heatmaps (3 decodes x 2 metrics)
    decodeNames = {decodes.name};
    climRange = [0.35 0.65];

    f = figure('Visible', 'off');
    for d = 1:numel(decodeNames)
        accMean = squeeze(mean(results.(decodeNames{d}).acc, 1));
        aucMean = squeeze(mean(results.(decodeNames{d}).auc, 1));
        tv = results.(decodeNames{d}).time;

        subplot(numel(decodeNames), 2, (d-1)*2 + 1);
        fn_plot_tempoGen_matrix(tv, tv, accMean, climRange, ...
            [strrep(decodeNames{d}, '_', ' ') ' - accuracy'], 'Train time (s)', 'Test time (s)');

        subplot(numel(decodeNames), 2, (d-1)*2 + 2);
        fn_plot_tempoGen_matrix(tv, tv, aucMean, climRange, ...
            [strrep(decodeNames{d}, '_', ' ') ' - AUC'], 'Train time (s)', 'Test time (s)');
    end
    sgtitle([subDir ' - tactile frame-of-reference temporal generalization'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1000 1200]);
    saveas(f, fullfile(subOutDir, [subDir '_tempoGen_tactileFoR.png']));
    close(f);

    subjectRuntime = toc(tSubject);
    fprintf('%s finished in %.1f s (%.2f min)\n', subDir, subjectRuntime, subjectRuntime/60);

end
