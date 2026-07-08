%% RSA: cross-modal alignment between vision and tactile frames of reference
%
% Time-resolved RSA test of visual-tactile alignment - the RSA
% counterpart to code/mvpa_crossModal_visualTactile/, and the more
% standard method (matching the fMRI study this EEG study follows up on,
% Shahzad et al. 2026) for testing whether visual and tactile motion-axis
% representations share structure.
%
% Trigger classes:
%   visual_vertical         = [13 14]
%   visual_horizontal       = [11 12]
%   somatotopic_fingerWrist = [21 22 31 32]  (pooled across tactile-up + tactile-down)
%   somatotopic_pinkyThumb  = [23 24 33 34]  (pooled across tactile-up + tactile-down)
%   external_vertical       = [21 22 33 34]
%   external_horizontal     = [23 24 31 32]
%
% For each of 2 target framings (somatotopic, external), a single 4x4 RDM
% is built combining BOTH visual conditions AND both tactile conditions
% together (unlike mvpa_crossModal_visualTactile, which trains a
% classifier in one modality and tests in the other, this puts all 4
% conditions in one shared representational space and looks at the
% cross-modal quadrant of the resulting RDM directly).
%
% Dissimilarity metric: cross-validated squared Euclidean distance
% ("crossnobis"-style, Walther et al. 2016) - see
% rsa_4dir_withinModality_subject.m for the full method description.
%
% Alignment index: for each framing, conditions are ordered
% [visual_vertical, visual_horizontal, tacA, tacB]. A "matched"
% correspondence is assumed (tacA corresponds to visual_vertical, tacB to
% visual_horizontal):
%   - external: this correspondence is given directly by the trigger
%     naming (external_vertical <-> visual_vertical), so it is principled.
%   - somatotopic: there is no a priori spatial correspondence (finger-wrist
%     and pinky-thumb are skin-based, not defined in visual/spatial
%     terms), so this pairing (fingerWrist<->vertical, pinkyThumb<->horizontal)
%     is an ARBITRARY convention (matching the label order used in
%     mvpa_crossModal_visualTactile_subject.m for consistency). If the true
%     correspondence is reversed, a real alignment effect would show up
%     as a negative index rather than disappearing.
%
%   alignIndex(t) = mismatched_sum(t) - matched_sum(t)
%                 = [dist(vis_vert,tacB) + dist(vis_horiz,tacA)]
%                 - [dist(vis_vert,tacA) + dist(vis_horiz,tacB)]
%   Positive alignIndex = evidence FOR alignment (matched pairs are more
%   similar / smaller distance than mismatched pairs).
%
% Follows the same conventions as the other analyses:
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

%% Trigger classes
visualCodes = {[13 14], [11 12]}; % [visual_vertical, visual_horizontal]
visualLabels = {'visual_vertical', 'visual_horizontal'};

targets = struct();
targets(1).name = 'somatotopic';
targets(1).tacCodes  = {[21 22 31 32], [23 24 33 34]};
targets(1).tacLabels = {'somatotopic_fingerWrist', 'somatotopic_pinkyThumb'};

