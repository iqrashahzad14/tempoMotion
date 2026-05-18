%% Preprocessing 

clear; 

%% 1. Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');   
ft_defaults;

%% 2. Define dataset and paths

projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion';

rawDir = fullfile(projectDir, 'inputs', 'raw');
outDir = fullfile(projectDir, 'outputs', 'preprocess');

subjects = {'sub-001','sub-002','sub-003'};

rawfile = fullfile(rawDir, subDir, [erase(subDir,'-') '.bdf']);

subOutDir = fullfile(outDir, subDir);
if ~exist(subOutDir, 'dir')
    mkdir(subOutDir);
end

%%
for s = 1:numel(subjects)

    subDir = subjects{s};

    fprintf('Processing %s\n', subDir);
    
    dataset = fullfile(rawDir, subDir, [erase(subDir,'-') '.bdf']);

    subOutDir = fullfile(outDir, subDir);
    if ~exist(subOutDir, 'dir')
        mkdir(subOutDir);
    end

    %% 3. import events and data, choose channel info
    cfg             = [];
    cfg.datafile    = rawfile;
    cfg.headerfile  = rawfile;
    cfg.channel     = 1:132;
    data         = ft_preprocessing(cfg);
    
    %% 4. Filtering 
    % Select channels 
    cfg = [];
    %{'A*','B*','C*','D*','EXG1','EXG2','EXG3','EXG4'}; %'all';
    
    cfg                     = [];
    cfg.lpfilter            = 'yes';
    cfg.lpfreq              = 45;
    cfg.lpfilttype          = 'but';
    cfg.lpfiltord           = 4;
    
    cfg.hpfilter            = 'yes';
    cfg.hpfreq              = 0.1;
    cfg.hpfilttype          = 'but';
    cfg.hpfiltord           = 4;
    
    data_filt = ft_preprocessing(cfg,data);
    
    %% 5. Epoching
    
    % Inspect events
    event = ft_read_event(rawfile);
    event_values = [event.value];
    disp(unique(event_values)');
    
    % Stimulus-locked epochs only
    visual_trigs = [65291 65292 65293 65294];   % 11 12 13 14
    tac_up_trigs = [65301 65302 65303 65304];   % 21 22 23 24
    tac_down_trigs = [65311 65312 65313 65314]; % 31 32 33 34
    target_trig   = [65295 65305 65315]; % 15 25 35
    stim_trigs = [visual_trigs tac_up_trigs tac_down_trigs target_trig];
    
    cfg = [];
    cfg.dataset = rawfile;
    
    cfg.trialdef.eventtype  = 'STATUS'; 
    cfg.trialdef.eventvalue = stim_trigs;
    
    cfg.trialdef.prestim    = 0.5;  % 500 ms before trigger
    cfg.trialdef.poststim   = 2.0;  % 2000 ms after trigger
    
    cfg = ft_definetrial(cfg);
    
    % Optional: store clean trigger codes in column 4: 11, 12, 13, etc.
    cfg.trl(:,4) = cfg.trl(:,4) - 65280;
    
    ind = find(ismember(cfg.trl(:,4),[15 25 35]));
    cfg.trl([ind-1,ind],:) = [];
    
    % Apply trial definition to filtered continuous data
    data_epoch = ft_redefinetrial(cfg, data_filt);
    
    %% 6. Baseline correction
    
    % Baseline: 500 ms before stimulus onset 

    cfg = [];
    cfg.demean = 'yes';
    cfg.baselinewindow = [-inf 0];
    
    data_base = ft_preprocessing(cfg, data_epoch);
    
    %% 7. Resampling
    
    cfg = [];
    cfg.resamplefs = 256;   % target sampling rate in Hz
    cfg.detrend    = 'no';
    
    data_resamp = ft_resampledata(cfg, data_base);
    
    %% 8. Artifact rejection: 
    
    %% ica

    if strcmp(subDir, 'sub-003')
        
    cfg = [];
    cfg.channel = {'A*','B*','C*','D*'};   % BioSemi 128 scalp channels
    data_ica_in = ft_selectdata(cfg, data_resamp);
    
    cfg = [];
    cfg.method = 'runica';
    cfg.channel = 'all';
    comp = ft_componentanalysis(cfg, data_ica_in);
    
    % Inspect ICA components
    
    figure;
    cfg = [];
    cfg.layout = '/Users/iqrashahzad/Documents/MATLAB/fieldtrip/template/layout/biosemi128.lay';
    cfg.viewmode = 'component';
    ft_databrowser(cfg, comp);
    
    % cfg = [];
    % cfg.component = 1:10;
    % cfg.layout = '/Users/iqrashahzad/Documents/MATLAB/fieldtrip/template/layout/biosemi128.lay';
    % ft_topoplotIC(cfg, comp);
    
    for tr = 1:length(comp.trial)
        for compo = 1:128
            c(compo,tr) = corr(comp.trial{tr}(compo,:)',data_resamp.trial{tr}(129,:)');
        end
    end
    
    % remove component
    cfg = [];
    cfg.component = [1];   % e.g. [1 3], fill in after inspection
    data_clean_ica = ft_rejectcomponent(cfg, comp, data_ica_in);

    % artifact rejection
    cfg = [];
    % Define threshold in microvolts
    cfg.artfctdef.threshold.channel = 'EEG';
    cfg.artfctdef.threshold.min     = -200;   % lower limit, µV
    cfg.artfctdef.threshold.max     = 200;    % upper limit, µV
    
    [cfg, artifact_threshold] = ft_artifact_threshold(cfg, data_clean_ica);
    
    % Reject trials containing threshold artifacts
    cfg.artfctdef.reject = 'complete';  % removes whole trials
    data_clean = ft_rejectartifact(cfg, data_clean_ica);

    end
    
    %% Option A: amplitude threshold
    
    cfg = [];
    
    % Define threshold in microvolts
    cfg.artfctdef.threshold.channel = 'EEG';
    cfg.artfctdef.threshold.min     = -200;   % lower limit, µV
    cfg.artfctdef.threshold.max     = 200;    % upper limit, µV
    
    [cfg, artifact_threshold] = ft_artifact_threshold(cfg, data_resamp);
    
    % Reject trials containing threshold artifacts
    cfg.artfctdef.reject = 'complete';  % removes whole trials
    data_clean = ft_rejectartifact(cfg, data_resamp);
    
    %% 9. Re-reference to average of all EEG channels
    
    cfg = [];
    cfg.reref      = 'yes';
    cfg.refchannel = 'all';   % average reference
    cfg.channel    = 'EEG';
    
    data_ref = ft_preprocessing(cfg, data_clean);
    
    %% Save final preprocessed EEG data
    save(fullfile(subOutDir, [subDir '_preprocessed.mat']), ...
             'data_ref', '-v7.3');

end
