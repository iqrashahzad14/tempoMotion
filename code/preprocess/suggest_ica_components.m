%% Suggest eye-blink ICA components (helper for preprocess_bandstop45.m)
% Read-only helper: loads each subject's cached ICA
% (outputs/derivatives/preprocess/<sub>/<sub>_ica_intermediate.mat) and scores every
% component on standard blink features:
%   - frontal: share of the topography weight on the frontal-polar
%              channels (C8 C15-C18 C28-C30, around Fp1/Fpz/Fp2)
%   - sym:     left/right symmetry of the frontal-polar weights (blinks
%              are bilateral; horizontal eye movements are anti-symmetric)
%   - corrFp:  correlation of the component time course with the raw
%              frontal-polar average (dominated by blinks)
%   - kurt:    kurtosis of the time course (blinks = sparse large peaks)
%   - var:     % of scalp signal variance carried by the component
% It writes a table per subject and a zoomed figure of the top candidates
% (topography + time-course snippet) to
% outputs/derivatives/preprocess/<sub>/<sub>_ica_candidates.png. Nothing else is
% changed; the final choice is still made by visual inspection.

clear;

addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;
[~, ftpath] = ft_version;

projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
outDir     = fullfile(projectDir, 'outputs', 'derivatives', 'preprocess');

% sub-001..006 are included only to check the scores against the
% components already chosen for them
subjects = {'sub-001','sub-002','sub-003','sub-004','sub-005','sub-006', ...
            'sub-007','sub-008','sub-009','sub-010','sub-011','sub-012'};
% subjects can be set from the shell (ICA_SUBJECTS=sub-014,sub-015) to score
% only new subjects
if ~isempty(getenv('ICA_SUBJECTS'))
    subjects = strsplit(getenv('ICA_SUBJECTS'), ',');
end

fpChans    = {'C17','C29','C16','C18','C28','C15','C30','C8'};
fpLeft     = {'C29','C28','C30'};
fpRight    = {'C16','C15','C8'};
nCandidate = 6;

for s = 1:numel(subjects)

    subDir = subjects{s};
    icaCacheFile = fullfile(outDir, subDir, [subDir '_ica_intermediate.mat']);
    if ~exist(icaCacheFile, 'file')
        fprintf('%s: no ICA cache - skipping\n', subDir);
        continue
    end
    loaded = load(icaCacheFile, 'comp', 'data_ica_in');
    comp = loaded.comp;
    dat  = loaded.data_ica_in;

    topo  = comp.topo;                                 % chan x comp
    ts    = cat(2, comp.trial{:});                     % comp x time
    raw   = cat(2, dat.trial{:});                      % chan x time
    nComp = size(topo, 2);

    iFp = ismember(comp.topolabel, fpChans);
    iL  = ismember(comp.topolabel, fpLeft);
    iR  = ismember(comp.topolabel, fpRight);

    frontal = sum(abs(topo(iFp,:)), 1) ./ sum(abs(topo), 1) * size(topo,1) / sum(iFp);
    sym     = 1 - abs(mean(topo(iL,:),1) - mean(topo(iR,:),1)) ./ ...
                  (abs(mean(topo(iL,:),1)) + abs(mean(topo(iR,:),1)) + eps);

    fpRaw  = mean(raw(ismember(dat.label, fpChans), :), 1);
    corrFp = abs(corr(ts', fpRaw'))';

    kurt = kurtosis(ts, 1, 2)';

    projVar = sum(topo.^2, 1) .* var(ts, 0, 2)';
    varPct  = projVar / sum(projVar) * 100;

    % blink score: frontal, bilateral, tracks the frontal-polar signal
    score = frontal .* sym .* corrFp;
    [~, order] = sort(score, 'descend');

    fprintf('\n=== %s ===\n', subDir);
    fprintf('%5s %8s %6s %7s %7s %7s %7s\n', 'comp', 'frontal', 'sym', 'corrFp', 'kurt', 'var%', 'score');
    for k = 1:nCandidate
        c = order(k);
        fprintf('%5d %8.2f %6.2f %7.2f %7.1f %7.2f %7.2f\n', c, frontal(c), sym(c), corrFp(c), kurt(c), varPct(c), score(c));
    end

    %% zoomed figure of the top candidates
    f = figure('Visible', 'off', 'Position', [0 0 1800 300*nCandidate]);
    fs   = comp.fsample;
    win  = 1:min(size(ts,2), round(20*fs));            % first 20 s
    tWin = (win-1)/fs;
    for k = 1:nCandidate
        c = order(k);
        subplot(nCandidate, 4, (k-1)*4 + 1);
        cfg = [];
        cfg.component = c;
        cfg.layout    = fullfile(ftpath, 'template', 'layout', 'biosemi128.lay');
        cfg.comment   = 'no';
        cfg.figure    = 'gca';
        ft_topoplotIC(cfg, comp);
        title(sprintf('comp %d', c));

        subplot(nCandidate, 4, (k-1)*4 + (2:4));
        plot(tWin, ts(c, win), 'k'); hold on;
        plot(tWin, fpRaw(win) / std(fpRaw(win)) * std(ts(c, win)) - 4*std(ts(c, win)), 'Color', [0.8 0.3 0.3]);
        xlim([tWin(1) tWin(end)]);
        title(sprintf('comp %d  (black)  vs  frontal-polar raw (red)  |  frontal %.2f  sym %.2f  corrFp %.2f  kurt %.1f  var %.1f%%', ...
              c, frontal(c), sym(c), corrFp(c), kurt(c), varPct(c)));
        xlabel('time in first run (s)');
    end
    saveas(f, fullfile(outDir, subDir, [subDir '_ica_candidates.png']));
    close(f);

end
