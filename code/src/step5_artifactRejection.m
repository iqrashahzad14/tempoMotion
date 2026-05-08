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

cfg = [];
cfg.method = 'summary';

data_clean_visual = ft_rejectvisual(cfg, data_resamp);

%% Option C: Visual trial-by-trial inspection

cfg = [];
cfg.method = 'trial';

data_clean_trial = ft_rejectvisual(cfg, data_resamp);

%% Option D: Visual channel-by-channel inspection

cfg = [];
cfg.method = 'channel';

data_clean_channel = ft_rejectvisual(cfg, data_resamp);

%% Option E: Z-value artifact detection

cfg = [];
cfg.artfctdef.zvalue.channel = 'EEG';
cfg.artfctdef.zvalue.cutoff  = 4;
cfg.artfctdef.zvalue.trlpadding = 0;
cfg.artfctdef.zvalue.artpadding = 0.1;
cfg.artfctdef.zvalue.fltpadding = 0;

[cfg, artifact_zvalue] = ft_artifact_zvalue(cfg, data_resamp);

cfg.artfctdef.reject = 'complete';
data_clean_zvalue = ft_rejectartifact(cfg, data_resamp);

%% save
% save('sub-002_clean.mat', 'data_clean', '-v7.3');