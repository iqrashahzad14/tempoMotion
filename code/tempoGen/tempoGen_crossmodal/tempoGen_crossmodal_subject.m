%% Temporal generalization: cross-modal visual-tactile decoding
%
% Full train-time x test-time generalization matrices for the same
% cross-modal comparisons as mvpa_crossModal_visualTactile_subject.m,
% instead of just the diagonal (train time == test time).
%
% Trigger classes (same as mvpa_crossModal_visualTactile_subject.m):
%   visual_horizontal       = [11 12]
%   visual_vertical         = [13 14]
%   somatotopic_fingerWrist = [21 22 31 32]  (pooled across tactile-up + tactile-down)
%   somatotopic_pinkyThumb  = [23 24 33 34]  (pooled across tactile-up + tactile-down)
%   external_vertical       = [21 22 33 34]
%   external_horizontal     = [23 24 31 32]
%
%   A) visual (vertical vs horizontal) <-> somatotopic (finger-wrist vs pinky-thumb)
%   B) visual (vertical vs horizontal) <-> external (vertical vs horizontal)
%
% For each of A and B, at every pair of timepoints (t1 = train, t2 = test):
%   a) train on visual @ t1 (all pseudotrials), test on tactile @ t2
%      -> matrix indexed (visual train time, tactile test time)
%   b) train on tactile @ t1 (all pseudotrials), test on visual @ t2
%      -> matrix indexed (tactile train time, visual test time)
%   c) both = average of (a) and (transpose of b), so that the two
%      directions are combined in a single (visual time, tactile time)
%      orientation rather than naively averaging two differently-oriented
%      matrices.
%
% No cross-validation folds are used (train/test are always disjoint
% domains), matching mvpa_crossModal_visualTactile_subject.m: each
% iteration trains once per train-timepoint on ALL pseudotrials from the
% training domain, and tests that single trained model against ALL
% test-timepoints (not just the matching one) in the testing domain.
%
% NOTE on cost: this is substantially more expensive than the
% diagonal-only version. Training cost is unchanged (one fit per
% train-timepoint per iteration), but each trained model is now evaluated
% at every test-timepoint instead of just one, multiplying the
% predict+score cost by roughly the number of timepoints.
%
% Follows the same conventions as the other mvpa_* scripts:
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
outDir     = fullfile(projectDir, 'outputs', 'derivatives', 'tempoGen', 'tempoGen_crossmodal');

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
    fprintf('\n=== Temporal generalization cross-modal: %s ===\n', subDir);
    tSubject = tic;

    subOutDir = fullfile(outDir, subDir);
    resultFile = fullfile(subOutDir, [subDir '_tempoGen_crossModal.mat']);

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

    trig  = data_clean.trialinfo(:, 1);
    nTime = size(data_clean.trial{1}, 2);
    nChan = size(data_clean.trial{1}, 1);
    timeVec = data_clean.time{1};

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

        acc_iter_a = zeros(param.n_iterations, nTime, nTime);
        auc_iter_a = zeros(param.n_iterations, nTime, nTime);
        acc_iter_b = zeros(param.n_iterations, nTime, nTime);
        auc_iter_b = zeros(param.n_iterations, nTime, nTime);

        for iter = 1:param.n_iterations

            visData = build_class_data(visTrials, param, nChan, nTime);
            tgtData = build_class_data(tgtTrials, param, nChan, nTime);

            visLabels = repelem([1; 2], cellfun(@(x) size(x, 3), visData));
            tgtLabels = repelem([1; 2], cellfun(@(x) size(x, 3), tgtData));

            visAll = cat(3, visData{:}); % chan x time x trials
            tgtAll = cat(3, tgtData{:});

            % pre-extract each timepoint's feature matrix once
            visByTime = cell(1, nTime);
            tgtByTime = cell(1, nTime);
            for tt = 1:nTime
                visByTime{tt} = squeeze(visAll(:, tt, :))'; % trials x channels
                tgtByTime{tt} = squeeze(tgtAll(:, tt, :))';
            end

            acc_a = zeros(nTime, nTime); auc_a = zeros(nTime, nTime);
            acc_b = zeros(nTime, nTime); auc_b = zeros(nTime, nTime);

            for t1 = 1:nTime

                %% train on visual @ t1 (all pseudotrials)
                Xvis_train = visByTime{t1};
                scaleVis = max(abs(Xvis_train(:)));
                if scaleVis == 0 || isnan(scaleVis); scaleVis = 1; end
                mdl_a = fitcsvm(Xvis_train / scaleVis, visLabels);

                %% train on tactile target @ t1 (all pseudotrials)
                Xtgt_train = tgtByTime{t1};
                scaleTgt = max(abs(Xtgt_train(:)));
                if scaleTgt == 0 || isnan(scaleTgt); scaleTgt = 1; end
                mdl_b = fitcsvm(Xtgt_train / scaleTgt, tgtLabels);

                for t2 = 1:nTime

                    %% a) test on tactile target @ t2
                    Xtgt_test = tgtByTime{t2} / scaleVis;
                    [predA, scoreA] = predict(mdl_a, Xtgt_test);
                    acc_a(t1, t2) = mean(predA == tgtLabels);
                    if numel(unique(tgtLabels)) < 2
                        auc_a(t1, t2) = nan;
                    else
                        [~, ~, ~, auc_a(t1, t2)] = perfcurve(tgtLabels, scoreA(:, mdl_a.ClassNames == 2), 2);
                    end

                    %% b) test on visual @ t2
                    Xvis_test = visByTime{t2} / scaleTgt;
                    [predB, scoreB] = predict(mdl_b, Xvis_test);
                    acc_b(t1, t2) = mean(predB == visLabels);
                    if numel(unique(visLabels)) < 2
                        auc_b(t1, t2) = nan;
                    else
                        [~, ~, ~, auc_b(t1, t2)] = perfcurve(visLabels, scoreB(:, mdl_b.ClassNames == 2), 2);
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

        % combine a and b into one (visual time, tactile time) matrix by
        % transposing b (which is natively (tactile time, visual time))
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

    save(resultFile, 'results', 'param', '-v7.3');

    %% diagnostic plot: T x T heatmaps (2 targets x 3 variants x 2 metrics)
    targetNames = {targets.name};
    climRange = [0.35 0.65];

    f = figure('Visible', 'off');
    nRows = numel(targetNames) * 3;
    row = 0;
    for ti = 1:numel(targetNames)
        tgtName = targetNames{ti};
        tv = timeVec;

        row = row + 1;
        subplot(nRows, 2, (row-1)*2 + 1);
        fn_plot_tempoGen_matrix(tv, tv, results.(tgtName).mean.a.acc, climRange, ...
            sprintf('%s - train vis / test tac - acc', tgtName), 'Train: visual time (s)', 'Test: tactile time (s)');
        subplot(nRows, 2, (row-1)*2 + 2);
        fn_plot_tempoGen_matrix(tv, tv, results.(tgtName).mean.a.auc, climRange, ...
            sprintf('%s - train vis / test tac - AUC', tgtName), 'Train: visual time (s)', 'Test: tactile time (s)');

        row = row + 1;
        subplot(nRows, 2, (row-1)*2 + 1);
        fn_plot_tempoGen_matrix(tv, tv, results.(tgtName).mean.b.acc, climRange, ...
            sprintf('%s - train tac / test vis - acc', tgtName), 'Train: tactile time (s)', 'Test: visual time (s)');
        subplot(nRows, 2, (row-1)*2 + 2);
        fn_plot_tempoGen_matrix(tv, tv, results.(tgtName).mean.b.auc, climRange, ...
            sprintf('%s - train tac / test vis - AUC', tgtName), 'Train: tactile time (s)', 'Test: visual time (s)');

        row = row + 1;
        subplot(nRows, 2, (row-1)*2 + 1);
        fn_plot_tempoGen_matrix(tv, tv, results.(tgtName).mean.both.acc, climRange, ...
            sprintf('%s - both (avg) - acc', tgtName), 'Visual time (s)', 'Tactile time (s)');
        subplot(nRows, 2, (row-1)*2 + 2);
        fn_plot_tempoGen_matrix(tv, tv, results.(tgtName).mean.both.auc, climRange, ...
            sprintf('%s - both (avg) - AUC', tgtName), 'Visual time (s)', 'Tactile time (s)');
    end
    sgtitle([subDir ' - cross-modal temporal generalization'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1100 1600]);
    saveas(f, fullfile(subOutDir, [subDir '_tempoGen_crossModal.png']));
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
