%% Temporal generalization: axis-of-motion decoding within each modality block - group level
%
% Loads each subject's saved train-time x test-time generalization
% matrices (already averaged over iterations within-subject, see
% tempoGen_axisOfMotion_withinModality_subject.m, for each of the 3
% blocks), and averages across the 6 subjects. Plots the group-average
% T x T heatmaps.
%
% Requires outputs/tempoGen_axisOfMotion_withinModality/<sub>/<sub>_tempoGen_axisOfMotion.mat
% for every subject (see tempoGen_axisOfMotion_withinModality_subject.m).

clear;

addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir       = fullfile(projectDir, 'outputs', 'tempoGen_axisOfMotion_withinModality');
groupOutDir = fullfile(tgDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(tgDir, subjects{s}, [subjects{s} '_tempoGen_axisOfMotion.mat']), 'results');
    allResults{s} = loaded.results;
end

blockNames = fieldnames(allResults{1});

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

groupTempoGen = struct();
climRange = [0.35 0.65];

f = figure('Visible', 'off');

for b = 1:numel(blockNames)
    blkName = blockNames{b};
    timeVec = allResults{1}.(blkName).time;
    nTime = numel(timeVec);

    accStack = zeros(nSub, nTime, nTime);
    aucStack = zeros(nSub, nTime, nTime);
    for s = 1:nSub
        accStack(s, :, :) = squeeze(mean(allResults{s}.(blkName).acc, 1));
        aucStack(s, :, :) = squeeze(mean(allResults{s}.(blkName).auc, 1));
    end
    accGroup = squeeze(mean(accStack, 1));
    aucGroup = squeeze(mean(aucStack, 1));

    groupTempoGen.(blkName).acc  = accGroup;
    groupTempoGen.(blkName).auc  = aucGroup;
    groupTempoGen.(blkName).time = timeVec;

    subplot(numel(blockNames), 2, (b-1)*2 + 1);
    fn_plot_tempoGen_matrix(timeVec, timeVec, accGroup, climRange, ...
        sprintf('%s - accuracy (N=%d)', strrep(blkName, '_', ' '), nSub), 'Train time (s)', 'Test time (s)');

    subplot(numel(blockNames), 2, (b-1)*2 + 2);
    fn_plot_tempoGen_matrix(timeVec, timeVec, aucGroup, climRange, ...
        sprintf('%s - AUC (N=%d)', strrep(blkName, '_', ' '), nSub), 'Train time (s)', 'Test time (s)');
end

sgtitle('Group - axis-of-motion temporal generalization', 'Interpreter', 'none');
set(f, 'Position', [0 0 1000 1200]);
saveas(f, fullfile(groupOutDir, 'group_tempoGen_axisOfMotion.png'));
close(f);

save(fullfile(groupOutDir, 'group_tempoGen_axisOfMotion.mat'), 'groupTempoGen', '-v7.3');
fprintf('Saved group axis-of-motion temporal generalization results and plot to %s\n', groupOutDir);
