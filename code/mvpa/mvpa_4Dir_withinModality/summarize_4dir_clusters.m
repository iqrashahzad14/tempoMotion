%% Read-only: significant clusters of the 4-direction decoding, N=6 vs N=13
% Lists the significant clusters (window, p) of the all-channel group stats
% and the group mean / peak accuracy per block, for group/ (N=6) and
% group_N13/ (all channels; the ROI versions were deleted on 2026-10-22).
clear;
D = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa/mvpa_4Dir_withinModality';
for g = {'group', 'group_N13'}
    S = load(fullfile(D, g{1}, 'group_stats_mvpa_4dir.mat'), 'statsResults');
    G = load(fullfile(D, g{1}, 'group_mvpa_4dir.mat'), 'groupMvpa');
    fprintf('\n=== %s ===\n', g{1});
    for b = fieldnames(S.statsResults)'
        t = S.statsResults.(b{1}).time;
        for m = {'acc', 'auc'}
            st = S.statsResults.(b{1}).([m{1} 'Stats']); c = st.clusters; parts = {};
            for k = find([c.sig])
                parts{end+1} = sprintf('%.2f-%.2f s (p=%.3f)', t(c(k).idx(1)), t(c(k).idx(end)), c(k).pval); %#ok<AGROW>
            end
            if isempty(parts), parts = {'none'}; end
            mu = G.groupMvpa.(b{1}).([m{1} 'Mean']); iP = t >= 0 & t <= 1.2; tp = t(iP);
            [pk, ip] = max(movmean(mu(iP), 5));
            fprintf('  %-12s %s: N=%d peak %.3f at %.2f s | %s\n', b{1}, m{1}, st.nSub, pk, tp(ip), strjoin(parts, ', '));
        end
    end
end
