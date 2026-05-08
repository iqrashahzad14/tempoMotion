%% 6. Baseline correction

% Baseline: 500 ms before stimulus onset

cfg = [];
cfg.demean = 'yes';
cfg.baselinewindow = [-0.5 0];

data_base = ft_preprocessing(cfg, data_epoch);

%% Save
% save('sub-002_baselineCorrected.mat',   'data_epoch',  '-v7.3');