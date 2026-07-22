%% RSA: 6-condition RAW FACTORIAL cross-modal RDM (no pooling)
%
% Time-resolved RSA over 6 FULLY DISJOINT conditions, forming a single
% 6x6 RDM per timepoint. Unlike rsa_tactileFor_vision_subject.m (8
% conditions, but 3 of them - somatotopic, external, handPos - are
% pooled/marginalized 2-way splits of the same underlying 2x2 tactile
% design, so their pairwise cells overlap in raw trials), this version
% uses the 4 RAW tactile factorial cells directly, with NO pooling:
%
%   1: up_fingerWrist    = [21 22]
%   2: up_pinkyThumb     = [23 24]
%   3: down_fingerWrist  = [31 32]
%   4: down_pinkyThumb   = [33 34]
%   5: visual_vertical   = [13 14]
%   6: visual_horizontal = [11 12]
%
% Every pair of conditions is trial-disjoint (no shared raw trials), so
% there is no overlap-contamination caveat here (contrast with the 8x8
% pooled RDM's 12 overlap-contaminated tactile-tactile cells). This also
% means a genuine axis x posture INTERACTION contrast can be defined
% that is mathematically independent of the two main effects (axis,
% posture) - not possible with the pooled 8-condition design, where only
% 3 non-trivial 2-way splits exist and all cells are already used by the
% 3 pooled "factors" (somatotopic, external, handPos).
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

%% 6 raw factorial conditions (order: A1 A2 B1 B2 C1 C2)
conds = struct();
conds(1).label = 'up_fingerWrist';    conds(1).codes = [21 22];
conds(2).label = 'up_pinkyThumb';     conds(2).codes = [23 24];
conds(3).label = 'down_fingerWrist';  conds(3).codes = [31 32];
conds(4).label = 'down_pinkyThumb';   conds(4).codes = [33 34];
conds(5).label = 'visual_vertical';   conds(5).codes = [13 14];
conds(6).label = 'visual_horizontal'; conds(6).codes = [11 12];

C = numel(conds);
condLabels = {conds.label};

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== RSA raw-factorial cross-modal: %s ===\n', subDir);
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

    rdm_iter = compute_rdm_timeresolved(condTrials, param, nChan, nTime); % n_iter x 6 x 6 x nTime
    rdm_mean = squeeze(mean(rdm_iter, 1)); % 6 x 6 x nTime

    offDiagMask = ~eye(C);
    meanOffDiag = zeros(1, nTime);
    for t = 1:nTime
        slice = rdm_mean(:, :, t);
        meanOffDiag(t) = mean(slice(offDiagMask));
    end

    results = struct();
    results.rdm = rdm_mean;
    results.condLabels = condLabels;
    results.time = timeVec;
    results.meanOffDiag = meanOffDiag;
    results.rdmBaseline = mean(rdm_mean(:, :, baseIdx), 3);
    results.rdmPostStim = mean(rdm_mean(:, :, postIdx), 3);

    save(fullfile(subOutDir, [subDir '_rsa_tactileFor_vision_rawFactorial.mat']), 'results', 'param', '-v7.3');

    %% diagnostic plot
    f = figure('Visible', 'off');

    subplot(1, 3, 1);
    plot(results.time, results.meanOffDiag, 'LineWidth', 1.5, 'Color', [0.8 0.1 0.1]);
    hold on; yline(0, 'k--'); xline(0, 'k-'); hold off;
    xlabel('Time (s)'); ylabel('Mean cv-distance');
    title('overall distinctiveness');

    subplot(1, 3, 2);
    imagesc(results.rdmBaseline);
    axis square; colorbar;
    set(gca, 'XTick', 1:C, 'XTickLabel', condLabels, 'YTick', 1:C, 'YTickLabel', condLabels, ...
        'TickLabelInterpreter', 'none', 'FontSize', 6, 'XTickLabelRotation', 90);
    title('RDM (baseline)');

    subplot(1, 3, 3);
    imagesc(results.rdmPostStim);
    axis square; colorbar;
    set(gca, 'XTick', 1:C, 'XTickLabel', condLabels, 'YTick', 1:C, 'YTickLabel', condLabels, ...
        'TickLabelInterpreter', 'none', 'FontSize', 6, 'XTickLabelRotation', 90);
    title('RDM (post-stim)');

    sgtitle([subDir ' - 6-condition raw-factorial cross-modal RSA'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1500 550]);
    saveas(f, fullfile(subOutDir, [subDir '_rsa_tactileFor_vision_rawFactorial.png']));
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
