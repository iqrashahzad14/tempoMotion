%% MVPA: cross-condition decoding within touch (time-resolved)
%
% Tests whether the neural code that separates a tactile reference-frame
% contrast (somatotopic or external) shares a common discriminant
% direction with the neural code that separates hand posture, at each
% timepoint, for each subject. Unlike mvpa_tactileFrameOfReference (which
% decodes each contrast against its OWN held-out data), this trains on
% one labeling of the touch trials and tests on a DIFFERENT labeling of
% the same underlying trials - a cross-classification / shared-code test,
% not a posture-invariance test (see project discussion for the
% distinction). Because axis-of-touch and hand-posture are fully crossed
% at the trial level (every trial has both an axis identity and a
% posture identity) and the class definitions below are balanced across
% the other factor, this is a valid test for a shared linear code: the
% model trained on one labeling never sees the other labeling's classes,
% so scoring it against the other labeling is not circular.
%
% Trigger classes:
%   somatotopic_fingerWrist = [21 22 31 32]  (pooled across tactile-up + tactile-down)
%   somatotopic_pinkyThumb  = [23 24 33 34]  (pooled across tactile-up + tactile-down)
%   external_vertical       = [21 22 33 34]  (referred to as "ext_vertical")
%   external_horizontal     = [23 24 31 32]  (referred to as "ext_horizontal")
%   handPos_tactileUp       = [21 22 23 24]
%   handPos_tactileDown     = [31 32 33 34]
%
%   1) somatotopic (finger-wrist vs pinky-thumb) <-> handPos (up vs down)
%   2) external (vertical vs horizontal)         <-> handPos (up vs down)
%
% For each of 1) and 2):
%   a) train on the reference-frame contrast, test on handPos
%   b) train on handPos, test on the reference-frame contrast
%   c) both = average of (a) and (b)
%
% IMPORTANT CAVEAT - arbitrary class pairing: accuracy/AUC requires a
% correspondence between class A of the training contrast and class A of
% the testing contrast (here: finger_wrist<->tactile_up, pinky_thumb<->
% tactile_down by array position; external_vertical<->tactile_up,
% external_horizontal<->tactile_down). Unlike the visual/tactile
% cross-modal decodes (where "vertical" has an obvious shared meaning
% across modalities), there is NO a priori reason axis identity should
% align with posture identity in one direction rather than the other.
% A real shared-code effect in the OPPOSITE pairing would show up as
% significantly BELOW chance under this fixed convention, which the
% project's one-tailed (decoding>chance) significance tests will not
% flag. Consider a two-tailed test at the stats stage for these decodes.
%
% Same conventions as mvpa_crossModal_visualTactile_subject.m: no
% cross-validation folds (train and test are disjoint LABEL SCHEMES, so
% there is no leakage risk even though both draw from the same pool of
% touch trials - the model is never fit with respect to the criterion
% it is scored on). Diagonal-only (train time == test time); see
% tempoGen_crossCondition_inTouch/ for the full train x test matrix.
%
%   - Binary (2-class) classification uses fitcsvm.
%   - Pseudotrial generation is optional (param.usePseudo) with a default
%     of 10 pseudotrials per class (param.pseudo_n = 10).
%   - Downsampling is optional (param.ds) with a default of 2x (256 Hz ->
%     128 Hz).
%   - Steps are repeated for param.n_iterations (default 20) and
%     averaged, to average out the randomness in trial-to-pseudotrial
%     assignment.
%
% Requires outputs/derivatives/preprocess/<sub>/<sub>_preprocessed.mat (see
% code/preprocess/preprocess_bandstop45.m).

clear;

%% Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
preprocDir = fullfile(projectDir, 'outputs', 'derivatives', 'preprocess');
outDir     = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa', 'mvpa_crossCondition_inTouch');

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
% handPos: the fixed comparison domain (plays the role "visual" played in
% mvpa_crossModal_visualTactile_subject.m)
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
    fprintf('\n=== MVPA cross-condition in touch: %s ===\n', subDir);
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

    % raw handPos trials (shared across targets)
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

        acc_iter_a = zeros(param.n_iterations, nTime);
        auc_iter_a = zeros(param.n_iterations, nTime);
        acc_iter_b = zeros(param.n_iterations, nTime);
        auc_iter_b = zeros(param.n_iterations, nTime);

        for iter = 1:param.n_iterations

            handData = build_class_data(handTrials, param, nChan, nTime);
            tgtData  = build_class_data(tgtTrials, param, nChan, nTime);

            handClassSizes = cellfun(@(x) size(x, 3), handData);
            tgtClassSizes  = cellfun(@(x) size(x, 3), tgtData);

            handLabels = repelem([1; 2], handClassSizes);
            tgtLabels  = repelem([1; 2], tgtClassSizes);

            handAll = cat(3, handData{:}); % chan x time x trials
            tgtAll  = cat(3, tgtData{:});

            acc_a = zeros(1, nTime); auc_a = zeros(1, nTime);
            acc_b = zeros(1, nTime); auc_b = zeros(1, nTime);

            for t = 1:nTime

                Xhand = squeeze(handAll(:, t, :))'; % trials x channels
                Xtgt  = squeeze(tgtAll(:, t, :))';

                %% a) train on target contrast (all pseudotrials), test on handPos (all pseudotrials)
                scaleTgt = max(abs(Xtgt(:)));
                if scaleTgt == 0 || isnan(scaleTgt); scaleTgt = 1; end
                XtgtTrain  = Xtgt / scaleTgt;
                XhandTestA = Xhand / scaleTgt;

                mdl_a = fitcsvm(XtgtTrain, tgtLabels);
                [predA, scoreA] = predict(mdl_a, XhandTestA);
                acc_a(t) = mean(predA == handLabels);
                if numel(unique(handLabels)) < 2
                    auc_a(t) = nan;
                else
                    [~, ~, ~, auc_a(t)] = perfcurve(handLabels, scoreA(:, mdl_a.ClassNames == 2), 2);
                end

                %% b) train on handPos (all pseudotrials), test on target contrast (all pseudotrials)
                scaleHand = max(abs(Xhand(:)));
                if scaleHand == 0 || isnan(scaleHand); scaleHand = 1; end
                XhandTrain = Xhand / scaleHand;
                XtgtTestB  = Xtgt / scaleHand;

                mdl_b = fitcsvm(XhandTrain, handLabels);
                [predB, scoreB] = predict(mdl_b, XtgtTestB);
                acc_b(t) = mean(predB == tgtLabels);
                if numel(unique(tgtLabels)) < 2
                    auc_b(t) = nan;
                else
                    [~, ~, ~, auc_b(t)] = perfcurve(tgtLabels, scoreB(:, mdl_b.ClassNames == 2), 2);
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

    save(fullfile(subOutDir, [subDir '_mvpa_crossCondition.mat']), 'results', 'param', '-v7.3');

    %% quick diagnostic plot (accuracy & AUC vs time, averaged over iterations)
    targetNames = {targets.name};
    variants = {'a', 'b', 'both'};
    variantTitles = {'train tgt / test handPos', 'train handPos / test tgt', 'both (avg)'};

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
    sgtitle([subDir ' - cross-condition decoding within touch'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1000 1400]);
    saveas(f, fullfile(subOutDir, [subDir '_mvpa_crossCondition.png']));
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
