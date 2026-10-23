%% Read-only: significant clusters of the tactile frame-of-reference temporal
% generalization (all channels). Set the group folder with TG_GROUP
% (e.g. group_N13). Per decode and metric: p, size, train/test windows,
% share of pixels on the diagonal (|train-test| <= one grid step), peak.
% Rows of each matrix = train time, columns = test time.
clear;
D = fullfile('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/tempoGen/tempoGen_tactileFrameOfReference', getenv('TG_GROUP'));
S = load(fullfile(D, 'group_stats_tempoGen_tactileFoR.mat'), 'statsResults');
for b = {'somatotopic', 'external', 'handPos'}
    R = S.statsResults.(b{1}); t = R.time; dt = median(diff(t));
    for m = {'acc', 'auc'}
        st = R.([m{1} 'Stats']); G = R.([m{1} 'Group']);
        sig = find([st.clusters.sig]);
        if isempty(sig)
            best = 1; if ~isempty(st.clusters), best = min([st.clusters.pval]); end
            fprintf('%-12s %s: none (best p=%.3f)\n', b{1}, m{1}, best);
        end
        for c = sig
            M = st.clusters(c).mask; [ri, ci] = find(M);
            onDiag = mean(abs(t(ri) - t(ci)) <= dt + 1e-9);
            [pk, ip] = max(G(M));
            fprintf('%-12s %s: p=%.4f, %d px, train %.2f-%.2f s, test %.2f-%.2f s, on diagonal %.0f%%, peak %.3f (train %.2f / test %.2f)\n', ...
                b{1}, m{1}, st.clusters(c).pval, nnz(M), min(t(ri)), max(t(ri)), min(t(ci)), max(t(ci)), 100 * onDiag, pk, t(ri(ip)), t(ci(ip)));
        end
    end
end
