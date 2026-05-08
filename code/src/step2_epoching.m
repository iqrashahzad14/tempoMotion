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

% stimulus,  target and response markers
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

%% save 
% save('sub-002_epoched.mat',   'data_epoch',  '-v7.3');