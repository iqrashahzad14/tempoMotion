%% SNR analysis (1): baseline-vs-response variance ratio - per subject
%
% (1) baseline-vs-response variance ratio — compute variance in the
% post-stimulus window vs. the pre-stimulus baseline window (per
% channel/ROI, per direction), essentially signal power over noise-floor
% power; simple and doesn't need trial-level access, but sensitive to
% which time window you pick.
%
% For each subject, each modality block (visual, tactile up, tactile
% down), and both direction-level and axis-of-motion conditions: computes
% the condition-averaged ERP (ft_timelockanalysis), then per channel:
%   SNR_dB = 10*log10( var(response window) / var(baseline window) )
% Generates a per-channel scatter-topography plot and 3 ROI-averaged bar
% charts per block/analysis combination (see fn_plot_snr_block.m).
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

%% Time windows
% Adjust responseWindow if you want to focus on an earlier ERP window
% instead of the whole post-stimulus epoch.
baselineWindow = [-0.25 0];
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
    fprintf('\n=== SNR variance-ratio: %s ===\n', subDir);

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
        [snrVec, chanLabels] = compute_variance_ratio_snr(data_clean, trig, dirCodesCell, baselineWindow, responseWindow);
        snr.(blk.name).direction.labels = blk.dirLabels;
        snr.(blk.name).direction.snr_dB = snrVec;
        snr.(blk.name).direction.chanLabels = chanLabels;

        fn_plot_snr_block(fullfile(blkOutDir, 'direction', 'variance_ratio'), blk.dirLabels, snrVec, chanLabels, ...
            roiChans, layoutLabel, layoutPos, sprintf('%s - %s - direction (variance-ratio SNR)', subDir, blk.name), 'SNR (dB)');

        %% axis-of-motion SNR
        [snrVecA, chanLabelsA] = compute_variance_ratio_snr(data_clean, trig, blk.axisCodes, baselineWindow, responseWindow);
        snr.(blk.name).axis.labels = blk.axisLabels;
        snr.(blk.name).axis.snr_dB = snrVecA;
        snr.(blk.name).axis.chanLabels = chanLabelsA;

        fn_plot_snr_block(fullfile(blkOutDir, 'axis', 'variance_ratio'), blk.axisLabels, snrVecA, chanLabelsA, ...
            roiChans, layoutLabel, layoutPos, sprintf('%s - %s - axis of motion (variance-ratio SNR)', subDir, blk.name), 'SNR (dB)');
    end

    save(fullfile(subOutDir, [subDir '_snr_variance_ratio.mat']), 'snr', '-v7.3');
    fprintf('Saved variance-ratio SNR results and plots for %s\n', subDir);

end


%% ---- local functions ----

function [snrVec, chanLabelsOut] = compute_variance_ratio_snr(data_clean, trig, condCodesCell, baselineWindow, responseWindow)
% Per condition (each cell = a vector of trigger codes pooled into one
% condition), compute the condition-averaged ERP and return, per channel,
% 10*log10( var(response window) / var(baseline window) ).

nCond = numel(condCodesCell);
snrVec = cell(1, nCond);
chanLabelsOut = cell(1, nCond);

for c = 1:nCond
    cfg = [];
    cfg.trials = find(ismember(trig, condCodesCell{c}));
    tl = ft_timelockanalysis(cfg, data_clean);

    baseIdx = tl.time >= baselineWindow(1) & tl.time < baselineWindow(2);
    respIdx = tl.time >= responseWindow(1) & tl.time <= responseWindow(2);

    baseVar = var(tl.avg(:, baseIdx), 0, 2);
    respVar = var(tl.avg(:, respIdx), 0, 2);

    snrVec{c} = 10 * log10(respVar ./ baseVar);
    chanLabelsOut{c} = tl.label;
end

end
