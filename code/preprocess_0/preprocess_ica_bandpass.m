%% Preprocessing _ica_bandstop

clear;

%% Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');   
ft_defaults;

%% Define dataset and paths

projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';

rawDir = fullfile(projectDir, 'inputs', 'raw');
outDir = fullfile(projectDir, 'outputs', 'preprocess');

%% Define subject interactively

% subNum = input('Enter subject number, e.g. 4 for sub-004: ');
% subDir = sprintf('sub-%03d', subNum);

subDir = 'sub-006'; 

%%
% s=1;
% subDir = subjects{s};

rawfile = fullfile(rawDir, subDir, [erase(subDir,'-') '.bdf']);
subOutDir = fullfile(outDir, subDir);
if ~exist(subOutDir, 'dir')
    mkdir(subOutDir);
end

fprintf('Processing %s\n', subDir);

dataset = fullfile(rawDir, subDir, [erase(subDir,'-') '.bdf']);

subOutDir = fullfile(outDir, subDir);
if ~exist(subOutDir, 'dir')
    mkdir(subOutDir);
end

%% 
% import events and data, choose channel info
cfg             = [];
cfg.datafile    = rawfile;
cfg.headerfile  = rawfile;
cfg.channel     = 1:132;
data            = ft_preprocessing(cfg);

% High pass - Filtering
% Select channels
cfg = [];
cfg.hpfilter            = 'yes';
cfg.hpfreq              = 0.5;
cfg.hpfilttype          = 'but';
cfg.hpfiltord           = 4;
cfg.bpfilter            = 'yes';
cfg.bpfreq              = [49 52];
cfg.bpfilttype          = 'but';
cfg.bpfiltord           = 4;

data_filt = ft_preprocessing(cfg,data);

%% Epoching and concatenate runs

event = ft_read_event(rawfile);

event_values = ({event.value});
event_sample = ({event.sample});

% Stimulus-locked epochs only
visual_trigs = [65291 65292 65293 65294];   % 11 12 13 14
tac_up_trigs = [65301 65302 65303 65304];   % 21 22 23 24
tac_down_trigs = [65311 65312 65313 65314]; % 31 32 33 34
target_trig   = [65295 65305 65315]; % 15 25 35
stim_trigs = [visual_trigs tac_up_trigs tac_down_trigs target_trig];

ind = find(cellfun(@(c) any(ismember(c, stim_trigs)), event_values));
event_samplemat = cell2mat(event_sample(ind));
event_valuesmat = cell2mat(event_values(ind));

diff = event_samplemat(2:end) - event_samplemat(1:end-1);

gaplength = data_filt.fsample*5;
prestim = 0.25;
poststim = 1.5;

run_end   = [event_samplemat(find(diff > gaplength))  event_samplemat(end)] + (data_filt.fsample*poststim); % 2seconds after last trigger
run_start = [event_samplemat(1) event_samplemat(find(diff > gaplength)+1)]  - (data_filt.fsample*prestim); %0.5 seconds before first trigger

data_runs = [];
cfg = [];
cfg.trl = [run_start; run_end; ones(1,length(run_start)).* -(data_filt.fsample*prestim)]';
data_runs = ft_redefinetrial(cfg,data_filt);

%% adjust trigger information

epoch_info = [];
for run = 1:numel(run_start)
    ind = find(event_samplemat >= run_start(run) & event_samplemat <= run_end(run));
    epoch_info{run}(:,1) = event_samplemat(ind) - (data_filt.fsample*prestim)-1; %onset
    epoch_info{run}(:,2) = event_samplemat(ind) + (data_filt.fsample*poststim); %offset
    epoch_info{run}(:,3) = ones(1,numel(event_valuesmat(ind))).* - (data_filt.fsample*prestim);
    epoch_info{run}(:,4) = event_valuesmat(ind) - 65280;

    % delete the extra trigger during targets
    ind = find(ismember(epoch_info{run}(:,4),[15 25 35]));
    epoch_info{run}([ind-1;ind],:) = [];
end

%% resampling

cfg = [];
cfg.resamplefs = 256;   % target sampling rate in Hz
cfg.detrend    = 'no';
cfg.keepsampleinfo = 'yes';
data_resamp = ft_resampledata(cfg, data_runs);

