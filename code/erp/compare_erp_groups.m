%% Read-only: compare two ERP group sizes and one subject against the group
% ROI averages (all directions pooled) per block; set with environment
% variables ERP_GROUP_A, ERP_GROUP_B (e.g. group_N12, group_N13) and
% ERP_SUBJECT (e.g. sub-014).
clear;
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
E = fullfile(projectDir, 'outputs', 'derivatives', 'erp');
gA = getenv('ERP_GROUP_A'); gB = getenv('ERP_GROUP_B'); sub = getenv('ERP_SUBJECT');
roi.occipital      = {'A11','A12','A13','A14','A15','A22','A23','A24','A25','A26','A27','A28','B8','B9'};
roi.centroparietal = {'A3','A4','A5','A6','A7','A8','A9','A16','A17','A18','A19','A20','A21','A29','A30','A31','A32','B3','B4','B5','B6'};
A = load(fullfile(E, gA, 'group_erp.mat')); B = load(fullfile(E, gB, 'group_erp.mat'));
S = load(fullfile(E, sub, [sub '_erp.mat']));
for blk = {'visual', 'tactile_up', 'tactile_down'}
    for rn = fieldnames(roi)'
        r = roi.(rn{1});
        tlA = A.groupErp.(blk{1}).direction.tl; tlB = B.groupErp.(blk{1}).direction.tl; tlS = S.erp.(blk{1}).direction.tl;
        t = tlB{1}.time;
        ya = local_roi(tlA, r); yb = local_roi(tlB, r); ys = local_roi(tlS, r);
        w = t >= 0.05 & t <= 0.8; tw = t(w); [~, i] = max(abs(yb(w)));
        iT = t >= 0 & t <= 1;
        fprintf('%-12s %-14s: %s vs %s max diff %.3f uV (group peak %.2f uV at %.3f s) | %s vs %s r = %.2f, %s peak |%.2f| uV\n', ...
            blk{1}, rn{1}, gA, gB, max(abs(yb - ya)), yb(find(w, 1) + i - 1), tw(i), sub, gA, corr(ys(iT)', ya(iT)'), sub, max(abs(ys(w))));
    end
end
function y = local_roi(tl, r)
y = mean(cell2mat(cellfun(@(x) mean(x.avg(ismember(x.label, r), :), 1), tl(:), 'UniformOutput', false)), 1);
end
