%% MVPA: tactile frame-of-reference decoding, frequency-band variant - group level
%
% Loads each subject's saved per-band, per-decode results (see
% ft_mvpa_tactileFrameOfReference_subject.m) and averages across
% the 6 subjects. Plots the group-average accuracy and AUC time courses
% in a bands (rows) x decodes (cols) grid.
%
% Requires outputs/derivatives/mvpa_freqBands/ft_mvpa_tactileFrameOfReference/<sub>/<sub>_mvpa_tactileFoR_freqBands.mat
% for every subject.

clear;

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
mvpaDir     = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa_freqBands', 'ft_mvpa_tactileFrameOfReference');
groupOutDir = fullfile(mvpaDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

%% Load all subjects' per-subject results
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(mvpaDir, subjects{s}, [subjects{s} '_mvpa_tactileFoR_freqBands.mat']), 'results');
    allResults{s} = loaded.results;
end

bandNames   = fieldnames(allResults{1});
decodeNames = fieldnames(allResults{1}.(bandNames{1}));

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

groupResults = struct();

f1 = figure('Visible', 'off');
f2 = figure('Visible', 'off');

for bi = 1:numel(bandNames)
    bandName = bandNames{bi};
    for d = 1:numel(decodeNames)
        dcName = decodeNames{d};
        timeVec = allResults{1}.(bandName).(dcName).time;
        nTime = numel(timeVec);

        accStack = zeros(nSub, nTime);
        aucStack = zeros(nSub, nTime);
        for s = 1:nSub
            accStack(s, :) = mean(allResults{s}.(bandName).(dcName).acc, 1);
            aucStack(s, :) = mean(allResults{s}.(bandName).(dcName).auc, 1, 'omitnan');
        end
        accMean = mean(accStack, 1); accSEM = std(accStack, 0, 1) / sqrt(nSub);
        aucMean = mean(aucStack, 1); aucSEM = std(aucStack, 0, 1) / sqrt(nSub);

        groupResults.(bandName).(dcName).accMean = accMean;
        groupResults.(bandName).(dcName).accSEM  = accSEM;
        groupResults.(bandName).(dcName).aucMean  = aucMean;
        groupResults.(bandName).(dcName).aucSEM  = aucSEM;
        groupResults.(bandName).(dcName).time    = timeVec;

        figure(f1);
        subplot(numel(bandNames), numel(decodeNames), (bi-1)*numel(decodeNames) + d);
        fill([timeVec, fliplr(timeVec)], [accMean+accSEM, fliplr(accMean-accSEM)], ...
            [0.7 0.7 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5); hold on;
        plot(timeVec, accMean, 'LineWidth', 1.2, 'Color', [0 0 0.8]);
        yline(0.5, 'k--'); xline(0, 'k-');
        xline(-0.01, ':', 'Color', [0.6 0.6 0.6]); xline(0.01, ':', 'Color', [0.6 0.6 0.6]);
        hold off;
        xlim([-0.5 1.5]);
        ylim([0 1]);
        if bi == 1; title(strrep(dcName, '_', ' ')); end
        if d == 1; ylabel(bandName, 'FontWeight', 'bold'); end
        if bi == numel(bandNames); xlabel('Time (s)'); end

        figure(f2);
        subplot(numel(bandNames), numel(decodeNames), (bi-1)*numel(decodeNames) + d);
        fill([timeVec, fliplr(timeVec)], [aucMean+aucSEM, fliplr(aucMean-aucSEM)], ...
            [0.7 0.7 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5); hold on;
        plot(timeVec, aucMean, 'LineWidth', 1.2, 'Color', [0 0 0.8]);
        yline(0.5, 'k--'); xline(0, 'k-');
        xline(-0.01, ':', 'Color', [0.6 0.6 0.6]); xline(0.01, ':', 'Color', [0.6 0.6 0.6]);
        hold off;
        xlim([-0.5 1.5]);
        ylim([0 1]);
        if bi == 1; title(strrep(dcName, '_', ' ')); end
        if d == 1; ylabel(bandName, 'FontWeight', 'bold'); end
        if bi == numel(bandNames); xlabel('Time (s)'); end
    end
end

figure(f1);
sgtitle(sprintf('Group - tactile frame-of-reference decoding accuracy by frequency band (N=%d)', nSub), 'Interpreter', 'none');
set(f1, 'Position', [0 0 1200 1400]);
saveas(f1, fullfile(groupOutDir, 'group_mvpa_tactileFoR_freqBands_acc.png'));
close(f1);

figure(f2);
sgtitle(sprintf('Group - tactile frame-of-reference decoding AUC by frequency band (N=%d)', nSub), 'Interpreter', 'none');
set(f2, 'Position', [0 0 1200 1400]);
saveas(f2, fullfile(groupOutDir, 'group_mvpa_tactileFoR_freqBands_auc.png'));
close(f2);

save(fullfile(groupOutDir, 'group_mvpa_tactileFoR_freqBands.mat'), 'groupResults', '-v7.3');
fprintf('Saved group tactile frame-of-reference freq-band MVPA results and plots to %s\n', groupOutDir);
