%% MVPA: tactile frame-of-reference time-resolved decoding
%  - frequency-band variant (theta / alpha / beta / gamma / sustained ERP)
%
% Same binary tactile frame-of-reference decoding as
% code/mvpa_tactileFrameOfReference/mvpa_tactileFrameOfReference_subject.m
% (all-channel, diagonal-only, pooling trials across tactile-up +
% tactile-down), repeated separately for 5 different band-limited
% versions of the signal instead of the broadband (0.1-45 Hz) ERP:
%
%   theta / alpha / beta / gamma - bandpass filter + Hilbert amplitude,
%     squared to give instantaneous power (Bae & Luck 2019's alpha-power
%     method; band edges from Wang et al. 2024: theta 4-7, alpha 8-13,
%     beta 14-30, gamma 31-45 Hz).
%   sustainedERP - low-pass filter at 6 Hz on the raw voltage (Bae & Luck
%     2019), isolating the slow phase-locked ERP from oscillatory content.
%
% See fn_apply_band_filter.m for the filtering implementation.
%
% Otherwise follows the same conventions as the all-channel diagonal script:
%   - Binary (2-class) classification uses fitcsvm.
%   - Pseudotrial generation is optional (param.usePseudo) with a default
%     of 10 pseudotrials per class (param.pseudo_n = 10).
%   - When using pseudotrials: leave-one-pseudotrial-out cross-validation
%     (nFolds = pseudo_n).
%   - Downsampling is optional (param.ds) with a default of 2x (256 Hz ->
%     128 Hz), applied AFTER band-limiting (at native 256 Hz).
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
outDir     = fullfile(projectDir, 'outputs', 'ft_mvpa_tactileFrameOfReference');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};

%% Decoding parameters
param = [];
param.usePseudo    = true;
param.pseudo_n     = 10;
param.n_iterations = 20;
param.ds           = 2;
param.fs           = 256;
param.timewindow   = [];

