%% Artifact follow-up: is the handPos (tactile-up vs tactile-down) effect
%  seen in ft_mvpa_tactileFrameOfReference genuine or muscle/EMG artifact?
%
% Motivation: ft_mvpa_tactileFrameOfReference_subject.m found that
% handPos decodes at near-ceiling accuracy (~0.9-0.97) in the beta/gamma
% power bands, FLAT across the entire trial including the pre-stimulus
% baseline (i.e. already near-ceiling before the tactile stimulus even
% occurs). That is inconsistent with a stimulus-evoked neural response,
% and beta/gamma is exactly the frequency range most contaminated by
% muscle (EMG) activity, so the leading candidate explanation is a
% posture-related EMG artifact (differing sustained forearm/wrist muscle
% tension between the two static hand positions), not a cortical
% oscillatory code for hand position.
%
% This script runs two checks, using ONLY the pre-stimulus baseline
% window [-0.25 0] s (deliberately excluding any real stimulus-evoked
% activity, to isolate whatever pre-existing/tonic difference separates
% the two blocks):
%
%   A) Per-channel scalp topography of the tactile-up vs tactile-down
%      effect size (Cohen's d) in each of the 5 signal variants (theta /
%      alpha / beta / gamma power, sustainedERP energy). A classic
%      peripheral/"horseshoe" pattern concentrated at frontal/temporal
%      sites (near jaw/neck muscles) supports the EMG-artifact
%      explanation; a focal central/parietal (sensorimotor) pattern would
%      argue against it.
%   B) Baseline-vs-post-stimulus comparison of handPos decoding accuracy
%      and AUC, reusing the already-saved
%      outputs/ft_mvpa_tactileFrameOfReference/<sub>/<sub>_mvpa_tactileFoR_freqBands.mat
%      (no re-decoding needed): if baseline-window accuracy is already as
%      high as the post-stimulus-window accuracy, that's further evidence
%      the effect is not stimulus-locked.
%
% Requires:
%   outputs/preprocess/<sub>/<sub>_preprocessed.mat (see
%     code/preprocess/preprocess_bandstop45.m)
%   outputs/ft_mvpa_tactileFrameOfReference/<sub>/<sub>_mvpa_tactileFoR_freqBands.mat
%     (see code/ft_mvpa_tactileFrameOfReference/ft_mvpa_tactileFrameOfReference_subject.m)

clear;

%% Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;
[~, ftpath] = ft_version;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
preprocDir = fullfile(projectDir, 'outputs', 'preprocess');
ftMvpaDir  = fullfile(projectDir, 'outputs', 'ft_mvpa_tactileFrameOfReference');
outDir     = fullfile(projectDir, 'outputs', 'artifactCheck_handPos');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};

%% Params
param = [];
param.ds = 2;   % downsample factor applied AFTER band-limiting
param.fs = 256;
baselineWindow = [-0.25 0];
postWindow     = [0 1.5];

%% Frequency bands / signal variants (same as ft_mvpa_tactileFrameOfReference)
bands = struct();
bands(1).name = 'theta';        bands(1).freq = [4 7];   bands(1).type = 'power';
bands(2).name = 'alpha';        bands(2).freq = [8 13];  bands(2).type = 'power';
bands(3).name = 'beta';         bands(3).freq = [14 30]; bands(3).type = 'power';
bands(4).name = 'gamma';        bands(4).freq = [31 45]; bands(4).type = 'power';
bands(5).name = 'sustainedERP'; bands(5).freq = [NaN 6]; bands(5).type = 'voltage';

upCodes   = [21 22 23 24];
downCodes = [31 32 33 34];

