%% ERP analysis - static-vs-motion supplementary session - group (grand average)
%
% Loads each subject's per-condition timelock results (saved by
% erp_staticVsMotion_subject.m), computes the grand average across
% subjects (ft_timelockgrandaverage) for both analysis types
% (direction_vs_static, motion_vs_static) in each block (visual, tactile),
% and generates the same 4 summary plots at the group level.
%
% NOTE: N=2 (sub-001, sub-006 only) - sub-004's static.bdf recording has
% no usable stimulus triggers (see erp_staticVsMotion_subject.m header).
% Treat this as an exploratory/supplementary result given the small N.
%
% Requires outputs/derivatives/erp/erp_staticVsMotion/<sub>/<sub>_erp_staticVsMotion.mat
% for every subject (see erp_staticVsMotion_subject.m).

clear;

%% Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;
[~, ftpath] = ft_version;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
erpDir      = fullfile(projectDir, 'outputs', 'derivatives', 'erp', 'erp_staticVsMotion');
groupOutDir = fullfile(erpDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-006'};

%% Channel ROIs (must match erp_staticVsMotion_subject.m)
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

%% Load all subjects' per-subject ERP results
allErp = cell(1, numel(subjects));
for s = 1:numel(subjects)
    loaded = load(fullfile(erpDir, subjects{s}, [subjects{s} '_erp_staticVsMotion.mat']), 'erp');
    allErp{s} = loaded.erp;
end

blockNames = fieldnames(allErp{1});
analysisTypes = {'direction_vs_static', 'motion_vs_static'};

groupErp = struct();

for b = 1:numel(blockNames)
    blkName = blockNames{b};

    for a = 1:numel(analysisTypes)
        analysisType = analysisTypes{a};

        condLabels = allErp{1}.(blkName).(analysisType).labels;
        nCond = numel(condLabels);

        gaTL = cell(1, nCond);
        for c = 1:nCond
            subTLs = cell(1, numel(subjects));
            for s = 1:numel(subjects)
                subTLs{s} = allErp{s}.(blkName).(analysisType).tl{c};
            end
            cfg = [];
            gaTL{c} = ft_timelockgrandaverage(cfg, subTLs{:});
        end

        groupErp.(blkName).(analysisType).labels = condLabels;
        groupErp.(blkName).(analysisType).tl = gaTL;

        blkOutDir = fullfile(groupOutDir, blkName, analysisType);
        fn_plot_erp_block(blkOutDir, condLabels, gaTL, roiChans, chanOrder, ...
            sprintf('Group (N=%d) - %s - %s', numel(subjects), blkName, strrep(analysisType, '_', ' ')));
    end
end

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end
save(fullfile(groupOutDir, 'group_erp_staticVsMotion.mat'), 'groupErp', '-v7.3');
fprintf('Saved group ERP static-vs-motion results and plots to %s\n', groupOutDir);
