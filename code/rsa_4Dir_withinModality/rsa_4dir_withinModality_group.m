%% RSA: 4-direction dissimilarity - group level (mean +/- SEM across subjects)
%
% Loads each subject's saved RDMs/time-courses (see
% rsa_4dir_withinModality_subject.m), averages across the 6 subjects, and
% plots the group mean +/- SEM distinctiveness time-course plus group
% mean RDM heatmaps (baseline / post-stimulus) per block.
%
% Requires outputs/rsa_4Dir_withinModality/<sub>/<sub>_rsa_4dir.mat for
% every subject (see rsa_4dir_withinModality_subject.m).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
rsaDir      = fullfile(projectDir, 'outputs', 'rsa_4Dir_withinModality');
groupOutDir = fullfile(rsaDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

%% Load all subjects
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(rsaDir, subjects{s}, [subjects{s} '_rsa_4dir.mat']), 'results');
    allResults{s} = loaded.results;
end

blockNames = fieldnames(allResults{1});

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

groupRsa = struct();

f = figure('Visible', 'off');
for b = 1:numel(blockNames)
    bn = blockNames{b};
    timeVec = allResults{1}.(bn).time;
    nTime = numel(timeVec);
    labels = allResults{1}.(bn).labels;

    offDiagBySubj = nan(nSub, nTime);
    baselineStack = zeros(nSub, numel(labels), numel(labels));
    postStack     = zeros(nSub, numel(labels), numel(labels));
    for s = 1:nSub
        offDiagBySubj(s, :) = allResults{s}.(bn).meanOffDiag;
        baselineStack(s, :, :) = allResults{s}.(bn).rdmBaseline;
        postStack(s, :, :)     = allResults{s}.(bn).rdmPostStim;
    end

    offDiagMean = mean(offDiagBySubj, 1);
    offDiagSEM  = std(offDiagBySubj, 0, 1) / sqrt(nSub);
    rdmBaselineMean = squeeze(mean(baselineStack, 1));
    rdmPostMean     = squeeze(mean(postStack, 1));

    groupRsa.(bn).time = timeVec;
    groupRsa.(bn).offDiagMean = offDiagMean;
    groupRsa.(bn).offDiagSEM  = offDiagSEM;
    groupRsa.(bn).rdmBaseline = rdmBaselineMean;
    groupRsa.(bn).rdmPostStim = rdmPostMean;
    groupRsa.(bn).labels = labels;

    subplot(numel(blockNames), 3, (b-1)*3 + 1);
    hold on;
    fill([timeVec, fliplr(timeVec)], [offDiagMean + offDiagSEM, fliplr(offDiagMean - offDiagSEM)], ...
        [0.3 0.5 0.9], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    plot(timeVec, offDiagMean, 'LineWidth', 1.5, 'Color', [0.1 0.3 0.8]);
    yline(0, 'k--'); xline(0, 'k-');
    hold off;
    xlabel('Time (s)'); ylabel('Mean cv-distance');
    title(sprintf('%s - overall distinctiveness (N=%d)', strrep(bn, '_', ' '), nSub));

    subplot(numel(blockNames), 3, (b-1)*3 + 2);
    imagesc(rdmBaselineMean);
    axis square; colorbar;
    set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels, 'YTick', 1:numel(labels), 'YTickLabel', labels, ...
        'TickLabelInterpreter', 'none', 'FontSize', 7);
    title([strrep(bn, '_', ' ') ' - RDM (baseline)']);

    subplot(numel(blockNames), 3, (b-1)*3 + 3);
    imagesc(rdmPostMean);
    axis square; colorbar;
    set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels, 'YTick', 1:numel(labels), 'YTickLabel', labels, ...
        'TickLabelInterpreter', 'none', 'FontSize', 7);
    title([strrep(bn, '_', ' ') ' - RDM (post-stim)']);
end

sgtitle('Group - 4-direction RSA (mean \pm SEM)', 'Interpreter', 'tex');
set(f, 'Position', [0 0 1300 900]);
saveas(f, fullfile(groupOutDir, 'group_rsa_4dir.png'));
close(f);

save(fullfile(groupOutDir, 'group_rsa_4dir.mat'), 'groupRsa', '-v7.3');
fprintf('Saved group RSA 4-direction results and plot to %s\n', groupOutDir);
