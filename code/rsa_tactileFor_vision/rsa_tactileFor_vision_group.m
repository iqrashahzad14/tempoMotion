%% RSA: cross-modal alignment (vision + tactile FoR) - group level
%
% Loads each subject's saved RDMs/alignment-index time-courses (see
% rsa_tactileFor_vision_subject.m), averages across the 6 subjects, and
% plots the group mean +/- SEM alignment index (plus within-modality
% distances for context) and group mean RDM heatmaps per framing.
%
% Requires outputs/rsa_tactileFor_vision/<sub>/<sub>_rsa_tactileFor_vision.mat
% for every subject (see rsa_tactileFor_vision_subject.m).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
rsaDir      = fullfile(projectDir, 'outputs', 'rsa_tactileFor_vision');
groupOutDir = fullfile(rsaDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

%% Load all subjects
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(rsaDir, subjects{s}, [subjects{s} '_rsa_tactileFor_vision.mat']), 'results');
    allResults{s} = loaded.results;
end

targetNames = fieldnames(allResults{1});

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

groupRsa = struct();

f = figure('Visible', 'off');
for ti = 1:numel(targetNames)
    tn = targetNames{ti};
    timeVec = allResults{1}.(tn).time;
    nTime = numel(timeVec);
    condLabels = allResults{1}.(tn).condLabels;

    alignBySubj = nan(nSub, nTime);
    withinVisBySubj = nan(nSub, nTime);
    withinTacBySubj = nan(nSub, nTime);
    baselineStack = zeros(nSub, 4, 4);
    postStack     = zeros(nSub, 4, 4);
    for s = 1:nSub
        alignBySubj(s, :)     = allResults{s}.(tn).alignIndex;
        withinVisBySubj(s, :) = allResults{s}.(tn).withinVis;
        withinTacBySubj(s, :) = allResults{s}.(tn).withinTac;
        baselineStack(s, :, :) = allResults{s}.(tn).rdmBaseline;
        postStack(s, :, :)     = allResults{s}.(tn).rdmPostStim;
    end

    alignMean = mean(alignBySubj, 1);
    alignSEM  = std(alignBySubj, 0, 1) / sqrt(nSub);
    withinVisMean = mean(withinVisBySubj, 1);
    withinTacMean = mean(withinTacBySubj, 1);
    rdmBaselineMean = squeeze(mean(baselineStack, 1));
    rdmPostMean     = squeeze(mean(postStack, 1));

    groupRsa.(tn).time = timeVec;
    groupRsa.(tn).alignMean = alignMean;
    groupRsa.(tn).alignSEM  = alignSEM;
    groupRsa.(tn).alignBySubject = alignBySubj;
    groupRsa.(tn).withinVisMean = withinVisMean;
    groupRsa.(tn).withinTacMean = withinTacMean;
    groupRsa.(tn).rdmBaseline = rdmBaselineMean;
    groupRsa.(tn).rdmPostStim = rdmPostMean;
    groupRsa.(tn).condLabels = condLabels;

    subplot(numel(targetNames), 3, (ti-1)*3 + 1);
    hold on;
    fill([timeVec, fliplr(timeVec)], [alignMean + alignSEM, fliplr(alignMean - alignSEM)], ...
        [0.9 0.4 0.4], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    plot(timeVec, alignMean, 'LineWidth', 1.5, 'Color', [0.8 0.1 0.1]);
    plot(timeVec, withinVisMean, '--', 'LineWidth', 1, 'Color', [0.2 0.5 0.9]);
    plot(timeVec, withinTacMean, '--', 'LineWidth', 1, 'Color', [0.3 0.7 0.3]);
    yline(0, 'k--'); xline(0, 'k-');
    hold off;
    xlabel('Time (s)'); ylabel('cv-distance');
    legend({'', 'alignment index (\pm SEM)', 'within-vis dist', 'within-tac dist'}, 'Location', 'best', 'FontSize', 6);
    title(sprintf('%s - alignment index (N=%d)', tn, nSub), 'Interpreter', 'none');

    subplot(numel(targetNames), 3, (ti-1)*3 + 2);
    imagesc(rdmBaselineMean);
    axis square; colorbar;
    set(gca, 'XTick', 1:4, 'XTickLabel', condLabels, 'YTick', 1:4, 'YTickLabel', condLabels, ...
        'TickLabelInterpreter', 'none', 'FontSize', 6);
    title([tn ' - RDM (baseline)'], 'Interpreter', 'none');

    subplot(numel(targetNames), 3, (ti-1)*3 + 3);
    imagesc(rdmPostMean);
    axis square; colorbar;
    set(gca, 'XTick', 1:4, 'XTickLabel', condLabels, 'YTick', 1:4, 'YTickLabel', condLabels, ...
        'TickLabelInterpreter', 'none', 'FontSize', 6);
    title([tn ' - RDM (post-stim)'], 'Interpreter', 'none');
end

sgtitle('Group - cross-modal RSA (vision + tactile FoR)', 'Interpreter', 'none');
set(f, 'Position', [0 0 1300 700]);
saveas(f, fullfile(groupOutDir, 'group_rsa_tactileFor_vision.png'));
close(f);

save(fullfile(groupOutDir, 'group_rsa_tactileFor_vision.mat'), 'groupRsa', '-v7.3');
fprintf('Saved group cross-modal RSA results and plot to %s\n', groupOutDir);
