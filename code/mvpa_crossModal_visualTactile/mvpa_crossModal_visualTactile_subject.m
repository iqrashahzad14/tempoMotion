%% MVPA: cross-modal visual-tactile time-resolved decoding
%
% Tests whether the axis-of-motion code learned in one modality
% generalizes to the other, at each timepoint, for each subject.
%
% Trigger classes:
%   visual_horizontal      = [11 12]
%   visual_vertical        = [13 14]
%   somatotopic_fingerWrist = [21 22 31 32]  (pooled across tactile-up + tactile-down)
%   somatotopic_pinkyThumb  = [23 24 33 34]  (pooled across tactile-up + tactile-down)
%   external_vertical       = [21 22 33 34]
%   external_horizontal    = [23 24 31 32]
%
%   A) visual (vertical vs horizontal) <-> somatotopic (finger-wrist vs pinky-thumb)
%   B) visual (vertical vs horizontal) <-> external (vertical vs horizontal)
%
% For each of A and B:
%   a) train on visual, test on tactile
%   b) train on tactile, test on visual
%   c) both = average of (a) and (b)
%
% Unlike the within-modality decoding scripts, no cross-validation folds
% are used here: since train and test data always come from two disjoint
% domains (different modality/condition), there is no risk of testing on
% training data. Each iteration trains once on ALL pseudotrials from the
% training domain and tests on ALL pseudotrials from the testing domain
% (leave-nothing-out, as opposed to a 10-fold leave-one-pseudotrial-out
% scheme).
%
% This is the diagonal-only version (train time == test time), not a full
% train-time x test-time generalization matrix.
%
% Follows the same overall style as the other mvpa_* scripts:
%   - Binary (2-class) classification uses fitcsvm.
%   - Pseudotrial generation is optional (param.usePseudo) with a default
%     of 10 pseudotrials per class (param.pseudo_n = 10).
%   - When NOT using pseudotrials (param.usePseudo = false): decode on
%     raw single trials directly instead.
%   - Downsampling is optional (param.ds) with a default of 2x (256 Hz ->
%     128 Hz).
%   - Steps are repeated for param.n_iterations (default 20) and
%     averaged, to average out the randomness in trial-to-pseudotrial
%     assignment.
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
outDir     = fullfile(projectDir, 'outputs', 'mvpa_crossModal_visualTactile');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};

%% Decoding parameters
param = [];
param.usePseudo    = true;  % true: average trials into pseudotrials before decoding
                             % false: decode on raw single trials instead
param.pseudo_n     = 10;    % number of pseudotrials per class (only used if usePseudo)
param.n_iterations = 20;    % repeat pseudotrial assignment this many times
param.ds           = 2;     % downsample factor applied to the (already 256 Hz) preprocessed data; [] to skip
param.fs           = 256;   % sampling rate of the preprocessed data
param.timewindow   = [];    % [] = full epoch, or [begin end] in seconds

%% Trigger classes
visual.classACodes = [13 14]; visual.classALabel = 'visual_vertical';
visual.classBCodes = [11 12]; visual.classBLabel = 'visual_horizontal';

targets = struct();
targets(1).name = 'somatotopic';
targets(1).classACodes = [21 22 31 32]; targets(1).classALabel = 'somatotopic_fingerWrist';
targets(1).classBCodes = [23 24 33 34]; targets(1).classBLabel = 'somatotopic_pinkyThumb';

