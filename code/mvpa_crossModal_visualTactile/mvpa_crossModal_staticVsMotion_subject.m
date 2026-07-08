%% MVPA: cross-modal visual-tactile decoding of static-vs-motion
%
% Tests whether the "motion vs static" code learned in one modality
% generalizes to the other, at each timepoint, for each subject, in the
% static-vs-motion supplementary session.
%
% Trigger classes:
%   visual_motion   = [11 12 13 14]  (all 4 visual directions pooled)
%   visual_static   = 17
%   tactile_motion  = [21 22 23 24]  (all 4 tactile directions pooled)
%   tactile_static  = 27
%
%   a) train on visual (motion vs static), test on tactile (motion vs static)
%   b) train on tactile (motion vs static), test on visual (motion vs static)
%   c) both = average of (a) and (b)
%
% Unlike the within-modality decoding scripts, no cross-validation folds
% are used here: since train and test data always come from two disjoint
% domains (different modality), there is no risk of testing on training
% data. Each iteration trains once on ALL pseudotrials from the training
% domain and tests on ALL pseudotrials from the testing domain
% (leave-nothing-out, as opposed to a 10-fold leave-one-pseudotrial-out
% scheme) - same design as mvpa_crossModal_visualTactile_subject.m.
%
% This is the diagonal-only version (train time == test time), not a full
% train-time x test-time generalization matrix.
%
% Only sub-001 and sub-006 are included: sub-004's static.bdf recording
% has no usable stimulus triggers (see
% code/preprocess_staticVsMotion/preprocess_staticVsMotion.m header) and
% no alternate/backup file exists. N=2 - treat as exploratory/
% supplementary given the small sample.
%
% Follows the same conventions as mvpa_crossModal_visualTactile_subject.m:
%   - Binary (2-class) classification uses fitcsvm.
%   - Pseudotrial generation is optional (param.usePseudo) with a default
%     of 10 pseudotrials per class (param.pseudo_n = 10).
%   - Downsampling is optional (param.ds) with a default of 2x (256 Hz ->
%     128 Hz).
%   - Steps are repeated for param.n_iterations (default 20) and
%     averaged.
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
outDir     = fullfile(projectDir, 'outputs', 'mvpa_crossModal_staticVsMotion');

%% Subjects (see header note re: sub-004 exclusion)
subjects = {'sub-001', 'sub-006'};

%% Decoding parameters
param = [];
param.usePseudo    = true;  % true: average trials into pseudotrials before decoding
param.pseudo_n     = 10;    % number of pseudotrials per class (only used if usePseudo)
param.n_iterations = 20;    % repeat pseudotrial assignment this many times
param.ds           = 2;     % downsample factor applied to the (already 256 Hz) preprocessed data; [] to skip
param.fs           = 256;   % sampling rate of the preprocessed data
param.timewindow   = [];    % [] = full epoch, or [begin end] in seconds

%% Trigger classes
visual.classACodes  = [11 12 13 14]; visual.classALabel  = 'visual_motion';
visual.classBCodes  = 17;            visual.classBLabel  = 'visual_static';

