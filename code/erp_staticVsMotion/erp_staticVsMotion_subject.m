%% ERP analysis - static-vs-motion supplementary session - per subject
%
% For each subject and each modality block (visual, tactile), computes:
%   a) direction_vs_static: each of the 4 motion directions PLUS the
%      static condition, all 5 overlaid on the same plot (lets you read
%      off how each direction differs from static directly).
%   b) motion_vs_static: the 4 directions pooled into one "motion"
%      condition vs. static (2 conditions) - the coarser, pooled contrast.
%
% Generates the standard 4 summary plots per block/analysis combination
% (all_channels.png, all_channels_butterfly.png, across_channel.png,
% centroparietal.png, occipital.png; see fn_plot_erp_block.m).
%
% Trigger codes (confirmed directly from the raw event channel; matches
% inputs/references/tempoMotion_studyDesign.docx section 1.3):
%   visual:  11 left, 12 right, 13 up, 14 down, 17 static
%   tactile: 21 wrist->finger, 22 finger->wrist, 23 pinky->thumb, 24 thumb->pinky, 27 static
%
% Only sub-001 and sub-006 are included: sub-004's static.bdf recording
% has no usable stimulus triggers (event/status channel contains only 3
% non-stimulus entries and the recording is ~5 min shorter than the other
% two) - the trigger/status channel was evidently not active during that
% session, and no alternate/backup file exists.
%
% Requires outputs/preprocess_staticVsMotion/<sub>/<sub>_preprocessed.mat
% (see code/preprocess_staticVsMotion/preprocess_staticVsMotion.m).

clear;

%% Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;
[~, ftpath] = ft_version;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
preprocDir = fullfile(projectDir, 'outputs', 'preprocess_staticVsMotion');
outDir     = fullfile(projectDir, 'outputs', 'erp_staticVsMotion');

%% Subjects (see header note re: sub-004 exclusion)
subjects = {'sub-001', 'sub-006'};

%% Condition definitions per block
blocks = struct();

blocks(1).name           = 'visual';
blocks(1).dirCodes       = [11 12 13 14];
blocks(1).dirLabels      = {'left', 'right', 'up', 'down'};
blocks(1).staticCode     = 17;
blocks(1).staticLabel    = 'static';

blocks(2).name           = 'tactile';
blocks(2).dirCodes       = [21 22 23 24];
blocks(2).dirLabels      = {'wrist_to_finger', 'finger_to_wrist', 'pinky_to_thumb', 'thumb_to_pinky'};
blocks(2).staticCode     = 27;
blocks(2).staticLabel    = 'static';

%% Channel ROIs (same as code/erp/erp_subject.m; derived from biosemi128.lay coordinates)
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
    fprintf('\n=== ERP static-vs-motion: %s ===\n', subDir);

    subOutDir = fullfile(outDir, subDir);
    if ~exist(subOutDir, 'dir')
        mkdir(subOutDir);
    end

    loaded = load(fullfile(preprocDir, subDir, [subDir '_preprocessed.mat']), 'data_clean');
    data_clean = loaded.data_clean;
    trig = data_clean.trialinfo(:, 1);

    erp = struct();

    for b = 1:numel(blocks)
        blk = blocks(b);
        blkOutDir = fullfile(subOutDir, blk.name);

        %% (a) direction_vs_static: each direction + static, all overlaid
        condCodes  = [blk.dirCodes, blk.staticCode];
        condLabels = [blk.dirLabels, {blk.staticLabel}];

        condTL = cell(1, numel(condCodes));
        for c = 1:numel(condCodes)
            cfg = [];
            cfg.trials = find(trig == condCodes(c));
            condTL{c} = ft_timelockanalysis(cfg, data_clean);
        end
        erp.(blk.name).direction_vs_static.labels = condLabels;
        erp.(blk.name).direction_vs_static.tl = condTL;

        fn_plot_erp_block(fullfile(blkOutDir, 'direction_vs_static'), condLabels, condTL, ...
            roiChans, chanOrder, sprintf('%s - %s - direction vs static', subDir, blk.name));

        %% (b) motion_vs_static: all 4 directions pooled vs static
        pooledCodes = {blk.dirCodes, blk.staticCode};
        pooledLabels = {'motion', blk.staticLabel};

        pooledTL = cell(1, numel(pooledCodes));
        for c = 1:numel(pooledCodes)
            cfg = [];
            cfg.trials = find(ismember(trig, pooledCodes{c}));
            pooledTL{c} = ft_timelockanalysis(cfg, data_clean);
        end
        erp.(blk.name).motion_vs_static.labels = pooledLabels;
        erp.(blk.name).motion_vs_static.tl = pooledTL;

        fn_plot_erp_block(fullfile(blkOutDir, 'motion_vs_static'), pooledLabels, pooledTL, ...
            roiChans, chanOrder, sprintf('%s - %s - motion (pooled) vs static', subDir, blk.name));
    end

    save(fullfile(subOutDir, [subDir '_erp_staticVsMotion.mat']), 'erp', '-v7.3');
    fprintf('Saved ERP static-vs-motion results and plots for %s\n', subDir);

end
