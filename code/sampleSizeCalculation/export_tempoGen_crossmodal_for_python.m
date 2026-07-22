%% Export tempoGen_crossmodal per-subject data for the Python/cluster power analysis
%
% The saved per-subject .mat files use '-v7.3' (HDF5), which is awkward
% to parse from Python for deeply nested structs. This script loads them
% the normal MATLAB way, stacks each of the 12 target x variant x metric
% combinations into a plain (nSub, nTime, nTime) array, and re-saves
% everything into ONE flat '-v7' .mat file (not HDF5) that
% scipy.io.loadmat can read directly with no extra dependencies.
%
% Cheap/fast - no permutation testing, just loading and reshaping.
%
% Requires outputs/tempoGen_crossmodal/<sub>/<sub>_tempoGen_crossModal.mat
% for every subject. Writes outputs/sampleSizeCalculation/tempoGen_crossmodal/crossmodal_export.mat.

clear;

projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
tgDir      = fullfile(projectDir, 'outputs', 'tempoGen_crossmodal');
outDir     = fullfile(projectDir, 'outputs', 'sampleSizeCalculation', 'tempoGen_crossmodal');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(tgDir, subjects{s}, [subjects{s} '_tempoGen_crossModal.mat']), 'results');
    allResults{s} = loaded.results;
end

targetNames = fieldnames(allResults{1});
variants = {'a', 'b', 'both'};
metrics = {'acc', 'auc'};
timeVec = allResults{1}.(targetNames{1}).time;

exportData = struct(); %#ok<NASGU>
varNames = {};

for ti = 1:numel(targetNames)
    tgtName = targetNames{ti};
    for v = 1:numel(variants)
        variant = variants{v};
        for mi = 1:numel(metrics)
            metricName = metrics{mi};

            sz = size(allResults{1}.(tgtName).mean.(variant).(metricName));
            stack = zeros(nSub, sz(1), sz(2));
            for s = 1:nSub
                stack(s, :, :) = allResults{s}.(tgtName).mean.(variant).(metricName);
            end

            varName = sprintf('%s_%s_%s', tgtName, variant, metricName);
            exportData.(varName) = stack; %#ok<STRNU>
            varNames{end+1} = varName; %#ok<AGROW>
        end
    end
end

save(fullfile(outDir, 'crossmodal_export.mat'), '-struct', 'exportData', '-v7');
save(fullfile(outDir, 'crossmodal_export_meta.mat'), 'timeVec', 'subjects', 'varNames', '-v7');

fprintf('Exported %d combinations for tempoGen_crossmodal to %s\n', numel(varNames), outDir);
fprintf('Variables: %s\n', strjoin(varNames, ', '));
