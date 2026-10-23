%% Regenerate per-subject diagnostic plots for mvpa_tactileFrameOfReference
% Reloads each subject's saved results (no recomputation) and regenerates
% the diagnostic PNG using the current plotting settings in
% mvpa_tactileFrameOfReference_subject.m (full y-axis: 0 to 1, x-axis:
% -0.5 to 1.5 s, plus light dashed reference lines at +/-10ms around
% stimulus onset).

clear;

projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
outDir     = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa', 'mvpa_tactileFrameOfReference');
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};

for s = 1:numel(subjects)
    subDir = subjects{s};
    subOutDir = fullfile(outDir, subDir);
    loaded = load(fullfile(subOutDir, [subDir '_mvpa_tactileFoR.mat']), 'results');
    results = loaded.results;
    decodeNames = fieldnames(results);

    f = figure('Visible', 'off');
    for d = 1:numel(decodeNames)
        subplot(numel(decodeNames), 2, (d-1)*2 + 1);
        plot(results.(decodeNames{d}).time, mean(results.(decodeNames{d}).acc, 1), 'LineWidth', 1.5);
        hold on; yline(0.5, 'k--'); xline(0, 'k-');
        xline(-0.01, ':', 'Color', [0.6 0.6 0.6]); xline(0.01, ':', 'Color', [0.6 0.6 0.6]);
        hold off;
        xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('Accuracy');
        title([strrep(decodeNames{d}, '_', ' ') ' - accuracy']);

        subplot(numel(decodeNames), 2, (d-1)*2 + 2);
        plot(results.(decodeNames{d}).time, mean(results.(decodeNames{d}).auc, 1), 'LineWidth', 1.5);
        hold on; yline(0.5, 'k--'); xline(0, 'k-');
        xline(-0.01, ':', 'Color', [0.6 0.6 0.6]); xline(0.01, ':', 'Color', [0.6 0.6 0.6]);
        hold off;
        xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('AUC');
        title([strrep(decodeNames{d}, '_', ' ') ' - AUC']);
    end
    sgtitle([subDir ' - tactile frame-of-reference decoding'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1000 900]);
    saveas(f, fullfile(subOutDir, [subDir '_mvpa_tactileFoR.png']));
    close(f);
    fprintf('Replotted %s\n', subDir);
end
