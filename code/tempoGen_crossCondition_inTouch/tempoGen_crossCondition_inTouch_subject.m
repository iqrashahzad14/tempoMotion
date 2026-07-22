%% Temporal generalization: cross-condition decoding within touch
%
% Full train-time x test-time generalization matrices for the same
% cross-condition (shared-code) comparisons as
% mvpa_crossCondition_inTouch_subject.m, instead of just the diagonal
% (train time == test time). See that script's header for the full
% rationale and the important caveat about the arbitrary class-pairing
% convention (a real shared-code effect in the opposite pairing would
% show up as significantly BELOW chance, which this project's one-tailed
% tests will not flag).
%
% Trigger classes (same as mvpa_crossCondition_inTouch_subject.m):
%   somatotopic_fingerWrist = [21 22 31 32]  (pooled across tactile-up + tactile-down)
%   somatotopic_pinkyThumb  = [23 24 33 34]  (pooled across tactile-up + tactile-down)
%   external_vertical       = [21 22 33 34]  ("ext_vertical")
%   external_horizontal     = [23 24 31 32]  ("ext_horizontal")
%   handPos_tactileUp       = [21 22 23 24]
%   handPos_tactileDown     = [31 32 33 34]
%
%   1) somatotopic (finger-wrist vs pinky-thumb) <-> handPos (up vs down)
%   2) external (vertical vs horizontal)         <-> handPos (up vs down)
%
% For each of 1) and 2), at every pair of timepoints (t1 = train, t2 = test):
%   a) train on the reference-frame contrast @ t1 (all pseudotrials),
%      test on handPos @ t2 -> matrix indexed (target train time, handPos test time)
%   b) train on handPos @ t1 (all pseudotrials), test on the
%      reference-frame contrast @ t2 -> matrix indexed (handPos train time, target test time)
%   c) both = average of (a) and (transpose of b), so both directions are
%      combined in a single (target time, handPos time) orientation
%      rather than naively averaging two differently-oriented matrices -
%      matches tempoGen_crossmodal_subject.m's convention.
%
% No cross-validation folds (train and test are disjoint LABEL SCHEMES,
% not disjoint trials - see mvpa_crossCondition_inTouch_subject.m for why
% this is not circular), matching tempoGen_crossmodal_subject.m.
%
% COST CONTROL: unlike tempoGen_crossmodal (visual-tactile), both domains
% here are touch-only and share the same time axis, so this uses the same
% param.tgen_step grid-subsampling as tempoGen_tactileFrameOfReference (a
% train/test grid step of 4, matching that touch-only precedent) to keep
% the O(nTime^2) cost tractable without needing cluster resources.
%
% Follows the same conventions as the other mvpa_*/tempoGen_* scripts:
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
outDir     = fullfile(projectDir, 'outputs', 'tempoGen_crossCondition_inTouch');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};

%% Decoding parameters
param = [];
param.usePseudo    = true;  % true: average trials into pseudotrials before decoding
param.pseudo_n     = 10;    % number of pseudotrials per class
param.n_iterations = 20;    % repeat pseudotrial assignment this many times
param.ds           = 2;     % downsample factor applied to the (already 256 Hz) preprocessed data; [] to skip
param.fs           = 256;   % sampling rate of the preprocessed data
param.timewindow   = [];    % [] = full epoch, or [begin end] in seconds
param.tgen_step    = 4;     % subsampling factor for the train/test time grid (cost control, see header note)

%% Trigger classes
handPos.classACodes = [21 22 23 24]; handPos.classALabel = 'tactile_up';
handPos.classBCodes = [31 32 33 34]; handPos.classBLabel = 'tactile_down';

targets = struct();
targets(1).name = 'somatotopic';
targets(1).classACodes = [21 22 31 32]; targets(1).classALabel = 'finger_wrist';
targets(1).classBCodes = [23 24 33 34]; targets(1).classBLabel = 'pinky_thumb';

