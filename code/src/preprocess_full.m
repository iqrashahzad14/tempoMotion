%% preprocessing 
clear; 

%% 1. Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');   
ft_defaults;

%% 2. Define dataset and paths

rawDir ='/Users/iqrashahzad/Files/eeg/tempoMotion/inputs/raw';

subjects = {'sub-001','sub-002','sub-003'};

subDir = 'sub-002';

dataset = fullfile(rawDir, subDir, 'sub002.bdf');

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

% save('sub-002_filtered.mat', 'data_filt', '-v7.3');