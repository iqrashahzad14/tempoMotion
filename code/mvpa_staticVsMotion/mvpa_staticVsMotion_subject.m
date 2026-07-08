%% MVPA: static-vs-motion time-resolved decoding - per subject
%
% For each of the 2 modality blocks (visual, tactile), decodes:
%   a) each individual motion direction vs. static (4 binary decodes/block)
%   b) all 4 directions pooled ("motion") vs. static (1 binary decode/block)
% i.e. 5 decodes per block, 10 total.
%
% Trigger codes (confirmed directly from the raw event channel; matches
% inputs/references/tempoMotion_studyDesign.docx section 1.3):
%   visual:  11 left, 12 right, 13 up, 14 down, 17 static
%   tactile: 21 wrist->finger, 22 finger->wrist, 23 pinky->thumb, 24 thumb->pinky, 27 static
%
% Only sub-001 and sub-006 are included: sub-004's static.bdf recording
% has no usable stimulus triggers (see
% code/preprocess_staticVsMotion/preprocess_staticVsMotion.m header) and
% no alternate/backup file exists. N=2 - treat as exploratory/
% supplementary given the small sample.
%
% Follows the same conventions as the other mvpa_* scripts in this
% project:
%   - Binary (2-class) classification uses fitcsvm.
%   - Pseudotrial generation is optional (param.usePseudo) with a default
%     of 10 pseudotrials per class (param.pseudo_n = 10).
%   - When using pseudotrials: leave-one-pseudotrial-out cross-validation
%     (nFolds = pseudo_n).
%   - Downsampling is optional (param.ds) with a default of 2x (256 Hz ->
%     128 Hz).
%   - Steps are repeated for param.n_iterations (default 20) and
%     averaged, to average out the randomness in trial-to-pseudotrial
%     assignment.
%
% NOTE: this supplementary session has far fewer trials per condition
% (~35-40) than the main experiment (~350/direction), so each pseudotrial
% averages only ~3-4 raw trials - noisier than the main-experiment
% analyses, an inherent limitation of the smaller session, not a bug.
%
% For each timepoint: features = channel amplitudes at that timepoint,
% labels = class A (1, motion) / class B (2, static). Reports
% classification accuracy and AUC at every timepoint, for every subject.
%
% Requires outputs/preprocess_staticVsMotion/<sub>/<sub>_preprocessed.mat
% (see code/preprocess_staticVsMotion/preprocess_staticVsMotion.m).

clear;

%% Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
preprocDir = fullfile(projectDir, 'outputs', 'preprocess_staticVsMotion');
outDir     = fullfile(projectDir, 'outputs', 'mvpa_staticVsMotion');

%% Subjects (see header note re: sub-004 exclusion)
subjects = {'sub-001', 'sub-006'};

%% Decoding parameters
param = [];
param.usePseudo    = true;  % true: average trials into pseudotrials before decoding
param.pseudo_n     = 10;    % number of pseudotrials per class (only used if usePseudo)
param.n_iterations = 20;    % repeat pseudotrial assignment / CV partition this many times
param.ds           = 2;     % downsample factor applied to the (already 256 Hz) preprocessed data; [] to skip
param.fs           = 256;   % sampling rate of the preprocessed data
param.timewindow   = [];    % [] = full epoch, or [begin end] in seconds

%% Blocks + decodes (4 per-direction-vs-static + 1 pooled motion-vs-static, per block)
blocks = struct();

blocks(1).name = 'visual';
blocks(1).decodes = struct();
blocks(1).decodes(1).name = 'left_vs_static';   blocks(1).decodes(1).classACodes = 11;          blocks(1).decodes(1).classALabel = 'left';   blocks(1).decodes(1).classBCodes = 17; blocks(1).decodes(1).classBLabel = 'static';
blocks(1).decodes(2).name = 'right_vs_static';  blocks(1).decodes(2).classACodes = 12;          blocks(1).decodes(2).classALabel = 'right';  blocks(1).decodes(2).classBCodes = 17; blocks(1).decodes(2).classBLabel = 'static';
blocks(1).decodes(3).name = 'up_vs_static';     blocks(1).decodes(3).classACodes = 13;          blocks(1).decodes(3).classALabel = 'up';     blocks(1).decodes(3).classBCodes = 17; blocks(1).decodes(3).classBLabel = 'static';
blocks(1).decodes(4).name = 'down_vs_static';   blocks(1).decodes(4).classACodes = 14;          blocks(1).decodes(4).classALabel = 'down';   blocks(1).decodes(4).classBCodes = 17; blocks(1).decodes(4).classBLabel = 'static';
blocks(1).decodes(5).name = 'motion_vs_static'; blocks(1).decodes(5).classACodes = [11 12 13 14]; blocks(1).decodes(5).classALabel = 'motion'; blocks(1).decodes(5).classBCodes = 17; blocks(1).decodes(5).classBLabel = 'static';

