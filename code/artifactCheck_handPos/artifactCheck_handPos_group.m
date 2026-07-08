%% Artifact follow-up: handPos effect - group level
%
% Loads each subject's saved per-channel Cohen's d topography (baseline
% window) and baseline-vs-post-stimulus decoding summary (see
% artifactCheck_handPos_subject.m), and:
%   A) averages the per-channel effect size across subjects and plots the
%      group topography.
%   B) averages baseline/post-stimulus accuracy & AUC across subjects,
%      runs a paired t-test (baseline vs. post) per band, and plots a bar
%      chart with individual-subject points.
%
% Requires outputs/artifactCheck_handPos/<sub>/<sub>_artifactCheck_handPos.mat
% for every subject.

clear;

%% Add FieldTrip (for the layout)
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;
[~, ftpath] = ft_version;
addpath(fileparts(mfilename('fullpath')));

%% Paths
projectDir  = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
inDir       = fullfile(projectDir, 'outputs', 'artifactCheck_handPos');
groupOutDir = fullfile(inDir, 'group');

%% Subjects
subjects = {'sub-001', 'sub-002', 'sub-003', 'sub-004', 'sub-005', 'sub-006'};
nSub = numel(subjects);

if ~exist(groupOutDir, 'dir')
    mkdir(groupOutDir);
end

%% Load all subjects
allResults = cell(1, nSub);
for s = 1:nSub
    loaded = load(fullfile(inDir, subjects{s}, [subjects{s} '_artifactCheck_handPos.mat']), 'results', 'bands');
    allResults{s} = loaded.results;
    if s == 1
        bands = loaded.bands;
    end
end
bandNames = {bands.name};

%% Layout
cfg = [];
cfg.layout = fullfile(ftpath, 'template', 'layout', 'biosemi128.lay');
layout = ft_prepare_layout(cfg);
keep = ~ismember(layout.label, {'COMNT', 'SCALE'});
layoutLabel = layout.label(keep);
layoutPos   = layout.pos(keep, :);

%% Part A: group-average topography
% Average per-channel Cohen's d across subjects (channel order is
% identical across subjects: the full 128-channel biosemi montage).
effectPerBand     = cell(1, numel(bandNames));
chanLabelsPerBand = cell(1, numel(bandNames));

for bi = 1:numel(bandNames)
    bandName = bandNames{bi};
    chanLabels = allResults{1}.(bandName).chanLabels;
    nChan = numel(chanLabels);

    dStack = zeros(nSub, nChan);
    for s = 1:nSub
        dStack(s, :) = allResults{s}.(bandName).cohend;
    end

    effectPerBand{bi} = mean(dStack, 1)';
    chanLabelsPerBand{bi} = chanLabels;
end

fn_plot_topo_effect(fullfile(groupOutDir, 'group_artifactCheck_topo.png'), ...
    bandNames, effectPerBand, chanLabelsPerBand, layoutLabel, layoutPos, ...
    sprintf('Group (N=%d) - tactile up vs down, baseline-window effect size', nSub));

%% Part B: baseline-vs-post-stimulus decoding, group stats
baselineAccStack = zeros(nSub, numel(bandNames)); postAccStack = zeros(nSub, numel(bandNames));
baselineAucStack = zeros(nSub, numel(bandNames)); postAucStack = zeros(nSub, numel(bandNames));

for s = 1:nSub
    bp = allResults{s}.baselineVsPost;
    baselineAccStack(s, :) = bp.baselineAcc;
    postAccStack(s, :)     = bp.postAcc;
    baselineAucStack(s, :) = bp.baselineAuc;
    postAucStack(s, :)     = bp.postAuc;
end

statsTable = struct();
fprintf('\n=== handPos: baseline vs. post-stimulus decoding (paired t-test, N=%d) ===\n', nSub);
for bi = 1:numel(bandNames)
    [~, pAcc, ~, statAcc] = ttest(baselineAccStack(:, bi), postAccStack(:, bi));
    [~, pAuc, ~, statAuc] = ttest(baselineAucStack(:, bi), postAucStack(:, bi));
    statsTable.(bandNames{bi}).acc_t = statAcc.tstat;
    statsTable.(bandNames{bi}).acc_p = pAcc;
    statsTable.(bandNames{bi}).auc_t = statAuc.tstat;
    statsTable.(bandNames{bi}).auc_p = pAuc;
    fprintf('%-14s acc: baseline=%.3f post=%.3f  t(%d)=%.2f p=%.3f | auc: baseline=%.3f post=%.3f  t(%d)=%.2f p=%.3f\n', ...
        bandNames{bi}, mean(baselineAccStack(:,bi)), mean(postAccStack(:,bi)), statAcc.df, statAcc.tstat, pAcc, ...
        mean(baselineAucStack(:,bi)), mean(postAucStack(:,bi)), statAuc.df, statAuc.tstat, pAuc);
end

f = figure('Visible', 'off');
subplot(1, 2, 1);
means = [mean(baselineAccStack, 1); mean(postAccStack, 1)]';
bar(means); hold on;
nB = numel(bandNames);
for bi = 1:nB
    xBase = bi - 0.15; xPost = bi + 0.15;
    plot(xBase*ones(nSub,1), baselineAccStack(:,bi), 'k.', 'MarkerSize', 10);
    plot(xPost*ones(nSub,1), postAccStack(:,bi), 'k.', 'MarkerSize', 10);
end
hold off;
set(gca, 'XTickLabel', bandNames);
ylabel('handPos accuracy'); ylim([0 1]); yline(0.5, 'k--');
legend({'baseline [-0.25 0]s', 'post-stim [0 1.5]s'}, 'Location', 'southoutside');
title('Accuracy');

subplot(1, 2, 2);
means = [mean(baselineAucStack, 1); mean(postAucStack, 1)]';
bar(means); hold on;
for bi = 1:nB
    xBase = bi - 0.15; xPost = bi + 0.15;
    plot(xBase*ones(nSub,1), baselineAucStack(:,bi), 'k.', 'MarkerSize', 10);
    plot(xPost*ones(nSub,1), postAucStack(:,bi), 'k.', 'MarkerSize', 10);
end
hold off;
set(gca, 'XTickLabel', bandNames);
ylabel('handPos AUC'); ylim([0 1]); yline(0.5, 'k--');
legend({'baseline [-0.25 0]s', 'post-stim [0 1.5]s'}, 'Location', 'southoutside');
title('AUC');

sgtitle(sprintf('Group (N=%d) - handPos decoding: baseline vs. post-stimulus', nSub), 'Interpreter', 'none');
set(f, 'Position', [0 0 900 500]);
saveas(f, fullfile(groupOutDir, 'group_artifactCheck_baselineVsPost.png'));
close(f);

save(fullfile(groupOutDir, 'group_artifactCheck_handPos.mat'), 'effectPerBand', 'chanLabelsPerBand', ...
    'baselineAccStack', 'postAccStack', 'baselineAucStack', 'postAucStack', 'statsTable', 'bandNames', '-v7.3');
fprintf('\nSaved group artifact-check results and plots to %s\n', groupOutDir);
