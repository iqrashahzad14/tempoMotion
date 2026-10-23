%% Read-only: how similar is one subject's ERP scalp pattern to the group?
% Visual and tactile-up blocks (all directions pooled). Correlates the
% subject's 128-channel topography with the group (ERP_GROUP) at several
% time points, compared with the normal range (each of sub-001..012 vs the
% group), and reports where the extreme values lie (layout y: anterior +,
% posterior -). Each subject's ERP file is loaded only once.
clear;
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip'); ft_defaults; [~, ftpath] = ft_version;
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
E = fullfile(projectDir, 'outputs', 'derivatives', 'erp');
grp = getenv('ERP_GROUP'); sub = getenv('ERP_SUBJECT');
blocks = {'visual', 'tactile_up'}; times = [0.16 0.30 0.50 0.70];
others = {'sub-001','sub-002','sub-003','sub-004','sub-005','sub-006','sub-007','sub-008','sub-009','sub-010','sub-011','sub-012'};
G = load(fullfile(E, grp, 'group_erp.mat'));
cfg = []; cfg.layout = fullfile(ftpath, 'template', 'layout', 'biosemi128.lay'); lay = ft_prepare_layout(cfg);
% pooled subject ERPs, loaded once
Ys = struct(); Yo = cell(1, numel(others));
L = load(fullfile(E, sub, [sub '_erp.mat']), 'erp');
for b = blocks, Ys.(b{1}) = local_pool(L.erp.(b{1}).direction.tl); end
for o = 1:numel(others)
    L = load(fullfile(E, others{o}, [others{o} '_erp.mat']), 'erp');
    for b = blocks, Yo{o}.(b{1}) = local_pool(L.erp.(b{1}).direction.tl); end
end
for b = blocks
    gl = G.groupErp.(b{1}).direction.tl; lab = gl{1}.label; t = gl{1}.time;
    Yg = local_pool(gl);
    [~, il] = ismember(lab, lay.label); y = lay.pos(il, 2);
    fprintf('\n%s (%s vs %s):\n', b{1}, sub, grp);
    for tt = times
        [~, k] = min(abs(t - tt));
        r = corr(Ys.(b{1})(:, k), Yg(:, k));
        rr = cellfun(@(Z) corr(Z.(b{1})(:, k), Yg(:, k)), Yo);
        [~, mxS] = max(Ys.(b{1})(:, k)); [~, mnS] = min(Ys.(b{1})(:, k)); [~, mxG] = max(Yg(:, k)); [~, mnG] = min(Yg(:, k));
        fprintf('  t=%.2f s: r = %5.2f (others vs group: median %.2f, range %.2f..%.2f) | %s max %s (y=%.2f) min %s (y=%.2f) | group max %s (y=%.2f) min %s (y=%.2f)\n', ...
            t(k), r, median(rr), min(rr), max(rr), sub, lab{mxS}, y(mxS), lab{mnS}, y(mnS), lab{mxG}, y(mxG), lab{mnG}, y(mnG));
    end
end
function Y = local_pool(tl)
C = cellfun(@(x) x.avg, tl(:)', 'UniformOutput', false);
Y = mean(cat(3, C{:}), 3);
end
