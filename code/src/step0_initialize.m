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
