%% RSA: 8-condition cross-modal RDM (somatotopic + external + hand posture + visual)
%
% Time-resolved RSA over 8 conditions, forming a single 8x8 RDM per
% timepoint (replaces the previous 2x4x4 "framing" design):
%
%   A. somatotopic (skin-based touch axis, pooled across both postures)
%      A1 = pinky_thumb   = [23 24 33 34]
%      A2 = finger_wrist  = [21 22 31 32]
%   B. external (world-referenced touch axis)
%      B1 = horizontal    = [23 24 31 32]
%      B2 = vertical      = [21 22 33 34]
%   C. hand posture (pooled across both touch axes)
%      C1 = tactile_up    = [21 22 23 24]
%      C2 = tactile_down  = [31 32 33 34]
%   D. visual motion axis
%      D1 = vertical      = [13 14]
%      D2 = horizontal    = [11 12]
%
% IMPORTANT - A/B/C are NOT independent factors: they are three different
% 2-way splits of the SAME underlying 2x2 (touch-axis x posture) trial
% pool, so their trigger-code sets overlap. Of the 15 tactile-tactile
% cells in this 8x8 RDM, only 3 are trial-disjoint (A1-A2, B1-B2, C1-C2 -
% each a clean complementary split of all 8 tactile trigger codes); the
% other 12 cross-factor cells (e.g. A vs B, A vs C, B vs C) are built from
% PARTIALLY OVERLAPPING raw trials. Cross-validation (splitting each
% condition's pseudotrials into two independent halves) makes the
% estimator unbiased for a given pair, but does NOT remove the bias from
% two DIFFERENT conditions sharing raw trials: a cell built from
% overlapping pools will read as more similar (smaller distance) than the
% true representational distance, regardless of any real neural
% relationship, simply because part of the same physical trial went into
% both conditions being compared. The 12 visual-tactile cells and the 1
% visual-visual cell (D1-D2) are unaffected (fully independent trials).
% A logical `cleanPairMask` (8x8) is saved alongside the RDM marking which
% of the 28 unique cells are clean (trial-disjoint) vs overlap-
% contaminated, computed programmatically from the trigger-code sets -
% use it to filter/caveat any summary statistic computed from this RDM.
%
% Dissimilarity metric: cross-validated squared Euclidean distance
% ("crossnobis"-style, Walther et al. 2016) - see
% rsa_4dir_withinModality_subject.m for the full method description.
%
% Same conventions as the other RSA analyses:
%   - 10 pseudotrials per class (param.pseudo_n = 10), split into two
%     halves of 5 for cross-validation.
%   - Repeated over param.n_iterations (default 20) and averaged.
%   - Downsampling optional (param.ds), default 2x (256 Hz -> 128 Hz).
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
outDir     = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};

%% RSA parameters
param = [];
param.pseudo_n     = 10;
param.n_iterations = 20;
param.ds           = 2;
param.fs           = 256;
param.timewindow   = [];

%% 8 conditions (order: A1 A2 B1 B2 C1 C2 D1 D2)
conds = struct();
conds(1).label = 'somatotopic_pinkyThumb';  conds(1).codes = [23 24 33 34];
conds(2).label = 'somatotopic_fingerWrist'; conds(2).codes = [21 22 31 32];
conds(3).label = 'external_horizontal';     conds(3).codes = [23 24 31 32];
conds(4).label = 'external_vertical';       conds(4).codes = [21 22 33 34];
conds(5).label = 'handPos_up';              conds(5).codes = [21 22 23 24];
conds(6).label = 'handPos_down';            conds(6).codes = [31 32 33 34];
conds(7).label = 'visual_vertical';         conds(7).codes = [13 14];
conds(8).label = 'visual_horizontal';       conds(8).codes = [11 12];

C = numel(conds);
condLabels = {conds.label};

%% clean (trial-disjoint) vs overlap-contaminated pair mask, from trigger-code sets
cleanPairMask = false(C, C);
for ci = 1:C
    for cj = 1:C
        cleanPairMask(ci, cj) = isempty(intersect(conds(ci).codes, conds(cj).codes));
    end
