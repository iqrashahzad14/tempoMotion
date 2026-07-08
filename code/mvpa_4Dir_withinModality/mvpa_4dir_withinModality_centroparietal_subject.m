%% MVPA: 4-direction time-resolved decoding within each modality block
%
% Investigates the time course of 4-class decoding (all 4 directions at
% once, within each of visual / tactile-up / tactile-down blocks) for
% each subject. Follows the same overall style as the legacy pipeline in
% code/mvpa_my/ (pseudotrials -> per-timepoint decoding -> repeat over
% iterations -> average), with these changes:
%
%   - 4-class classification uses fitcecoc (error-correcting output
%     codes); binary classification elsewhere in this project's MVPA
%     scripts should use fitcsvm.
%   - Pseudotrial generation is optional (param.usePseudo) with a default
%     of 10 pseudotrials per class (param.pseudo_n = 10).
%   - When using pseudotrials: leave-one-pseudotrial-out cross-validation
%     (nFolds = pseudo_n).
%   - When NOT using pseudotrials (param.usePseudo = false): decode on
%     single trials with stratified 10-fold cross-validation instead.
%   - Downsampling is optional (param.ds) with a default of 2x (256 Hz ->
%     128 Hz) to keep runtime manageable.
%   - Steps (pseudotrial assignment / fold partitioning through decoding)
%     are repeated for param.n_iterations (default 20) and averaged, to
%     average out the randomness in trial-to-pseudotrial assignment (or
%     in the 10-fold partition, when not using pseudotrials).
%
% For each timepoint: features = channel amplitudes at that timepoint,
% labels = 1-4 (direction identity). Reports classification accuracy and
% macro-averaged one-vs-rest AUC (averaged across the 4 classes) at every
% timepoint, for every subject.
%
% Requires outputs/preprocess/<sub>/<sub>_preprocessed.mat (see
% code/preprocess/preprocess_bandstop45.m).

% ROI-restricted variant: decoding uses only the centroparietal channel subset
% instead of all 128 channels (see roiChans below). Otherwise identical to
% the all-channels version in this folder.

clear;

%% Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
preprocDir = fullfile(projectDir, 'outputs', 'preprocess');
outDir     = fullfile(projectDir, 'outputs', 'mvpa_4Dir_withinModality', 'centroparietal');

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

%% ROI channels (derived from biosemi128.lay coordinates; see code/erp/erp_subject.m)
roiChans = {'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9', 'A16', 'A17', 'A18', 'A19', 'A20', 'A21', 'A29', 'A30', 'A31', 'A32', 'B3', 'B4', 'B5', 'B6'};

%% Blocks (4 directions each)
blocks = struct();
blocks(1).name = 'visual';       blocks(1).trig = [11 12 13 14];
blocks(2).name = 'tactile_up';   blocks(2).trig = [21 22 23 24];
blocks(3).name = 'tactile_down'; blocks(3).trig = [31 32 33 34];

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== MVPA 4-direction: %s ===\n', subDir);
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

    %% restrict to ROI channels
    cfg = [];
    cfg.channel = roiChans;
    data_clean = ft_selectdata(cfg, data_clean);

    trig  = data_clean.trialinfo(:, 1);
    nTime = size(data_clean.trial{1}, 2);
    nChan = size(data_clean.trial{1}, 1);
    timeVec = data_clean.time{1};

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

        acc_iter = zeros(param.n_iterations, nTime);
        auc_iter = zeros(param.n_iterations, nTime);

        for iter = 1:param.n_iterations

            %% build the per-iteration dataset (pseudotrials or raw trials)
            if param.usePseudo
                condData = cell(1, 4);
                for c = 1:4
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
            allLabels = repelem((1:4)', classSizes);

            if param.usePseudo
                % leave-one-pseudotrial-out: fold f = the f-th pseudotrial
                % of every class
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

                    mdl = fitcecoc(Xtrain, ytrain);
                    [predLabels, negLoss] = predict(mdl, Xtest);

                    acc_fold(f) = mean(predLabels == ytest);

                    % macro one-vs-rest AUC across the 4 classes
                    aucPerClass = nan(1, 4);
                    for c = 1:4
                        binaryTest = double(ytest == c);
                        if numel(unique(binaryTest)) < 2
                            continue
                        end
                        [~, ~, ~, aucPerClass(c)] = perfcurve(binaryTest, negLoss(:, c), 1);
                    end
                    auc_fold(f) = mean(aucPerClass, 'omitnan');
                end

                acc_time(t) = mean(acc_fold);
                auc_time(t) = mean(auc_fold);
            end

            acc_iter(iter, :) = acc_time;
            auc_iter(iter, :) = auc_time;
        end

        results.(blk.name).acc  = acc_iter; % iteration x time
        results.(blk.name).auc  = auc_iter;
        results.(blk.name).time = timeVec;
    end

    save(fullfile(subOutDir, [subDir '_mvpa_4dir_centroparietal.mat']), 'results', 'param', '-v7.3');

    %% quick diagnostic plot (accuracy & AUC vs time, averaged over iterations)
    f = figure('Visible', 'off');
    blockNames = {blocks.name};
    for b = 1:numel(blockNames)
        subplot(numel(blockNames), 2, (b-1)*2 + 1);
        plot(results.(blockNames{b}).time, mean(results.(blockNames{b}).acc, 1), 'LineWidth', 1.5);
        hold on; yline(0.25, 'k--'); xline(0, 'k-'); hold off;
        ylim([0.10 0.40]); xlabel('Time (s)'); ylabel('Accuracy');
        title([strrep(blockNames{b}, '_', ' ') ' - accuracy']);

        subplot(numel(blockNames), 2, (b-1)*2 + 2);
        plot(results.(blockNames{b}).time, mean(results.(blockNames{b}).auc, 1), 'LineWidth', 1.5);
        hold on; yline(0.5, 'k--'); xline(0, 'k-'); hold off;
        ylim([0.35 0.65]); xlabel('Time (s)'); ylabel('AUC (macro)');
        title([strrep(blockNames{b}, '_', ' ') ' - AUC']);
    end
    sgtitle([subDir ' - 4-direction decoding (centroparietal)'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1000 900]);
    saveas(f, fullfile(subOutDir, [subDir '_mvpa_4dir_centroparietal.png']));
    close(f);

    subjectRuntime = toc(tSubject);
    fprintf('%s finished in %.1f s (%.2f min)\n', subDir, subjectRuntime, subjectRuntime/60);

end
