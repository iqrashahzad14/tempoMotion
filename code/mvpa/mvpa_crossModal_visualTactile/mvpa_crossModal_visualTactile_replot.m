%% Regenerate per-subject diagnostic plots for mvpa_crossModal_visualTactile
% Reloads each subject's saved results (no recomputation) and regenerates
% the diagnostic PNG using the current plotting settings in
% mvpa_crossModal_visualTactile_subject.m (full axis: x -0.5..1.5 s, y 0..1;
% changed from the zoomed 0.35-0.65 y-axis on 2026-10-22).

clear;

projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
outDir     = fullfile(projectDir, 'outputs', 'derivatives', 'mvpa', 'mvpa_crossModal_visualTactile');
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006', ...
            'sub-007', 'sub-008', 'sub-009', 'sub-010', 'sub-011', 'sub-012'};
% subjects can be set from the shell (REPLOT_SUBJECTS=sub-007,sub-008)
if ~isempty(getenv('REPLOT_SUBJECTS'))
    subjects = strsplit(getenv('REPLOT_SUBJECTS'), ',');
end

variants = {'a', 'b', 'both'};
variantTitles = {'train vis / test tac', 'train tac / test vis', 'both (avg)'};

for s = 1:numel(subjects)
    subDir = subjects{s};
    subOutDir = fullfile(outDir, subDir);
    loaded = load(fullfile(subOutDir, [subDir '_mvpa_crossModal.mat']), 'results');
    results = loaded.results;
    targetNames = fieldnames(results);

    f = figure('Visible', 'off');
    nRows = numel(targetNames) * numel(variants);
    row = 0;
    for ti = 1:numel(targetNames)
        for v = 1:numel(variants)
            row = row + 1;
            subplot(nRows, 2, (row-1)*2 + 1);
            plot(results.(targetNames{ti}).time, mean(results.(targetNames{ti}).(variants{v}).acc, 1), 'LineWidth', 1.5);
            hold on; yline(0.5, 'k--'); xline(0, 'k-'); hold off;
            xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('Accuracy');
            title(sprintf('%s - %s - acc', targetNames{ti}, variantTitles{v}), 'Interpreter', 'none', 'FontSize', 8);

            subplot(nRows, 2, (row-1)*2 + 2);
            plot(results.(targetNames{ti}).time, mean(results.(targetNames{ti}).(variants{v}).auc, 1, 'omitnan'), 'LineWidth', 1.5);
            hold on; yline(0.5, 'k--'); xline(0, 'k-'); hold off;
            xlim([-0.5 1.5]); ylim([0 1]); xlabel('Time (s)'); ylabel('AUC');
            title(sprintf('%s - %s - AUC', targetNames{ti}, variantTitles{v}), 'Interpreter', 'none', 'FontSize', 8);
        end
    end
    sgtitle([subDir ' - cross-modal visual-tactile decoding'], 'Interpreter', 'none');
    set(f, 'Position', [0 0 1000 1400]);
    saveas(f, fullfile(subOutDir, [subDir '_mvpa_crossModal.png']));
    close(f);
    fprintf('Replotted %s\n', subDir);
end
