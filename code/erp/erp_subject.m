%% ERP analysis - per subject
% For each subject and each modality block (visual, tactile up, tactile
% down), computes:
%   a) per-direction ERPs (ft_timelockanalysis on each direction trigger)
%   b) per-axis-of-motion ERPs (directions pooled into 2 axis conditions)
%
% and generates 4 summary plots per block/analysis combination:
%   all_channels.png, across_channel.png, centroparietal.png, occipital.png
% (see fn_plot_erp_block.m)
%
% Trigger codes (see code/src/triggerNotes.m):
%   visual:       11 left, 12 right, 13 up, 14 down
%   tactile up:   21 wrist->finger, 22 finger->wrist, 23 pinky->thumb, 24 thumb->pinky
%   tactile down: 31 wrist->finger, 32 finger->wrist, 33 pinky->thumb, 34 thumb->pinky
%
% Axis-of-motion grouping:
%   visual:       vertical = up+down, horizontal = left+right
%   tactile up:   finger_wrist = wrist->finger+finger->wrist, pinky_thumb = pinky->thumb+thumb->pinky
%   tactile down: same grouping as tactile up
%
% Requires outputs/derivatives/preprocess/<sub>/<sub>_preprocessed.mat (see
% code/preprocess/preprocess_bandstop45.m).

clear;

%% Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;
[~, ftpath] = ft_version;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
preprocDir = fullfile(projectDir, 'outputs', 'derivatives', 'preprocess');
outDir     = fullfile(projectDir, 'outputs', 'derivatives', 'erp');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006', ...
            'sub-007', 'sub-008', 'sub-009', 'sub-010', 'sub-011', 'sub-012', ...
            'sub-014'};  % sub-014 added 2026-10-22 (sub-013, sub-015 still to be preprocessed)

%% Condition definitions per block
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

%% Channel ROIs
% Derived from the biosemi128.lay layout coordinates (y = anterior(+) /
% posterior(-), x = left(-) / right(+)):
%   occipital       : y <= -0.30, |x| <= 0.35  (posterior pole cluster)
%   centro-parietal : -0.30 < y <= -0.03, |x| <= 0.25 (central-parietal band)
roiChans.occipital = {'A11', 'A12', 'A13', 'A14', 'A15', 'A22', 'A23', 'A24', 'A25', 'A26', 'A27', 'A28', 'B8', 'B9'};
roiChans.centroparietal = {'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9', 'A16', 'A17', 'A18', 'A19', 'A20', 'A21', 'A29', 'A30', 'A31', 'A32', 'B3', 'B4', 'B5', 'B6'};

%% Channel order (anterior -> posterior) for the all-channel heatmap view
cfg = [];
cfg.layout = fullfile(ftpath, 'template', 'layout', 'biosemi128.lay');
layout = ft_prepare_layout(cfg);
keep = ~ismember(layout.label, {'COMNT', 'SCALE'});
layoutLabel = layout.label(keep);
layoutPos   = layout.pos(keep, :);
[~, sortIdx] = sort(layoutPos(:, 2), 'descend');
chanOrder = layoutLabel(sortIdx);

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== ERP: %s ===\n', subDir);

    subOutDir = fullfile(outDir, subDir);
    erpFile   = fullfile(subOutDir, [subDir '_erp.mat']);

    % never redo or overwrite a subject whose ERPs are already computed
    if exist(erpFile, 'file')
        fprintf('%s ERPs already computed (%s) - skipping.\n', subDir, erpFile);
        continue
    end

    if ~exist(subOutDir, 'dir')
        mkdir(subOutDir);
    end

    loaded = load(fullfile(preprocDir, subDir, [subDir '_preprocessed.mat']), 'data_clean');
    data_clean = loaded.data_clean;
    trig = data_clean.trialinfo(:, 1);
    fprintf('%s trials per trigger: %s\n', subDir, strjoin(arrayfun(@(t) sprintf('%d:%d', t, sum(trig == t)), unique(trig)', 'UniformOutput', false), ' '));

    erp = struct();

    for b = 1:numel(blocks)
        blk = blocks(b);
        blkOutDir = fullfile(subOutDir, blk.name);

        %% direction-level timelocks
        dirTL = cell(1, numel(blk.dirCodes));
        for c = 1:numel(blk.dirCodes)
            cfg = [];
            cfg.trials = find(trig == blk.dirCodes(c));
            dirTL{c} = ft_timelockanalysis(cfg, data_clean);
        end
        erp.(blk.name).direction.labels = blk.dirLabels;
        erp.(blk.name).direction.tl = dirTL;

        fn_plot_erp_block(fullfile(blkOutDir, 'direction'), blk.dirLabels, dirTL, ...
            roiChans, chanOrder, sprintf('%s - %s - direction', subDir, blk.name));

        %% axis-of-motion timelocks
        axisTL = cell(1, numel(blk.axisCodes));
        for c = 1:numel(blk.axisCodes)
            cfg = [];
            cfg.trials = find(ismember(trig, blk.axisCodes{c}));
            axisTL{c} = ft_timelockanalysis(cfg, data_clean);
        end
        erp.(blk.name).axis.labels = blk.axisLabels;
        erp.(blk.name).axis.tl = axisTL;

        fn_plot_erp_block(fullfile(blkOutDir, 'axis'), blk.axisLabels, axisTL, ...
            roiChans, chanOrder, sprintf('%s - %s - axis of motion', subDir, blk.name));
    end

    save(erpFile, 'erp', '-v7.3');
    fprintf('Saved ERP results and plots for %s\n', subDir);

end
