%% Pre-check of the stimulus triggers before preprocessing (read-only)
% Splits the stimulus triggers into runs exactly as preprocess_bandstop45.m
% does (new run where consecutive stimulus triggers are > 5 s apart) and
% reports, per subject: number of runs, triggers per run, first/last trigger
% of each run, runs with < 50 triggers (stray triggers, as in sub-013),
% runs that start with a target trigger (15/25/35, which crash the
% target-removal step), and the number of stimulus trials per condition
% after removing the target trials (expected 120 each).
% Subjects are set with the environment variable CHECK_SUBJECTS
% (e.g. CHECK_SUBJECTS=sub-014,sub-015). inputs/ is only read.

clear;
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;

projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
rawDir     = fullfile(projectDir, 'inputs', 'raw');
subjects   = strsplit(getenv('CHECK_SUBJECTS'), ',');

stimTrigs   = [65291:65294 65301:65304 65311:65314 65295 65305 65315];
targetCodes = [15 25 35];
condCodes   = [11:14 21:24 31:34];

for s = 1:numel(subjects)
    sub = subjects{s};
    f   = fullfile(rawDir, sub, [erase(sub, '-') '.bdf']);
    hdr = ft_read_header(f);
    ev  = ft_read_event(f);
    % select stimulus events one by one (as the preprocessing does), so that
    % values and samples stay aligned even if some events have an empty value
    k   = arrayfun(@(e) isnumeric(e.value) && isscalar(e.value) && ismember(e.value, stimTrigs), ev);
    v   = [ev(k).value] - 65280; smp = [ev(k).sample];
    fprintf('%s: %d events in file, %d with an empty/non-numeric value\n', sub, numel(ev), sum(arrayfun(@(e) ~isnumeric(e.value) || isempty(e.value), ev)));

    breaks = [0 find(diff(smp) > hdr.Fs * 5) numel(v)];
    fprintf('\n=== %s: %d stimulus triggers, %d runs ===\n', sub, numel(v), numel(breaks) - 1);
    nStray = 0; nTargetStart = 0; kept = [];
    for r = 1:numel(breaks) - 1
        idx = breaks(r) + 1:breaks(r + 1);
        c   = v(idx);
        flag = '';
        if numel(idx) < 50, flag = [flag ' <-- STRAY (< 50 triggers)']; nStray = nStray + 1; end
        if ismember(c(1), targetCodes), flag = [flag ' <-- STARTS WITH TARGET']; nTargetStart = nTargetStart + 1; end
        fprintf('  run %2d: %3d triggers, start %7.1f s, first %s, last %d%s\n', r, numel(idx), smp(idx(1)) / hdr.Fs, ...
            mat2str(c(1:min(3, end))), c(end), flag);
        % same target removal as the preprocessing (target + the trial before it)
        t = find(ismember(c, targetCodes));
        drop = unique([t t - 1]); drop = drop(drop >= 1);
        keep = c; keep(drop) = [];
        kept = [kept keep]; %#ok<AGROW>
    end
    counts = arrayfun(@(cc) sum(kept == cc), condCodes);
    fprintf('  trials per condition after target removal: %s\n', strjoin(arrayfun(@(cc, n) sprintf('%d:%d', cc, n), condCodes, counts, 'UniformOutput', false), ' '));
    fprintf('  SUMMARY %s: runs=%d stray=%d targetStart=%d minCond=%d maxCond=%d\n', sub, numel(breaks) - 1, nStray, nTargetStart, min(counts), max(counts));
end
