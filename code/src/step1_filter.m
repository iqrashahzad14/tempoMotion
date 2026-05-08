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

%% Save
% save('sub-002_filtered.mat', 'data_filt', '-v7.3');
