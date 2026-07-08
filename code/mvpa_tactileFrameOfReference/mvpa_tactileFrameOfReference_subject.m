%% MVPA: tactile frame-of-reference time-resolved decoding
%
% Investigates the time course of binary decoding between tactile frames
% of reference, pooling trials across BOTH the tactile-up and
% tactile-down blocks (same grouping as code/mvpa_my/fn_svm_decode_libsvm_touch_decoding.m):
%
%   somatotopic : finger-wrist (up+down) vs pinky-thumb (up+down)
%                 -- skin-based grouping, invariant to hand posture
%   external    : externally-defined axis that crosses hand posture
%                 (up-finger-wrist + down-pinky-thumb) vs
%                 (up-pinky-thumb + down-finger-wrist)
%   handPos     : tactile-up (all 4 directions) vs tactile-down (all 4 directions)
%                 -- decodes hand posture itself
%
% Follows the same style as code/mvpa_4Dir_withinModality/ and
% code/mvpa_axisOfMotion_withinModality/, with:
%   - Binary (2-class) classification uses fitcsvm.
%   - Pseudotrial generation is optional (param.usePseudo) with a default
%     of 10 pseudotrials per class (param.pseudo_n = 10). Trials from all
%     directions/blocks making up a class are pooled first, then
%     averaged into pseudotrials.
%   - When using pseudotrials: leave-one-pseudotrial-out cross-validation
%     (nFolds = pseudo_n).
%   - When NOT using pseudotrials (param.usePseudo = false): decode on
%     single trials with stratified 10-fold cross-validation instead.
%   - Downsampling is optional (param.ds) with a default of 2x (256 Hz ->
%     128 Hz).
%   - Steps are repeated for param.n_iterations (default 20) and
%     averaged, to average out the randomness in trial-to-pseudotrial
%     assignment (or in the 10-fold partition, when not using
%     pseudotrials).
%
% For each timepoint: features = channel amplitudes at that timepoint,
% labels = class A (1) / class B (2). Reports classification accuracy and
% AUC at every timepoint, for every subject.
%
% Requires outputs/preprocess/<sub>/<sub>_preprocessed.mat (see
% code/preprocess/preprocess_bandstop45.m).

clear;

%% Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
preprocDir = fullfile(projectDir, 'outputs', 'preprocess');
outDir     = fullfile(projectDir, 'outputs', 'mvpa_tactileFrameOfReference');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};

%% Decoding parameters
param = [];
param.usePseudo    = true;  % true: average trials into pseudotrials before decoding
                             % false: decode on single trials with 10-fold CV instead
