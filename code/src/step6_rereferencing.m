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

%% Save 
% save('sub-002_rereferenced.mat', 'data_ref', '-v7.3');