end

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== RSA 8-condition cross-modal: %s ===\n', subDir);
    tSubject = tic;

    subOutDir = fullfile(outDir, subDir);
    if ~exist(subOutDir, 'dir')
        mkdir(subOutDir);
    end

    loaded = load(fullfile(preprocDir, subDir, [subDir '_preprocessed.mat']), 'data_clean');
    data_clean = loaded.data_clean;

    if ~isempty(param.ds)
        cfg = [];
        cfg.resamplefs = param.fs / param.ds;
        data_clean = ft_resampledata(cfg, data_clean);
    end
    if ~isempty(param.timewindow)
        cfg = [];
        cfg.toilim = param.timewindow;
        data_clean = ft_redefinetrial(cfg, data_clean);
    end

    trig  = data_clean.trialinfo(:, 1);
    nTime = size(data_clean.trial{1}, 2);
    nChan = size(data_clean.trial{1}, 1);
    timeVec = data_clean.time{1};
    baseIdx = timeVec < 0;
    postIdx = timeVec >= 0;

    condTrials = cell(1, C);
    for c = 1:C
        idx = find(ismember(trig, conds(c).codes));
        condTrials{c} = cat(3, data_clean.trial{idx}); % chan x time x trial
    end

    rdm_iter = compute_rdm_timeresolved(condTrials, param, nChan, nTime); % n_iter x 8 x 8 x nTime
    rdm_mean = squeeze(mean(rdm_iter, 1)); % 8 x 8 x nTime

    offDiagMask = ~eye(C);
    cleanOffDiagMask = offDiagMask & cleanPairMask;

    meanOffDiagAll   = zeros(1, nTime); % all off-diagonal cells (includes overlap-contaminated)
    meanOffDiagClean = zeros(1, nTime); % only trial-disjoint cells
    for t = 1:nTime
        slice = rdm_mean(:, :, t);
        meanOffDiagAll(t)   = mean(slice(offDiagMask));
        meanOffDiagClean(t) = mean(slice(cleanOffDiagMask));
    end

    results = struct();
    results.rdm = rdm_mean;
    results.condLabels = condLabels;
    results.cleanPairMask = cleanPairMask;
    results.time = timeVec;
    results.meanOffDiagAll = meanOffDiagAll;
    results.meanOffDiagClean = meanOffDiagClean;
    results.rdmBaseline = mean(rdm_mean(:, :, baseIdx), 3);
    results.rdmPostStim = mean(rdm_mean(:, :, postIdx), 3);

    save(fullfile(subOutDir, [subDir '_rsa_tactileFor_vision.mat']), 'results', 'param', '-v7.3');

    %% diagnostic plot
    f = figure('Visible', 'off');

    subplot(1, 3, 1);
    hold on;
    plot(results.time, results.meanOffDiagAll, 'LineWidth', 1.5, 'Color', [0.5 0.5 0.5]);
    plot(results.time, results.meanOffDiagClean, 'LineWidth', 1.5, 'Color', [0.8 0.1 0.1]);
    yline(0, 'k--'); xline(0, 'k-');
    hold off;
    xlabel('Time (s)'); ylabel('Mean cv-distance');
    legend({'all cells', 'clean cells only'}, 'Location', 'best', 'FontSize', 7);
    title('overall distinctiveness');

    subplot(1, 3, 2);
    imagesc(results.rdmBaseline);
    axis square; colorbar;
    set(gca, 'XTick', 1:C, 'XTickLabel', condLabels, 'YTick', 1:C, 'YTickLabel', condLabels, ...
        'TickLabelInterpreter', 'none', 'FontSize', 6);
    title('RDM (baseline)');

    subplot(1, 3, 3);
    imagesc(results.rdmPostStim);
    axis square; colorbar;
    set(gca, 'XTick', 1:C, 'XTickLabel', condLabels, 'YTick', 1:C, 'YTickLabel', condLabels, ...
        'TickLabelInterpreter', 'none', 'FontSize', 6);
    title('RDM (post-stim)');

    sgtitle([subDir ' - 8-condition cross-modal RSA'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1500 500]);
    saveas(f, fullfile(subOutDir, [subDir '_rsa_tactileFor_vision.png']));
    close(f);

    subjectRuntime = toc(tSubject);
    fprintf('%s finished in %.1f s (%.2f min)\n', subDir, subjectRuntime, subjectRuntime/60);

end


%% ---- local functions ----

function rdm_iter = compute_rdm_timeresolved(condTrials, param, nChan, nTime)
% condTrials: 1xC cell array, each chan x time x trial for one condition.
% Returns rdm_iter: n_iterations x C x C x nTime cross-validated squared
% Euclidean distances (crossnobis-style).

C = numel(condTrials);
halfN = floor(param.pseudo_n / 2);
rdm_iter = zeros(param.n_iterations, C, C, nTime);

for iter = 1:param.n_iterations

    half1 = cell(1, C);
    half2 = cell(1, C);

    for c = 1:C
        nTr = size(condTrials{c}, 3);
        nPerGroup = floor(nTr / param.pseudo_n);
        perm = randperm(nTr, nPerGroup * param.pseudo_n);
        perm = reshape(perm, [nPerGroup, param.pseudo_n]);

        pseudo = nan(nChan, nTime, param.pseudo_n);
        for g = 1:param.pseudo_n
            pseudo(:, :, g) = mean(condTrials{c}(:, :, perm(:, g)), 3);
        end

        half1{c} = mean(pseudo(:, :, 1:halfN), 3);           % chan x time
        half2{c} = mean(pseudo(:, :, halfN+1:2*halfN), 3);   % chan x time
    end

    for ci = 1:C
        for cj = 1:C
            diff1 = half1{ci} - half1{cj};
            diff2 = half2{ci} - half2{cj};
            rdm_iter(iter, ci, cj, :) = sum(diff1 .* diff2, 1); % dot product over channels, per timepoint
        end
    end
end

end
