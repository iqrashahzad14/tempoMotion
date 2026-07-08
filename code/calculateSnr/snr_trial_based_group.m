%% SNR analysis (2): trial-based SNR - group
%
% (2) trial-based SNR — using the single-trial data (not just the
% averaged ERP), compute the peak amplitude relative to the standard
% error across trials at that time point, which directly reflects how
% much statistical reliability you're getting from the number of trials
% retained per condition (relevant here since trial counts vary 90–104
% after artifact rejection).
%
% Loads each subject's per-channel peak trial-based SNR computed by
% snr_trial_based_subject.m, averages across subjects per channel, and
% generates the same 4 summary plots at the group level. Per-subject
% trial counts are carried through for reference.
%
% Requires outputs/calculateSnr/<sub>/<sub>_snr_trial_based.mat for every
% subject (see snr_trial_based_subject.m).

clear;

%% Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;
[~, ftpath] = ft_version;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
snrDir      = fullfile(projectDir, 'outputs', 'calculateSnr');
groupOutDir = fullfile(snrDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};

%% Channel ROIs (must match snr_trial_based_subject.m)
roiChans.occipital = {'A11', 'A12', 'A13', 'A14', 'A15', 'A22', 'A23', 'A24', 'A25', 'A26', 'A27', 'A28', 'B8', 'B9'};
roiChans.centroparietal = {'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9', 'A16', 'A17', 'A18', 'A19', 'A20', 'A21', 'A29', 'A30', 'A31', 'A32', 'B3', 'B4', 'B5', 'B6'};

%% Layout (channel positions for the topography scatter plot)
cfg = [];
cfg.layout = fullfile(ftpath, 'template', 'layout', 'biosemi128.lay');
layout = ft_prepare_layout(cfg);
keep = ~ismember(layout.label, {'COMNT', 'SCALE'});
layoutLabel = layout.label(keep);
layoutPos   = layout.pos(keep, :);

%% Load all subjects' per-subject SNR results
allSnr = cell(1, numel(subjects));
for s = 1:numel(subjects)
    loaded = load(fullfile(snrDir, subjects{s}, [subjects{s} '_snr_trial_based.mat']), 'snr');
    allSnr{s} = loaded.snr;
end

blockNames = fieldnames(allSnr{1});
analysisTypes = {'direction', 'axis'};

groupSnr = struct();

for b = 1:numel(blockNames)
    blkName = blockNames{b};

    for a = 1:numel(analysisTypes)
        analysisType = analysisTypes{a};

        condLabels = allSnr{1}.(blkName).(analysisType).labels;
        nCond = numel(condLabels);

        snrVec = cell(1, nCond);
        chanLabels = cell(1, nCond);
        nTrialsBySubject = zeros(numel(subjects), nCond);
        for c = 1:nCond
            % average per-channel peak SNR across subjects, matching by channel label
            refLabels = allSnr{1}.(blkName).(analysisType).chanLabels{c};
            acc = nan(numel(refLabels), numel(subjects));
            for s = 1:numel(subjects)
                subVals = allSnr{s}.(blkName).(analysisType).snr{c};
                subLabels = allSnr{s}.(blkName).(analysisType).chanLabels{c};
                [~, idx] = ismember(refLabels, subLabels);
                acc(:, s) = subVals(idx);
                nTrialsBySubject(s, c) = allSnr{s}.(blkName).(analysisType).nTrials(c);
            end
            snrVec{c} = mean(acc, 2);
            chanLabels{c} = refLabels;
        end

        groupSnr.(blkName).(analysisType).labels = condLabels;
        groupSnr.(blkName).(analysisType).snr = snrVec;
        groupSnr.(blkName).(analysisType).chanLabels = chanLabels;
        groupSnr.(blkName).(analysisType).nTrialsBySubject = nTrialsBySubject;

        blkOutDir = fullfile(groupOutDir, blkName, analysisType, 'trial_based');
        fn_plot_snr_block(blkOutDir, condLabels, snrVec, chanLabels, roiChans, layoutLabel, layoutPos, ...
            sprintf('Group (N=%d) - %s - %s (trial-based SNR)', numel(subjects), blkName, analysisType), 'SNR (signal / SEM)');
    end
end

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end
save(fullfile(groupOutDir, 'group_snr_trial_based.mat'), 'groupSnr', '-v7.3');
fprintf('Saved group trial-based SNR results and plots to %s\n', groupOutDir);