%% Frequency bands / signal variants
bands = struct();
bands(1).name = 'theta';        bands(1).freq = [4 7];   bands(1).type = 'power';
bands(2).name = 'alpha';        bands(2).freq = [8 13];  bands(2).type = 'power';
bands(3).name = 'beta';         bands(3).freq = [14 30]; bands(3).type = 'power';
bands(4).name = 'gamma';        bands(4).freq = [31 45]; bands(4).type = 'power';
bands(5).name = 'sustainedERP'; bands(5).freq = [NaN 6]; bands(5).type = 'voltage';

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
    fprintf('\n=== MVPA tactile frame-of-reference (freq bands): %s ===\n', subDir);
    tSubject = tic;

    subOutDir = fullfile(outDir, subDir);
    if ~exist(subOutDir, 'dir')
        mkdir(subOutDir);
    end

    loaded = load(fullfile(preprocDir, subDir, [subDir '_preprocessed.mat']), 'data_clean');
    data_clean_raw = loaded.data_clean;

    results = struct();

    for bi = 1:numel(bands)
        band = bands(bi);
        fprintf(' band: %s\n', band.name);

        data_band = fn_apply_band_filter(data_clean_raw, band);

        if ~isempty(param.ds)
            cfg = [];
            cfg.resamplefs = param.fs / param.ds;
            data_band = ft_resampledata(cfg, data_band);
        end

        if ~isempty(param.timewindow)
            cfg = [];
            cfg.toilim = param.timewindow;
            data_band = ft_redefinetrial(cfg, data_band);
        end

        trig  = data_band.trialinfo(:, 1);
        nTime = size(data_band.trial{1}, 2);
        nChan = size(data_band.trial{1}, 1);
        timeVec = data_band.time{1};

        for d = 1:numel(decodes)
            dc = decodes(d);
            fprintf('  decode: %s (%s vs %s)\n', dc.name, dc.classALabel, dc.classBLabel);

            idxA = find(ismember(trig, dc.classACodes));
            idxB = find(ismember(trig, dc.classBCodes));
            classTrials = {cat(3, data_band.trial{idxA}), cat(3, data_band.trial{idxB})};

            acc_iter = zeros(param.n_iterations, nTime);
            auc_iter = zeros(param.n_iterations, nTime);

            for iter = 1:param.n_iterations

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

                classSizes = cellfun(@(x) size(x, 3), condData);
                allData = cat(3, condData{:});
                allLabels = repelem([1; 2], classSizes);

                startIdx = [0, cumsum(classSizes(1:end-1))];
                foldTestIdx = arrayfun(@(f) startIdx + f, 1:nFolds, 'UniformOutput', false);

                acc_time = zeros(1, nTime);
                auc_time = zeros(1, nTime);

                for t = 1:nTime

                    X = squeeze(allData(:, t, :))';
                    y = allLabels;

                    acc_fold = zeros(1, nFolds);
                    auc_fold = zeros(1, nFolds);

                    for f = 1:nFolds
                        testIdx  = foldTestIdx{f};
                        trainIdx = setdiff(1:size(X, 1), testIdx);

                        Xtrain = X(trainIdx, :); ytrain = y(trainIdx);
                        Xtest  = X(testIdx, :);  ytest  = y(testIdx);

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

            results.(band.name).(dc.name).acc  = acc_iter;
            results.(band.name).(dc.name).auc  = auc_iter;
            results.(band.name).(dc.name).time = timeVec;
            results.(band.name).(dc.name).classALabel = dc.classALabel;
            results.(band.name).(dc.name).classBLabel = dc.classBLabel;
        end
    end

    save(fullfile(subOutDir, [subDir '_mvpa_tactileFoR_freqBands.mat']), 'results', 'param', 'bands', '-v7.3');

    %% diagnostic plot: bands (rows) x decodes (cols), one figure for acc, one for AUC
    bandNames   = {bands.name};
    decodeNames = {decodes.name};

    f1 = figure('Visible', 'off');
    for bi = 1:numel(bandNames)
        for d = 1:numel(decodeNames)
            subplot(numel(bandNames), numel(decodeNames), (bi-1)*numel(decodeNames) + d);
            r = results.(bandNames{bi}).(decodeNames{d});
            plot(r.time, mean(r.acc, 1), 'LineWidth', 1.2);
            hold on; yline(0.5, 'k--'); xline(0, 'k-');
            xline(-0.01, ':', 'Color', [0.6 0.6 0.6]); xline(0.01, ':', 'Color', [0.6 0.6 0.6]);
            hold off;
            xlim([-0.5 1.5]);
            ylim([0 1]);
            if bi == 1
                title(strrep(decodeNames{d}, '_', ' '));
            end
            if d == 1
                ylabel(bandNames{bi}, 'FontWeight', 'bold');
            end
            if bi == numel(bandNames)
                xlabel('Time (s)');
            end
        end
    end
    sgtitle([subDir ' - tactile frame-of-reference decoding accuracy by frequency band'], 'Interpreter', 'none');
    set(f1, 'Position', [0 0 1200 1400]);
    saveas(f1, fullfile(subOutDir, [subDir '_mvpa_tactileFoR_freqBands_acc.png']));
    close(f1);

    f2 = figure('Visible', 'off');
    for bi = 1:numel(bandNames)
        for d = 1:numel(decodeNames)
            subplot(numel(bandNames), numel(decodeNames), (bi-1)*numel(decodeNames) + d);
            r = results.(bandNames{bi}).(decodeNames{d});
            plot(r.time, mean(r.auc, 1), 'LineWidth', 1.2);
            hold on; yline(0.5, 'k--'); xline(0, 'k-');
            xline(-0.01, ':', 'Color', [0.6 0.6 0.6]); xline(0.01, ':', 'Color', [0.6 0.6 0.6]);
            hold off;
            xlim([-0.5 1.5]);
            ylim([0 1]);
            if bi == 1
                title(strrep(decodeNames{d}, '_', ' '));
            end
            if d == 1
                ylabel(bandNames{bi}, 'FontWeight', 'bold');
            end
            if bi == numel(bandNames)
                xlabel('Time (s)');
            end
        end
    end
    sgtitle([subDir ' - tactile frame-of-reference decoding AUC by frequency band'], 'Interpreter', 'none');
    set(f2, 'Position', [0 0 1200 1400]);
    saveas(f2, fullfile(subOutDir, [subDir '_mvpa_tactileFoR_freqBands_auc.png']));
    close(f2);

    subjectRuntime = toc(tSubject);
    fprintf('%s finished in %.1f s (%.2f min)\n', subDir, subjectRuntime, subjectRuntime/60);

end
