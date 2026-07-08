%% RSA: axis-of-motion dissimilarity - group level (mean +/- SEM across subjects)
%
% Loads each subject's saved distance time-courses (see
% rsa_axisOfMotion_withinModality_subject.m), averages across the 6
% subjects, and plots the group mean +/- SEM per block.
%
% Requires outputs/rsa_axisOfMotion_withinModality/<sub>/<sub>_rsa_axisOfMotion.mat
% for every subject (see rsa_axisOfMotion_withinModality_subject.m).

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
rsaDir      = fullfile(projectDir, 'outputs', 'rsa_axisOfMotion_withinModality');
groupOutDir = fullfile(rsaDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

%% Load all subjects
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(rsaDir, subjects{s}, [subjects{s} '_rsa_axisOfMotion.mat']), 'results');
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

    distBySubj = nan(nSub, nTime);
    for s = 1:nSub
        distBySubj(s, :) = allResults{s}.(bn).distTimeCourse;
    end

    distMean = mean(distBySubj, 1);
    distSEM  = std(distBySubj, 0, 1) / sqrt(nSub);

    groupRsa.(bn).time = timeVec;
    groupRsa.(bn).distMean = distMean;
    groupRsa.(bn).distSEM  = distSEM;
    groupRsa.(bn).classALabel = allResults{1}.(bn).classALabel;
    groupRsa.(bn).classBLabel = allResults{1}.(bn).classBLabel;

    subplot(numel(blockNames), 1, b);
    hold on;
    fill([timeVec, fliplr(timeVec)], [distMean + distSEM, fliplr(distMean - distSEM)], ...
        [0.3 0.5 0.9], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    plot(timeVec, distMean, 'LineWidth', 1.5, 'Color', [0.1 0.3 0.8]);
    yline(0, 'k--'); xline(0, 'k-');
    hold off;
    xlabel('Time (s)'); ylabel('cv-distance');
    title(sprintf('%s: %s vs %s (N=%d)', strrep(bn, '_', ' '), ...
        groupRsa.(bn).classALabel, groupRsa.(bn).classBLabel, nSub), 'Interpreter', 'none');
end

sgtitle('Group - axis-of-motion RSA (mean \pm SEM)', 'Interpreter', 'tex');
set(f, 'Position', [0 0 900 900]);
saveas(f, fullfile(groupOutDir, 'group_rsa_axisOfMotion.png'));
close(f);

save(fullfile(groupOutDir, 'group_rsa_axisOfMotion.mat'), 'groupRsa', '-v7.3');
fprintf('Saved group RSA axis-of-motion results and plot to %s\n', groupOutDir);