epoch_info_resamp = epoch_info;
for run = 1:numel(epoch_info)
    for col = 1:3
        epoch_info_resamp{run}(:,col) = floor(epoch_info{run}(:,col) * cfg.resamplefs / data_runs.fsample);
    end
    % make sure all trials are same length
    mn = min(epoch_info_resamp{run}(:,2) - epoch_info_resamp{run}(:,1));
    ind = find(epoch_info_resamp{run}(:,2) - epoch_info_resamp{run}(:,1)>mn);
    epoch_info_resamp{run}(ind,2) = epoch_info_resamp{run}(ind,2)-1;
end

%% ica
cfg = [];
cfg.channel = {'A*','B*','C*','D*'};   % BioSemi 128 scalp channels
data_ica_in = ft_selectdata(cfg, data_resamp);

cfg = [];
cfg.method = 'runica';
cfg.channel = 'all';
comp = ft_componentanalysis(cfg, data_ica_in);

%% view comp

figure;
cfg = [];
% cfg.layout = fullfile(ftpath,'/template/layout/biosemi128.lay');
cfg.layout = '/Users/iqrashahzad/Documents/MATLAB/fieldtrip/template/layout/biosemi128.lay';
cfg.viewmode = 'component';
ft_databrowser(cfg, comp);

%% correlation with the occulomotor channels
% for tr = 1:length(comp.trial)
%     for compo = 1:128
%         c(compo,tr) = corr(comp.trial{tr}(compo,:)',data_resamp.trial{tr}(131,:)');
%     end
% end
% 
% figure;
% bar(mean(c,2));

%% %% Define ICA component interactively and remove component

% icaComp = input('Enter ICA component(s) to remove, e.g. [1] or [1 3]: ');

cfg = [];

% fill in after inspection
% sub-1: [2]; sub-2: [3]; sub-3: [1]; sub-4: [5];
% sub-5: [1]; sub-6: [1];

cfg.component = [1];    %e.g. [1 3]
data_clean_ica = ft_rejectcomponent(cfg, comp, data_ica_in);

% cfg.component = icaComp;
% data_clean_ica = ft_rejectcomponent(cfg, comp, data_ica_in);

%% lpf
cfg            = [];
cfg.lpfilter   = 'yes';
cfg.lpfreq     = 45;
cfg.lpfilttype = 'but';
cfg.lpfiltord  = 4;

data_filt_lpf = ft_preprocessing(cfg,data_clean_ica);

%% Re-reference to average of all EEG channels

cfg = [];
cfg.reref      = 'yes';
cfg.refchannel = 'all';   % average reference
cfg.channel    = 'EEG';

data_ref = ft_preprocessing(cfg, data_filt_lpf);

%% epoch trials

data_ref = rmfield(data_ref,"sampleinfo");
epoch_info_resamp2 = epoch_info_resamp;
for run = 1:numel(data_ref.trial)

    epoch_info_resamp2{run}(:,1) = epoch_info_resamp{run}(:,1) - (epoch_info_resamp{run}(1,1)-1);
    epoch_info_resamp2{run}(:,2) = epoch_info_resamp{run}(:,2) - (epoch_info_resamp{run}(1,1));

    cfg = [];
    cfg.trl = epoch_info_resamp2{run};
    cfg.trials = run;
    data_tmp{run} = ft_redefinetrial(cfg, data_ref);

end

cfg = [];
cfg.keepsampleinfo = 'no';
data_epoch = ft_appenddata(cfg,data_tmp{:});

%% Baseline correction

% Baseline: 250 ms before stimulus onset

cfg = [];
cfg.demean = 'yes';
cfg.baselinewindow = [-inf 0];

data_base = ft_preprocessing(cfg, data_epoch);

%% artifact rejection
cfg = [];
% Define threshold in microvolts
cfg.artfctdef.threshold.channel = 'EEG';
cfg.artfctdef.threshold.min     = -100;   % lower limit, µV
cfg.artfctdef.threshold.max     = 100;    % upper limit, µV

[cfg, artifact_threshold] = ft_artifact_threshold(cfg, data_base);

% Reject trials containing threshold artifacts
cfg.artfctdef.reject = 'complete';  % removes whole trials
data_clean = ft_rejectartifact(cfg, data_base);

%% Save final preprocessed EEG data
save(fullfile(subOutDir, [subDir '_preprocessed.mat']), ...
    'data_clean', '-v7.3');