targets(2).name = 'external';
targets(2).classACodes = [21 22 33 34]; targets(2).classALabel = 'external_vertical';
targets(2).classBCodes = [23 24 31 32]; targets(2).classBLabel = 'external_horizontal';

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== MVPA cross-modal: %s ===\n', subDir);
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

    % raw visual trials (shared across targets)
    idxVisA = find(ismember(trig, visual.classACodes));
    idxVisB = find(ismember(trig, visual.classBCodes));
    visTrials = {cat(3, data_clean.trial{idxVisA}), cat(3, data_clean.trial{idxVisB})}; % chan x time x trial

    results = struct();

    for ti = 1:numel(targets)
        tgt = targets(ti);
        fprintf('  target: %s (%s vs %s)\n', tgt.name, tgt.classALabel, tgt.classBLabel);

        idxTgtA = find(ismember(trig, tgt.classACodes));
        idxTgtB = find(ismember(trig, tgt.classBCodes));
        tgtTrials = {cat(3, data_clean.trial{idxTgtA}), cat(3, data_clean.trial{idxTgtB})};

        acc_iter_a = zeros(param.n_iterations, nTime);
        auc_iter_a = zeros(param.n_iterations, nTime);
        acc_iter_b = zeros(param.n_iterations, nTime);
        auc_iter_b = zeros(param.n_iterations, nTime);

        for iter = 1:param.n_iterations

            visData = build_class_data(visTrials, param, nChan, nTime);
            tgtData = build_class_data(tgtTrials, param, nChan, nTime);

            visClassSizes = cellfun(@(x) size(x, 3), visData);
            tgtClassSizes = cellfun(@(x) size(x, 3), tgtData);

            visLabels = repelem([1; 2], visClassSizes);
            tgtLabels = repelem([1; 2], tgtClassSizes);

            visAll = cat(3, visData{:}); % chan x time x trials
            tgtAll = cat(3, tgtData{:});

            acc_a = zeros(1, nTime); auc_a = zeros(1, nTime);
            acc_b = zeros(1, nTime); auc_b = zeros(1, nTime);

            for t = 1:nTime

                Xvis = squeeze(visAll(:, t, :))'; % trials x channels
                Xtgt = squeeze(tgtAll(:, t, :))';

                %% a) train on visual (all pseudotrials), test on tactile target (all pseudotrials)
                scaleVis = max(abs(Xvis(:)));
                if scaleVis == 0 || isnan(scaleVis); scaleVis = 1; end
                XvisTrain = Xvis / scaleVis;
                XtgtTestA = Xtgt / scaleVis;

                mdl_a = fitcsvm(XvisTrain, visLabels);
                [predA, scoreA] = predict(mdl_a, XtgtTestA);
                acc_a(t) = mean(predA == tgtLabels);
                if numel(unique(tgtLabels)) < 2
                    auc_a(t) = nan;
                else
                    [~, ~, ~, auc_a(t)] = perfcurve(tgtLabels, scoreA(:, mdl_a.ClassNames == 2), 2);
                end

                %% b) train on tactile target (all pseudotrials), test on visual (all pseudotrials)
                scaleTgt = max(abs(Xtgt(:)));
                if scaleTgt == 0 || isnan(scaleTgt); scaleTgt = 1; end
                XtgtTrain = Xtgt / scaleTgt;
                XvisTestB = Xvis / scaleTgt;

                mdl_b = fitcsvm(XtgtTrain, tgtLabels);
                [predB, scoreB] = predict(mdl_b, XvisTestB);
                acc_b(t) = mean(predB == visLabels);
                if numel(unique(visLabels)) < 2
                    auc_b(t) = nan;
                else
                    [~, ~, ~, auc_b(t)] = perfcurve(visLabels, scoreB(:, mdl_b.ClassNames == 2), 2);
                end
            end

            acc_iter_a(iter, :) = acc_a; auc_iter_a(iter, :) = auc_a;
            acc_iter_b(iter, :) = acc_b; auc_iter_b(iter, :) = auc_b;
        end

        acc_iter_both = (acc_iter_a + acc_iter_b) / 2;
        auc_iter_both = (auc_iter_a + auc_iter_b) / 2;

        results.(tgt.name).a.acc = acc_iter_a; results.(tgt.name).a.auc = auc_iter_a;
        results.(tgt.name).b.acc = acc_iter_b; results.(tgt.name).b.auc = auc_iter_b;
        results.(tgt.name).both.acc = acc_iter_both; results.(tgt.name).both.auc = auc_iter_both;
        results.(tgt.name).time = timeVec;
        results.(tgt.name).classALabel = tgt.classALabel;
        results.(tgt.name).classBLabel = tgt.classBLabel;
    end

    save(fullfile(subOutDir, [subDir '_mvpa_crossModal.mat']), 'results', 'param', '-v7.3');

    %% quick diagnostic plot (accuracy & AUC vs time, averaged over iterations)
    targetNames = {targets.name};
    variants = {'a', 'b', 'both'};
    variantTitles = {'train vis / test tac', 'train tac / test vis', 'both (avg)'};

    f = figure('Visible', 'off');
    nRows = numel(targetNames) * numel(variants);
    row = 0;
    for ti = 1:numel(targetNames)
        for v = 1:numel(variants)
            row = row + 1;
            subplot(nRows, 2, (row-1)*2 + 1);
            plot(results.(targetNames{ti}).time, mean(results.(targetNames{ti}).(variants{v}).acc, 1), 'LineWidth', 1.5);
            hold on; yline(0.5, 'k--'); xline(0, 'k-'); hold off;
            ylim([0.35 0.65]); xlabel('Time (s)'); ylabel('Accuracy');
            title(sprintf('%s - %s - acc', targetNames{ti}, variantTitles{v}), 'Interpreter', 'none', 'FontSize', 8);

            subplot(nRows, 2, (row-1)*2 + 2);
            plot(results.(targetNames{ti}).time, mean(results.(targetNames{ti}).(variants{v}).auc, 1, 'omitnan'), 'LineWidth', 1.5);
            hold on; yline(0.5, 'k--'); xline(0, 'k-'); hold off;
            ylim([0.35 0.65]); xlabel('Time (s)'); ylabel('AUC');
            title(sprintf('%s - %s - AUC', targetNames{ti}, variantTitles{v}), 'Interpreter', 'none', 'FontSize', 8);
        end
    end
    sgtitle([subDir ' - cross-modal visual-tactile decoding'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1000 1400]);
    saveas(f, fullfile(subOutDir, [subDir '_mvpa_crossModal.png']));
    close(f);

    subjectRuntime = toc(tSubject);
    fprintf('%s finished in %.1f s (%.2f min)\n', subDir, subjectRuntime, subjectRuntime/60);

end


%% ---- local functions ----

function condData = build_class_data(classTrials, param, nChan, nTime)
% Builds pseudotrials (or passes through raw trials) for the 2 classes in
% classTrials = {chan x time x trial (class A), chan x time x trial (class B)}.

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
else
    condData = classTrials;
end

end