tactile.classACodes = [21 22 23 24]; tactile.classALabel = 'tactile_motion';
tactile.classBCodes = 27;            tactile.classBLabel = 'tactile_static';

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== MVPA cross-modal static-vs-motion: %s ===\n', subDir);
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

    idxVisA = find(ismember(trig, visual.classACodes));
    idxVisB = find(ismember(trig, visual.classBCodes));
    visTrials = {cat(3, data_clean.trial{idxVisA}), cat(3, data_clean.trial{idxVisB})}; % chan x time x trial

    idxTacA = find(ismember(trig, tactile.classACodes));
    idxTacB = find(ismember(trig, tactile.classBCodes));
    tacTrials = {cat(3, data_clean.trial{idxTacA}), cat(3, data_clean.trial{idxTacB})};

    results = struct();

    acc_iter_a = zeros(param.n_iterations, nTime);
    auc_iter_a = zeros(param.n_iterations, nTime);
    acc_iter_b = zeros(param.n_iterations, nTime);
    auc_iter_b = zeros(param.n_iterations, nTime);

    for iter = 1:param.n_iterations

        visData = build_class_data(visTrials, param, nChan, nTime);
        tacData = build_class_data(tacTrials, param, nChan, nTime);

        visClassSizes = cellfun(@(x) size(x, 3), visData);
        tacClassSizes = cellfun(@(x) size(x, 3), tacData);

        visLabels = repelem([1; 2], visClassSizes);
        tacLabels = repelem([1; 2], tacClassSizes);

        visAll = cat(3, visData{:}); % chan x time x trials
        tacAll = cat(3, tacData{:});

        acc_a = zeros(1, nTime); auc_a = zeros(1, nTime);
        acc_b = zeros(1, nTime); auc_b = zeros(1, nTime);

        for t = 1:nTime

            Xvis = squeeze(visAll(:, t, :))'; % trials x channels
            Xtac = squeeze(tacAll(:, t, :))';

            %% a) train on visual (all pseudotrials), test on tactile (all pseudotrials)
            scaleVis = max(abs(Xvis(:)));
            if scaleVis == 0 || isnan(scaleVis); scaleVis = 1; end
            XvisTrain = Xvis / scaleVis;
            XtacTestA = Xtac / scaleVis;

            mdl_a = fitcsvm(XvisTrain, visLabels);
            [predA, scoreA] = predict(mdl_a, XtacTestA);
            acc_a(t) = mean(predA == tacLabels);
            if numel(unique(tacLabels)) < 2
                auc_a(t) = nan;
            else
                [~, ~, ~, auc_a(t)] = perfcurve(tacLabels, scoreA(:, mdl_a.ClassNames == 2), 2);
            end

            %% b) train on tactile (all pseudotrials), test on visual (all pseudotrials)
            scaleTac = max(abs(Xtac(:)));
            if scaleTac == 0 || isnan(scaleTac); scaleTac = 1; end
            XtacTrain = Xtac / scaleTac;
            XvisTestB = Xvis / scaleTac;

            mdl_b = fitcsvm(XtacTrain, tacLabels);
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

    results.a.acc = acc_iter_a; results.a.auc = auc_iter_a;
    results.b.acc = acc_iter_b; results.b.auc = auc_iter_b;
    results.both.acc = acc_iter_both; results.both.auc = auc_iter_both;
    results.time = timeVec;
    results.visualLabels  = {visual.classALabel, visual.classBLabel};
    results.tactileLabels = {tactile.classALabel, tactile.classBLabel};

    save(fullfile(subOutDir, [subDir '_mvpa_crossModal_staticVsMotion.mat']), 'results', 'param', '-v7.3');

    %% diagnostic plot: 3 rows (a, b, both) x 2 metrics
    variants = {'a', 'b', 'both'};
    variantTitles = {'train vis / test tac', 'train tac / test vis', 'both (avg)'};

    f = figure('Visible', 'off');
    for v = 1:numel(variants)
        subplot(numel(variants), 2, (v-1)*2 + 1);
        plot(results.time, mean(results.(variants{v}).acc, 1), 'LineWidth', 1.5);
        hold on; yline(0.5, 'k--'); xline(0, 'k-'); hold off;
        xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('Accuracy');
        title(sprintf('%s - accuracy', variantTitles{v}), 'Interpreter', 'none');

        subplot(numel(variants), 2, (v-1)*2 + 2);
        plot(results.time, mean(results.(variants{v}).auc, 1, 'omitnan'), 'LineWidth', 1.5);
        hold on; yline(0.5, 'k--'); xline(0, 'k-'); hold off;
        xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('AUC');
        title(sprintf('%s - AUC', variantTitles{v}), 'Interpreter', 'none');
    end
    sgtitle([subDir ' - cross-modal visual-tactile static-vs-motion decoding'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1000 1000]);
    saveas(f, fullfile(subOutDir, [subDir '_mvpa_crossModal_staticVsMotion.png']));
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
