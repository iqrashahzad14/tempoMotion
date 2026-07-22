%% Temporal generalization: cross-condition decoding within touch - group level
%
% Loads each subject's saved train-time x test-time generalization
% matrices (already averaged over iterations within-subject, see
% tempoGen_crossCondition_inTouch_subject.m, for a/b/both x acc/auc x 2
% targets), and averages across the 6 subjects. Plots the group-average
% T x T heatmaps for each combination.
%
% Requires outputs/tempoGen_crossCondition_inTouch/<sub>/<sub>_tempoGen_crossCondition.mat
% for every subject (see tempoGen_crossCondition_inTouch_subject.m).

clear;

addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir       = fullfile(projectDir, 'outputs', 'tempoGen_crossCondition_inTouch');
groupOutDir = fullfile(tgDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(tgDir, subjects{s}, [subjects{s} '_tempoGen_crossCondition.mat']), 'results');
    allResults{s} = loaded.results;
end

targetNames = fieldnames(allResults{1});
variants = {'a', 'b', 'both'};

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

groupTempoGen = struct();
climRange = [0.35 0.65];

f = figure('Visible', 'off');
nRows = numel(targetNames) * numel(variants);
row = 0;

for ti = 1:numel(targetNames)
    tgtName = targetNames{ti};
    timeVec = allResults{1}.(tgtName).time;
    nTime = numel(timeVec);

    for v = 1:numel(variants)
        variant = variants{v};
        row = row + 1;

        accStack = zeros(nSub, nTime, nTime);
        aucStack = zeros(nSub, nTime, nTime);
        for s = 1:nSub
            accStack(s, :, :) = allResults{s}.(tgtName).mean.(variant).acc;
            aucStack(s, :, :) = allResults{s}.(tgtName).mean.(variant).auc;
        end
        accGroup = squeeze(mean(accStack, 1));
        aucGroup = squeeze(mean(aucStack, 1, 'omitnan'));

        groupTempoGen.(tgtName).(variant).acc = accGroup;
        groupTempoGen.(tgtName).(variant).auc = aucGroup;
        groupTempoGen.(tgtName).(variant).time = timeVec;

        switch variant
            case 'a'
                ylab = 'Train: target time (s)'; xlab = 'Test: handPos time (s)';
                vLabel = 'train tgt / test handPos';
            case 'b'
                ylab = 'Train: handPos time (s)'; xlab = 'Test: target time (s)';
                vLabel = 'train handPos / test tgt';
            case 'both'
                ylab = 'Target time (s)'; xlab = 'HandPos time (s)';
                vLabel = 'both (avg)';
        end

        subplot(nRows, 2, (row-1)*2 + 1);
        fn_plot_tempoGen_matrix(timeVec, timeVec, accGroup, climRange, ...
            sprintf('%s - %s - acc (N=%d)', tgtName, vLabel, nSub), ylab, xlab);

        subplot(nRows, 2, (row-1)*2 + 2);
        fn_plot_tempoGen_matrix(timeVec, timeVec, aucGroup, climRange, ...
            sprintf('%s - %s - AUC (N=%d)', tgtName, vLabel, nSub), ylab, xlab);
    end
end

sgtitle('Group - cross-condition temporal generalization within touch', 'Interpreter', 'none');
set(f, 'Position', [0 0 1100 1600]);
saveas(f, fullfile(groupOutDir, 'group_tempoGen_crossCondition.png'));
close(f);

save(fullfile(groupOutDir, 'group_tempoGen_crossCondition.mat'), 'groupTempoGen', '-v7.3');
fprintf('Saved group cross-condition temporal generalization (in touch) results and plot to %s\n', groupOutDir);