blocks(2).name = 'tactile';
blocks(2).decodes = struct();
blocks(2).decodes(1).name = 'wristToFinger_vs_static'; blocks(2).decodes(1).classACodes = 21;          blocks(2).decodes(1).classALabel = 'wrist_to_finger'; blocks(2).decodes(1).classBCodes = 27; blocks(2).decodes(1).classBLabel = 'static';
blocks(2).decodes(2).name = 'fingerToWrist_vs_static'; blocks(2).decodes(2).classACodes = 22;          blocks(2).decodes(2).classALabel = 'finger_to_wrist'; blocks(2).decodes(2).classBCodes = 27; blocks(2).decodes(2).classBLabel = 'static';
blocks(2).decodes(3).name = 'pinkyToThumb_vs_static';  blocks(2).decodes(3).classACodes = 23;          blocks(2).decodes(3).classALabel = 'pinky_to_thumb';  blocks(2).decodes(3).classBCodes = 27; blocks(2).decodes(3).classBLabel = 'static';
blocks(2).decodes(4).name = 'thumbToPinky_vs_static';  blocks(2).decodes(4).classACodes = 24;          blocks(2).decodes(4).classALabel = 'thumb_to_pinky';  blocks(2).decodes(4).classBCodes = 27; blocks(2).decodes(4).classBLabel = 'static';
blocks(2).decodes(5).name = 'motion_vs_static';        blocks(2).decodes(5).classACodes = [21 22 23 24]; blocks(2).decodes(5).classALabel = 'motion';        blocks(2).decodes(5).classBCodes = 27; blocks(2).decodes(5).classBLabel = 'static';

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== MVPA static-vs-motion: %s ===\n', subDir);
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

    for b = 1:numel(blocks)
        blk = blocks(b);
        fprintf(' block: %s\n', blk.name);

        for d = 1:numel(blk.decodes)
            dc = blk.decodes(d);
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

            results.(blk.name).(dc.name).acc  = acc_iter; % iteration x time
            results.(blk.name).(dc.name).auc  = auc_iter;
            results.(blk.name).(dc.name).time = timeVec;
            results.(blk.name).(dc.name).classALabel = dc.classALabel;
            results.(blk.name).(dc.name).classBLabel = dc.classBLabel;
        end
    end

    save(fullfile(subOutDir, [subDir '_mvpa_staticVsMotion.mat']), 'results', 'param', '-v7.3');

    %% diagnostic plot: one figure per block (5 decodes x 2 metrics)
    for b = 1:numel(blocks)
        blk = blocks(b);
        decodeNames = {blk.decodes.name};

        f = figure('Visible', 'off');
        for d = 1:numel(decodeNames)
            r = results.(blk.name).(decodeNames{d});

            subplot(numel(decodeNames), 2, (d-1)*2 + 1);
            plot(r.time, mean(r.acc, 1), 'LineWidth', 1.5);
            hold on; yline(0.5, 'k--'); xline(0, 'k-'); hold off;
            xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('Accuracy');
            title([strrep(decodeNames{d}, '_', ' ') ' - accuracy']);

            subplot(numel(decodeNames), 2, (d-1)*2 + 2);
            plot(r.time, mean(r.auc, 1), 'LineWidth', 1.5);
            hold on; yline(0.5, 'k--'); xline(0, 'k-'); hold off;
            xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('AUC');
            title([strrep(decodeNames{d}, '_', ' ') ' - AUC']);
        end
        sgtitle([subDir ' - ' blk.name ' - static vs motion decoding'], 'Interpreter', 'none');
        set(f, 'Position', [0 0 1000 1400]);
        saveas(f, fullfile(subOutDir, [subDir '_mvpa_staticVsMotion_' blk.name '.png']));
        close(f);
    end

    subjectRuntime = toc(tSubject);
    fprintf('%s finished in %.1f s (%.2f min)\n', subDir, subjectRuntime, subjectRuntime/60);

end