targets(2).name = 'external';
targets(2).classACodes = [21 22 33 34]; targets(2).classALabel = 'ext_vertical';
targets(2).classBCodes = [23 24 31 32]; targets(2).classBLabel = 'ext_horizontal';

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== Temporal generalization cross-condition in touch: %s ===\n', subDir);
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

    idxHandA = find(ismember(trig, handPos.classACodes));
    idxHandB = find(ismember(trig, handPos.classBCodes));
    handTrials = {cat(3, data_clean.trial{idxHandA}), cat(3, data_clean.trial{idxHandB})}; % chan x time x trial

    results = struct();

    for ti = 1:numel(targets)
        tgt = targets(ti);
        fprintf('  target: %s (%s vs %s)\n', tgt.name, tgt.classALabel, tgt.classBLabel);

        idxTgtA = find(ismember(trig, tgt.classACodes));
        idxTgtB = find(ismember(trig, tgt.classBCodes));
        tgtTrials = {cat(3, data_clean.trial{idxTgtA}), cat(3, data_clean.trial{idxTgtB})};

        acc_iter_a = zeros(param.n_iterations, nTime, nTime);
        auc_iter_a = zeros(param.n_iterations, nTime, nTime);
        acc_iter_b = zeros(param.n_iterations, nTime, nTime);
        auc_iter_b = zeros(param.n_iterations, nTime, nTime);

        for iter = 1:param.n_iterations

            handData = build_class_data(handTrials, param, nChan, nTimeAll);
            tgtData  = build_class_data(tgtTrials, param, nChan, nTimeAll);

            handLabels = repelem([1; 2], cellfun(@(x) size(x, 3), handData));
            tgtLabels  = repelem([1; 2], cellfun(@(x) size(x, 3), tgtData));

            handAll = cat(3, handData{:}); % chan x time x trials
            tgtAll  = cat(3, tgtData{:});

            % pre-extract each grid timepoint's feature matrix once
            handByTime = cell(1, nTime);
            tgtByTime  = cell(1, nTime);
            for gi = 1:nTime
                handByTime{gi} = squeeze(handAll(:, gridIdx(gi), :))'; % trials x channels
                tgtByTime{gi}  = squeeze(tgtAll(:, gridIdx(gi), :))';
            end

            acc_a = zeros(nTime, nTime); auc_a = zeros(nTime, nTime);
            acc_b = zeros(nTime, nTime); auc_b = zeros(nTime, nTime);

            for t1 = 1:nTime

                %% train on target contrast @ t1 (all pseudotrials)
                Xtgt_train = tgtByTime{t1};
                scaleTgt = max(abs(Xtgt_train(:)));
                if scaleTgt == 0 || isnan(scaleTgt); scaleTgt = 1; end
                mdl_a = fitcsvm(Xtgt_train / scaleTgt, tgtLabels);

                %% train on handPos @ t1 (all pseudotrials)
                Xhand_train = handByTime{t1};
                scaleHand = max(abs(Xhand_train(:)));
                if scaleHand == 0 || isnan(scaleHand); scaleHand = 1; end
                mdl_b = fitcsvm(Xhand_train / scaleHand, handLabels);

                for t2 = 1:nTime

                    %% a) test on handPos @ t2
                    Xhand_test = handByTime{t2} / scaleTgt;
                    [predA, scoreA] = predict(mdl_a, Xhand_test);
                    acc_a(t1, t2) = mean(predA == handLabels);
                    if numel(unique(handLabels)) < 2
                        auc_a(t1, t2) = nan;
                    else
                        [~, ~, ~, auc_a(t1, t2)] = perfcurve(handLabels, scoreA(:, mdl_a.ClassNames == 2), 2);
                    end

                    %% b) test on target contrast @ t2
                    Xtgt_test = tgtByTime{t2} / scaleHand;
                    [predB, scoreB] = predict(mdl_b, Xtgt_test);
                    acc_b(t1, t2) = mean(predB == tgtLabels);
                    if numel(unique(tgtLabels)) < 2
                        auc_b(t1, t2) = nan;
                    else
                        [~, ~, ~, auc_b(t1, t2)] = perfcurve(tgtLabels, scoreB(:, mdl_b.ClassNames == 2), 2);
                    end
                end
            end

            acc_iter_a(iter, :, :) = acc_a; auc_iter_a(iter, :, :) = auc_a;
            acc_iter_b(iter, :, :) = acc_b; auc_iter_b(iter, :, :) = auc_b;

            fprintf('    iteration %d/%d done\n', iter, param.n_iterations);
        end

        acc_a_mean = squeeze(mean(acc_iter_a, 1));
        auc_a_mean = squeeze(mean(auc_iter_a, 1, 'omitnan'));
        acc_b_mean = squeeze(mean(acc_iter_b, 1));
        auc_b_mean = squeeze(mean(auc_iter_b, 1, 'omitnan'));

        % combine a and b into one (target time, handPos time) matrix by
        % transposing b (which is natively (handPos time, target time))
        acc_both_mean = (acc_a_mean + acc_b_mean') / 2;
        auc_both_mean = (auc_a_mean + auc_b_mean') / 2;

        results.(tgt.name).a.acc = acc_iter_a; results.(tgt.name).a.auc = auc_iter_a;
        results.(tgt.name).b.acc = acc_iter_b; results.(tgt.name).b.auc = auc_iter_b;
        results.(tgt.name).mean.a.acc = acc_a_mean; results.(tgt.name).mean.a.auc = auc_a_mean;
        results.(tgt.name).mean.b.acc = acc_b_mean; results.(tgt.name).mean.b.auc = auc_b_mean;
        results.(tgt.name).mean.both.acc = acc_both_mean; results.(tgt.name).mean.both.auc = auc_both_mean;
        results.(tgt.name).time = timeVec;
        results.(tgt.name).classALabel = tgt.classALabel;
        results.(tgt.name).classBLabel = tgt.classBLabel;
    end

    save(fullfile(subOutDir, [subDir '_tempoGen_crossCondition.mat']), 'results', 'param', '-v7.3');

    %% diagnostic plot: T x T heatmaps (2 targets x 3 variants x 2 metrics)
    targetNames = {targets.name};
    climRange = [0.35 0.65];

    f = figure('Visible', 'off');
    nRows = numel(targetNames) * 3;
    row = 0;
    for ti = 1:numel(targetNames)
        tgtName = targetNames{ti};
        tv = results.(tgtName).time;

        row = row + 1;
        subplot(nRows, 2, (row-1)*2 + 1);
        fn_plot_tempoGen_matrix(tv, tv, results.(tgtName).mean.a.acc, climRange, ...
            sprintf('%s - train tgt / test handPos - acc', tgtName), 'Train: target time (s)', 'Test: handPos time (s)');
        subplot(nRows, 2, (row-1)*2 + 2);
        fn_plot_tempoGen_matrix(tv, tv, results.(tgtName).mean.a.auc, climRange, ...
            sprintf('%s - train tgt / test handPos - AUC', tgtName), 'Train: target time (s)', 'Test: handPos time (s)');

        row = row + 1;
        subplot(nRows, 2, (row-1)*2 + 1);
        fn_plot_tempoGen_matrix(tv, tv, results.(tgtName).mean.b.acc, climRange, ...
            sprintf('%s - train handPos / test tgt - acc', tgtName), 'Train: handPos time (s)', 'Test: target time (s)');
        subplot(nRows, 2, (row-1)*2 + 2);
        fn_plot_tempoGen_matrix(tv, tv, results.(tgtName).mean.b.auc, climRange, ...
            sprintf('%s - train handPos / test tgt - AUC', tgtName), 'Train: handPos time (s)', 'Test: target time (s)');

        row = row + 1;
        subplot(nRows, 2, (row-1)*2 + 1);
        fn_plot_tempoGen_matrix(tv, tv, results.(tgtName).mean.both.acc, climRange, ...
            sprintf('%s - both (avg) - acc', tgtName), 'Target time (s)', 'HandPos time (s)');
        subplot(nRows, 2, (row-1)*2 + 2);
        fn_plot_tempoGen_matrix(tv, tv, results.(tgtName).mean.both.auc, climRange, ...
            sprintf('%s - both (avg) - AUC', tgtName), 'Target time (s)', 'HandPos time (s)');
    end
    sgtitle([subDir ' - cross-condition temporal generalization within touch'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1100 1600]);
    saveas(f, fullfile(subOutDir, [subDir '_tempoGen_crossCondition.png']));
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