%% Layout (channel positions for the topography scatter plot)
cfg = [];
cfg.layout = fullfile(ftpath, 'template', 'layout', 'biosemi128.lay');
layout = ft_prepare_layout(cfg);
keep = ~ismember(layout.label, {'COMNT', 'SCALE'});
layoutLabel = layout.label(keep);
layoutPos   = layout.pos(keep, :);

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== Artifact check (handPos): %s ===\n', subDir);

    subOutDir = fullfile(outDir, subDir);
    if ~exist(subOutDir, 'dir')
        mkdir(subOutDir);
    end

    loaded = load(fullfile(preprocDir, subDir, [subDir '_preprocessed.mat']), 'data_clean');
    data_clean_raw = loaded.data_clean;
    trig = data_clean_raw.trialinfo(:, 1);

    results = struct();
    bandNames = {bands.name};

    effectPerBand     = cell(1, numel(bands));
    chanLabelsPerBand = cell(1, numel(bands));

    %% Part A: per-channel Cohen's d topography, pre-stimulus baseline only
    for bi = 1:numel(bands)
        band = bands(bi);
        fprintf(' band: %s\n', band.name);

        data_band = fn_apply_band_filter(data_clean_raw, band);

        if ~isempty(param.ds)
            cfg = [];
            cfg.resamplefs = param.fs / param.ds;
            data_band = ft_resampledata(cfg, data_band);
        end

        timeVec = data_band.time{1};
        baseIdx = timeVec >= baselineWindow(1) & timeVec < baselineWindow(2);
        nChan = size(data_band.trial{1}, 1);

        idxUp   = find(ismember(trig, upCodes));
        idxDown = find(ismember(trig, downCodes));

        % per-trial, per-channel scalar summarising the baseline window:
        % mean power for the oscillatory bands, variance (energy) for the
        % low-passed sustainedERP signal (keeps consistent "energy"
        % semantics across all 5 signal variants)
        if strcmp(band.type, 'power')
            summariseFn = @(x) mean(x(:, baseIdx), 2);
        else
            summariseFn = @(x) var(x(:, baseIdx), 0, 2);
        end

        valsUp   = cell2mat(cellfun(@(x) summariseFn(x)', data_band.trial(idxUp), 'UniformOutput', false)'); % nUp x nChan
        valsDown = cell2mat(cellfun(@(x) summariseFn(x)', data_band.trial(idxDown), 'UniformOutput', false)'); % nDown x nChan

        meanUp = mean(valsUp, 1); meanDown = mean(valsDown, 1);
        varUp  = var(valsUp, 0, 1); varDown = var(valsDown, 0, 1);
        nUp = size(valsUp, 1); nDown = size(valsDown, 1);
        pooledStd = sqrt(((nUp-1)*varUp + (nDown-1)*varDown) / (nUp+nDown-2));

        cohend = (meanUp - meanDown) ./ pooledStd;

        results.(band.name).cohend = cohend(:);
        results.(band.name).chanLabels = data_band.label;
        results.(band.name).meanUp = meanUp(:);
        results.(band.name).meanDown = meanDown(:);

        effectPerBand{bi} = cohend(:);
        chanLabelsPerBand{bi} = data_band.label;
    end

    fn_plot_topo_effect(fullfile(subOutDir, [subDir '_artifactCheck_topo.png']), ...
        bandNames, effectPerBand, chanLabelsPerBand, layoutLabel, layoutPos, ...
        [subDir ' - tactile up vs down, baseline-window effect size']);

    %% Part B: baseline-vs-post-stimulus handPos decoding comparison
    % (reuses the already-saved ft_mvpa_tactileFrameOfReference results)
    ftMvpaFile = fullfile(ftMvpaDir, subDir, [subDir '_mvpa_tactileFoR_freqBands.mat']);
    if exist(ftMvpaFile, 'file')
        loadedMvpa = load(ftMvpaFile, 'results');
        mvpaResults = loadedMvpa.results;

        baselineAcc = zeros(1, numel(bands)); postAcc = zeros(1, numel(bands));
        baselineAuc = zeros(1, numel(bands)); postAuc = zeros(1, numel(bands));

        for bi = 1:numel(bands)
            r = mvpaResults.(bands(bi).name).handPos;
            tv = r.time;
            accMean = mean(r.acc, 1);
            aucMean = mean(r.auc, 1);

            baseIdxD = tv >= baselineWindow(1) & tv < baselineWindow(2);
            postIdxD = tv >= postWindow(1) & tv <= postWindow(2);

            baselineAcc(bi) = mean(accMean(baseIdxD));
            postAcc(bi)     = mean(accMean(postIdxD));
            baselineAuc(bi) = mean(aucMean(baseIdxD));
            postAuc(bi)     = mean(aucMean(postIdxD));
        end

        results.baselineVsPost.bandNames   = bandNames;
        results.baselineVsPost.baselineAcc = baselineAcc;
        results.baselineVsPost.postAcc     = postAcc;
        results.baselineVsPost.baselineAuc = baselineAuc;
        results.baselineVsPost.postAuc     = postAuc;

        f = figure('Visible', 'off');
        subplot(1, 2, 1);
        bar([baselineAcc; postAcc]');
        set(gca, 'XTickLabel', bandNames);
        ylabel('handPos accuracy'); ylim([0 1]); yline(0.5, 'k--');
        legend({'baseline [-0.25 0]s', 'post-stim [0 1.5]s'}, 'Location', 'southoutside');
        title('Accuracy');

        subplot(1, 2, 2);
        bar([baselineAuc; postAuc]');
        set(gca, 'XTickLabel', bandNames);
        ylabel('handPos AUC'); ylim([0 1]); yline(0.5, 'k--');
        legend({'baseline [-0.25 0]s', 'post-stim [0 1.5]s'}, 'Location', 'southoutside');
        title('AUC');

        sgtitle([subDir ' - handPos decoding: baseline vs. post-stimulus'], 'Interpreter', 'none');
        set(f, 'Position', [0 0 900 500]);
        saveas(f, fullfile(subOutDir, [subDir '_artifactCheck_baselineVsPost.png']));
        close(f);
    else
        warning('%s: ft_mvpa_tactileFrameOfReference results not found, skipping Part B.', subDir);
    end

    save(fullfile(subOutDir, [subDir '_artifactCheck_handPos.mat']), 'results', 'bands', '-v7.3');
    fprintf('%s done\n', subDir);

end
