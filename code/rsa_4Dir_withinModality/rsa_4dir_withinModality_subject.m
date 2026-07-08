%% RSA: 4-direction representational dissimilarity within each modality block
%
% Time-resolved representational similarity analysis (RSA) for the 4
% directions within each of visual / tactile-up / tactile-down, for each
% subject - the RSA counterpart to code/mvpa_4Dir_withinModality/.
%
% Dissimilarity metric: cross-validated squared Euclidean distance
% ("crossnobis"-style, Walther et al. 2016). For each pair of conditions
% (i, j) and at each timepoint: pseudotrials are split into two
% independent halves, a mean pattern is computed per condition per half,
% and the dissimilarity is the dot product of (mean_i - mean_j) from half
% 1 with (mean_i - mean_j) from half 2. This is an UNBIASED estimator of
% the true squared distance between condition means (unlike a naive
% same-data distance, which is always positive due to noise) - it can be
% negative when there is no true difference, centered at 0 under the
% null. This also means no classifier is trained at all - RSA distances
% are just linear algebra on averaged patterns, so this is much cheaper
% to compute than the MVPA decoding scripts.
%
% Follows the same conventions as the other analyses:
%   - 10 pseudotrials per class (param.pseudo_n = 10), split into two
%     halves of 5 for cross-validation.
%   - Repeated over param.n_iterations (default 20) and averaged, to
%     average out the randomness in trial-to-pseudotrial assignment.
%   - Downsampling optional (param.ds), default 2x (256 Hz -> 128 Hz).
%
% For each block, produces:
%   - a time-course of the mean pairwise dissimilarity across all 6
%     direction pairs (an "overall representational distinctiveness"
%     measure, analogous to the averaged pairwise decoding accuracy used
%     in the MVPA version)
%   - a representative 4x4 RDM heatmap, averaged over a baseline window
%     (-0.25 to 0s) and a post-stimulus window (0 to end), to visualize
%     which directions are more/less distinguishable from each other.
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
outDir     = fullfile(projectDir, 'outputs', 'rsa_4Dir_withinModality');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};

%% RSA parameters
param = [];
param.pseudo_n     = 10;    % pseudotrials per class (split into 2 halves of 5 for cross-validation)
param.n_iterations = 20;    % repeat pseudotrial assignment this many times
param.ds           = 2;     % downsample factor; [] to skip
param.fs           = 256;   % sampling rate of the preprocessed data
param.timewindow   = [];    % [] = full epoch

%% Blocks (4 directions each)
blocks = struct();
blocks(1).name = 'visual';       blocks(1).trig = [11 12 13 14]; blocks(1).labels = {'left','right','up','down'};
blocks(2).name = 'tactile_up';   blocks(2).trig = [21 22 23 24]; blocks(2).labels = {'wristFinger','fingerWrist','pinkyThumb','thumbPinky'};
blocks(3).name = 'tactile_down'; blocks(3).trig = [31 32 33 34]; blocks(3).labels = {'wristFinger','fingerWrist','pinkyThumb','thumbPinky'};

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== RSA 4-direction: %s ===\n', subDir);
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

    results = struct();

    for b = 1:numel(blocks)
        blk = blocks(b);
        fprintf('  block: %s\n', blk.name);

        condTrials = cell(1, numel(blk.trig));
        for c = 1:numel(blk.trig)
            idx = find(trig == blk.trig(c));
            condTrials{c} = cat(3, data_clean.trial{idx}); % chan x time x trial
        end

        rdm_iter = compute_rdm_timeresolved(condTrials, param, nChan, nTime);
        rdm_mean = squeeze(mean(rdm_iter, 1)); % C x C x nTime

        C = numel(blk.trig);
        offDiagMask = ~eye(C);
        meanOffDiag = zeros(1, nTime);
        for t = 1:nTime
            slice = rdm_mean(:, :, t);
            meanOffDiag(t) = mean(slice(offDiagMask));
        end

        results.(blk.name).rdm = rdm_mean;
        results.(blk.name).meanOffDiag = meanOffDiag;
        results.(blk.name).time = timeVec;
        results.(blk.name).labels = blk.labels;
        results.(blk.name).rdmBaseline = mean(rdm_mean(:, :, baseIdx), 3);
        results.(blk.name).rdmPostStim = mean(rdm_mean(:, :, postIdx), 3);
    end

    save(fullfile(subOutDir, [subDir '_rsa_4dir.mat']), 'results', 'param', '-v7.3');

    %% diagnostic plot
    blockNames = {blocks.name};
    f = figure('Visible', 'off');
    for b = 1:numel(blockNames)
        bn = blockNames{b};

        subplot(numel(blockNames), 3, (b-1)*3 + 1);
        plot(results.(bn).time, results.(bn).meanOffDiag, 'LineWidth', 1.5);
        hold on; yline(0, 'k--'); xline(0, 'k-'); hold off;
        xlabel('Time (s)'); ylabel('Mean cv-distance');
        title([strrep(bn, '_', ' ') ' - overall distinctiveness']);

        subplot(numel(blockNames), 3, (b-1)*3 + 2);
        imagesc(results.(bn).rdmBaseline);
        axis square; colorbar;
        set(gca, 'XTick', 1:numel(results.(bn).labels), 'XTickLabel', results.(bn).labels, ...
            'YTick', 1:numel(results.(bn).labels), 'YTickLabel', results.(bn).labels, ...
            'TickLabelInterpreter', 'none', 'FontSize', 7);
        title([strrep(bn, '_', ' ') ' - RDM (baseline)']);

        subplot(numel(blockNames), 3, (b-1)*3 + 3);
        imagesc(results.(bn).rdmPostStim);
        axis square; colorbar;
        set(gca, 'XTick', 1:numel(results.(bn).labels), 'XTickLabel', results.(bn).labels, ...
            'YTick', 1:numel(results.(bn).labels), 'YTickLabel', results.(bn).labels, ...
            'TickLabelInterpreter', 'none', 'FontSize', 7);
        title([strrep(bn, '_', ' ') ' - RDM (post-stim)']);
    end
    sgtitle([subDir ' - 4-direction RSA'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1300 900]);
    saveas(f, fullfile(subOutDir, [subDir '_rsa_4dir.png']));
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
