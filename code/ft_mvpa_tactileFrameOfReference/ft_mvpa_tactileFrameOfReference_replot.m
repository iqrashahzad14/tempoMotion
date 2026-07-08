%% Re-plot subject-level ft_mvpa_tactileFrameOfReference figures from saved .mat
%
% Regenerates the accuracy/AUC PNGs for each subject from the already-saved
% <sub>_mvpa_tactileFoR_freqBands.mat results, without re-running the
% (expensive) decoding. Use this after changing plotting code only (e.g.
% axis limits) -- see ft_mvpa_tactileFrameOfReference_subject.m for the
% original decoding + plotting logic this mirrors.

clear;

projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
outDir     = fullfile(projectDir, 'outputs', 'ft_mvpa_tactileFrameOfReference');

subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};

for s = 1:numel(subjects)
    subDir = subjects{s};
    subOutDir = fullfile(outDir, subDir);

    loaded = load(fullfile(subOutDir, [subDir '_mvpa_tactileFoR_freqBands.mat']), 'results', 'bands');
    results = loaded.results;
    bands   = loaded.bands;

    bandNames   = {bands.name};
    decodeNames = fieldnames(results.(bandNames{1}));

    f1 = figure('Visible', 'off');
    for bi = 1:numel(bandNames)
        for d = 1:numel(decodeNames)
            subplot(numel(bandNames), numel(decodeNames), (bi-1)*numel(decodeNames) + d);
            r = results.(bandNames{bi}).(decodeNames{d});
            plot(r.time, mean(r.acc, 1), 'LineWidth', 1.2);
            hold on; yline(0.5, 'k--'); xline(0, 'k-');
            xline(-0.01, ':', 'Color', [0.6 0.6 0.6]); xline(0.01, ':', 'Color', [0.6 0.6 0.6]);
            hold off;
            xlim([-0.5 1.5]);
            ylim([0 1]);
            if bi == 1
                title(strrep(decodeNames{d}, '_', ' '));
            end
            if d == 1
                ylabel(bandNames{bi}, 'FontWeight', 'bold');
            end
            if bi == numel(bandNames)
                xlabel('Time (s)');
            end
        end
    end
    sgtitle([subDir ' - tactile frame-of-reference decoding accuracy by frequency band'], 'Interpreter', 'none');
    set(f1, 'Position', [0 0 1200 1400]);
    saveas(f1, fullfile(subOutDir, [subDir '_mvpa_tactileFoR_freqBands_acc.png']));
    close(f1);

    f2 = figure('Visible', 'off');
    for bi = 1:numel(bandNames)
        for d = 1:numel(decodeNames)
            subplot(numel(bandNames), numel(decodeNames), (bi-1)*numel(decodeNames) + d);
            r = results.(bandNames{bi}).(decodeNames{d});
            plot(r.time, mean(r.auc, 1), 'LineWidth', 1.2);
            hold on; yline(0.5, 'k--'); xline(0, 'k-');
            xline(-0.01, ':', 'Color', [0.6 0.6 0.6]); xline(0.01, ':', 'Color', [0.6 0.6 0.6]);
            hold off;
            xlim([-0.5 1.5]);
            ylim([0 1]);
            if bi == 1
                title(strrep(decodeNames{d}, '_', ' '));
            end
            if d == 1
                ylabel(bandNames{bi}, 'FontWeight', 'bold');
            end
            if bi == numel(bandNames)
                xlabel('Time (s)');
            end
        end
    end
    sgtitle([subDir ' - tactile frame-of-reference decoding AUC by frequency band'], 'Interpreter', 'none');
    set(f2, 'Position', [0 0 1200 1400]);
    saveas(f2, fullfile(subOutDir, [subDir '_mvpa_tactileFoR_freqBands_auc.png']));
    close(f2);

    fprintf('Re-plotted %s\n', subDir);
end
