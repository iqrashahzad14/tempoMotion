%% preprocess

filename 'sub-001.bdf';

cfg = [];
cfg.dataset = filename;
cfg.trialdef.eventtype  = 'STATUS'
cfg.trialdef.eventvalue = [1 2];
cfg.trialdef.prestim    = 0.2;
cfg.trialdef.poststim   = 0.8;
cfg = ft_definetrial(cfg);

cfg.reref = 'yes';
cfg.refchannel = 'A1';
cfg.demean = 'yes';
cfg.baselinewindow = [-0.2 0];
data = ft_preprocessing(cfg);

cfg = [];
timelock = ft_timelockanalysis(cfg, data);