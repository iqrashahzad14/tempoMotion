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

%%

for s = 1:numel(subjects)

    subDir = subjects{s};

    fprintf('\n=============================\n');
    fprintf('Processing %s\n', subDir);
    fprintf('=============================\n');

    dataset = fullfile(rawDir, subDir, [erase(subDir,'-') '.bdf']);

    subOutDir = fullfile(outDir, subDir);
    if ~exist(subOutDir, 'dir')
        mkdir(subOutDir);
    end

    %% 3. Inspect header and events
    hdr = ft_read_header(dataset);
    disp(hdr)
    
    event = ft_read_event(dataset);
    disp(event(1:min(20,numel(event))))
    
    %% 4. Filtering 
    cfg = [];
    cfg.dataset = dataset;
    
    % Select channels 
    cfg.channel = {'A*','B*','C*','D*'}; %'all';
    
    % high-pass:  stable FIR,  default IIR
    cfg.hpfilter   = 'yes';
    cfg.hpfreq     = 0.5;
    cfg.hpfilttype = 'firws';
    cfg.hpfiltdir  = 'onepass-zerophase';
    
    % low-pass
    cfg.lpfilter   = 'yes';
    cfg.lpfreq     = 40;
    cfg.lpfilttype = 'firws';
    cfg.lpfiltdir  = 'onepass-zerophase';
    
    % notch / band-stop
    cfg.bsfilter   = 'yes';
    cfg.bsfreq     = [49 51];
    cfg.bsfilttype = 'firws';
    cfg.bsfiltdir  = 'onepass-zerophase';
    
    data_filt = ft_preprocessing(cfg);
    
    %% 5. Epoching
    
    % Inspect events
    event = ft_read_event(dataset);
    event_values = [event.value];
    disp(unique(event_values)');
    
    % Stimulus-locked epochs only
    % visual_trigs = [65291 65292 65293 65294];   % 11 12 13 14
    % tac_up_trigs = [65301 65302 65303 65304];   % 21 22 23 24
    % tac_down_trigs = [65311 65312 65313 65314]; % 31 32 33 34
    % stim_trigs = [visual_trigs tac_up_trigs tac_down_trigs];
    
    % Stimulus-locked and target epochs 
    visual_trigs = [65291 65292 65293 65294 65295];   % 11 12 13 14 15
    tac_up_trigs = [65301 65302 65303 65304 65305];   % 21 22 23 24 25
    tac_down_trigs = [65311 65312 65313 65314 65315]; % 31 32 33 34 35
    stim_target_trigs = [visual_trigs tac_up_trigs tac_down_trigs];
    
    % stimulus, target and response markers epochs
    % all_trigs = [65291 65292 65293 65294 65295 65296 ...
    %              65301 65302 65303 65304 65305 65306 ...
    %              65311 65312 65313 65314 65315 65316];
    
    cfg = [];
    cfg.dataset = dataset;
    
    cfg.trialdef.eventtype  = 'STATUS'; 
    cfg.trialdef.eventvalue = stim_target_trigs;
    
    cfg.trialdef.prestim    = 0.5;  % 500 ms before trigger
    cfg.trialdef.poststim   = 2.0;  % 2000 ms after trigger
    
    cfg = ft_definetrial(cfg);
    
    % Optional: store clean trigger codes in column 4: 11, 12, 13, etc.
    cfg.trl(:,4) = cfg.trl(:,4) - 65280;
    
    % Apply trial definition to filtered continuous data
    data_epoch = ft_redefinetrial(cfg, data_filt);
    
    %% 6. Baseline correction
    
    % Baseline: 500 ms before stimulus onset 
    
    cfg = [];
    cfg.demean = 'yes';
    cfg.baselinewindow = [-0.5 0];
    
    data_base = ft_preprocessing(cfg, data_epoch);
    
    %% 7. Resampling
    
    cfg = [];
    cfg.resamplefs = 500;   % target sampling rate in Hz
    cfg.detrend    = 'no';
    
    data_resamp = ft_resampledata(cfg, data_base);
    
    % Check sampling rate before/after:
    disp(data_base.fsample)
    disp(data_resamp.fsample)
    
    %% 8. Artifact rejection: 
    
    %% Option A: amplitude threshold
    
    cfg = [];
    
    % Define threshold in microvolts
    cfg.artfctdef.threshold.channel = 'EEG';
    cfg.artfctdef.threshold.min     = -100;   % lower limit, µV
    cfg.artfctdef.threshold.max     = 100;    % upper limit, µV
    
    [cfg, artifact_threshold] = ft_artifact_threshold(cfg, data_resamp);
    
    % Reject trials containing threshold artifacts
    cfg.artfctdef.reject = 'complete';  % removes whole trials
    data_clean = ft_rejectartifact(cfg, data_resamp);
    
    %% Option B: Visual summary rejection
    
    % cfg = [];
    % cfg.method = 'summary';
    % 
    % data_clean_visual = ft_rejectvisual(cfg, data_resamp);
    
    %% Option C: Visual trial-by-trial inspection
    
    % cfg = [];
    % cfg.method = 'trial';
    % 
    % data_clean_trial = ft_rejectvisual(cfg, data_resamp);
    
    %% Option D: Visual channel-by-channel inspection
    
    % cfg = [];
    % cfg.method = 'channel';
    % 
    % data_clean_channel = ft_rejectvisual(cfg, data_resamp);
    
    %% Option E: Z-value artifact detection
    
    % cfg = [];
    % cfg.artfctdef.zvalue.channel = 'EEG';
    % cfg.artfctdef.zvalue.cutoff  = 4;
    % cfg.artfctdef.zvalue.trlpadding = 0;
    % cfg.artfctdef.zvalue.artpadding = 0.1;
    % cfg.artfctdef.zvalue.fltpadding = 0;
    % 
    % [cfg, artifact_zvalue] = ft_artifact_zvalue(cfg, data_resamp);
    % 
    % cfg.artfctdef.reject = 'complete';
    % data_clean_zvalue = ft_rejectartifact(cfg, data_resamp);

    %% 9. Re-reference to average of all EEG channels
    
    cfg = [];
    cfg.reref      = 'yes';
    cfg.refchannel = 'all';   % average reference
    cfg.channel    = 'EEG';
    
    data_ref = ft_preprocessing(cfg, data_clean);
    
    %% option: reference to another channel
    % cfg = [];
    % cfg.reref      = 'yes';
    % cfg.refchannel = {'Cz'};
    % 
    % data_ref = ft_preprocessing(cfg, data_clean);

    %% Save final preprocessed EEG data
        save(fullfile(subOutDir, [subDir '_preprocessed.mat']), ...
         'data_ref', '-v7.3');

end


