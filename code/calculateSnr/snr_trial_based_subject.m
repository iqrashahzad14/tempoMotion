%% SNR analysis (2): trial-based SNR - per subject
%
% (2) trial-based SNR — using the single-trial data (not just the
% averaged ERP), compute the peak amplitude relative to the standard
% error across trials at that time point, which directly reflects how
% much statistical reliability you're getting from the number of trials
% retained per condition (relevant here since trial counts vary 90–104
% after artifact rejection).
%
% For each subject, each modality block (visual, tactile up, tactile
% down), and both direction-level and axis-of-motion conditions: for
% every channel and time point, computes
%   tSNR(t) = mean_over_trials(t) / SEM_over_trials(t)
% (a one-sample-t-statistic-like reliability measure), then takes
%   peak SNR = max(|tSNR(t)|) over the response window
% as the per-channel summary. Generates a per-channel scatter-topography
% plot and 3 ROI-averaged bar charts per block/analysis combination (see
% fn_plot_snr_block.m). Trial counts per condition are stored alongside
% the SNR values since they directly determine this metric.
%
% Requires outputs/preprocess/<sub>/<sub>_preprocessed.mat (see
% code/preprocess/preprocess_bandstop45.m).

clear;

%% Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;
[~, ftpath] = ft_version;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
preprocDir = fullfile(projectDir, 'outputs', 'preprocess');
outDir     = fullfile(projectDir, 'outputs', 'calculateSnr');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};

%% Time window
% Adjust if you want to focus on an earlier ERP window instead of the
% whole post-stimulus epoch.
responseWindow = [0 1.496];

%% Condition definitions per block (same as code/erp/erp_subject.m)
blocks = struct();

blocks(1).name       = 'visual';
blocks(1).dirCodes   = [11 12 13 14];
blocks(1).dirLabels  = {'left', 'right', 'up', 'down'};
blocks(1).axisCodes  = {[13 14], [11 12]};
blocks(1).axisLabels = {'vertical', 'horizontal'};

blocks(2).name       = 'tactile_up';
blocks(2).dirCodes   = [21 22 23 24];
blocks(2).dirLabels  = {'wrist_to_finger', 'finger_to_wrist', 'pinky_to_thumb', 'thumb_to_pinky'};
blocks(2).axisCodes  = {[21 22], [23 24]};
blocks(2).axisLabels = {'finger_wrist', 'pinky_thumb'};

blocks(3).name       = 'tactile_down';
blocks(3).dirCodes   = [31 32 33 34];
blocks(3).dirLabels  = {'wrist_to_finger', 'finger_to_wrist', 'pinky_to_thumb', 'thumb_to_pinky'};
blocks(3).axisCodes  = {[31 32], [33 34]};
blocks(3).axisLabels = {'finger_wrist', 'pinky_thumb'};

%% Channel ROIs (same as code/erp/erp_subject.m; derived from biosemi128.lay coordinates)
roiChans.occipital = {'A11', 'A12', 'A13', 'A14', 'A15', 'A22', 'A23', 'A24', 'A25', 'A26', 'A27', 'A28', 'B8', 'B9'};
roiChans.centroparietal = {'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9', 'A16', 'A17', 'A18', 'A19', 'A20', 'A21', 'A29', 'A30', 'A31', 'A32', 'B3', 'B4', 'B5', 'B6'};

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
    fprintf('\n=== SNR trial-based: %s ===\n', subDir);

    subOutDir = fullfile(outDir, subDir);
    if ~exist(subOutDir, 'dir')
        mkdir(subOutDir);
    end

    loaded = load(fullfile(preprocDir, subDir, [subDir '_preprocessed.mat']), 'data_clean');
    data_clean = loaded.data_clean;
    trig = data_clean.trialinfo(:, 1);

    snr = struct();

    for b = 1:numel(blocks)
        blk = blocks(b);
        blkOutDir = fullfile(subOutDir, blk.name);

        %% direction-level SNR
        dirCodesCell = num2cell(blk.dirCodes);
        [snrVec, chanLabels, nTrials] = compute_trial_based_snr(data_clean, trig, dirCodesCell, responseWindow);
        snr.(blk.name).direction.labels = blk.dirLabels;
        snr.(blk.name).direction.snr = snrVec;
        snr.(blk.name).direction.chanLabels = chanLabels;
        snr.(blk.name).direction.nTrials = nTrials;

        fn_plot_snr_block(fullfile(blkOutDir, 'direction', 'trial_based'), blk.dirLabels, snrVec, chanLabels, ...
            roiChans, layoutLabel, layoutPos, sprintf('%s - %s - direction (trial-based SNR)', subDir, blk.name), 'SNR (signal / SEM)');

        %% axis-of-motion SNR
        [snrVecA, chanLabelsA, nTrialsA] = compute_trial_based_snr(data_clean, trig, blk.axisCodes, responseWindow);
        snr.(blk.name).axis.labels = blk.axisLabels;
        snr.(blk.name).axis.snr = snrVecA;
        snr.(blk.name).axis.chanLabels = chanLabelsA;
        snr.(blk.name).axis.nTrials = nTrialsA;

        fn_plot_snr_block(fullfile(blkOutDir, 'axis', 'trial_based'), blk.axisLabels, snrVecA, chanLabelsA, ...
            roiChans, layoutLabel, layoutPos, sprintf('%s - %s - axis of motion (trial-based SNR)', subDir, blk.name), 'SNR (signal / SEM)');
    end

    save(fullfile(subOutDir, [subDir '_snr_trial_based.mat']), 'snr', '-v7.3');
    fprintf('Saved trial-based SNR results and plots for %s\n', subDir);

end


%% ---- local functions ----

function [snrVec, chanLabelsOut, nTrialsOut] = compute_trial_based_snr(data_clean, trig, condCodesCell, responseWindow)
% Per condition (each cell = a vector of trigger codes pooled into one
% condition), builds a channel x time x trial array from the single
% trials, computes tSNR(t) = mean_over_trials(t) / SEM_over_trials(t) per
% channel, and returns the peak |tSNR| over the response window.

nCond = numel(condCodesCell);
snrVec = cell(1, nCond);
chanLabelsOut = cell(1, nCond);
nTrialsOut = zeros(1, nCond);

time = data_clean.time{1};
respIdx = time >= responseWindow(1) & time <= responseWindow(2);

for c = 1:nCond
    trialIdx = find(ismember(trig, condCodesCell{c}));
    nTrialsOut(c) = numel(trialIdx);

    trialsArray = cat(3, data_clean.trial{trialIdx}); % channel x time x trial

    meanTrace = mean(trialsArray, 3);
    semTrace  = std(trialsArray, 0, 3) ./ sqrt(nTrialsOut(c));
    tStat = meanTrace ./ semTrace;

    snrVec{c} = max(abs(tStat(:, respIdx)), [], 2);
    chanLabelsOut{c} = data_clean.label;
end

end
