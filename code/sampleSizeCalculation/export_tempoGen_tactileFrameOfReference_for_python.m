%% Export tempoGen_tactileFrameOfReference per-subject data for the Python/cluster power analysis
%
% Same purpose as export_tempoGen_crossmodal_for_python.m: flattens the
% per-subject '-v7.3' (HDF5) results into ONE plain '-v7' .mat file with
% one (nSub, nTime, nTime) array per decode x metric combination, so
% Python can load it directly via scipy.io.loadmat with no extra
% dependencies. Averages over the 20 decoding iterations per subject
% (same as stats_tempoGen_tactileFrameOfReference_group.m).
%
% Cheap/fast - no permutation testing, just loading and reshaping.
%
% Requires outputs/tempoGen_tactileFrameOfReference/<sub>/<sub>_tempoGen_tactileFoR.mat
% for every subject. Writes outputs/sampleSizeCalculation/tempoGen_tactileFrameOfReference/tactileFoR_export.mat.

clear;

projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir      = fullfile(projectDir, 'outputs', 'tempoGen_tactileFrameOfReference');
outDir     = fullfile(projectDir, 'outputs', 'sampleSizeCalculation', 'tempoGen_tactileFrameOfReference');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(tgDir, subjects{s}, [subjects{s} '_tempoGen_tactileFoR.mat']), 'results');
    allResults{s} = loaded.results;
end

decodeNames = fieldnames(allResults{1});
metrics = {'acc', 'auc'};
timeVec = allResults{1}.(decodeNames{1}).time;

exportData = struct(); %#ok<NASGU>
varNames = {};

for d = 1:numel(decodeNames)
    dcName = decodeNames{d};
    nTime = size(allResults{1}.(dcName).acc, 2);

    for mi = 1:numel(metrics)
        metricName = metrics{mi};

        stack = zeros(nSub, nTime, nTime);
        for s = 1:nSub
            stack(s, :, :) = squeeze(mean(allResults{s}.(dcName).(metricName), 1)); % average over iterations
        end

        varName = sprintf('%s_%s', dcName, metricName);
        exportData.(varName) = stack; %#ok<STRNU>
        varNames{end+1} = varName; %#ok<AGROW>
    end
end

save(fullfile(outDir, 'tactileFoR_export.mat'), '-struct', 'exportData', '-v7');
save(fullfile(outDir, 'tactileFoR_export_meta.mat'), 'timeVec', 'subjects', 'varNames', '-v7');

fprintf('Exported %d combinations for tempoGen_tactileFrameOfReference to %s\n', numel(varNames), outDir);
fprintf('Variables: %s\n', strjoin(varNames, ', '));
