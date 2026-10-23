%% Read-only check of the ICA input data: noisy channels and blinks
% For each subject (ICA_SUBJECTS=sub-014,sub-015): per-channel SD of the
% ICA input data (robust z vs the other channels), which channel dominates
% each of the first 30 components, and how many blink-like peaks the
% frontal-polar average shows (peaks > 5 robust SD).
clear;
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
subjects = strsplit(getenv('ICA_SUBJECTS'), ',');
fp = {'C17','C29','C16','C18','C28','C15','C30','C8'};
for s = 1:numel(subjects)
    sub = subjects{s};
    L = load(fullfile(projectDir, 'outputs', 'derivatives', 'preprocess', sub, [sub '_ica_intermediate.mat']), 'comp', 'data_ica_in');
    X = cat(2, L.data_ica_in.trial{:}); lab = L.data_ica_in.label;
    sd = std(X, 0, 2); z = (sd - median(sd)) / (1.4826 * mad(sd, 1));
    [zs, o] = sort(z, 'descend');
    fprintf('\n=== %s: %d samples (%.1f min at 256 Hz) ===\n', sub, size(X, 2), size(X, 2) / 256 / 60);
    fprintf('channel SD: median %.1f uV; top channels: %s\n', median(sd), ...
        strjoin(arrayfun(@(k) sprintf('%s (SD %.0f uV, z %.1f)', lab{o(k)}, sd(o(k)), zs(k)), 1:6, 'UniformOutput', false), ', '));
    fprintf('channels with z > 5: %d; flat channels (SD < 1 uV): %d\n', sum(z > 5), sum(sd < 1));
    T = L.comp.topo; [~, dom] = max(abs(T), [], 1);
    share = max(abs(T), [], 1) ./ sum(abs(T), 1);
    fprintf('dominant channel of components 1-30 (share of |topo|):\n  ');
    for c = 1:30, fprintf('%d:%s(%.2f) ', c, L.comp.topolabel{dom(c)}, share(c)); if mod(c, 10) == 0, fprintf('\n  '); end, end
    f = mean(X(ismember(lab, fp), :), 1);
    rz = (f - median(f)) / (1.4826 * mad(f, 1));
    pk = find(rz(2:end-1) > 5 & rz(2:end-1) >= rz(1:end-2) & rz(2:end-1) >= rz(3:end)) + 1;
    pk = pk([true diff(pk) > 0.3 * 256]);
    fprintf('\nfrontal-polar blink-like peaks: %d (%.1f per minute)\n', numel(pk), numel(pk) / (size(X, 2) / 256 / 60));
end
