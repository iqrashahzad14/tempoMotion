%% Regenerate per-subject diagnostic plots for mvpa_axisOfMotion_withinModality
% Reloads each subject's saved results (no recomputation) and regenerates
% the diagnostic PNG using the current plotting settings in
% mvpa_axisOfMotion_withinModality_subject.m (zoomed y-axis: chance +/- 0.15).

clear;

projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
outDir     = fullfile(projectDir, 'outputs', 'mvpa_axisOfMotion_withinModality');
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};

for s = 1:numel(subjects)
    subDir = subjects{s};
    subOutDir = fullfile(outDir, subDir);
    loaded = load(fullfile(subOutDir, [subDir '_mvpa_axisOfMotion.mat']), 'results');
    results = loaded.results;
    blockNames = fieldnames(results);

    f = figure('Visible', 'off');
    for b = 1:numel(blockNames)
        subplot(numel(blockNames), 2, (b-1)*2 + 1);
        plot(results.(blockNames{b}).time, mean(results.(blockNames{b}).acc, 1), 'LineWidth', 1.5);
        hold on; yline(0.5, 'k--'); xline(0, 'k-'); hold off;
        ylim([0.35 0.65]); xlabel('Time (s)'); ylabel('Accuracy');
        title([strrep(blockNames{b}, '_', ' ') ' - accuracy']);

        subplot(numel(blockNames), 2, (b-1)*2 + 2);
        plot(results.(blockNames{b}).time, mean(results.(blockNames{b}).auc, 1), 'LineWidth', 1.5);
        hold on; yline(0.5, 'k--'); xline(0, 'k-'); hold off;
        ylim([0.35 0.65]); xlabel('Time (s)'); ylabel('AUC');
        title([strrep(blockNames{b}, '_', ' ') ' - AUC']);
    end
    sgtitle([subDir ' - axis-of-motion decoding'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1000 900]);
    saveas(f, fullfile(subOutDir, [subDir '_mvpa_axisOfMotion.png']));
    close(f);
    fprintf('Replotted %s\n', subDir);
end