param.pseudo_n     = 10;    % number of pseudotrials per class (only used if usePseudo)
param.n_iterations = 20;    % repeat pseudotrial assignment / CV partition this many times
param.ds           = 2;     % downsample factor applied to the (already 256 Hz) preprocessed data; [] to skip
param.fs           = 256;   % sampling rate of the preprocessed data
param.timewindow   = [];    % [] = full epoch, or [begin end] in seconds

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
    fprintf('\n=== MVPA tactile frame-of-reference: %s ===\n', subDir);
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

    trig  = data_clean.trialinfo(:, 1);
    nTime = size(data_clean.trial{1}, 2);
    nChan = size(data_clean.trial{1}, 1);
    timeVec = data_clean.time{1};

    results = struct();

    for d = 1:numel(decodes)
        dc = decodes(d);
        fprintf('  decode: %s (%s vs %s)\n', dc.name, dc.classALabel, dc.classBLabel);

        idxA = find(ismember(trig, dc.classACodes));
        idxB = find(ismember(trig, dc.classBCodes));
        classTrials = {cat(3, data_clean.trial{idxA}), cat(3, data_clean.trial{idxB})}; % chan x time x trial

        acc_iter = zeros(param.n_iterations, nTime);
        auc_iter = zeros(param.n_iterations, nTime);

        for iter = 1:param.n_iterations

            %% build the per-iteration dataset (pseudotrials or raw trials)
            if param.usePseudo
                condData = cell(1, 2);
                for c = 1:2
                    nTr = size(classTrials{c}, 3);
                    nPerGroup = floor(nTr / param.pseudo_n);
                    perm = randperm(nTr, nPerGroup * param.pseudo_n);
                    perm = reshape(perm, [nPerGroup, param.pseudo_n]);

                    avgGroups = nan(nChan, nTime, param.pseudo_n);
                    for g = 1:param.pseudo_n
                        avgGroups(:, :, g) = mean(classTrials{c}(:, :, perm(:, g)), 3);
                    end
                    condData{c} = avgGroups;
                end
                nFolds = param.pseudo_n;
            else
                condData = classTrials;
                nFolds = 10;
            end

            classSizes = cellfun(@(x) size(x, 3), condData);
            allData = cat(3, condData{:}); % chan x time x totalTrials
            allLabels = repelem([1; 2], classSizes);

            if param.usePseudo
                startIdx = [0, cumsum(classSizes(1:end-1))];
                foldTestIdx = arrayfun(@(f) startIdx + f, 1:nFolds, 'UniformOutput', false);
            else
                cvp = cvpartition(allLabels, 'KFold', nFolds);
            end

            acc_time = zeros(1, nTime);
            auc_time = zeros(1, nTime);

            for t = 1:nTime

                X = squeeze(allData(:, t, :))'; % trials x channels
                y = allLabels;

                acc_fold = zeros(1, nFolds);
                auc_fold = zeros(1, nFolds);

                for f = 1:nFolds
                    if param.usePseudo
                        testIdx  = foldTestIdx{f};
                        trainIdx = setdiff(1:size(X, 1), testIdx);
                    else
                        trainIdx = training(cvp, f);
                        testIdx  = test(cvp, f);
                    end

                    Xtrain = X(trainIdx, :); ytrain = y(trainIdx);
                    Xtest  = X(testIdx, :);  ytest  = y(testIdx);

                    % scale by training-set max abs value (no test leakage)
                    scaleVal = max(abs(Xtrain(:)));
                    if scaleVal == 0 || isnan(scaleVal)
                        scaleVal = 1;
                    end
                    Xtrain = Xtrain / scaleVal;
                    Xtest  = Xtest / scaleVal;

                    mdl = fitcsvm(Xtrain, ytrain);
                    [predLabels, score] = predict(mdl, Xtest);

                    acc_fold(f) = mean(predLabels == ytest);

                    positiveScore = score(:, mdl.ClassNames == 2);
                    if numel(unique(ytest)) < 2
                        auc_fold(f) = nan;
                    else
                        [~, ~, ~, auc_fold(f)] = perfcurve(ytest, positiveScore, 2);
                    end
                end

                acc_time(t) = mean(acc_fold);
                auc_time(t) = mean(auc_fold, 'omitnan');
            end

            acc_iter(iter, :) = acc_time;
            auc_iter(iter, :) = auc_time;
        end

        results.(dc.name).acc  = acc_iter; % iteration x time
        results.(dc.name).auc  = auc_iter;
        results.(dc.name).time = timeVec;
        results.(dc.name).classALabel = dc.classALabel;
        results.(dc.name).classBLabel = dc.classBLabel;
    end

    save(fullfile(subOutDir, [subDir '_mvpa_tactileFoR.mat']), 'results', 'param', '-v7.3');

    %% quick diagnostic plot (accuracy & AUC vs time, averaged over iterations)
    f = figure('Visible', 'off');
    decodeNames = {decodes.name};
    for d = 1:numel(decodeNames)
        subplot(numel(decodeNames), 2, (d-1)*2 + 1);
        plot(results.(decodeNames{d}).time, mean(results.(decodeNames{d}).acc, 1), 'LineWidth', 1.5);
        hold on; yline(0.5, 'k--'); xline(0, 'k-');
        xline(-0.01, ':', 'Color', [0.6 0.6 0.6]); xline(0.01, ':', 'Color', [0.6 0.6 0.6]);
        hold off;
        xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('Accuracy');
        title([strrep(decodeNames{d}, '_', ' ') ' - accuracy']);

        subplot(numel(decodeNames), 2, (d-1)*2 + 2);
        plot(results.(decodeNames{d}).time, mean(results.(decodeNames{d}).auc, 1), 'LineWidth', 1.5);
        hold on; yline(0.5, 'k--'); xline(0, 'k-');
        xline(-0.01, ':', 'Color', [0.6 0.6 0.6]); xline(0.01, ':', 'Color', [0.6 0.6 0.6]);
        hold off;
        xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('AUC');
        title([strrep(decodeNames{d}, '_', ' ') ' - AUC']);
    end
    sgtitle([subDir ' - tactile frame-of-reference decoding'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1000 900]);
    saveas(f, fullfile(subOutDir, [subDir '_mvpa_tactileFoR.png']));
    close(f);

    subjectRuntime = toc(tSubject);
    fprintf('%s finished in %.1f s (%.2f min)\n', subDir, subjectRuntime, subjectRuntime/60);

end