targets(2).name = 'external';
targets(2).tacCodes  = {[21 22 33 34], [23 24 31 32]};
targets(2).tacLabels = {'external_vertical', 'external_horizontal'};

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== RSA cross-modal alignment: %s ===\n', subDir);
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

    visTrials = cell(1, 2);
    for c = 1:2
        idx = find(ismember(trig, visualCodes{c}));
        visTrials{c} = cat(3, data_clean.trial{idx});
    end

    results = struct();

    for ti = 1:numel(targets)
        tgt = targets(ti);
        fprintf('  target: %s (%s vs %s)\n', tgt.name, tgt.tacLabels{1}, tgt.tacLabels{2});

        tacTrials = cell(1, 2);
        for c = 1:2
            idx = find(ismember(trig, tgt.tacCodes{c}));
            tacTrials{c} = cat(3, data_clean.trial{idx});
        end

        % condition order: [visual_vertical, visual_horizontal, tacA, tacB]
        condTrials = [visTrials, tacTrials];
        condLabels = [visualLabels, tgt.tacLabels];

        rdm_iter = compute_rdm_timeresolved(condTrials, param, nChan, nTime); % n_iter x 4 x 4 x nTime
        rdm_mean = squeeze(mean(rdm_iter, 1)); % 4 x 4 x nTime

        withinVis = squeeze(rdm_mean(1, 2, :))'; % vis_vert vs vis_horiz
        withinTac = squeeze(rdm_mean(3, 4, :))'; % tacA vs tacB

        matched_sum    = squeeze(rdm_mean(1, 3, :))' + squeeze(rdm_mean(2, 4, :))'; % vis_vert-tacA + vis_horiz-tacB
        mismatched_sum = squeeze(rdm_mean(1, 4, :))' + squeeze(rdm_mean(2, 3, :))'; % vis_vert-tacB + vis_horiz-tacA
        alignIndex = mismatched_sum - matched_sum;

        results.(tgt.name).rdm = rdm_mean;
        results.(tgt.name).condLabels = condLabels;
        results.(tgt.name).time = timeVec;
        results.(tgt.name).withinVis = withinVis;
        results.(tgt.name).withinTac = withinTac;
        results.(tgt.name).alignIndex = alignIndex;
        results.(tgt.name).rdmBaseline = mean(rdm_mean(:, :, baseIdx), 3);
        results.(tgt.name).rdmPostStim = mean(rdm_mean(:, :, postIdx), 3);
    end

    save(fullfile(subOutDir, [subDir '_rsa_tactileFor_vision.mat']), 'results', 'param', '-v7.3');

    %% diagnostic plot
    targetNames = {targets.name};
    f = figure('Visible', 'off');
    for ti = 1:numel(targetNames)
        tn = targetNames{ti};

        subplot(numel(targetNames), 3, (ti-1)*3 + 1);
        hold on;
        plot(results.(tn).time, results.(tn).alignIndex, 'LineWidth', 1.5, 'Color', [0.8 0.1 0.1]);
        plot(results.(tn).time, results.(tn).withinVis, '--', 'LineWidth', 1, 'Color', [0.2 0.5 0.9]);
        plot(results.(tn).time, results.(tn).withinTac, '--', 'LineWidth', 1, 'Color', [0.3 0.7 0.3]);
        yline(0, 'k--'); xline(0, 'k-');
        hold off;
        xlabel('Time (s)'); ylabel('cv-distance');
        legend({'alignment index', 'within-vis dist', 'within-tac dist'}, 'Location', 'best', 'FontSize', 6);
        title([tn ' - alignment index'], 'Interpreter', 'none');

        subplot(numel(targetNames), 3, (ti-1)*3 + 2);
        imagesc(results.(tn).rdmBaseline);
        axis square; colorbar;
        set(gca, 'XTick', 1:4, 'XTickLabel', results.(tn).condLabels, 'YTick', 1:4, 'YTickLabel', results.(tn).condLabels, ...
            'TickLabelInterpreter', 'none', 'FontSize', 6);
        title([tn ' - RDM (baseline)'], 'Interpreter', 'none');

        subplot(numel(targetNames), 3, (ti-1)*3 + 3);
        imagesc(results.(tn).rdmPostStim);
        axis square; colorbar;
        set(gca, 'XTick', 1:4, 'XTickLabel', results.(tn).condLabels, 'YTick', 1:4, 'YTickLabel', results.(tn).condLabels, ...
            'TickLabelInterpreter', 'none', 'FontSize', 6);
        title([tn ' - RDM (post-stim)'], 'Interpreter', 'none');
    end
    sgtitle([subDir ' - cross-modal RSA (vision + tactile FoR)'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1300 700]);
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

        half1{c} = mean(pseudo(:, :, 1:halfN), 3);
        half2{c} = mean(pseudo(:, :, halfN+1:2*halfN), 3);
    end

    for ci = 1:C
        for cj = 1:C
            diff1 = half1{ci} - half1{cj};
            diff2 = half2{ci} - half2{cj};
            rdm_iter(iter, ci, cj, :) = sum(diff1 .* diff2, 1);
        end
    end
end

end
