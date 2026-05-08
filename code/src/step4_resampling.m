%% 7. Resampling

cfg = [];
cfg.resamplefs = 500;   % target sampling rate in Hz
cfg.detrend    = 'no';

data_resamp = ft_resampledata(cfg, data_base);

% Check sampling rate before/after:
disp(data_base.fsample)
disp(data_resamp.fsample)

%% Save
% save('sub-002_resampled.mat',   'data_epoch',  '-v7.3');